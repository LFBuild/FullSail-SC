/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module governance::voter {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use sui::table::{Self, Table};
    use sui::linked_table::{Self, LinkedTable};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{VecMap};
    use std::type_name::{Self, TypeName};
    use governance::distribution_config::{DistributionConfig};
    
    const ECreateVoterInvalidPublisher: u64 = 831911472280262500;
    const ESetVotingEscrowCapInvalidPublisher: u64 = 180901439185181760;

    const EDepositManagedEpochVoteEnded: u64 = 922337530103326315;
    const EDepositManagedVotingEscrowCapNotSet: u64 = 742033984283866600;

    const EWithdrawManagedInvalidManaged: u64 = 922337537833933209;
    const EWithdrawManagedVotingEscrowCapNotSet: u64 = 445278511513513150;

    const EAddEpochGovernorInvalidGovernor: u64 = 922337326521692981;

    const ERevokeGaugeCreateCapInvalidPublisher: u64 = 740613477966525400;

    const EAddGovernorInvalidPublisher: u64 = 155939257957301570;

    const ERevokeGaugeCreateCapAlreadyRevoked: u64 = 525186290931396700;

    const EVotingNotStarted: u64 = 922337333393679977;

    const ECheckVoteSizesDoNotMatch: u64 = 922337416286430823;
    const ECheckVoteVolumeSizeDoNotMatch: u64 = 379359304918467140;
    const ECheckVoteMaxVoteNumExceed: u64 = 922337416716058627;
    const ECheckVoteGaugeNotFound: u64 = 922337418433927579;
    const ECheckVoteWeightTooLarge: u64 = 922337418863437416;

    const ECreateGaugeInvalidCreateCap: u64 = 951701448926939500;
    const ECreateGaugeDistributionConfigInvalid: u64 = 922337388798568038;
    const ECreateGaugeVotingEscrowInvalidVoter: u64 = 247841512148847520;
    const ECreateGaugePoolAlreadyHasGauge: u64 = 379600280551732200;

    const EGetVotesNotVoted: u64 = 922337561885750067;

    const EPokeVotingNotStartedYet: u64 = 922337443344842755;
    const EPokeLockNotVoted: u64 = 922337451075875639;
    const EPokePoolNotVoted: u64 = 922337452793862558;

    const ETokenNotWhitelisted: u64 = 922337385362594201;

    const EReceiveGaugePoolAreadyHasGauge: u64 = 922337372477987230;

    const ERemoveEpochGovernorNotAGovernor: u64 = 922337331246157007;

    const ERemoveGovernorInvalidPublisher: u64 = 774314565719218300;

    const ESetMaxVotingNumGovernorInvalid: u64 = 922337318361255119;
    const ESetMaxVotingNumAtLeast10: u64 = 922337318790764956;
    const ESetMaxVotingNumNotChanged: u64 = 922337319649594572;

    const EVoteVotingEscrowDeactivated: u64 = 922337463101718531;
    const EVoteNotWhitelistedNft: u64 = 922337464819718557;
    const EVoteNoVotingPower: u64 = 922337468685202231;

    const EVoteInternalVotingEscrowCapNotSet: u64 = 120698940230993040;
    const EVoteInternalGaugeDoesNotExist: u64 = 922337479851920589;
    const EVoteInternalGaugeNotAlive: u64 = 922337480710992693;
    const EVoteInternalPoolAreadyVoted: u64 = 922337483288104144;
    const EVoteInternalWeightResultedInZeroVotes: u64 = 922337484147110711;

    const EDistributeGaugeInvalidToken: u64 = 727114932399146200;
    const EDistributeGaugeInvalidPool: u64 = 922337598392972083;
    const EDistributeGaugeGaugeIsKilled: u64 = 519025590138764600;
    const EAdjustGaugeGaugeIsKilled: u64 = 855951837524523600;

    const EWhitelistNftGovernorInvalid: u64 = 922337395670666447;

    const EWhitelistTokenGovernorInvalid: u64 = 922337389657712232;

    const EResetVotingEscrowCapNotSet: u64 = 466338960180442200;

    /// Module identifier for the Voter module
    public struct VOTER has drop {}

    /// Represents a pool ID wrapper with copy, drop, and store abilities
    public struct PoolID has copy, drop, store {
        id: ID,
    }

    /// Represents a lock ID wrapper with copy, drop, and store abilities
    public struct LockID has copy, drop, store {
        id: ID,
    }

    /// Represents a gauge ID wrapper with copy, drop, and store abilities
    public struct GaugeID has copy, drop, store {
        id: ID,
    }

    /// Hold lock's vote for a pool and it's volume
    public struct VolumeVote has drop, store {
        volume: u64, // us dollars, decimals 6
        votes: u64, // according to the voting power of the lock and the weight of the pool
    }

    public struct Voter has store, key {
        id: UID,
        global_config: ID,
        distribution_config: ID,
        revoked_gauge_create_caps: VecSet<ID>,
        governors: VecSet<ID>,
        epoch_governors: VecSet<ID>,
        used_weights: Table<LockID, u64>,
        pools: vector<PoolID>,
        pool_to_gauger: Table<PoolID, GaugeID>,
        votes: Table<LockID, Table<PoolID, VolumeVote>>,
        weights: Table<GaugeID, u64>,
        epoch: u64,
        voter_cap: governance::voter_cap::VoterCap,
        balances: sui::bag::Bag,
        // it is supposed that only one coin type is distributed per epoch.
        // This allows us to optimize calculations, as we don't need to iterate over old coins.
        // Is undefined if distribution has not started
        current_epoch_token: Option<TypeName>,
        // the history of all coins that were distributed. In case we need to iterate over them to calculate rewards.
        // Linked table cos we probably need both to check if a sertain coin was used as reward and to iterate.
        reward_tokens: LinkedTable<TypeName, bool>,
        whitelisted_manager: voting_escrow::whitelisted_tokens::WhitelistManager,
        whitelisted_manager_cap: voting_escrow::whitelisted_tokens::WhitelistManagerCap,
        is_whitelisted_nft: Table<LockID, bool>,
        max_voting_num: u64,
        last_voted: Table<LockID, u64>,
        pool_vote: Table<LockID, vector<PoolID>>,
        gauge_to_fee: Table<GaugeID, governance::fee_voting_reward::FeeVotingReward>,
        exercise_fee_reward: governance::exercise_fee_reward::ExerciseFeeReward,
        voting_escrow_cap: Option<voting_escrow::voting_escrow_cap::VotingEscrowCap>,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public struct EventNotifyEpochToken has copy, drop, store {
        notifier: ID,
        token: TypeName,
    }

    /// Event emitted when an NFT is whitelisted or de-whitelisted
    public struct EventWhitelistNFT has copy, drop, store {
        sender: address,
        id: ID,
        listed: bool,
    }

    /// Event emitted when a user casts a vote
    public struct EventVoted has copy, drop, store {
        sender: address,
        pool: ID,
        lock: ID,
        voting_weight: u64,
        volume: u64,
        pool_weight: u64,
    }

    /// Event emitted when a user abstains from voting
    public struct EventAbstained has copy, drop, store {
        sender: address,
        pool: ID,
        lock: ID,
        votes: u64,
        pool_weight: u64,
    }

    /// Event emitted when a governor is added
    public struct EventAddGovernor has copy, drop, store {
        who: address,
        cap: ID,
    }

    /// Event emitted when a governor is removed
    public struct EventRemoveGovernor has copy, drop, store {
        cap: ID,
    }

    /// Event emitted when an epoch governor is added
    public struct EventAddEpochGovernor has copy, drop, store {
        who: address,
        cap: ID,
    }

    /// Event emitted when an epoch governor is removed
    public struct EventRemoveEpochGovernor has copy, drop, store {
        cap: ID,
    }

    /// Event emitted when a voting fee reward is claimed
    public struct EventClaimVotingFeeReward has copy, drop, store {
        who: address,
        amount: u64,
        pool: ID,
        gauge: ID,
        token: TypeName,
        lock: ID,
    }

    /// Event emitted when an exercise oSAIL fee reward is claimed
    public struct EventClaimExerciseFeeReward has copy, drop, store {
        who: address,
        amount: u64,
        token: TypeName,
        lock: ID,
        sail_claim: bool,
    }

    /// Event emitted when rewards are distributed to a gauge
    public struct EventDistributeGauge has copy, drop, store {
        pool: ID,
        gauge: ID,
        fee_a_amount: u64,
        fee_b_amount: u64,
        usd_amount: u64,
        ended_epoch_o_sail_emission: u64,
    }

    /// Creates a new Voter contract.
    /// 
    /// # Arguments
    /// * `publisher` - The publisher of the package
    /// * `global_config` - The ID of the global configuration
    /// * `distribution_config` - The ID of the distribution configuration
    /// * `supported_coins` - List of initially supported token types
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A new Voter instance and a NotifyRewardCap for reward notification
    public fun create(
        publisher: &sui::package::Publisher,
        global_config: ID,
        distribution_config: ID,
        ctx: &mut TxContext
    ): (Voter, governance::distribute_cap::DistributeCap) {
        assert!(publisher.from_module<VOTER>(), ECreateVoterInvalidPublisher);
        let uid = object::new(ctx);
        let id = *object::uid_as_inner(&uid);
        let (whitelisted_manager, whitelisted_manager_cap) = voting_escrow::whitelisted_tokens::create(id, ctx);
        let voter = Voter {
            id: uid,
            global_config,
            distribution_config,
            revoked_gauge_create_caps: vec_set::empty<ID>(),
            governors: vec_set::empty<ID>(),
            epoch_governors: vec_set::empty<ID>(),
            used_weights: table::new<LockID, u64>(ctx),
            pools: std::vector::empty<PoolID>(),
            pool_to_gauger: table::new<PoolID, GaugeID>(ctx),
            votes: table::new<LockID, Table<PoolID, VolumeVote>>(ctx),
            weights: table::new<GaugeID, u64>(ctx),
            epoch: 0,
            voter_cap: governance::voter_cap::create_voter_cap(id, ctx),
            balances: sui::bag::new(ctx),
            current_epoch_token: option::none<TypeName>(),
            reward_tokens: linked_table::new<TypeName, bool>(ctx),
            whitelisted_manager,
            whitelisted_manager_cap,
            is_whitelisted_nft: table::new<LockID, bool>(ctx),
            max_voting_num: 20,
            last_voted: table::new<LockID, u64>(ctx),
            pool_vote: table::new<LockID, vector<PoolID>>(ctx),
            gauge_to_fee: table::new<GaugeID, governance::fee_voting_reward::FeeVotingReward>(ctx),
            exercise_fee_reward: governance::exercise_fee_reward::create(id, vector[], ctx),
            voting_escrow_cap: option::none(),
            // bag to be preapred for future updates
            bag: sui::bag::new(ctx),
        };
        let distribute_cap = governance::distribute_cap::create_internal(id, ctx);
        (voter, distribute_cap)
    }

    public fun set_voting_escrow_cap(
        voter: &mut Voter,
        publisher: &sui::package::Publisher,
        voting_escrow_cap: voting_escrow::voting_escrow_cap::VotingEscrowCap
    ) {
        assert!(publisher.from_module<VOTER>(), ESetVotingEscrowCapInvalidPublisher);
        voter.voting_escrow_cap.fill(voting_escrow_cap);
    }

    /// Deposits a managed lock into the voting escrow system.
    /// This function allows a user to deposit their lock to be managed by another lock,
    /// enabling delegation of voting power.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration reference
    /// * `lock` - The owner's lock
    /// * `managed_lock` - The manager's lock that will control the voting
    /// * `clock` - The system clock for time-based validation
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the voter has already voted in the current epoch
    /// * If the current time is after the epoch voting end time
    public fun deposit_managed<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock: &mut voting_escrow::voting_escrow::Lock,
        managed_lock: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let lock_id = into_lock_id(object::id<voting_escrow::voting_escrow::Lock>(lock));
        voter.assert_only_new_epoch(lock_id, clock);
        assert!(voter.voting_escrow_cap.is_some(), EDepositManagedVotingEscrowCapNotSet);
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(current_time <= voting_escrow::common::epoch_vote_end(current_time), EDepositManagedEpochVoteEnded);
        if (voter.last_voted.contains(lock_id)) {
            voter.last_voted.remove(lock_id);
        };
        voter.last_voted.add(lock_id, current_time);
        voting_escrow.deposit_managed(voter.voting_escrow_cap.borrow(), lock, managed_lock, clock, ctx);
        let balance = voting_escrow.balance_of_nft_at(lock_id.id, current_time);
        let managed_lock_id = into_lock_id(object::id(managed_lock));
        voter.poke_internal(voting_escrow, distribution_config, managed_lock_id, balance, clock, ctx);
    }

    /// Withdraws a previously deposited managed lock from the voting escrow system.
    /// This function reverts the delegation of voting power.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration reference
    /// * `lock` - The owner's lock
    /// * `managed_lock` - The manager's lock that was controlling the voting
    /// * `clock` - The system clock for time-based validation
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the voter has already voted in the current epoch
    /// * If the managed lock ID doesn't match the expected ID
    public fun withdraw_managed<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock: &mut voting_escrow::voting_escrow::Lock,
        managed_lock: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let lock_id = into_lock_id(object::id<voting_escrow::voting_escrow::Lock>(lock));
        voter.assert_only_new_epoch(lock_id, clock);
        assert!(voter.voting_escrow_cap.is_some(), EWithdrawManagedVotingEscrowCapNotSet);
        let managedd_lock_id = voting_escrow.id_to_managed(lock_id.id);
        assert!(
            managedd_lock_id == object::id<voting_escrow::voting_escrow::Lock>(managed_lock),
            EWithdrawManagedInvalidManaged
        );
        // voting_escrow.validate_ownership(lock, ctx);
        voting_escrow.withdraw_managed(voter.voting_escrow_cap.borrow(), lock, managed_lock, clock, ctx);
        let balance_of_nft = voting_escrow.balance_of_nft_at(
            managedd_lock_id,
            voting_escrow::common::current_timestamp(clock)
        );
        let managed_lock_id = into_lock_id(object::id(managed_lock));
        if (balance_of_nft == 0) {
            voter.reset_internal(voting_escrow, distribution_config, managed_lock_id, clock, ctx);
            if (voter.last_voted.contains(into_lock_id(managedd_lock_id))) {
                voter.last_voted.remove(into_lock_id(managedd_lock_id));
            };
        } else {
            voter.poke_internal(voting_escrow, distribution_config, managed_lock_id, balance_of_nft, clock, ctx);
        };
    }

    /// Adds an epoch governor to the system. Epoch governors have restricted 
    /// permissions compared to regular governors and can only manage specific
    /// operations within an epoch.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `who` - The address of the new epoch governor
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the caller is not a governor
    /// * If the governor capability doesn't match the voter ID
    public fun add_epoch_governor(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        governor_cap: &governance::voter_cap::GovernorCap,
        who: address,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        assert!(
            voter.is_governor(object::id<governance::voter_cap::GovernorCap>(governor_cap)),
            EAddEpochGovernorInvalidGovernor
        );
        governor_cap.validate_governor_voter_id(object::id<Voter>(voter));
        let epoch_governor_cap = governance::voter_cap::create_epoch_governor_cap(
            object::id<Voter>(voter),
            ctx
        );
        let epoch_governor_cap_id = object::id<governance::voter_cap::EpochGovernorCap>(&epoch_governor_cap);
        transfer::public_transfer<governance::voter_cap::EpochGovernorCap>(epoch_governor_cap, who);
        voter.epoch_governors.insert<ID>(epoch_governor_cap_id);
        let add_epoch_governor_event = EventAddEpochGovernor {
            who,
            cap: epoch_governor_cap_id,
        };
        sui::event::emit<EventAddEpochGovernor>(add_epoch_governor_event);
    }

    /// Revokes a gauge create cap.
    /// Supposed to be used in emergency case when the gauge create cap is compromised.
    public fun revoke_gauge_create_cap(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        publisher: &sui::package::Publisher,
        create_cap_id: ID
    ) {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<VOTER>(), ERevokeGaugeCreateCapInvalidPublisher);
        assert!(
            !voter.revoked_gauge_create_caps.contains(&create_cap_id),
            ERevokeGaugeCreateCapAlreadyRevoked
        );

        voter.revoked_gauge_create_caps.insert<ID>(create_cap_id);
    }

    public fun is_valid_gauge_create_cap(
        voter: &Voter,
        create_cap: &gauge_cap::gauge_cap::CreateCap
    ): bool {
        let cap_id = object::id<gauge_cap::gauge_cap::CreateCap>(create_cap);
        !voter.revoked_gauge_create_caps.contains(&cap_id)
    }

    /// Adds a governor to the system. Governors have the highest level of 
    /// permissions and can perform administrative operations.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `publisher` - The publisher of the package
    /// * `who` - The address of the new governor
    /// * `ctx` - The transaction context
    ///
    /// # Emits
    /// * `EventAddGovernor` when a governor is added
    public fun add_governor(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        publisher: &sui::package::Publisher,
        who: address,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<VOTER>(), EAddGovernorInvalidPublisher);
        let governor_cap = governance::voter_cap::create_governor_cap(
            object::id<Voter>(voter),
            who,
            ctx
        );
        let governor_cap_id = object::id<governance::voter_cap::GovernorCap>(&governor_cap);
        voter.governors.insert<ID>(governor_cap_id);
        transfer::public_transfer<governance::voter_cap::GovernorCap>(governor_cap, who);
        let add_governor_event = EventAddGovernor {
            who,
            cap: governor_cap_id,
        };
        sui::event::emit<EventAddGovernor>(add_governor_event);
    }

    /// Internal function to assert that an operation is being performed
    /// in a new epoch for a given lock. Prevents duplicate votes within
    /// the same epoch.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock
    /// * `clock` - The system clock for time-based validation
    ///
    /// # Aborts
    /// * If the lock has already voted in the current epoch
    /// * If voting for the current epoch hasn't started yet
    fun assert_only_new_epoch(_: &Voter, _: LockID, clock: &sui::clock::Clock) {
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(current_time > voting_escrow::common::epoch_vote_start(current_time), EVotingNotStarted);
    }

    /// Get a reference to the fee voting reward for a specific gauge.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `gauge_id` - The ID of the gauge
    ///
    /// # Returns
    /// A reference to the fee voting reward
    public fun borrow_fee_voting_reward(
        voter: &Voter,
        gauge_id: ID
    ): &governance::fee_voting_reward::FeeVotingReward {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id))
    }

    /// Get a mutable reference to the fee voting reward for a specific gauge.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `gauge_id` - The ID of the gauge
    ///
    /// # Returns
    /// A mutable reference to the fee voting reward
    public fun borrow_fee_voting_reward_mut(
        voter: &mut Voter,
        gauge_id: ID
    ): &mut governance::fee_voting_reward::FeeVotingReward {
        voter.gauge_to_fee.borrow_mut(into_gauge_id(gauge_id))
    }

    /// Borrow the voter capability after validating with the distribute capability.
    public fun borrow_voter_cap(
        voter: &Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap
    ): &governance::voter_cap::VoterCap {
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));
        &voter.voter_cap
    }

    public fun borrow_exercise_fee_reward(
        voter: &Voter
    ): &governance::exercise_fee_reward::ExerciseFeeReward {
        &voter.exercise_fee_reward
    }

    public fun borrow_exercise_fee_reward_mut(
        voter: &mut Voter
    ): &mut governance::exercise_fee_reward::ExerciseFeeReward {
        &mut voter.exercise_fee_reward
    }

    /// Notify the voter about the amount of exercise fee reward.
    /// 
    /// # Arguments
    /// * `distribute_cap` - The distribute cap to validate the voter and permissions
    /// * `voter` - The voter contract reference
    /// * `reward` - The reward coin
    /// * `clock` - The system clock
    public fun notify_exercise_fee_reward_amount<RewardCoinType>(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        reward: Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        // is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id(voter));
        let exercise_fee_reward = &mut voter.exercise_fee_reward;
        exercise_fee_reward
            .notify_reward_amount(
                &voter.voter_cap,
                reward,
                clock,
                ctx
            );
    }

    /// Claims exercise fee rewards for a specific lock. Exercise fee becomes available at the end of the week if the
    /// lock has voted during the week.
    public fun claim_exercise_fee_reward<SailCoinType, RewardCoinType>(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let sail_coin_type = type_name::get<SailCoinType>();
        let reward_coin_type = type_name::get<RewardCoinType>();
        let sail_claim = reward_coin_type == sail_coin_type;
        let amount = if (sail_claim) {
            voter.exercise_fee_reward.get_reward_sail<SailCoinType>(
                &voter.voter_cap,
                voting_escrow,
                lock,
                clock,
                ctx,
            )
        } else {
            voter.exercise_fee_reward.get_reward<SailCoinType, RewardCoinType>(
                &voter.voter_cap,
                voting_escrow,
                lock,
                clock,
                ctx,
            )
        };
        let claim_exercise_fee_reward_event = EventClaimExerciseFeeReward {
            who: ctx.sender(),
            amount,
            token: type_name::get<RewardCoinType>(),
            lock: into_lock_id(object::id(lock)).id,
            sail_claim,
        };
        sui::event::emit<EventClaimExerciseFeeReward>(claim_exercise_fee_reward_event);
    }

    /// Calculates the amount of exercise oSAIL fee in the specified coin type earned by the lock.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - The system clock
    public fun earned_exercise_fee<ExerciseFeeCoinType>(
        voter: &Voter,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter.exercise_fee_reward.earned<ExerciseFeeCoinType>(lock_id, clock)
    }

    /// Internal function to validate vote parameters.
    /// Checks that the pool IDs and weights arrays match in length,
    /// that the number of votes does not exceed the maximum allowed,
    /// and that all pools have valid gauges.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `pool_ids` - The IDs of the pools to vote for
    /// * `weights` - The weights to assign to each pool
    ///
    /// # Aborts
    /// * If the pool IDs and weights arrays have different lengths
    /// * If the number of votes exceeds the maximum allowed
    /// * If any pool doesn't have a valid gauge
    /// * If any weight is larger than 10000
    fun check_vote(
        voter: &Voter,
        pool_ids: &vector<ID>,
        weights: &vector<u64>,
        volumes: &vector<u64>
    ) {
        let pools_length = pool_ids.length();
        assert!(pools_length <= voter.max_voting_num, ECheckVoteMaxVoteNumExceed);
        assert!(pools_length == weights.length(), ECheckVoteSizesDoNotMatch);
        assert!(pools_length == volumes.length(), ECheckVoteVolumeSizeDoNotMatch);
        let mut i = 0;
        while (i < pools_length) {
            assert!(
                voter.pool_to_gauger.contains(into_pool_id(pool_ids[i])),
                ECheckVoteGaugeNotFound
            );
            assert!(weights[i] <= 10000, ECheckVoteWeightTooLarge);
            i = i + 1;
        };
    }

    /// Claims fee rewards for a single pool.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `lock` - The lock for which to claim fees
    /// * `pool` - The pool which user voted for and which fees to claim
    /// * `clock` - The system clock for time-based calculations
    /// * `ctx` - The transaction context
    ///
    /// # Emits
    /// * `EventClaimVotingFeeReward` for each pool with claimed rewards
    public fun claim_voting_fee_by_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let pool_id = object::id(pool);
        claim_voting_fee<SailCoinType, CoinTypeA>(voter, voting_escrow, distribution_config, lock, pool_id, clock, ctx);
        claim_voting_fee<SailCoinType, CoinTypeB>(voter, voting_escrow, distribution_config, lock, pool_id, clock, ctx);
    }

    /// Claims fee rewards for single pool and single fee coin type.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `lock` - The lock for which to claim fees
    /// * `pool_id` - The ID of the pool to claim fees for
    /// * `clock` - The system clock for time-based calculations
    /// * `ctx` - The transaction context
    ///
    /// # Emits
    /// * `EventClaimVotingFeeReward` for each pool with claimed rewards
    public fun claim_voting_fee<SailCoinType, FeeCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        pool_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        let pool_id_obj = into_pool_id(pool_id);
        let gauge_id = *voter.pool_to_gauger.borrow(pool_id_obj);
        let claim_voting_fee_reward_event = EventClaimVotingFeeReward {
            who: tx_context::sender(ctx),
            amount: voter
                .gauge_to_fee
                .borrow_mut(gauge_id)
                .get_reward<SailCoinType, FeeCoinType>(
                    &voter.voter_cap,
                    voting_escrow,
                    lock,
                    clock,
                    ctx,
                ),
            pool: pool_id,
            gauge: gauge_id.id,
            token: type_name::get<FeeCoinType>(),
            lock: into_lock_id(object::id(lock)).id,
        };
        sui::event::emit<EventClaimVotingFeeReward>(claim_voting_fee_reward_event);
    }

    /// Calculates the amount of rewards earned for a specific coin type for single pool.
    /// It doesn't make sense to calculate it for all pools because all pools have different coin types
    /// and function accepts only single coin type.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - The system clock
    public fun earned_voting_fee<FeeCoinType>(
        voter: &Voter,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter
        .borrow_fee_voting_reward(voter.pool_to_gauge(pool_id))
        .earned<FeeCoinType>(lock_id, clock)
    }

    /// Returns the total voting fee rewards available for a specific epoch for a specific coin type.
    public fun voting_fee_rewards_at_epoch<FeeCoinType>(
        voter: &Voter,
        gauge_id: ID,
        epoch_start: u64
    ): u64 {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id)).rewards_at_epoch<FeeCoinType>(epoch_start)
    }

    /// Returns the total voting fee rewards available for the current epoch for a specific coin type.
    public fun voting_fee_rewards_this_epoch<FeeCoinType>(
        voter: &Voter,
        gauge_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id)).rewards_this_epoch<FeeCoinType>(clock)
    }

    /// Creates a new gauge for a liquidity pool.
    /// Gauges are mechanisms that direct rewards to liquidity pools based on votes.
    /// Only governors can create gauges.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `distribution_config` - The distribution configuration
    /// * `create_cap` - The capability to create a gauge
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `voting_escrow` - The voting escrow reference
    /// * `pool` - The liquidity pool to create a gauge for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A new gauge for the specified pool
    ///
    /// # Aborts
    /// * If the caller is not a governor
    /// * If the distribution configuration is invalid
    public fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter,
        distribution_config: &mut governance::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): governance::gauge::Gauge<CoinTypeA, CoinTypeB> {
        distribution_config.checked_package_version();
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));
        assert!(
            voter.is_valid_gauge_create_cap(create_cap),
            ECreateGaugeInvalidCreateCap
        );
        assert!(
            voter.distribution_config == object::id<governance::distribution_config::DistributionConfig>(
                distribution_config
            ),
            ECreateGaugeDistributionConfigInvalid
        );
        assert!(
            voting_escrow.get_voter_id() == object::id<Voter>(voter),
            ECreateGaugeVotingEscrowInvalidVoter
        );
        let pool_id = into_pool_id(object::id(pool));
        assert!(
            !voter.pool_to_gauger.contains(pool_id),
            ECreateGaugePoolAlreadyHasGauge
        );
        let mut gauge = return_new_gauge(distribution_config, create_cap, pool, ctx);
        let mut reward_coins = std::vector::empty<TypeName>();
        reward_coins.push_back(type_name::get<CoinTypeA>());
        reward_coins.push_back(type_name::get<CoinTypeB>());
        let gauge_id = object::id<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(&gauge);
        let voter_id = object::id<Voter>(voter);
        let voting_escrow_id = object::id<voting_escrow::voting_escrow::VotingEscrow<SailCoinType>>(voting_escrow);
        voter.gauge_to_fee.add(
            into_gauge_id(gauge_id),
            governance::fee_voting_reward::create(voter_id, gauge_id, reward_coins, ctx)
        );
        let sail_coin_type=type_name::get<SailCoinType>();
        if (!reward_coins.contains(&sail_coin_type)) {
            reward_coins.push_back(sail_coin_type);
        };
        voter.receive_gauger(distribute_cap, &mut gauge, clock);
        let mut alive_gauges_vec = std::vector::empty<ID>();
        alive_gauges_vec.push_back(gauge_id);
        distribution_config.update_gauge_liveness(alive_gauges_vec, true);
        gauge
    }

    /// Distributes accumulated rewards to a gauge.
    /// This is a key function in the reward distribution flow.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `distribution_config` - The distribution configuration
    /// * `gauge` - The gauge to distribute rewards to
    /// * `pool` - The liquidity pool associated with the gauge
    /// * `usd_reward_amount` - The amount of reward to distribute in USD, decimals 6
    /// * `o_sail_price_q64` - The oSAIL price in USD in Q64.64 format, in SAIL token decimals
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// (amount of distributed rewards, balance containing rewards from previous epoch that were not distributed)
    ///
    /// # Aborts
    /// * If the gauge representation is invalid
    ///
    /// # Emits
    /// * `EventDistributeGauge` with information about distributed rewards
    public(package) fun distribute_gauge<CoinTypeA, CoinTypeB, NextEpochOSail>(
        voter: &mut Voter,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        usd_reward_amount: u64,
        o_sail_price_q64: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        // is called by minter so version control is handled by minter
        assert!(voter.is_valid_epoch_token<NextEpochOSail>(), EDistributeGaugeInvalidToken);
        assert!(distribution_config.is_gauge_alive(object::id(gauge)), EDistributeGaugeGaugeIsKilled);
        assert!(gauge.check_gauger_pool(pool), EDistributeGaugeInvalidPool);

        let gauge_id = into_gauge_id(object::id(gauge));
        let ended_epoch_o_sail_emission = gauge.notify_epoch_token<CoinTypeA, CoinTypeB, NextEpochOSail>(
            distribution_config,
            pool,
            &voter.voter_cap,
            clock,
            ctx
        );
        let (fee_reward_a, fee_reward_b) = gauge.notify_reward(
            distribution_config,
            pool,
            usd_reward_amount,
            o_sail_price_q64,
            clock,
            ctx
        );
        let fee_a_amount = fee_reward_a.value<CoinTypeA>();
        let fee_b_amount = fee_reward_b.value<CoinTypeB>();
        let fee_voting_reward = voter.gauge_to_fee.borrow_mut(gauge_id);
        fee_voting_reward.notify_reward_amount(
            &voter.voter_cap,
            coin::from_balance<CoinTypeA>(fee_reward_a, ctx),
            clock,
            ctx
        );
        fee_voting_reward.notify_reward_amount(
            &voter.voter_cap,
            coin::from_balance<CoinTypeB>(fee_reward_b, ctx),
            clock,
            ctx
        );
        let distribute_gauge_event = EventDistributeGauge {
            pool: object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            gauge: gauge_id.id,
            fee_a_amount,
            fee_b_amount,
            usd_amount: usd_reward_amount,
            ended_epoch_o_sail_emission,
        };
        sui::event::emit<EventDistributeGauge>(distribute_gauge_event);

        ended_epoch_o_sail_emission
    }

    /// Notifies additional reward amount to the gauge without claiming accumulated fees.
    /// Supposed to be used to increase gauge emissions in the middle of the epoch.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `distribute_cap` - The distribute capability for authorization
    /// * `distribution_config` - The distribution configuration
    /// * `gauge` - The gauge to notify reward to
    /// * `pool` - The pool to notify reward to
    /// * `usd_reward_amount` - The amount of reward to notify in usd, decimals 6
    /// * `o_sail_price_q64` - The oSAIL price in USD in Q64.64 format, in SAIL token decimals
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public(package) fun notify_gauge_reward_without_claim<CoinTypeA, CoinTypeB>(
        voter: &Voter,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        usd_reward_amount: u64,
        o_sail_price_q64: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        // is called by minter so version control is handled by minter
        assert!(distribution_config.is_gauge_alive(object::id(gauge)), EAdjustGaugeGaugeIsKilled);

        gauge.notify_reward_without_claim(
            distribution_config,
            pool,
            usd_reward_amount,
            o_sail_price_q64,
            clock,
            ctx
        );
    }


    public fun inject_voting_fee_reward<FeeCoinType>(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        gauge_id: ID,
        reward: Coin<FeeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        // method is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));
        let fee_voting_reward = voter.gauge_to_fee.borrow_mut(into_gauge_id(gauge_id));

        fee_voting_reward.notify_reward_amount(
            &voter.voter_cap,
            reward,
            clock,
            ctx
        );
    }

    /// Returns the balance of a specific token type in the fee voting rewards for a gauge.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `gauge_id` - The ID of the gauge
    ///
    /// # Returns
    /// The balance of the specified token type
    public fun fee_voting_reward_balance<FeeCoinType>(
        voter: &Voter,
        gauge_id: ID
    ): u64 {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id)).balance<FeeCoinType>()
    }

    /// Returns the balance of a specific token type in the voter contract.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    ///
    /// # Returns
    /// The balance of the specified token type
    public fun get_balance<RewardCoinType>(voter: &Voter): u64 {
        let bribe_coin_type = type_name::get<RewardCoinType>();
        if (!voter.balances.contains(bribe_coin_type)) {
            0
        } else {
            voter.balances.borrow<TypeName, Balance<RewardCoinType>>(
                bribe_coin_type
            ).value<RewardCoinType>()
        }
    }

    /// Returns the weight (voting power) assigned to a specific gauge.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `gauge_id` - The ID of the gauge
    ///
    /// # Returns
    /// The weight of the gauge
    public fun get_gauge_weight(voter: &Voter, gauge_id: ID): u64 {
        *voter.weights.borrow(into_gauge_id(gauge_id))
    }

    /// Returns the weight (voting power) assigned to a specific pool.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `pool_id` - The ID of the pool
    ///
    /// # Returns
    /// The weight of the pool
    public fun get_pool_weight(voter: &Voter, pool_id: ID): u64 {
        let gauge_id = *voter.pool_to_gauger.borrow(into_pool_id(pool_id));
        voter.get_gauge_weight(gauge_id.id)
    }

    /// Returns the votes cast by a specific lock.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock
    ///
    /// # Returns
    /// A table mapping pools to their vote weights
    ///
    /// # Aborts
    /// * If the lock has not voted
    public fun get_votes(
        voter: &Voter,
        lock_id: ID
    ): &Table<PoolID, VolumeVote> {
        let lock_id_obj = into_lock_id(lock_id);
        assert!(
            voter.votes.contains(lock_id_obj),
            EGetVotesNotVoted
        );
        voter.votes.borrow(lock_id_obj)
    }

    /// Initializes the module.
    /// 
    /// # Arguments
    /// * `otw` - The one-time witness for the module
    /// * `ctx` - The transaction context
    fun init(otw: VOTER, ctx: &mut TxContext) {
        sui::package::claim_and_keep<VOTER>(otw, ctx);
    }

    /// Converts an ID to a GaugeID.
    /// 
    /// # Arguments
    /// * `id` - The ID to convert
    /// 
    /// # Returns
    /// A GaugeID containing the input ID
    public(package) fun into_gauge_id(id: ID): GaugeID {
        GaugeID { id }
    }

    /// Converts an ID to a LockID.
    ///
    /// # Arguments
    /// * `id` - The ID to convert
    ///
    /// # Returns
    /// A LockID containing the input ID
    public(package) fun into_lock_id(id: ID): LockID {
        LockID { id }
    }

    /// Converts an ID to a PoolID.
    ///
    /// # Arguments
    /// * `id` - The ID to convert
    ///
    /// # Returns
    /// A PoolID containing the input ID
    public(package) fun into_pool_id(id: ID): PoolID {
        PoolID { id }
    }

    /// Checks if an ID corresponds to an epoch governor.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `who` - The ID to check
    ///
    /// # Returns
    /// True if the ID is an epoch governor, false otherwise
    public fun is_epoch_governor(voter: &Voter, who: ID): bool {
        voter.epoch_governors.contains<ID>(&who)
    }

    /// Checks if an ID corresponds to a governor.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `who` - The ID to check
    ///
    /// # Returns
    /// True if the ID is a governor, false otherwise
    public fun is_governor(voter: &Voter, who: ID): bool {
        voter.governors.contains<ID>(&who)
    }

    /// Checks if an NFT (lock) is whitelisted.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock to check
    ///
    /// # Returns
    /// True if the lock is whitelisted, false otherwise
    public fun is_whitelisted_nft(voter: &Voter, lock_id: ID): bool {
        let lock_id_obj = into_lock_id(lock_id);
        voter.is_whitelisted_nft.contains(lock_id_obj) &&
            *voter.is_whitelisted_nft.borrow(lock_id_obj)
    }

    /// Checks if a token type is whitelisted.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    ///
    /// # Returns
    /// True if the token type is whitelisted, false otherwise
    public fun is_whitelisted_token<CoinToCheckType>(voter: &Voter): bool {
        voter.whitelisted_manager.is_whitelisted_token<CoinToCheckType>()
    }

    /// Returns the timestamp when a lock last voted.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock
    /// 
    /// # Returns
    /// The timestamp when the lock last voted, or 0 if it never voted
    public fun lock_last_voted_at(voter: &Voter, lock_id: ID): u64 {
        let lock_id_obj = into_lock_id(lock_id);
        if (!voter.last_voted.contains(lock_id_obj)) {
            0
        } else {
            *voter.last_voted.borrow(lock_id_obj)
        }
    }

    /// Sets current_epoch_token. Only current_epoch_token can be distributed in current epoch via Voter.
    /// After this function is called all notify_reward calls will check that coin is allowed to be distributed.
    ///
    /// # Arguments
    /// * `<RewardCoinType>` - The type to be used as current epoch coin.
    /// * `voter` - The voter contract reference
    /// * `distribute_cap` - The distribute capability for authorization
    public fun notify_epoch_token<RewardCoinType>(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        ctx: &mut TxContext,
    ) {
        // is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));

        let coin_type = type_name::get<RewardCoinType>();

        voter.current_epoch_token.swap_or_fill(coin_type);

        let pool_id = object::id(voter);

        let event = EventNotifyEpochToken {
            notifier: distribute_cap.who(),
            token: coin_type,
        };
        sui::event::emit<EventNotifyEpochToken>(event);
    }

    /// Returns true if RewardCoinType matches current epoch token
    ///
    /// # Arguments
    /// * `<RewardCoinType>` - The coin type to be checked.
    /// * `voter` - The voter contract reference
    public fun is_valid_epoch_token<RewardCoinType>(
        voter: &Voter,
    ): bool {
        let coin_type = type_name::get<RewardCoinType>();

        let pool_id = object::id(voter);

        voter.current_epoch_token.borrow() == coin_type
    }

    /// Getter for current_epoch_token
    public fun get_current_epoch_token(voter: &Voter): TypeName {
        *voter.current_epoch_token.borrow()
    }


    /// "Pokes" the voting system to update a lock's votes based on its current voting power.
    /// This is useful when a lock's voting power changes and votes need to be recalculated.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock` - The lock to update votes for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun poke<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(current_time > voting_escrow::common::epoch_vote_start(current_time), EPokeVotingNotStartedYet);
        let voting_power = voting_escrow.get_voting_power(lock_id, clock);
        let lock_id_obj = into_lock_id(lock_id);
        voter.poke_internal(voting_escrow, distribution_config, lock_id_obj, voting_power, clock, ctx);
    }

    /// Internal function to update a lock's votes based on its current voting power.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock` - The lock to update votes for
    /// * `voting_power` - The voting power of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    fun poke_internal<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock_id: LockID,
        voting_power: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let pool_vote_count = if (voter.pool_vote.contains(lock_id)) {
            voter.pool_vote.borrow(lock_id).length()
        } else {
            0
        };
        if (pool_vote_count > 0) {
            let mut weights = std::vector::empty<u64>();
            let mut volumes = std::vector::empty<u64>();
            let mut i = 0;
            let pools_voted = voter.pool_vote.borrow(lock_id);
            let mut pools_voted_ids = std::vector::empty<ID>();
            assert!(
                voter.votes.contains(lock_id),
                EPokeLockNotVoted
            );
            while (i < pool_vote_count) {
                pools_voted_ids.push_back(pools_voted.borrow(i).id);
                let vote_amount_by_pool = voter.votes.borrow(lock_id);
                assert!(
                    vote_amount_by_pool.contains(pools_voted[i]),
                    EPokePoolNotVoted
                );
                let volume_vote = vote_amount_by_pool.borrow(pools_voted[i]);
                weights.push_back(volume_vote.votes);
                volumes.push_back(volume_vote.volume);
                i = i + 1;
            };
            voter.vote_internal(
                voting_escrow,
                distribution_config,
                lock_id,
                voting_power,
                pools_voted_ids,
                weights,
                volumes,
                clock,
                ctx
            );
        };
    }

    /// Returns the gauge ID associated with a specific pool.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `pool_id` - The ID of the pool to query
    /// 
    /// # Returns
    /// The ID of the gauge associated with the pool
    public fun pool_to_gauge(voter: &Voter, pool_id: ID): ID {
        voter.pool_to_gauger.borrow(into_pool_id(pool_id)).id
    }

    /// Returns all pools and their associated gauges in the system.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// 
    /// # Returns
    /// A tuple containing vectors of pool IDs and their corresponding gauge IDs
    public fun pools_gauges(
        voter: &Voter
    ): (vector<ID>, vector<ID>) {
        let mut pool_ids = std::vector::empty<ID>();
        let mut gauge_ids = std::vector::empty<ID>();
        let mut i = 0;
        while (i < voter.pools.length()) {
            let pool_id = voter.pools.borrow(i).id;
            pool_ids.push_back(pool_id);
            gauge_ids.push_back(voter.pool_to_gauge(pool_id));
            i = i + 1;
        };
        (pool_ids, gauge_ids)
    }

    /// Proves that a specific token is whitelisted in the system.
    /// Used to verify tokens for various operations.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    ///
    /// # Returns
    /// A capability proving that the token is whitelisted
    public fun prove_token_whitelisted<CoinToCheckType>(
        voter: &Voter
    ): voting_escrow::whitelisted_tokens::WhitelistedToken {
        voter.whitelisted_manager.prove_token_whitelisted<CoinToCheckType>()
    }

    /// Receives a gauge into the voter system, associating it with a pool.
    /// This is called after a gauge has been created, to integrate it fully
    /// into the voting system.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `gauge` - The gauge to be received
    /// * `clock` - The system clock
    public fun receive_gauger<CoinTypeA, CoinTypeB>(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ) {
        // is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));
        let gauge_id = into_gauge_id(
            object::id<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge)
        );
        let pool_id = into_pool_id(gauge.pool_id());
        assert!(
            !voter.pool_to_gauger.contains(pool_id),
            EReceiveGaugePoolAreadyHasGauge
        );
        voter.weights.add(gauge_id, 0);
        voter.pools.push_back(pool_id);
        voter.pool_to_gauger.add(pool_id, gauge_id);
        gauge.set_voter(object::id<Voter>(voter));
    }

    /// Removes an epoch governor from the system.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `who` - The ID of the epoch governor to remove
    public fun remove_epoch_governor(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        governor_cap: &governance::voter_cap::GovernorCap,
        who: ID
    ) {
        distribution_config.checked_package_version();
        governor_cap.validate_governor_voter_id(object::id<Voter>(voter));
        assert!(
            voter.is_governor(object::id<governance::voter_cap::GovernorCap>(governor_cap)),
            ERemoveEpochGovernorNotAGovernor
        );
        voter.epoch_governors.remove<ID>(&who);
        let remove_epoch_governor_event = EventRemoveEpochGovernor { cap: who, };
        sui::event::emit<EventRemoveEpochGovernor>(remove_epoch_governor_event);
    }

    /// Removes a governor from the system.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `publisher` - The publisher of the package
    /// * `who` - The ID of the governor to remove
    public fun remove_governor(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        publisher: &sui::package::Publisher,
        who: ID
    ) {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<VOTER>(), ERemoveGovernorInvalidPublisher);
        voter.governors.remove<ID>(&who);
        let remove_governor_event = EventRemoveGovernor { cap: who };
        sui::event::emit<EventRemoveGovernor>(remove_governor_event);
    }

    /// Resets all votes for a particular lock.
    /// This effectively removes all voting power allocated by this lock.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock` - The lock to reset votes for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun reset<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let lock_id = into_lock_id(object::id(lock));
        voter.assert_only_new_epoch(lock_id, clock);
        voter.reset_internal(voting_escrow, distribution_config, lock_id, clock, ctx);
    }

    /// Internal function to reset votes for a lock.
    /// Handles the accounting of removing votes and updating weights.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock_id` - The lock id to reset votes for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    fun reset_internal<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        _: &governance::distribution_config::DistributionConfig,
        lock_id: LockID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(voter.voting_escrow_cap.is_some(), EResetVotingEscrowCapNotSet);
        let exercise_fee_deposited_balance = voter.exercise_fee_reward
            .borrow_reward()
            .balance_of(lock_id.id, clock);
        if (exercise_fee_deposited_balance > 0) {
            voter.exercise_fee_reward.withdraw(
            &voter.voter_cap,
            exercise_fee_deposited_balance,
                lock_id.id,
                clock,
                ctx
            );
        };
        let total_pools_count = if (voter.pool_vote.contains(lock_id)) {
            voter.pool_vote.borrow(lock_id).length()
        } else {
            0
        };
        let mut total_removed_weight = 0;
        let mut pool_index = 0;
        while (pool_index < total_pools_count) {
            let voted_pools_vec = voter.pool_vote.borrow(lock_id);
            let pool_id = voted_pools_vec[pool_index];
            let pool_votes = voter.votes.borrow(lock_id).borrow(pool_id).votes;
            let gauge_id = *voter.pool_to_gauger.borrow(pool_id);
            if (pool_votes != 0) {
                let weight = voter.weights.remove(gauge_id) - pool_votes;
                voter.weights.add(gauge_id, weight);
                voter.votes.borrow_mut(lock_id).remove(pool_id);
                // we are not withdrawing from reward contracts as they are updated by backend voting service
                total_removed_weight = total_removed_weight + pool_votes;
                let abstained_event = EventAbstained {
                    sender: tx_context::sender(ctx),
                    pool: pool_id.id,
                    lock: lock_id.id,
                    votes: pool_votes,
                    pool_weight: *voter.weights.borrow(gauge_id),
                };
                sui::event::emit<EventAbstained>(abstained_event);
            };
            pool_index = pool_index + 1;
        };
        voting_escrow.voting(voter.voting_escrow_cap.borrow(), lock_id.id, false);
        if (voter.used_weights.contains(lock_id)) {
            voter.used_weights.remove(lock_id);
        };
        if (voter.pool_vote.contains(lock_id)) {
            voter.pool_vote.remove(lock_id);
        };
    }

    /// Creates and returns a new gauge for a pool.
    /// This is an internal function used by create_gauge.
    /// 
    /// # Arguments
    /// * `distribution_config` - The distribution configuration
    /// * `gauge_create_cap` - The capability to create a gauge
    /// * `pool` - The pool to create a gauge for
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A new gauge for the specified pool
    fun return_new_gauge<CoinTypeA, CoinTypeB>(
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge_create_cap: &gauge_cap::gauge_cap::CreateCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut TxContext
    ): governance::gauge::Gauge<CoinTypeA, CoinTypeB> {
        let pool_id = object::id(pool);
        let mut gauge = governance::gauge::create<CoinTypeA, CoinTypeB>(
            distribution_config,
            pool_id,
            ctx
        );
        let gauge_cap = gauge_create_cap.create_gauge_cap(
            pool_id,
            object::id<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(&gauge),
            ctx
        );
        pool.init_fullsail_distribution_gauge(&gauge_cap);
        gauge.receive_gauge_cap(gauge_cap);
        gauge
    }

    /// Sets the maximum number of pools a user can vote for.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `new_max_voting_num` - The new maximum number of pools (minimum 10)
    ///
    /// # Aborts
    /// * If the caller is not a governor
    /// * If the new maximum is less than 10
    /// * If the new maximum is the same as the current maximum
    public fun set_max_voting_num(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        governor_cap: &governance::voter_cap::GovernorCap,
        new_max_voting_num: u64
    ) {
        distribution_config.checked_package_version();
        governor_cap.validate_governor_voter_id(object::id<Voter>(voter));
        assert!(
            voter.is_governor(object::id<governance::voter_cap::GovernorCap>(governor_cap)),
            ESetMaxVotingNumGovernorInvalid
        );
        assert!(new_max_voting_num >= 10, ESetMaxVotingNumAtLeast10);
        assert!(new_max_voting_num != voter.max_voting_num, ESetMaxVotingNumNotChanged);
        voter.max_voting_num = new_max_voting_num;
    }

    /// Returns the total voting weight used by a specific lock.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock
    ///
    /// # Returns
    /// The used voting weight of the lock
    public fun used_weights(voter: &Voter, lock_id: ID): u64 {
        *voter.used_weights.borrow(into_lock_id(lock_id))
    }

    /// Casts votes for pools using a lock's voting power.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock` - The lock to vote with
    /// * `pools` - A vector of pool IDs to vote for
    /// * `weights` - A vector of weights to allocate to each pool
    /// * `volumes` - A vector of volumes to allocate to each pool
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the voter has already voted in the current epoch
    /// * If the voting escrow is deactivated
    /// * If the epoch vote has ended and the NFT is not whitelisted
    /// * If the lock has no voting power
    public fun vote<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        pools: vector<ID>,
        weights: vector<u64>,
        volumes: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        let lock_id = into_lock_id(object::id(lock));
        voter.assert_only_new_epoch(lock_id, clock);
        voter.check_vote(&pools, &weights, &volumes);
        assert!(
            !voting_escrow.deactivated(lock_id.id),
            EVoteVotingEscrowDeactivated
        );
        let current_time = voting_escrow::common::current_timestamp(clock);
        let epoch_vote_ended_and_nft_not_whitelisted = (
            current_time > voting_escrow::common::epoch_vote_end(current_time)
        ) && (
            !voter.is_whitelisted_nft.contains(lock_id) ||
                *voter.is_whitelisted_nft.borrow(lock_id) == false
        );
        assert!(!epoch_vote_ended_and_nft_not_whitelisted, EVoteNotWhitelistedNft);
        if (voter.last_voted.contains(lock_id)) {
            voter.last_voted.remove(lock_id);
        };
        voter.last_voted.add(lock_id, current_time);
        let voting_power = voting_escrow.get_voting_power(lock_id.id, clock);
        assert!(voting_power > 0, EVoteNoVotingPower);
        voter.vote_internal(voting_escrow, distribution_config, lock_id, voting_power, pools, weights, volumes, clock, ctx);
    }

    /// Internal function to implement the voting logic.
    /// Handles the details of allocating voting power to pools based on weights and volumes.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `voting_escrow` - The voting escrow reference
    /// * `distribution_config` - The distribution configuration
    /// * `lock` - The lock to vote with
    /// * `voting_power` - The voting power of the lock
    /// * `pools` - A vector of pool IDs to vote for
    /// * `weights` - A vector of weights to allocate to each pool
    /// * `volumes` - A vector of volumes to allocate to each pool
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the gauge doesn't exist
    /// * If the gauge is not alive
    /// * If the pool has already been voted for by this lock
    /// * If a weight results in zero votes
    ///
    /// # Emits
    /// * `EventVoted` for each pool voted for
    fun vote_internal<SailCoinType>(
        voter: &mut Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock_id: LockID,
        voting_power: u64,
        pools: vector<ID>,
        weights: vector<u64>,
        volumes: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(voter.voting_escrow_cap.is_some(), EVoteInternalVotingEscrowCapNotSet);
        voter.reset_internal(voting_escrow, distribution_config, lock_id, clock, ctx);

        voter.exercise_fee_reward.deposit(
            &voter.voter_cap,
            voting_power,
            lock_id.id,
            clock,
            ctx
        );

        let mut input_total_weight = 0;
        let mut lock_used_weights = 0;
        let mut i = 0;
        let pools_length = pools.length();
        while (i < pools_length) {
            let weight_i = weights.borrow(i);
            input_total_weight = input_total_weight + *weight_i;
            i = i + 1;
        };
        i = 0;
        while (i < pools_length) {
            let pool_id = into_pool_id(pools[i]);
            assert!(
                voter.pool_to_gauger.contains(pool_id),
                EVoteInternalGaugeDoesNotExist
            );
            let gauge_id = *voter.pool_to_gauger.borrow(pool_id);
            assert!(
                distribution_config.is_gauge_alive(gauge_id.id),
                EVoteInternalGaugeNotAlive
            );
            let votes_for_pool = if (weights[i] == 0) {
                0
            } else {
                integer_mate::full_math_u64::mul_div_floor(
                    weights[i],
                    voting_power,
                    input_total_weight
                )
            };

            let pool_has_votes = voter.votes.contains(lock_id) &&
                voter.votes.borrow(lock_id).contains(pool_id) &&
                voter.votes.borrow(lock_id).borrow(pool_id).votes != 0;

            assert!(!pool_has_votes, EVoteInternalPoolAreadyVoted);
            assert!(votes_for_pool > 0, EVoteInternalWeightResultedInZeroVotes);
            if (!voter.pool_vote.contains(lock_id)) {
                voter.pool_vote.add(lock_id, std::vector::empty<PoolID>());
            };
            voter.pool_vote.borrow_mut(lock_id).push_back(pool_id);
            let total_gauge_weight = if (voter.weights.contains(gauge_id)) {
                voter.weights.remove(gauge_id)
            } else {
                0
            };
            voter.weights.add(gauge_id, total_gauge_weight + votes_for_pool);
            if (!voter.votes.contains(lock_id)) {
                voter.votes.add(lock_id, table::new<PoolID, VolumeVote>(ctx));
            };
            let lock_votes = voter.votes.borrow_mut(lock_id);
            let lock_pool_votes = if (lock_votes.contains(pool_id)) {
                let VolumeVote { volume: _, votes: lock_pool_votes } = lock_votes.remove(pool_id);
                lock_pool_votes
            } else {
                0
            };
            let lock_volume_vote = VolumeVote {
                votes: lock_pool_votes + votes_for_pool,
                volume: volumes[i],
            };
            lock_votes.add(pool_id, lock_volume_vote);
            // we are not depositing to reward contracts as they are updated by backend voting service
            lock_used_weights = lock_used_weights + votes_for_pool;
            let voted_event = EventVoted {
                sender: tx_context::sender(ctx),
                pool: pool_id.id,
                lock: lock_id.id,
                voting_weight: votes_for_pool,
                volume: volumes[i],
                pool_weight: *voter.weights.borrow(gauge_id),
            };
            sui::event::emit<EventVoted>(voted_event);
            i = i + 1;
        };
        if (lock_used_weights > 0) {
            voting_escrow.voting(voter.voting_escrow_cap.borrow(), lock_id.id, true);
        };
        if (voter.used_weights.contains(lock_id)) {
            voter.used_weights.remove(lock_id);
        };
        voter.used_weights.add(lock_id, lock_used_weights);
    }

    /// Returns the pools that a specific lock has voted for.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `lock_id` - The ID of the lock
    ///
    /// # Returns
    /// A vector of pool IDs that the lock has voted for
    public fun voted_pools(
        voter: &Voter,
        lock_id: ID
    ): vector<ID> {
        let mut voted_pools_vec = std::vector::empty<ID>();
        let lock_id_obj = into_lock_id(lock_id);
        let voted_pools_from_voter = if (voter.pool_vote.contains(lock_id_obj)) {
            voter.pool_vote.borrow(lock_id_obj)
        } else {
            let voted_pools_empty = std::vector::empty<PoolID>();
            &voted_pools_empty
        };
        let mut i = 0;
        while (i < voted_pools_from_voter.length()) {
            voted_pools_vec.push_back(voted_pools_from_voter.borrow(i).id);
            i = i + 1;
        };
        voted_pools_vec
    }

    /// Whitelists or de-whitelists an NFT (lock) in the system.
    /// Whitelisted NFTs can vote outside the regular voting period.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `lock_id` - The ID of the lock to whitelist
    /// * `listed` - Whether to whitelist (true) or de-whitelist (false)
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the caller is not a governor
    ///
    /// # Emits
    /// * `EventWhitelistNFT` with whitelist information
    public fun whitelist_nft(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        governor_cap: &governance::voter_cap::GovernorCap,
        lock_id: ID,
        listed: bool,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        governor_cap.validate_governor_voter_id(object::id<Voter>(voter));
        assert!(
            voter.is_governor(object::id<governance::voter_cap::GovernorCap>(governor_cap)),
            EWhitelistNftGovernorInvalid
        );
        let lock_id_obj = into_lock_id(lock_id);
        if (voter.is_whitelisted_nft.contains(lock_id_obj)) {
            voter.is_whitelisted_nft.remove(lock_id_obj);
        };
        voter.is_whitelisted_nft.add(lock_id_obj, listed);
        let whitelisted_nft_event = EventWhitelistNFT {
            sender: tx_context::sender(ctx),
            id: lock_id,
            listed: listed,
        };
        sui::event::emit<EventWhitelistNFT>(whitelisted_nft_event);
    }

    /// Whitelists or de-whitelists a token type in the system.
    /// Only whitelisted tokens can be used in the voting system.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `governor_cap` - The governor capability to authorize the operation
    /// * `listed` - Whether to whitelist (true) or de-whitelist (false)
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the caller is not a governor
    public fun whitelist_token<CoinToWhitelistType>(
        voter: &mut Voter,
        distribution_config: &DistributionConfig,
        governor_cap: &governance::voter_cap::GovernorCap,
        listed: bool,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        governor_cap.validate_governor_voter_id(object::id<Voter>(voter));
        assert!(
            voter.is_governor(object::id(governor_cap)),
            EWhitelistTokenGovernorInvalid
        );
        voter.whitelist_token_internal(
            type_name::get<CoinToWhitelistType>(),
            listed,
            tx_context::sender(ctx)
        );
    }

    fun whitelist_token_internal(
        voter: &mut Voter,
        token: std::type_name::TypeName,
        listed: bool,
        sender: address
    ) {
        voter.whitelisted_manager.whitelist_token(
            &voter.whitelisted_manager_cap,
            token,
            listed,
            sender
        );
    }

    // proxy method to be called via Minter
    public fun update_voted_weights(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        gauge_id: ID,
        weights: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        final: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        // is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));
        let gauge_id_obj = into_gauge_id(gauge_id);

        let fee_voting_reward = voter.gauge_to_fee.borrow_mut(gauge_id_obj);
        fee_voting_reward.update_balances(
            &voter.voter_cap,
            weights,
            lock_ids,
            for_epoch_start,
            final,
            clock,
            ctx
        );
    }

    public fun update_exercise_fee_weights(
        voter: &mut Voter,
        distribute_cap: &governance::distribute_cap::DistributeCap,
        weights: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        final: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        // is called by minter so version control is handled by minter
        distribute_cap.validate_distribute_voter_id(object::id<Voter>(voter));

        let exercise_fee_reward = &mut voter.exercise_fee_reward;
        exercise_fee_reward.update_balances(
            &voter.voter_cap,
            weights,
            lock_ids,
            for_epoch_start,
            final,
            clock,
            ctx
        );
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
        sui::package::claim<VOTER>(VOTER {}, ctx)
    }
}



module distribution::voter {

    const EDepositManagedLockNotOwned: u64 = 9223375275260116991;
    const EDepositManagedLockDeactivated: u64 = 9223375275262279714;
    const EDepositManagedInvalidManaged: u64 = 9223375292439986175;
    const EDepositManagedEpochVoteEnded: u64 = 9223375301033263156;

    const EWithdrawManagedInvlidManaged: u64 = 9223375378339332095;

    const EAddEpochGovernorInvalidGovernor: u64 = 9223373265216929816;

    const EAlreadyVotedInCurrentEpoch: u64 = 9223373329641701404;
    const EVotingNotStarted: u64 = 9223373333936799774;

    const ECheckVoteSizesDoNotMatch: u64 = 9223374162864308236;
    const ECheckVoteMaxVoteNumExceed: u64 = 9223374167160586272;
    const ECheckVoteGaugeNotFound: u64 = 9223374184339275790;
    const ECheckVoteWeightTooLarge: u64 = 9223374188634374160;

    const ECreateGaugeNotAGovernor: u64 = 9223373604519346200;
    const ECreateGaugeDistributionConfigInvalid: u64 = 9223373887985680383;

    const EGetVotesNotVoted: u64 = 9223375618857500671;

    const EKillGaugeStatusUnknown: u64 = 9223374012540190728;
    const EKillGaugeDistributionConfigInvalid: u64 = 9223374308896342076;
    const EKillGaugeAlreadyKilled: u64 = 9223374016835944468;

    const EPokeVotingNotStartedYet: u64 = 9223374433448427550;
    const EPokeLockNotVoted: u64 = 9223374510758756396;
    const EPokePoolNotVoted: u64 = 9223374527938625580;

    const EFirstTokenNotWhitelisted: u64 = 9223373870805811199;
    const ESecondTokenNotWhitelisted: u64 = 9223373875100778495;

    const ETokenNotWhitelisted: u64 = 9223373853625942015;

    const EReceiveGaugeInvalidGovernor: u64 = 9223373991066402840;
    const EReceiveGaugeAlreadyHasRepresent: u64 = 9223373720482283526;
    const EReceiveGaugePoolAreadyHasGauge: u64 = 9223373724779872302;

    const ERemoveEpochGovernorNotAGovernor: u64 = 9223373312461570072;

    const EReviveGaugeInvalidDistributionConfig: u64 = 9223374403385622588;
    const EReviveGaugeAlreadyAlive: u64 = 9223374124208881663;

    const ESetMaxVotingNumGovernorInvalid: u64 = 9223373183612551192;
    const ESetMaxVotingNumAtLeast10: u64 = 9223373187907649562;
    const ESetMaxVotingNumNotChanged: u64 = 9223373196495945727;

    const EUpdateForInternalGaugeNotAlive: u64 = 9223375717644828720;

    const EVoteVotingEscrowDeactivated: u64 = 9223374631017185314;
    const EVoteNotWhitelistedNft: u64 = 9223374648197185572;
    const EVoteNoVotingPower: u64 = 9223374686852022310;

    const EVoteInternalGaugeDoesNotExist: u64 = 9223374798519205896;
    const EVoteInternalGaugeNotAlive: u64 = 9223374807109926932;
    const EVoteInternalPoolAreadyVoted: u64 = 9223374832881041448;
    const EVoteInternalWeightResultedInZeroVotes: u64 = 9223374841471107114;

    const EDistributeGaugeInvalidGaugeRepresent: u64 = 9223375983929720831;

    const EExtractClaimableForLessThanMin: u64 = 9223375923800178687;

    const EWhitelistNftGovernorInvalid: u64 = 9223373956706664472;

    const EWhitelistTokenGovernorInvalid: u64 = 9223373896577122328;

    public struct VOTER has drop {}

    public struct PoolID has copy, drop, store {
        id: sui::object::ID,
    }

    public struct LockID has copy, drop, store {
        id: sui::object::ID,
    }

    public struct GaugeID has copy, drop, store {
        id: sui::object::ID,
    }

    public struct GaugeRepresent has drop, store {
        gauger_id: sui::object::ID,
        pool_id: sui::object::ID,
        weight: u64,
        last_reward_time: u64,
    }

    public struct Voter<phantom SailCoinType> has store, key {
        id: sui::object::UID,
        global_config: sui::object::ID,
        distribution_config: sui::object::ID,
        governors: sui::vec_set::VecSet<sui::object::ID>,
        epoch_governors: sui::vec_set::VecSet<sui::object::ID>,
        emergency_council: sui::object::ID,
        total_weight: u64,
        used_weights: sui::table::Table<LockID, u64>,
        pools: vector<PoolID>,
        pool_to_gauger: sui::table::Table<PoolID, GaugeID>,
        gauge_represents: sui::table::Table<GaugeID, GaugeRepresent>,
        votes: sui::table::Table<LockID, sui::table::Table<PoolID, u64>>,
        rewards: sui::table::Table<GaugeID, sui::balance::Balance<SailCoinType>>,
        weights: sui::table::Table<GaugeID, u64>,
        epoch: u64,
        voter_cap: distribution::voter_cap::VoterCap,
        balances: sui::bag::Bag,
        index: u128,
        supply_index: sui::table::Table<GaugeID, u128>,
        // claimable amount per gauge
        claimable: sui::table::Table<GaugeID, u64>,
        is_whitelisted_token: sui::table::Table<std::type_name::TypeName, bool>,
        is_whitelisted_nft: sui::table::Table<LockID, bool>,
        max_voting_num: u64,
        last_voted: sui::table::Table<LockID, u64>,
        pool_vote: sui::table::Table<LockID, vector<PoolID>>,
        gauge_to_fee_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        gauge_to_fee: sui::table::Table<GaugeID, distribution::fee_voting_reward::FeeVotingReward>,
        gauge_to_bribe_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        gauge_to_bribe: sui::table::Table<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>,
    }

    public struct EventNotifyReward has copy, drop, store {
        notifier: sui::object::ID,
        token: std::type_name::TypeName,
        amount: u64,
    }

    public struct EventExtractClaimable has copy, drop, store {
        gauger: sui::object::ID,
        amount: u64,
    }

    public struct EventWhitelistToken has copy, drop, store {
        sender: address,
        token: std::type_name::TypeName,
        listed: bool,
    }

    public struct EventWhitelistNFT has copy, drop, store {
        sender: address,
        id: sui::object::ID,
        listed: bool,
    }

    public struct EventKillGauge has copy, drop, store {
        id: sui::object::ID,
    }

    public struct EventReviveGauge has copy, drop, store {
        id: sui::object::ID,
    }

    public struct EventVoted has copy, drop, store {
        sender: address,
        pool: sui::object::ID,
        lock: sui::object::ID,
        voting_weight: u64,
        pool_weight: u64,
    }

    public struct EventAbstained has copy, drop, store {
        sender: address,
        pool: sui::object::ID,
        lock: sui::object::ID,
        votes: u64,
        pool_weight: u64,
    }

    public struct EventAddGovernor has copy, drop, store {
        who: address,
        cap: sui::object::ID,
    }

    public struct EventRemoveGovernor has copy, drop, store {
        cap: sui::object::ID,
    }

    public struct EventAddEpochGovernor has copy, drop, store {
        who: address,
        cap: sui::object::ID,
    }

    public struct EventRemoveEpochGovernor has copy, drop, store {
        cap: sui::object::ID,
    }

    public struct EventClaimBribeReward has copy, drop, store {
        who: address,
        amount: u64,
        pool: sui::object::ID,
        gauge: sui::object::ID,
        token: std::type_name::TypeName,
    }

    public struct EventClaimVotingFeeReward has copy, drop, store {
        who: address,
        amount: u64,
        pool: sui::object::ID,
        gauge: sui::object::ID,
        token: std::type_name::TypeName,
    }

    public struct EventDistributeGauge has copy, drop, store {
        pool: sui::object::ID,
        gauge: sui::object::ID,
        fee_a_amount: u64,
        fee_b_amount: u64,
        amount: u64,
    }

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        global_config: sui::object::ID,
        distribution_config: sui::object::ID,
        supported_coins: vector<std::type_name::TypeName>,
        ctx: &mut sui::tx_context::TxContext
    ): (Voter<SailCoinType>, distribution::notify_reward_cap::NotifyRewardCap) {
        let uid = sui::object::new(ctx);
        let id = *sui::object::uid_as_inner(&uid);
        let mut voter = Voter<SailCoinType> {
            id: uid,
            global_config,
            distribution_config,
            governors: sui::vec_set::empty<sui::object::ID>(),
            epoch_governors: sui::vec_set::empty<sui::object::ID>(),
            emergency_council: sui::object::id_from_address(@0x0),
            total_weight: 0,
            used_weights: sui::table::new<LockID, u64>(ctx),
            pools: std::vector::empty<PoolID>(),
            pool_to_gauger: sui::table::new<PoolID, GaugeID>(ctx),
            gauge_represents: sui::table::new<GaugeID, GaugeRepresent>(ctx),
            votes: sui::table::new<LockID, sui::table::Table<PoolID, u64>>(ctx),
            rewards: sui::table::new<GaugeID, sui::balance::Balance<SailCoinType>>(ctx),
            weights: sui::table::new<GaugeID, u64>(ctx),
            epoch: 0,
            voter_cap: distribution::voter_cap::create_voter_cap(id, ctx),
            balances: sui::bag::new(ctx),
            index: 0,
            supply_index: sui::table::new<GaugeID, u128>(ctx),
            claimable: sui::table::new<GaugeID, u64>(ctx),
            is_whitelisted_token: sui::table::new<std::type_name::TypeName, bool>(ctx),
            is_whitelisted_nft: sui::table::new<LockID, bool>(ctx),
            max_voting_num: 10,
            last_voted: sui::table::new<LockID, u64>(ctx),
            pool_vote: sui::table::new<LockID, vector<PoolID>>(ctx),
            gauge_to_fee_authorized_cap: distribution::reward_authorized_cap::create(id, ctx),
            gauge_to_fee: sui::table::new<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(ctx),
            gauge_to_bribe_authorized_cap: distribution::reward_authorized_cap::create(id, ctx),
            gauge_to_bribe: sui::table::new<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(ctx),
        };
        let mut i = 0;
        while (i < std::vector::length<std::type_name::TypeName>(&supported_coins)) {
            whitelist_token_internal<SailCoinType>(
                &mut voter,
                supported_coins[i],
                true,
                sui::tx_context::sender(ctx)
            );
            i = i + 1;
        };
        let sail_coin_type = std::type_name::get<SailCoinType>();
        if (!sui::table::contains<std::type_name::TypeName, bool>(&voter.is_whitelisted_token, sail_coin_type)) {
            sui::table::add<std::type_name::TypeName, bool>(&mut voter.is_whitelisted_token, sail_coin_type, true);
        };
        let notify_reward_cap = distribution::notify_reward_cap::create_internal(sui::object::id<Voter<SailCoinType>>(&voter), ctx);
        (voter, notify_reward_cap)
    }

    public fun deposit_managed<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &mut distribution::voting_escrow::Lock,
        managed_lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        assert_only_new_epoch<SailCoinType>(voter, lock_id, clock);
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time <= distribution::common::epoch_vote_end(current_time), EDepositManagedEpochVoteEnded);
        if (sui::table::contains<LockID, u64>(&voter.last_voted, lock_id)) {
            sui::table::remove<LockID, u64>(&mut voter.last_voted, lock_id);
        };
        sui::table::add<LockID, u64>(&mut voter.last_voted, lock_id, current_time);
        distribution::voting_escrow::deposit_managed<SailCoinType>(
            voting_escrow,
            &voter.voter_cap,
            lock,
            managed_lock,
            clock,
            ctx
        );
        let balance = distribution::voting_escrow::balance_of_nft_at<SailCoinType>(
            voting_escrow,
            lock_id.id,
            current_time
        );
        poke_internal<SailCoinType>(
            voter,
            voting_escrow,
            distribution_config,
            managed_lock,
            balance,
            clock,
            ctx
        );
    }

    public fun withdraw_managed<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &mut distribution::voting_escrow::Lock,
        managed_lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        assert_only_new_epoch<SailCoinType>(voter, lock_id, clock);
        let managedd_lock_id = distribution::voting_escrow::id_to_managed<SailCoinType>(voting_escrow, lock_id.id);
        assert!(
            managedd_lock_id == sui::object::id<distribution::voting_escrow::Lock>(managed_lock),
            EWithdrawManagedInvlidManaged
        );
        let owner_proof = distribution::voting_escrow::owner_proof<SailCoinType>(
            voting_escrow,
            lock,
            ctx
        );
        distribution::voting_escrow::withdraw_managed<SailCoinType>(
            voting_escrow,
            &voter.voter_cap,
            lock,
            managed_lock,
            owner_proof,
            clock,
            ctx
        );
        let balance_of_nft = distribution::voting_escrow::balance_of_nft_at<SailCoinType>(
            voting_escrow,
            managedd_lock_id,
            distribution::common::current_timestamp(clock)
        );
        if (balance_of_nft == 0) {
            reset_internal<SailCoinType>(voter, voting_escrow, distribution_config, managed_lock, clock, ctx);
            if (sui::table::contains<LockID, u64>(&voter.last_voted, into_lock_id(managedd_lock_id))) {
                sui::table::remove<LockID, u64>(&mut voter.last_voted, into_lock_id(managedd_lock_id));
            };
        } else {
            poke_internal<SailCoinType>(
                voter,
                voting_escrow,
                distribution_config,
                managed_lock,
                balance_of_nft,
                clock,
                ctx
            );
        };
    }

    public fun add_epoch_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        who: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EAddEpochGovernorInvalidGovernor
        );
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        let epoch_governor_cap = distribution::voter_cap::create_epoch_governor_cap(
            sui::object::id<Voter<SailCoinType>>(voter),
            ctx
        );
        let epoch_governor_cap_id = sui::object::id<distribution::voter_cap::EpochGovernorCap>(&epoch_governor_cap);
        sui::transfer::public_transfer<distribution::voter_cap::EpochGovernorCap>(epoch_governor_cap, who);
        voter.epoch_governors.insert<sui::object::ID>(epoch_governor_cap_id);
        let add_epoch_governor_event = EventAddEpochGovernor {
            who,
            cap: epoch_governor_cap_id,
        };
        sui::event::emit<EventAddEpochGovernor>(add_epoch_governor_event);
    }

    public fun add_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        _publisher: &sui::package::Publisher,
        who: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let governor_cap = distribution::voter_cap::create_governor_cap(
            sui::object::id<Voter<SailCoinType>>(voter),
            who,
            ctx
        );
        let governor_cap_id = sui::object::id<distribution::voter_cap::GovernorCap>(&governor_cap);
        voter.governors.insert<sui::object::ID>(governor_cap_id);
        sui::transfer::public_transfer<distribution::voter_cap::GovernorCap>(governor_cap, who);
        let add_governor_event = EventAddGovernor {
            who,
            cap: governor_cap_id,
        };
        sui::event::emit<EventAddGovernor>(add_governor_event);
    }

    fun assert_only_new_epoch<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: LockID, clock: &sui::clock::Clock) {
        let current_time = distribution::common::current_timestamp(clock);
        assert!(
            !sui::table::contains<LockID, u64>(&voter.last_voted, lock_id) ||
                distribution::common::epoch_start(current_time) > *sui::table::borrow<LockID, u64>(
                    &voter.last_voted,
                    lock_id
                ),
            EAlreadyVotedInCurrentEpoch
        );
        assert!(current_time > distribution::common::epoch_vote_start(current_time), EVotingNotStarted);
    }

    public fun borrow_bribe_voting_reward<SailCoinType>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
            &voter.gauge_to_bribe,
            into_gauge_id(gauge_id)
        )
    }

    public fun borrow_bribe_voting_reward_mut<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &mut distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
            &mut voter.gauge_to_bribe,
            into_gauge_id(gauge_id)
        )
    }

    public fun borrow_fee_voting_reward<SailCoinType>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &voter.gauge_to_fee,
            into_gauge_id(gauge_id)
        )
    }

    public fun borrow_fee_voting_reward_mut<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &mut distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &mut voter.gauge_to_fee,
            into_gauge_id(gauge_id)
        )
    }

    public fun borrow_voter_cap<SailCoinType>(
        voter: &Voter<SailCoinType>,
        notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap
    ): &distribution::voter_cap::VoterCap {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(
            notify_reward_cap,
            sui::object::id<Voter<SailCoinType>>(voter)
        );
        &voter.voter_cap
    }

    fun check_vote<SailCoinType>(
        voter: &Voter<SailCoinType>,
        pool_ids: &vector<sui::object::ID>,
        weights: &vector<u64>
    ) {
        let pools_length = std::vector::length<sui::object::ID>(pool_ids);
        assert!(pools_length == std::vector::length<u64>(weights), ECheckVoteSizesDoNotMatch);
        assert!(pools_length <= voter.max_voting_num, ECheckVoteMaxVoteNumExceed);
        let mut i = 0;
        while (i < pools_length) {
            assert!(
                sui::table::contains<PoolID, GaugeID>(
                    &voter.pool_to_gauger,
                    into_pool_id(pool_ids[i])
                ),
                ECheckVoteGaugeNotFound
            );
            assert!(weights[i] <= 10000, ECheckVoteWeightTooLarge);
            i = i + 1;
        };
    }

    public fun claim_voting_bribe<SailCoinType, BribeCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let voted_pools = sui::table::borrow<LockID, vector<PoolID>>(
            &voter.pool_vote,
            into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock))
        );
        let mut i = 0;
        while (i < std::vector::length<PoolID>(voted_pools)) {
            let pool_id = *std::vector::borrow<PoolID>(voted_pools, i);
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id);
            i = i + 1;
            let claim_bribe_reward_event = EventClaimBribeReward {
                who: sui::tx_context::sender(ctx),
                amount: distribution::bribe_voting_reward::get_reward<SailCoinType, BribeCoinType>(
                    sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
                        &mut voter.gauge_to_bribe,
                        gauge_id
                    ),
                    voting_escrow,
                    lock,
                    clock,
                    ctx
                ),
                pool: pool_id.id,
                gauge: gauge_id.id,
                token: std::type_name::get<BribeCoinType>(),
            };
            sui::event::emit<EventClaimBribeReward>(claim_bribe_reward_event);
        };
    }

    public fun claim_voting_fee_reward<SailCoinType, FeeCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let voted_pools = sui::table::borrow<LockID, vector<PoolID>>(
            &voter.pool_vote,
            into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock))
        );
        let mut i = 0;
        while (i < std::vector::length<PoolID>(voted_pools)) {
            let pool_id = *std::vector::borrow<PoolID>(voted_pools, i);
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id);
            i = i + 1;
            let claim_voting_fee_reward_event = EventClaimVotingFeeReward {
                who: sui::tx_context::sender(ctx),
                amount: distribution::fee_voting_reward::get_reward<SailCoinType, FeeCoinType>(
                    sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                        &mut voter.gauge_to_fee,
                        gauge_id
                    ),
                    voting_escrow,
                    lock,
                    clock,
                    ctx
                ),
                pool: pool_id.id,
                gauge: gauge_id.id,
                token: std::type_name::get<FeeCoinType>(),
            };
            sui::event::emit<EventClaimVotingFeeReward>(claim_voting_fee_reward_event);
        };
    }

    public fun claimable<SailCoinType>(voter: &Voter<SailCoinType>, gauge_id: sui::object::ID): u64 {
        let gauge_id_obj = into_gauge_id(gauge_id);
        if (sui::table::contains<GaugeID, u64>(&voter.claimable, gauge_id_obj)) {
            *sui::table::borrow<GaugeID, u64>(&voter.claimable, gauge_id_obj)
        } else {
            0
        }
    }

    public fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        governor_cap: &distribution::voter_cap::GovernorCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            ECreateGaugeNotAGovernor
        );
        assert!(
            voter.distribution_config == sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ),
            ECreateGaugeDistributionConfigInvalid
        );
        let mut gauge = return_new_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
            distribution_config,
            create_cap,
            pool,
            ctx
        );
        let mut reward_coins = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut reward_coins, std::type_name::get<CoinTypeA>());
        std::vector::push_back<std::type_name::TypeName>(&mut reward_coins, std::type_name::get<CoinTypeB>());
        let gauge_id = sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(&gauge);
        let voter_id = sui::object::id<Voter<SailCoinType>>(voter);
        let voting_escrow_id = sui::object::id<distribution::voting_escrow::VotingEscrow<SailCoinType>>(voting_escrow);
        sui::table::add<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &mut voter.gauge_to_fee,
            into_gauge_id(gauge_id),
            distribution::fee_voting_reward::create(voter_id, voting_escrow_id, gauge_id, reward_coins, ctx)
        );
        std::vector::push_back<std::type_name::TypeName>(&mut reward_coins, std::type_name::get<SailCoinType>());
        sui::table::add<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
            &mut voter.gauge_to_bribe,
            into_gauge_id(gauge_id),
            distribution::bribe_voting_reward::create(voter_id, voting_escrow_id, gauge_id, reward_coins, ctx)
        );
        receive_gauger<CoinTypeA, CoinTypeB, SailCoinType>(voter, governor_cap, &mut gauge, clock, ctx);
        let mut alive_gauges_vec = std::vector::empty<sui::object::ID>();
        std::vector::push_back<sui::object::ID>(&mut alive_gauges_vec, gauge_id);
        distribution::distribution_config::update_gauge_liveness(distribution_config, alive_gauges_vec, true, ctx);
        gauge
    }

    public fun distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let gauge_id = into_gauge_id(
            sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)
        );
        let gauge_represent = sui::table::borrow<GaugeID, GaugeRepresent>(&voter.gauge_represents, gauge_id);
        assert!(
            gauge_represent.pool_id == sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(
                pool
            ) && gauge_represent.gauger_id == gauge_id.id,
            EDistributeGaugeInvalidGaugeRepresent
        );
        let claimable_balance = extract_claimable_for<SailCoinType>(voter, distribution_config, gauge_id.id);
        let balance_value = sui::balance::value<SailCoinType>(&claimable_balance);
        let (fee_reward_a, fee_reward_b) = distribution::gauge::notify_reward<CoinTypeA, CoinTypeB, SailCoinType>(
            gauge,
            &voter.voter_cap,
            pool,
            claimable_balance,
            clock,
            ctx
        );
        let fee_a_amount = fee_reward_a.value<CoinTypeA>();
        let fee_b_amount = fee_reward_b.value<CoinTypeB>();
        let fee_voting_reward = sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &mut voter.gauge_to_fee,
            gauge_id
        );
        distribution::fee_voting_reward::notify_reward_amount<CoinTypeA>(
            fee_voting_reward,
            &voter.gauge_to_fee_authorized_cap,
            sui::coin::from_balance<CoinTypeA>(fee_reward_a, ctx),
            clock,
            ctx
        );
        distribution::fee_voting_reward::notify_reward_amount<CoinTypeB>(
            fee_voting_reward,
            &voter.gauge_to_fee_authorized_cap,
            sui::coin::from_balance<CoinTypeB>(fee_reward_b, ctx),
            clock,
            ctx
        );
        let distribute_gauge_event = EventDistributeGauge {
            pool: sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            gauge: gauge_id.id,
            fee_a_amount,
            fee_b_amount,
            amount: balance_value,
        };
        sui::event::emit<EventDistributeGauge>(distribute_gauge_event);
        balance_value
    }

    fun extract_claimable_for<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_id: sui::object::ID
    ): sui::balance::Balance<SailCoinType> {
        let gauge_id = into_gauge_id(gauge_id);
        update_for_internal<SailCoinType>(voter, distribution_config, gauge_id);
        let amount = *sui::table::borrow<GaugeID, u64>(&voter.claimable, gauge_id);
        sui::table::remove<GaugeID, u64>(&mut voter.claimable, gauge_id);
        sui::table::add<GaugeID, u64>(&mut voter.claimable, gauge_id, 0);
        let extract_claimable_event = EventExtractClaimable {
            gauger: gauge_id.id,
            amount,
        };
        sui::event::emit<EventExtractClaimable>(extract_claimable_event);
        sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
            &mut voter.balances,
            std::type_name::get<SailCoinType>()
        ).split<SailCoinType>(amount)
    }

    public fun fee_voting_reward_balance<SailCoinType, CoinTypeA>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): u64 {
        distribution::fee_voting_reward::balance<CoinTypeA>(
            sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                &voter.gauge_to_fee,
                into_gauge_id(gauge_id)
            )
        )
    }

    public fun get_balance<SailCoinType, BribeCoinType>(voter: &Voter<SailCoinType>): u64 {
        let bribe_coin_type = std::type_name::get<BribeCoinType>();
        if (!sui::bag::contains<std::type_name::TypeName>(&voter.balances, bribe_coin_type)) {
            0
        } else {
            sui::bag::borrow<std::type_name::TypeName, sui::balance::Balance<BribeCoinType>>(
                &voter.balances,
                bribe_coin_type
            ).value<BribeCoinType>()
        }
    }

    public fun get_gauge_weight<SailCoinType>(voter: &Voter<SailCoinType>, gauge_id: sui::object::ID): u64 {
        *sui::table::borrow<GaugeID, u64>(&voter.weights, into_gauge_id(gauge_id))
    }

    public fun get_pool_weight<SailCoinType>(arg0: &Voter<SailCoinType>, pool_id: sui::object::ID): u64 {
        let gauge_id = *sui::table::borrow<PoolID, GaugeID>(
            &arg0.pool_to_gauger,
            into_pool_id(pool_id)
        );
        get_gauge_weight<SailCoinType>(arg0, gauge_id.id)
    }

    public fun get_total_weight<SailCoinType>(voter: &Voter<SailCoinType>): u64 {
        voter.total_weight
    }

    public fun get_votes<SailCoinType>(
        voter: &Voter<SailCoinType>,
        lock_id: sui::object::ID
    ): &sui::table::Table<PoolID, u64> {
        let lock_id_obj = into_lock_id(lock_id);
        assert!(
            sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id_obj),
            EGetVotesNotVoted
        );
        sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id_obj)
    }

    fun init(otw: VOTER, ctx: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<VOTER>(otw, ctx);
    }

    public(package) fun into_gauge_id(id: sui::object::ID): GaugeID {
        GaugeID { id }
    }

    public(package) fun into_lock_id(id: sui::object::ID): LockID {
        LockID { id }
    }

    public(package) fun into_pool_id(id: sui::object::ID): PoolID {
        PoolID { id }
    }

    public fun is_epoch_governor<SailCoinType>(voter: &Voter<SailCoinType>, who: sui::object::ID): bool {
        voter.epoch_governors.contains<sui::object::ID>(&who)
    }

    public fun is_governor<SailCoinType>(voter: &Voter<SailCoinType>, who: sui::object::ID): bool {
        voter.governors.contains<sui::object::ID>(&who)
    }

    public fun is_whitelisted_nft<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: sui::object::ID): bool {
        let lock_id_obj = into_lock_id(lock_id);
        sui::table::contains<LockID, bool>(&voter.is_whitelisted_nft, lock_id_obj) &&
            *sui::table::borrow<LockID, bool>(&voter.is_whitelisted_nft, lock_id_obj)
    }

    public fun is_whitelisted_token<SailCoinType, CoinToCheckType>(voter: &Voter<SailCoinType>): bool {
        let coin_type_name = std::type_name::get<CoinToCheckType>();
        if (sui::table::contains<std::type_name::TypeName, bool>(&voter.is_whitelisted_token, coin_type_name)) {
            let is_whitelisted_true = true;
            &is_whitelisted_true == sui::table::borrow<std::type_name::TypeName, bool>(
                &voter.is_whitelisted_token,
                coin_type_name
            )
        } else {
            false
        }
    }

    public fun kill_gauge<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<SailCoinType> {
        distribution::emergency_council::validate_emergency_council_voter_id(
            emergency_council_cap,
            sui::object::id<Voter<SailCoinType>>(
                voter
            )
        );
        assert!(
            sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ) == voter.distribution_config,
            EKillGaugeDistributionConfigInvalid
        );
        assert!(
            distribution::distribution_config::is_gauge_alive(distribution_config, gauge_id),
            EKillGaugeAlreadyKilled
        );
        let gauge_id_obj = into_gauge_id(gauge_id);
        update_for_internal<SailCoinType>(voter, distribution_config, gauge_id_obj);
        let remaining_claimable_amount = if (sui::table::contains<GaugeID, u64>(&voter.claimable, gauge_id_obj)) {
            sui::table::remove<GaugeID, u64>(&mut voter.claimable, gauge_id_obj)
        } else {
            0
        };
        let mut cashback = sui::balance::zero<SailCoinType>();
        if (remaining_claimable_amount > 0) {
            cashback.join<SailCoinType>(
                sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
                    &mut voter.balances,
                    std::type_name::get<SailCoinType>()
                ).split<SailCoinType>(remaining_claimable_amount)
            );
        };
        let mut killed_gauge_ids = std::vector::empty<sui::object::ID>();
        std::vector::push_back<sui::object::ID>(&mut killed_gauge_ids, gauge_id_obj.id);
        distribution::distribution_config::update_gauge_liveness(distribution_config, killed_gauge_ids, false, ctx);
        let kill_gauge_event = EventKillGauge { id: gauge_id_obj.id };
        sui::event::emit<EventKillGauge>(kill_gauge_event);
        cashback
    }

    public fun lock_last_voted_at<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: sui::object::ID): u64 {
        let lock_id_obj = into_lock_id(lock_id);
        if (!sui::table::contains<LockID, u64>(&voter.last_voted, lock_id_obj)) {
            0
        } else {
            *sui::table::borrow<LockID, u64>(&voter.last_voted, lock_id_obj)
        }
    }

    public fun notify_rewards<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap,
        reward: sui::coin::Coin<SailCoinType>
    ) {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(
            notify_reward_cap,
            sui::object::id<Voter<SailCoinType>>(voter)
        );
        let reward_balance = sui::coin::into_balance<SailCoinType>(reward);
        let reward_amount = reward_balance.value<SailCoinType>();
        let coin_type_name = std::type_name::get<SailCoinType>();
        let mut existing_balance = if (sui::bag::contains<std::type_name::TypeName>(&voter.balances, coin_type_name)) {
            sui::bag::remove<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(&mut voter.balances,
                coin_type_name
            )
        } else {
            sui::balance::zero<SailCoinType>()
        };
        existing_balance.join<SailCoinType>(reward_balance);
        sui::bag::add<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
            &mut voter.balances,
            coin_type_name,
            existing_balance
        );
        let total_weight = if (voter.total_weight == 0) {
            1
        } else {
            voter.total_weight
        };
        let reward_per_weight_unit = integer_mate::full_math_u128::mul_div_floor(
            reward_amount as u128,
            1 << 64,
            total_weight as u128
        );
        if (reward_per_weight_unit > 0) {
            voter.index = voter.index + reward_per_weight_unit;
        };
        let notify_reward_event = EventNotifyReward {
            notifier: distribution::notify_reward_cap::who(notify_reward_cap),
            token: coin_type_name,
            amount: reward_amount,
        };
        sui::event::emit<EventNotifyReward>(notify_reward_event);
    }

    public fun poke<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time > distribution::common::epoch_vote_start(current_time), EPokeVotingNotStartedYet);
        let voting_power = distribution::voting_escrow::get_voting_power<SailCoinType>(voting_escrow, lock, clock);
        poke_internal<SailCoinType>(
            voter,
            voting_escrow,
            distribution_config,
            lock,
            voting_power,
            clock,
            ctx
        );
    }

    fun poke_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        voting_power: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        let pool_vote_count = if (sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id)) {
            std::vector::length<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&voter.pool_vote, lock_id))
        } else {
            0
        };
        if (pool_vote_count > 0) {
            let mut vote_amounts = std::vector::empty<u64>();
            let mut i = 0;
            let pools_voted = sui::table::borrow<LockID, vector<PoolID>>(&voter.pool_vote, lock_id);
            let mut pools_voted_ids = std::vector::empty<sui::object::ID>();
            assert!(
                sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                EPokeLockNotVoted
            );
            while (i < pool_vote_count) {
                std::vector::push_back<sui::object::ID>(&mut pools_voted_ids, std::vector::borrow<PoolID>(
                    pools_voted, i).id);
                let vote_amount_by_pool = sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(
                    &voter.votes,
                    lock_id
                );
                assert!(
                    sui::table::contains<PoolID, u64>(vote_amount_by_pool, pools_voted[i]),
                    EPokePoolNotVoted
                );
                std::vector::push_back<u64>(
                    &mut vote_amounts,
                    *sui::table::borrow<PoolID, u64>(vote_amount_by_pool, pools_voted[i])
                );
                i = i + 1;
            };
            vote_internal<SailCoinType>(
                voter,
                voting_escrow,
                distribution_config,
                lock,
                voting_power,
                pools_voted_ids,
                vote_amounts,
                clock,
                ctx
            );
        };
    }

    public fun pool_to_gauge<SailCoinType>(voter: &Voter<SailCoinType>, pool_id: sui::object::ID): sui::object::ID {
        sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, into_pool_id(pool_id)).id
    }

    public fun pools_gauges<SailCoinType>(
        voter: &Voter<SailCoinType>
    ): (vector<sui::object::ID>, vector<sui::object::ID>) {
        let mut pool_ids = std::vector::empty<sui::object::ID>();
        let mut gauge_ids = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < std::vector::length<PoolID>(&voter.pools)) {
            let pool_id = std::vector::borrow<PoolID>(&voter.pools, i).id;
            std::vector::push_back<sui::object::ID>(&mut pool_ids, pool_id);
            std::vector::push_back<sui::object::ID>(&mut gauge_ids, pool_to_gauge<SailCoinType>(voter, pool_id));
            i = i + 1;
        };
        (pool_ids, gauge_ids)
    }

    public fun prove_pair_whitelisted<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &Voter<SailCoinType>
    ): distribution::whitelisted_tokens::WhitelistedTokenPair {
        assert!(is_whitelisted_token<SailCoinType, CoinTypeA>(voter), EFirstTokenNotWhitelisted);
        assert!(is_whitelisted_token<SailCoinType, CoinTypeB>(voter), ESecondTokenNotWhitelisted);
        distribution::whitelisted_tokens::create_pair<CoinTypeA, CoinTypeB>(sui::object::id<Voter<SailCoinType>>(voter))
    }

    public fun prove_token_whitelisted<SailCoinType, CoinToCheckType>(
        voter: &Voter<SailCoinType>
    ): distribution::whitelisted_tokens::WhitelistedToken {
        assert!(is_whitelisted_token<SailCoinType, CoinToCheckType>(voter), ETokenNotWhitelisted);
        distribution::whitelisted_tokens::create<CoinToCheckType>(sui::object::id<Voter<SailCoinType>>(voter))
    }

    public fun receive_gauger<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EReceiveGaugeInvalidGovernor
        );
        let gauge_id = into_gauge_id(
            sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)
        );
        let pool_id = into_pool_id(distribution::gauge::pool_id<CoinTypeA, CoinTypeB, SailCoinType>(gauge));
        assert!(
            !sui::table::contains<GaugeID, GaugeRepresent>(&voter.gauge_represents, gauge_id),
            EReceiveGaugeAlreadyHasRepresent
        );
        assert!(
            !sui::table::contains<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id),
            EReceiveGaugePoolAreadyHasGauge
        );
        let gauge_represent = GaugeRepresent {
            gauger_id: sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            pool_id: distribution::gauge::pool_id<CoinTypeA, CoinTypeB, SailCoinType>(gauge),
            weight: 0,
            last_reward_time: sui::clock::timestamp_ms(clock),
        };
        sui::table::add<GaugeID, GaugeRepresent>(&mut voter.gauge_represents, gauge_id, gauge_represent);
        sui::table::add<GaugeID, sui::balance::Balance<SailCoinType>>(
            &mut voter.rewards,
            gauge_id,
            sui::balance::zero<SailCoinType>()
        );
        sui::table::add<GaugeID, u64>(&mut voter.weights, gauge_id, 0);
        std::vector::push_back<PoolID>(&mut voter.pools, pool_id);
        sui::table::add<PoolID, GaugeID>(&mut voter.pool_to_gauger, pool_id, gauge_id);
        distribution::gauge::set_voter<CoinTypeA, CoinTypeB, SailCoinType>(
            gauge,
            sui::object::id<Voter<SailCoinType>>(voter)
        );
        whitelist_token<SailCoinType, CoinTypeA>(voter, governor_cap, true, ctx);
        whitelist_token<SailCoinType, CoinTypeB>(voter, governor_cap, true, ctx);
        if (!is_whitelisted_token<SailCoinType, SailCoinType>(voter)) {
            whitelist_token<SailCoinType, SailCoinType>(voter, governor_cap, true, ctx);
        };
    }

    public fun remove_epoch_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        who: sui::object::ID
    ) {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            ERemoveEpochGovernorNotAGovernor
        );
        voter.epoch_governors.remove<sui::object::ID>(&who);
        let remove_epoch_governor_event = EventRemoveEpochGovernor { cap: who, };
        sui::event::emit<EventRemoveEpochGovernor>(remove_epoch_governor_event);
    }

    public fun remove_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        _publisher: &sui::package::Publisher,
        who: sui::object::ID
    ) {
        voter.governors.remove<sui::object::ID>(&who);
        let remove_governor_event = EventRemoveGovernor { cap: who };
        sui::event::emit<EventRemoveGovernor>(remove_governor_event);
    }

    public fun reset<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert_only_new_epoch<SailCoinType>(
            voter,
            into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock)),
            clock
        );
        reset_internal<SailCoinType>(
            voter,
            voting_escrow,
            distribution_config,
            lock,
            clock,
            ctx
        );
    }

    fun reset_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        let total_pools_count = if (sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id)) {
            std::vector::length<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&voter.pool_vote, lock_id))
        } else {
            0
        };
        let mut total_removed_weight = 0;
        let mut pool_index = 0;
        while (pool_index < total_pools_count) {
            let pool_id = (sui::table::borrow<LockID, vector<PoolID>>(&voter.pool_vote, lock_id))[pool_index];
            let pool_votes = *sui::table::borrow<PoolID, u64>(
                sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                pool_id
            );
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id);
            if (pool_votes != 0) {
                update_for_internal<SailCoinType>(voter, distribution_config, gauge_id);
                let weight = sui::table::remove<GaugeID, u64>(&mut voter.weights, gauge_id) - pool_votes;
                sui::table::add<GaugeID, u64>(&mut voter.weights, gauge_id, weight);
                sui::table::remove<PoolID, u64>(
                    sui::table::borrow_mut<LockID, sui::table::Table<PoolID, u64>>(&mut voter.votes, lock_id),
                    pool_id
                );
                distribution::fee_voting_reward::withdraw(
                    sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                        &mut voter.gauge_to_fee,
                        gauge_id
                    ),
                    &voter.gauge_to_fee_authorized_cap,
                    pool_votes,
                    lock_id.id,
                    clock,
                    ctx
                );
                distribution::bribe_voting_reward::withdraw(
                    sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
                        &mut voter.gauge_to_bribe,
                        gauge_id
                    ),
                    &voter.gauge_to_bribe_authorized_cap,
                    pool_votes,
                    lock_id.id,
                    clock,
                    ctx
                );
                total_removed_weight = total_removed_weight + pool_votes;
                let abstained_event = EventAbstained {
                    sender: sui::tx_context::sender(ctx),
                    pool: pool_id.id,
                    lock: lock_id.id,
                    votes: pool_votes,
                    pool_weight: *sui::table::borrow<GaugeID, u64>(&voter.weights, gauge_id),
                };
                sui::event::emit<EventAbstained>(abstained_event);
            };
            pool_index = pool_index + 1;
        };
        distribution::voting_escrow::voting<SailCoinType>(voting_escrow, &voter.voter_cap, lock_id.id, false);
        voter.total_weight = voter.total_weight - total_removed_weight;
        if (sui::table::contains<LockID, u64>(&voter.used_weights, lock_id)) {
            sui::table::remove<LockID, u64>(&mut voter.used_weights, lock_id);
        };
        if (sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id)) {
            sui::table::remove<LockID, vector<PoolID>>(&mut voter.pool_vote, lock_id);
        };
    }

    public(package) fun return_new_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_create_cap: &gauge_cap::gauge_cap::CreateCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ): distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let mut gauge = distribution::gauge::create<CoinTypeA, CoinTypeB, SailCoinType>(
            distribution_config,
            pool_id,
            ctx
        );
        let gauge_cap = gauge_cap::gauge_cap::create_gauge_cap(
            gauge_create_cap,
            pool_id,
            sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(&gauge),
            ctx
        );
        clmm_pool::pool::init_magma_distribution_gauge<CoinTypeA, CoinTypeB>(pool, &gauge_cap);
        distribution::gauge::receive_gauge_cap<CoinTypeA, CoinTypeB, SailCoinType>(&mut gauge, gauge_cap);
        gauge
    }

    public fun revive_gauge<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::emergency_council::validate_emergency_council_voter_id(
            emergency_council_cap,
            sui::object::id<Voter<SailCoinType>>(
                voter
            )
        );
        assert!(
            sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ) == voter.distribution_config,
            EReviveGaugeInvalidDistributionConfig
        );
        assert!(
            !distribution::distribution_config::is_gauge_alive(distribution_config, gauge_id),
            EReviveGaugeAlreadyAlive
        );
        let mut alive_gauge_ids = std::vector::empty<sui::object::ID>();
        std::vector::push_back<sui::object::ID>(&mut alive_gauge_ids, gauge_id);
        distribution::distribution_config::update_gauge_liveness(distribution_config, alive_gauge_ids, true, ctx);
        let revieve_gauge_event = EventReviveGauge { id: gauge_id };
        sui::event::emit<EventReviveGauge>(revieve_gauge_event);
    }

    public fun set_max_voting_num<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        new_max_voting_num: u64
    ) {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            ESetMaxVotingNumGovernorInvalid
        );
        assert!(new_max_voting_num >= 10, ESetMaxVotingNumAtLeast10);
        assert!(new_max_voting_num != voter.max_voting_num, ESetMaxVotingNumNotChanged);
        voter.max_voting_num = new_max_voting_num;
    }

    public fun total_weight<SailCoinType>(voter: &Voter<SailCoinType>): u64 {
        voter.total_weight
    }

    public fun update_for<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_id: sui::object::ID
    ) {
        update_for_internal<SailCoinType>(voter, distribution_config, into_gauge_id(gauge_id));
    }

    fun update_for_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_id: GaugeID
    ) {
        let gauge_weight = if (sui::table::contains<GaugeID, u64>(&voter.weights, gauge_id)) {
            *sui::table::borrow<GaugeID, u64>(&voter.weights, gauge_id)
        } else {
            0
        };
        if (gauge_weight > 0) {
            let gauge_supply_index = if (sui::table::contains<GaugeID, u128>(&voter.supply_index, gauge_id)) {
                sui::table::remove<GaugeID, u128>(&mut voter.supply_index, gauge_id)
            } else {
                0
            };
            let voter_index = voter.index;
            sui::table::add<GaugeID, u128>(&mut voter.supply_index, gauge_id, voter_index);
            let index_delta = voter_index - gauge_supply_index;
            if (index_delta > 0) {
                assert!(
                    distribution::distribution_config::is_gauge_alive(distribution_config, gauge_id.id),
                    EUpdateForInternalGaugeNotAlive
                );
                let gauge_claimable = if (sui::table::contains<GaugeID, u64>(&voter.claimable, gauge_id)) {
                    sui::table::remove<GaugeID, u64>(&mut voter.claimable, gauge_id)
                } else {
                    0
                };
                sui::table::add<GaugeID, u64>(
                    &mut voter.claimable,
                    gauge_id,
                    gauge_claimable + (integer_mate::full_math_u128::mul_div_floor(
                        gauge_weight as u128,
                        index_delta,
                        1 << 64
                    ) as u64)
                );
            };
        } else {
            if (sui::table::contains<GaugeID, u128>(&voter.supply_index, gauge_id)) {
                sui::table::remove<GaugeID, u128>(&mut voter.supply_index, gauge_id);
            };
            sui::table::add<GaugeID, u128>(&mut voter.supply_index, gauge_id, voter.index);
        };
    }

    public fun update_for_many<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_ids: vector<sui::object::ID>
    ) {
        let mut i = 0;
        while (i < std::vector::length<sui::object::ID>(&gauge_ids)) {
            update_for_internal<SailCoinType>(voter, distribution_config, into_gauge_id(gauge_ids[i]));
            i = i + 1;
        };
    }

    public fun update_for_range<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        start_index: u64,
        end_index: u64
    ) {
        let mut i = 0;
        let pools_length = std::vector::length<PoolID>(&voter.pools);
        let mut iteration_end = pools_length;
        if (pools_length > end_index) {
            iteration_end = end_index;
        };
        while (start_index + i < iteration_end) {
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(
                &voter.pool_to_gauger,
                voter.pools[start_index + i]
            );
            update_for_internal<SailCoinType>(
                voter,
                distribution_config,
                gauge_id,
            );
            i = i + 1;
        };
    }

    public fun used_weights<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: sui::object::ID): u64 {
        *sui::table::borrow<LockID, u64>(&voter.used_weights, into_lock_id(lock_id))
    }

    public fun vote<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        pools: vector<sui::object::ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        assert_only_new_epoch<SailCoinType>(voter, lock_id, clock);
        check_vote<SailCoinType>(voter, &pools, &weights);
        assert!(
            !distribution::voting_escrow::deactivated<SailCoinType>(voting_escrow, lock_id.id),
            EVoteVotingEscrowDeactivated
        );
        let current_time = distribution::common::current_timestamp(clock);
        let epoch_vote_ended_and_nft_not_whitelisted = (
            current_time > distribution::common::epoch_vote_end(current_time)
        ) && (
            !sui::table::contains<LockID, bool>(&voter.is_whitelisted_nft, lock_id) ||
                *sui::table::borrow<LockID, bool>(&voter.is_whitelisted_nft, lock_id) == false
        );
        if (epoch_vote_ended_and_nft_not_whitelisted) {
            abort EVoteNotWhitelistedNft
        };
        if (sui::table::contains<LockID, u64>(&voter.last_voted, lock_id)) {
            sui::table::remove<LockID, u64>(&mut voter.last_voted, lock_id);
        };
        sui::table::add<LockID, u64>(&mut voter.last_voted, lock_id, current_time);
        let voting_power = distribution::voting_escrow::get_voting_power<SailCoinType>(voting_escrow, lock, clock);
        assert!(voting_power > 0, EVoteNoVotingPower);
        vote_internal<SailCoinType>(
            voter,
            voting_escrow,
            distribution_config,
            lock,
            voting_power,
            pools,
            weights,
            clock,
            ctx
        );
    }

    fun vote_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        voting_power: u64,
        pools: vector<sui::object::ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        reset_internal<SailCoinType>(voter, voting_escrow, distribution_config, lock, clock, ctx);
        let mut input_total_weight = 0;
        let mut lock_used_weights = 0;
        let mut global_total_weight_delta = 0;
        let mut i = 0;
        let pools_length = std::vector::length<sui::object::ID>(&pools);
        while (i < pools_length) {
            let weight_i = std::vector::borrow<u64>(&weights, i);
            input_total_weight = input_total_weight + *weight_i;
            i = i + 1;
        };
        i = 0;
        while (i < pools_length) {
            let pool_id = into_pool_id(pools[i]);
            assert!(
                sui::table::contains<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id),
                EVoteInternalGaugeDoesNotExist
            );
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id);
            assert!(
                distribution::distribution_config::is_gauge_alive(distribution_config, gauge_id.id),
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
            let pool_has_votes = if (sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(
                &voter.votes,
                lock_id
            )) {
                if (sui::table::contains<PoolID, u64>(
                    sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                    pool_id
                )) {
                    let zero_votes = 0;
                    sui::table::borrow<PoolID, u64>(
                        sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                        pool_id
                    ) != &zero_votes
                } else {
                    false
                }
            } else {
                false
            };
            if (pool_has_votes) {
                abort EVoteInternalPoolAreadyVoted
            };
            assert!(votes_for_pool > 0, EVoteInternalWeightResultedInZeroVotes);
            update_for_internal<SailCoinType>(voter, distribution_config, gauge_id);
            if (!sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id)) {
                sui::table::add<LockID, vector<PoolID>>(&mut voter.pool_vote, lock_id, std::vector::empty<PoolID>());
            };
            std::vector::push_back<PoolID>(
                sui::table::borrow_mut<LockID, vector<PoolID>>(&mut voter.pool_vote, lock_id),
                pool_id
            );
            let total_gauge_weight = if (sui::table::contains<GaugeID, u64>(&voter.weights, gauge_id)) {
                sui::table::remove<GaugeID, u64>(&mut voter.weights, gauge_id)
            } else {
                0
            };
            sui::table::add<GaugeID, u64>(&mut voter.weights, gauge_id, total_gauge_weight + votes_for_pool);
            if (!sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id)) {
                sui::table::add<LockID, sui::table::Table<PoolID, u64>>(
                    &mut voter.votes,
                    lock_id,
                    sui::table::new<PoolID, u64>(ctx)
                );
            };
            let lock_votes = sui::table::borrow_mut<LockID, sui::table::Table<PoolID, u64>>(&mut voter.votes, lock_id);
            let lock_pool_votes = if (sui::table::contains<PoolID, u64>(lock_votes, pool_id)) {
                sui::table::remove<PoolID, u64>(lock_votes, pool_id)
            } else {
                0
            };
            sui::table::add<PoolID, u64>(lock_votes, pool_id, lock_pool_votes + votes_for_pool);
            distribution::fee_voting_reward::deposit(
                sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                    &mut voter.gauge_to_fee,
                    gauge_id
                ),
                &voter.gauge_to_fee_authorized_cap,
                votes_for_pool,
                lock_id.id,
                clock,
                ctx
            );
            distribution::bribe_voting_reward::deposit(
                sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
                    &mut voter.gauge_to_bribe,
                    gauge_id
                ),
                &voter.gauge_to_bribe_authorized_cap,
                votes_for_pool,
                lock_id.id,
                clock,
                ctx
            );
            lock_used_weights = lock_used_weights + votes_for_pool;
            global_total_weight_delta = global_total_weight_delta + votes_for_pool;
            let voted_event = EventVoted {
                sender: sui::tx_context::sender(ctx),
                pool: pool_id.id,
                lock: lock_id.id,
                voting_weight: votes_for_pool,
                pool_weight: *sui::table::borrow<GaugeID, u64>(&voter.weights, gauge_id),
            };
            sui::event::emit<EventVoted>(voted_event);
            i = i + 1;
        };
        if (lock_used_weights > 0) {
            distribution::voting_escrow::voting<SailCoinType>(voting_escrow, &voter.voter_cap, lock_id.id, true);
        };
        voter.total_weight = voter.total_weight + global_total_weight_delta;
        if (sui::table::contains<LockID, u64>(&voter.used_weights, lock_id)) {
            sui::table::remove<LockID, u64>(&mut voter.used_weights, lock_id);
        };
        sui::table::add<LockID, u64>(&mut voter.used_weights, lock_id, lock_used_weights);
    }

    public fun voted_pools<SailCoinType>(
        voter: &Voter<SailCoinType>,
        lock_id: sui::object::ID
    ): vector<sui::object::ID> {
        let mut voted_pools_vec = std::vector::empty<sui::object::ID>();
        let lock_id_obj = into_lock_id(lock_id);
        let voted_pools_from_voter = if (sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id_obj)) {
            sui::table::borrow<LockID, vector<PoolID>>(&voter.pool_vote, lock_id_obj)
        } else {
            let voted_pools_empty = std::vector::empty<PoolID>();
            &voted_pools_empty
        };
        let mut i = 0;
        while (i < std::vector::length<PoolID>(voted_pools_from_voter)) {
            std::vector::push_back<sui::object::ID>(&mut voted_pools_vec, std::vector::borrow<PoolID>(
                voted_pools_from_voter, i).id);
            i = i + 1;
        };
        voted_pools_vec
    }

    public fun whitelist_nft<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        lock_id: sui::object::ID,
        listed: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            is_governor<SailCoinType>(voter, sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EWhitelistNftGovernorInvalid
        );
        let lock_id_obj = into_lock_id(lock_id);
        if (sui::table::contains<LockID, bool>(&voter.is_whitelisted_nft, lock_id_obj)) {
            sui::table::remove<LockID, bool>(&mut voter.is_whitelisted_nft, lock_id_obj);
        };
        sui::table::add<LockID, bool>(&mut voter.is_whitelisted_nft, lock_id_obj, listed);
        let whitelisted_nft_event = EventWhitelistNFT {
            sender: sui::tx_context::sender(ctx),
            id: lock_id,
            listed: listed,
        };
        sui::event::emit<EventWhitelistNFT>(whitelisted_nft_event);
    }

    public fun whitelist_token<SailCoinType, CoinToWhitelistType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        listed: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(
            governor_cap,
            sui::object::id<Voter<SailCoinType>>(voter)
        );
        assert!(
            is_governor<SailCoinType>(voter, distribution::voter_cap::who(governor_cap)),
            EWhitelistTokenGovernorInvalid
        );
        whitelist_token_internal<SailCoinType>(
            voter,
            std::type_name::get<CoinToWhitelistType>(),
            listed,
            sui::tx_context::sender(ctx)
        );
    }

    fun whitelist_token_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        coinTypeName: std::type_name::TypeName,
        listed: bool,
        sender: address
    ) {
        if (sui::table::contains<std::type_name::TypeName, bool>(&voter.is_whitelisted_token, coinTypeName)) {
            sui::table::remove<std::type_name::TypeName, bool>(&mut voter.is_whitelisted_token, coinTypeName);
        };
        sui::table::add<std::type_name::TypeName, bool>(&mut voter.is_whitelisted_token, coinTypeName, listed);
        let whitelist_token_event = EventWhitelistToken {
            sender,
            token: coinTypeName,
            listed,
        };
        sui::event::emit<EventWhitelistToken>(whitelist_token_event);
    }
}



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
        while (i < supported_coins.length()) {
            voter.whitelist_token_internal(supported_coins[i], true, sui::tx_context::sender(ctx));
            i = i + 1;
        };
        let sail_coin_type = std::type_name::get<SailCoinType>();
        if (!voter.is_whitelisted_token.contains(sail_coin_type)) {
            voter.is_whitelisted_token.add(sail_coin_type, true);
        };
        let notify_reward_cap = distribution::notify_reward_cap::create_internal(
            sui::object::id<Voter<SailCoinType>>(&voter),
            ctx
        );
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
        voter.assert_only_new_epoch(lock_id, clock);
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time <= distribution::common::epoch_vote_end(current_time), EDepositManagedEpochVoteEnded);
        if (voter.last_voted.contains(lock_id)) {
            voter.last_voted.remove(lock_id);
        };
        voter.last_voted.add(lock_id, current_time);
        voting_escrow.deposit_managed(&voter.voter_cap, lock, managed_lock, clock, ctx);
        let balance = voting_escrow.balance_of_nft_at(lock_id.id, current_time);
        voter.poke_internal(voting_escrow, distribution_config, managed_lock, balance, clock, ctx);
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
        voter.assert_only_new_epoch(lock_id, clock);
        let managedd_lock_id = voting_escrow.id_to_managed(lock_id.id);
        assert!(
            managedd_lock_id == sui::object::id<distribution::voting_escrow::Lock>(managed_lock),
            EWithdrawManagedInvlidManaged
        );
        let owner_proof = voting_escrow.owner_proof(lock, ctx);
        voting_escrow.withdraw_managed(&voter.voter_cap, lock, managed_lock, owner_proof, clock, ctx);
        let balance_of_nft = voting_escrow.balance_of_nft_at(
            managedd_lock_id,
            distribution::common::current_timestamp(clock)
        );
        if (balance_of_nft == 0) {
            voter.reset_internal(voting_escrow, distribution_config, managed_lock, clock, ctx);
            if (voter.last_voted.contains(into_lock_id(managedd_lock_id))) {
                voter.last_voted.remove(into_lock_id(managedd_lock_id));
            };
        } else {
            voter.poke_internal(voting_escrow, distribution_config, managed_lock, balance_of_nft, clock, ctx);
        };
    }

    public fun add_epoch_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        who: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EAddEpochGovernorInvalidGovernor
        );
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
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
            !voter.last_voted.contains(lock_id) ||
                distribution::common::epoch_start(current_time) > *voter.last_voted.borrow(lock_id),
            EAlreadyVotedInCurrentEpoch
        );
        assert!(current_time > distribution::common::epoch_vote_start(current_time), EVotingNotStarted);
    }

    public fun borrow_bribe_voting_reward<SailCoinType>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &distribution::bribe_voting_reward::BribeVotingReward {
        voter.gauge_to_bribe.borrow(into_gauge_id(gauge_id))
    }

    public fun borrow_bribe_voting_reward_mut<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &mut distribution::bribe_voting_reward::BribeVotingReward {
        voter.gauge_to_bribe.borrow_mut(into_gauge_id(gauge_id))
    }

    public fun borrow_fee_voting_reward<SailCoinType>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &distribution::fee_voting_reward::FeeVotingReward {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id))
    }

    public fun borrow_fee_voting_reward_mut<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): &mut distribution::fee_voting_reward::FeeVotingReward {
        voter.gauge_to_fee.borrow_mut(into_gauge_id(gauge_id))
    }

    public fun borrow_voter_cap<SailCoinType>(
        voter: &Voter<SailCoinType>,
        notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap
    ): &distribution::voter_cap::VoterCap {
        notify_reward_cap.validate_notify_reward_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        &voter.voter_cap
    }

    fun check_vote<SailCoinType>(
        voter: &Voter<SailCoinType>,
        pool_ids: &vector<sui::object::ID>,
        weights: &vector<u64>
    ) {
        let pools_length = pool_ids.length();
        assert!(pools_length == weights.length(), ECheckVoteSizesDoNotMatch);
        assert!(pools_length <= voter.max_voting_num, ECheckVoteMaxVoteNumExceed);
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

    public fun claim_voting_bribe<SailCoinType, BribeCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let voted_pools = voter.pool_vote.borrow(
            into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock))
        );
        let mut i = 0;
        while (i < voted_pools.length()) {
            let pool_id = *voted_pools.borrow(i);
            let gauge_id = *voter.pool_to_gauger.borrow(pool_id);
            i = i + 1;
            let claim_bribe_reward_event = EventClaimBribeReward {
                who: sui::tx_context::sender(ctx),
                amount: voter.gauge_to_bribe.borrow_mut(gauge_id).get_reward<SailCoinType, BribeCoinType>(
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
        let voted_pools = voter.pool_vote.borrow(
            into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock))
        );
        let mut i = 0;
        while (i < voted_pools.length()) {
            let pool_id = *voted_pools.borrow(i);
            let gauge_id = *voter.pool_to_gauger.borrow(pool_id);
            i = i + 1;
            let claim_voting_fee_reward_event = EventClaimVotingFeeReward {
                who: sui::tx_context::sender(ctx),
                amount: voter.gauge_to_fee.borrow_mut(gauge_id).get_reward<SailCoinType, FeeCoinType>(
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
        if (voter.claimable.contains(gauge_id_obj)) {
            *voter.claimable.borrow(gauge_id_obj)
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
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
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
        reward_coins.push_back(std::type_name::get<CoinTypeA>());
        reward_coins.push_back(std::type_name::get<CoinTypeB>());
        let gauge_id = sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(&gauge);
        let voter_id = sui::object::id<Voter<SailCoinType>>(voter);
        let voting_escrow_id = sui::object::id<distribution::voting_escrow::VotingEscrow<SailCoinType>>(voting_escrow);
        voter.gauge_to_fee.add(
            into_gauge_id(gauge_id),
            distribution::fee_voting_reward::create(voter_id, voting_escrow_id, gauge_id, reward_coins, ctx)
        );
        reward_coins.push_back(std::type_name::get<SailCoinType>());
        voter.gauge_to_bribe.add(
            into_gauge_id(gauge_id),
            distribution::bribe_voting_reward::create(voter_id, voting_escrow_id, gauge_id, reward_coins, ctx)
        );
        voter.receive_gauger(governor_cap, &mut gauge, clock, ctx);
        let mut alive_gauges_vec = std::vector::empty<sui::object::ID>();
        alive_gauges_vec.push_back(gauge_id);
        distribution_config.update_gauge_liveness(alive_gauges_vec, true, ctx);
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
        let gauge_represent = voter.gauge_represents.borrow(gauge_id);
        assert!(
            gauge_represent.pool_id == sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(
                pool
            ) && gauge_represent.gauger_id == gauge_id.id,
            EDistributeGaugeInvalidGaugeRepresent
        );
        let claimable_balance = voter.extract_claimable_for(distribution_config, gauge_id.id);
        let balance_value = claimable_balance.value();
        let (fee_reward_a, fee_reward_b) = gauge.notify_reward(&voter.voter_cap, pool, claimable_balance, clock, ctx);
        let fee_a_amount = fee_reward_a.value<CoinTypeA>();
        let fee_b_amount = fee_reward_b.value<CoinTypeB>();
        let fee_voting_reward = voter.gauge_to_fee.borrow_mut(gauge_id);
        fee_voting_reward.notify_reward_amount(
            &voter.gauge_to_fee_authorized_cap,
            sui::coin::from_balance<CoinTypeA>(fee_reward_a, ctx),
            clock,
            ctx
        );
        fee_voting_reward.notify_reward_amount(
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
        voter.update_for_internal(distribution_config, gauge_id);
        let amount = *voter.claimable.borrow(gauge_id);
        voter.claimable.remove(gauge_id);
        voter.claimable.add(gauge_id, 0);
        let extract_claimable_event = EventExtractClaimable {
            gauger: gauge_id.id,
            amount,
        };
        sui::event::emit<EventExtractClaimable>(extract_claimable_event);
        voter.balances.borrow_mut<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
            std::type_name::get<SailCoinType>()
        ).split<SailCoinType>(amount)
    }

    public fun fee_voting_reward_balance<SailCoinType, CoinTypeA>(
        voter: &Voter<SailCoinType>,
        gauge_id: sui::object::ID
    ): u64 {
        voter.gauge_to_fee.borrow(into_gauge_id(gauge_id)).balance<CoinTypeA>()
    }

    public fun get_balance<SailCoinType, BribeCoinType>(voter: &Voter<SailCoinType>): u64 {
        let bribe_coin_type = std::type_name::get<BribeCoinType>();
        if (!voter.balances.contains(bribe_coin_type)) {
            0
        } else {
            voter.balances.borrow<std::type_name::TypeName, sui::balance::Balance<BribeCoinType>>(
                bribe_coin_type
            ).value<BribeCoinType>()
        }
    }

    public fun get_gauge_weight<SailCoinType>(voter: &Voter<SailCoinType>, gauge_id: sui::object::ID): u64 {
        *voter.weights.borrow(into_gauge_id(gauge_id))
    }

    public fun get_pool_weight<SailCoinType>(arg0: &Voter<SailCoinType>, pool_id: sui::object::ID): u64 {
        let gauge_id = *arg0.pool_to_gauger.borrow(into_pool_id(pool_id));
        arg0.get_gauge_weight(gauge_id.id)
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
            voter.votes.contains(lock_id_obj),
            EGetVotesNotVoted
        );
        voter.votes.borrow(lock_id_obj)
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
        voter.is_whitelisted_nft.contains(lock_id_obj) &&
            *voter.is_whitelisted_nft.borrow(lock_id_obj)
    }

    public fun is_whitelisted_token<SailCoinType, CoinToCheckType>(voter: &Voter<SailCoinType>): bool {
        let coin_type_name = std::type_name::get<CoinToCheckType>();
        if (voter.is_whitelisted_token.contains(coin_type_name)) {
            let is_whitelisted_true = true;
            &is_whitelisted_true == voter.is_whitelisted_token.borrow(coin_type_name)
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
        emergency_council_cap.validate_emergency_council_voter_id(sui::object::id<Voter<SailCoinType>>(
            voter
        ));
        assert!(
            sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ) == voter.distribution_config,
            EKillGaugeDistributionConfigInvalid
        );
        assert!(
            distribution_config.is_gauge_alive(gauge_id),
            EKillGaugeAlreadyKilled
        );
        let gauge_id_obj = into_gauge_id(gauge_id);
        voter.update_for_internal(distribution_config, gauge_id_obj);
        let remaining_claimable_amount = if (voter.claimable.contains(gauge_id_obj)) {
            voter.claimable.remove(gauge_id_obj)
        } else {
            0
        };
        let mut cashback = sui::balance::zero<SailCoinType>();
        if (remaining_claimable_amount > 0) {
            cashback.join<SailCoinType>(
                voter.balances.borrow_mut<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
                    std::type_name::get<SailCoinType>()
                ).split<SailCoinType>(remaining_claimable_amount)
            );
        };
        let mut killed_gauge_ids = std::vector::empty<sui::object::ID>();
        killed_gauge_ids.push_back(gauge_id_obj.id);
        distribution_config.update_gauge_liveness(killed_gauge_ids, false, ctx);
        let kill_gauge_event = EventKillGauge { id: gauge_id_obj.id };
        sui::event::emit<EventKillGauge>(kill_gauge_event);
        cashback
    }

    public fun lock_last_voted_at<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: sui::object::ID): u64 {
        let lock_id_obj = into_lock_id(lock_id);
        if (!voter.last_voted.contains(lock_id_obj)) {
            0
        } else {
            *voter.last_voted.borrow(lock_id_obj)
        }
    }

    public fun notify_rewards<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap,
        reward: sui::coin::Coin<SailCoinType>
    ) {
        notify_reward_cap.validate_notify_reward_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        let reward_balance = reward.into_balance();
        let reward_amount = reward_balance.value<SailCoinType>();
        let coin_type_name = std::type_name::get<SailCoinType>();
        let mut existing_balance = if (voter.balances.contains(coin_type_name)) {
            voter.balances.remove<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(coin_type_name)
        } else {
            sui::balance::zero<SailCoinType>()
        };
        existing_balance.join<SailCoinType>(reward_balance);
        voter.balances.add(coin_type_name, existing_balance);
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
            notifier: notify_reward_cap.who(),
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
        let voting_power = voting_escrow.get_voting_power(lock, clock);
        voter.poke_internal(voting_escrow, distribution_config, lock, voting_power, clock, ctx);
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
        let pool_vote_count = if (voter.pool_vote.contains(lock_id)) {
            voter.pool_vote.borrow(lock_id).length()
        } else {
            0
        };
        if (pool_vote_count > 0) {
            let mut vote_amounts = std::vector::empty<u64>();
            let mut i = 0;
            let pools_voted = voter.pool_vote.borrow(lock_id);
            let mut pools_voted_ids = std::vector::empty<sui::object::ID>();
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
                vote_amounts.push_back(*vote_amount_by_pool.borrow(pools_voted[i]));
                i = i + 1;
            };
            voter.vote_internal(
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
        voter.pool_to_gauger.borrow(into_pool_id(pool_id)).id
    }

    public fun pools_gauges<SailCoinType>(
        voter: &Voter<SailCoinType>
    ): (vector<sui::object::ID>, vector<sui::object::ID>) {
        let mut pool_ids = std::vector::empty<sui::object::ID>();
        let mut gauge_ids = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < voter.pools.length()) {
            let pool_id = voter.pools.borrow(i).id;
            pool_ids.push_back(pool_id);
            gauge_ids.push_back(voter.pool_to_gauge(pool_id));
            i = i + 1;
        };
        (pool_ids, gauge_ids)
    }

    public fun prove_pair_whitelisted<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &Voter<SailCoinType>
    ): distribution::whitelisted_tokens::WhitelistedTokenPair {
        assert!(voter.is_whitelisted_token<SailCoinType, CoinTypeA>(), EFirstTokenNotWhitelisted);
        assert!(voter.is_whitelisted_token<SailCoinType, CoinTypeB>(), ESecondTokenNotWhitelisted);
        distribution::whitelisted_tokens::create_pair<CoinTypeA, CoinTypeB>(sui::object::id<Voter<SailCoinType>>(voter))
    }

    public fun prove_token_whitelisted<SailCoinType, CoinToCheckType>(
        voter: &Voter<SailCoinType>
    ): distribution::whitelisted_tokens::WhitelistedToken {
        assert!(voter.is_whitelisted_token<SailCoinType, CoinToCheckType>(), ETokenNotWhitelisted);
        distribution::whitelisted_tokens::create<CoinToCheckType>(sui::object::id<Voter<SailCoinType>>(voter))
    }

    public fun receive_gauger<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EReceiveGaugeInvalidGovernor
        );
        let gauge_id = into_gauge_id(
            sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)
        );
        let pool_id = into_pool_id(gauge.pool_id());
        assert!(
            !voter.gauge_represents.contains(gauge_id),
            EReceiveGaugeAlreadyHasRepresent
        );
        assert!(
            !voter.pool_to_gauger.contains(pool_id),
            EReceiveGaugePoolAreadyHasGauge
        );
        let gauge_represent = GaugeRepresent {
            gauger_id: sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            pool_id: gauge.pool_id(),
            weight: 0,
            last_reward_time: clock.timestamp_ms(),
        };
        voter.gauge_represents.add(gauge_id, gauge_represent);
        voter.rewards.add(gauge_id, sui::balance::zero<SailCoinType>());
        voter.weights.add(gauge_id, 0);
        voter.pools.push_back(pool_id);
        voter.pool_to_gauger.add(pool_id, gauge_id);
        gauge.set_voter(sui::object::id<Voter<SailCoinType>>(voter));
        voter.whitelist_token<SailCoinType, CoinTypeA>(governor_cap, true, ctx);
        voter.whitelist_token<SailCoinType, CoinTypeB>(governor_cap, true, ctx);
        if (!voter.is_whitelisted_token<SailCoinType, SailCoinType>()) {
            voter.whitelist_token<SailCoinType, SailCoinType>(governor_cap, true, ctx);
        };
    }

    public fun remove_epoch_governor<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        who: sui::object::ID
    ) {
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
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
        voter.assert_only_new_epoch(into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock)), clock);
        voter.reset_internal(voting_escrow, distribution_config, lock, clock, ctx);
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
            let pool_votes = *voter.votes.borrow(lock_id).borrow(pool_id);
            let gauge_id = *voter.pool_to_gauger.borrow(pool_id);
            if (pool_votes != 0) {
                voter.update_for_internal(distribution_config, gauge_id);
                let weight = voter.weights.remove(gauge_id) - pool_votes;
                voter.weights.add(gauge_id, weight);
                voter.votes.borrow_mut(lock_id).remove(pool_id);
                voter.gauge_to_fee.borrow_mut(gauge_id).withdraw(
                    &voter.gauge_to_fee_authorized_cap,
                    pool_votes,
                    lock_id.id,
                    clock,
                    ctx
                );
                voter.gauge_to_bribe.borrow_mut(gauge_id).withdraw(
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
                    pool_weight: *voter.weights.borrow(gauge_id),
                };
                sui::event::emit<EventAbstained>(abstained_event);
            };
            pool_index = pool_index + 1;
        };
        voting_escrow.voting(&voter.voter_cap, lock_id.id, false);
        voter.total_weight = voter.total_weight - total_removed_weight;
        if (voter.used_weights.contains(lock_id)) {
            voter.used_weights.remove(lock_id);
        };
        if (voter.pool_vote.contains(lock_id)) {
            voter.pool_vote.remove(lock_id);
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
        let gauge_cap = gauge_create_cap.create_gauge_cap(
            pool_id,
            sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(&gauge),
            ctx
        );
        pool.init_magma_distribution_gauge(&gauge_cap);
        gauge.receive_gauge_cap(gauge_cap);
        gauge
    }

    public fun revive_gauge<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ) {
        emergency_council_cap.validate_emergency_council_voter_id(sui::object::id<Voter<SailCoinType>>(
            voter
        ));
        assert!(
            sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ) == voter.distribution_config,
            EReviveGaugeInvalidDistributionConfig
        );
        assert!(
            !distribution_config.is_gauge_alive(gauge_id),
            EReviveGaugeAlreadyAlive
        );
        let mut alive_gauge_ids = std::vector::empty<sui::object::ID>();
        alive_gauge_ids.push_back(gauge_id);
        distribution_config.update_gauge_liveness(alive_gauge_ids, true, ctx);
        let revieve_gauge_event = EventReviveGauge { id: gauge_id };
        sui::event::emit<EventReviveGauge>(revieve_gauge_event);
    }

    public fun set_max_voting_num<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        new_max_voting_num: u64
    ) {
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
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
        voter.update_for_internal(distribution_config, into_gauge_id(gauge_id));
    }

    fun update_for_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_id: GaugeID
    ) {
        let gauge_weight = if (voter.weights.contains(gauge_id)) {
            *voter.weights.borrow(gauge_id)
        } else {
            0
        };
        if (gauge_weight > 0) {
            let gauge_supply_index = if (voter.supply_index.contains(gauge_id)) {
                voter.supply_index.remove(gauge_id)
            } else {
                0
            };
            let voter_index = voter.index;
            voter.supply_index.add(gauge_id, voter_index);
            let index_delta = voter_index - gauge_supply_index;
            if (index_delta > 0) {
                assert!(
                    distribution_config.is_gauge_alive(gauge_id.id),
                    EUpdateForInternalGaugeNotAlive
                );
                let gauge_claimable = if (voter.claimable.contains(gauge_id)) {
                    voter.claimable.remove(gauge_id)
                } else {
                    0
                };
                voter.claimable.add(gauge_id, gauge_claimable + (integer_mate::full_math_u128::mul_div_floor(
                    gauge_weight as u128,
                    index_delta,
                    1 << 64
                ) as u64));
            };
        } else {
            if (voter.supply_index.contains(gauge_id)) {
                voter.supply_index.remove(gauge_id);
            };
            voter.supply_index.add(gauge_id, voter.index);
        };
    }

    public fun update_for_many<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge_ids: vector<sui::object::ID>
    ) {
        let mut i = 0;
        while (i < gauge_ids.length()) {
            voter.update_for_internal(distribution_config, into_gauge_id(gauge_ids[i]));
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
        let pools_length = voter.pools.length();
        let mut iteration_end = pools_length;
        if (pools_length > end_index) {
            iteration_end = end_index;
        };
        while (start_index + i < iteration_end) {
            let gauge_id = *voter.pool_to_gauger.borrow(voter.pools[start_index + i]);
            voter.update_for_internal(distribution_config, gauge_id);
            i = i + 1;
        };
    }

    public fun used_weights<SailCoinType>(voter: &Voter<SailCoinType>, lock_id: sui::object::ID): u64 {
        *voter.used_weights.borrow(into_lock_id(lock_id))
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
        voter.assert_only_new_epoch(lock_id, clock);
        voter.check_vote(&pools, &weights);
        assert!(
            !voting_escrow.deactivated(lock_id.id),
            EVoteVotingEscrowDeactivated
        );
        let current_time = distribution::common::current_timestamp(clock);
        let epoch_vote_ended_and_nft_not_whitelisted = (
            current_time > distribution::common::epoch_vote_end(current_time)
        ) && (
            !voter.is_whitelisted_nft.contains(lock_id) ||
                *voter.is_whitelisted_nft.borrow(lock_id) == false
        );
        if (epoch_vote_ended_and_nft_not_whitelisted) {
            abort EVoteNotWhitelistedNft
        };
        if (voter.last_voted.contains(lock_id)) {
            voter.last_voted.remove(lock_id);
        };
        voter.last_voted.add(lock_id, current_time);
        let voting_power = voting_escrow.get_voting_power(lock, clock);
        assert!(voting_power > 0, EVoteNoVotingPower);
        voter.vote_internal(voting_escrow, distribution_config, lock, voting_power, pools, weights, clock, ctx);
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
        voter.reset_internal(voting_escrow, distribution_config, lock, clock, ctx);
        let mut input_total_weight = 0;
        let mut lock_used_weights = 0;
        let mut global_total_weight_delta = 0;
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

            let pool_has_votes = if (voter.votes.contains(lock_id)) {
                if (voter.votes.borrow(lock_id).contains(pool_id)) {
                    let zero_votes = 0;
                    voter.votes.borrow(lock_id).borrow(pool_id) != &zero_votes
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
            voter.update_for_internal(distribution_config, gauge_id);
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
                voter.votes.add(lock_id, sui::table::new<PoolID, u64>(ctx));
            };
            let lock_votes = voter.votes.borrow_mut(lock_id);
            let lock_pool_votes = if (lock_votes.contains(pool_id)) {
                lock_votes.remove(pool_id)
            } else {
                0
            };
            lock_votes.add(pool_id, lock_pool_votes + votes_for_pool);
            voter.gauge_to_fee.borrow_mut(gauge_id).deposit(
                &voter.gauge_to_fee_authorized_cap,
                votes_for_pool,
                lock_id.id,
                clock,
                ctx
            );
            voter.gauge_to_bribe.borrow_mut(gauge_id).deposit(
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
                pool_weight: *voter.weights.borrow(gauge_id),
            };
            sui::event::emit<EventVoted>(voted_event);
            i = i + 1;
        };
        if (lock_used_weights > 0) {
            voting_escrow.voting(&voter.voter_cap, lock_id.id, true);
        };
        voter.total_weight = voter.total_weight + global_total_weight_delta;
        if (voter.used_weights.contains(lock_id)) {
            voter.used_weights.remove(lock_id);
        };
        voter.used_weights.add(lock_id, lock_used_weights);
    }

    public fun voted_pools<SailCoinType>(
        voter: &Voter<SailCoinType>,
        lock_id: sui::object::ID
    ): vector<sui::object::ID> {
        let mut voted_pools_vec = std::vector::empty<sui::object::ID>();
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

    public fun whitelist_nft<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        governor_cap: &distribution::voter_cap::GovernorCap,
        lock_id: sui::object::ID,
        listed: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(sui::object::id<distribution::voter_cap::GovernorCap>(governor_cap)),
            EWhitelistNftGovernorInvalid
        );
        let lock_id_obj = into_lock_id(lock_id);
        if (voter.is_whitelisted_nft.contains(lock_id_obj)) {
            voter.is_whitelisted_nft.remove(lock_id_obj);
        };
        voter.is_whitelisted_nft.add(lock_id_obj, listed);
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
        governor_cap.validate_governor_voter_id(sui::object::id<Voter<SailCoinType>>(voter));
        assert!(
            voter.is_governor(governor_cap.who()),
            EWhitelistTokenGovernorInvalid
        );
        voter.whitelist_token_internal(
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
        if (voter.is_whitelisted_token.contains(coinTypeName)) {
            voter.is_whitelisted_token.remove(coinTypeName);
        };
        voter.is_whitelisted_token.add(coinTypeName, listed);
        let whitelist_token_event = EventWhitelistToken {
            sender,
            token: coinTypeName,
            listed,
        };
        sui::event::emit<EventWhitelistToken>(whitelist_token_event);
    }
}



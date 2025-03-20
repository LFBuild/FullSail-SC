module distribution::voter {

    const ENotAGovernorOfTheVoter: u64 = 9223373604519346200;
    const EVotingNotStartedYet: u64 = 9223374433448427550;
    const EPokeLockNotVoted: u64 = 9223374510758756396;
    const EPokePoolNotVoted: u64 = 9223374527938625580;

    const EVoteFlagDistribution: u64 = 9223374626723266610;
    const EVoteVotingEscrowDeactivated: u64 = 9223374631017185314;
    const EVoteNotWhitelistedNft: u64 = 9223374648197185572;
    const EVoteNoVotingPower: u64 = 9223374686852022310;

    const EVoteInternalGaugeDoesNotExist: u64 = 9223374798519205896;
    const EVoteInternalGaugeNotAlive: u64 = 9223374807109926932;

    const EDistributeGaugeInvalidGaugeRepresent: u64 = 9223375983929720831;

    const EExtractClaimableForLessThanMin: u64 = 9223375923800178687;

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

    public struct Voter<phantom T0> has store, key {
        id: sui::object::UID,
        flag_distribution: bool,
        governors: sui::vec_set::VecSet<sui::object::ID>,
        epoch_governors: sui::vec_set::VecSet<sui::object::ID>,
        emergency_council: sui::object::ID,
        is_alive: sui::table::Table<GaugeID, bool>,
        total_weight: u64,
        used_weights: sui::table::Table<LockID, u64>,
        pools: vector<PoolID>,
        pool_to_gauger: sui::table::Table<PoolID, GaugeID>,
        gauge_represents: sui::table::Table<GaugeID, GaugeRepresent>,
        votes: sui::table::Table<LockID, sui::table::Table<PoolID, u64>>,
        rewards: sui::table::Table<GaugeID, sui::balance::Balance<T0>>,
        weights: sui::table::Table<GaugeID, u64>,
        epoch: u64,
        voter_cap: distribution::voter_cap::VoterCap,
        balances: sui::bag::Bag,
        index: u128,
        supply_index: sui::table::Table<GaugeID, u128>,
        claimable: sui::table::Table<GaugeID, u64>, // claimable amount per gauge
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
    }

    public struct EventRemoveGovernor has copy, drop, store {
        who: address,
    }

    public struct EventAddEpochGovernor has copy, drop, store {
        who: address,
    }

    public struct EventRemoveEpochGovernor has copy, drop, store {
        who: address,
    }

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        supported_coins: vector<std::type_name::TypeName>,
        ctx: &mut sui::tx_context::TxContext
    ): (Voter<SailCoinType>, distribution::notify_reward_cap::NotifyRewardCap) {
        let voter_uid = sui::object::new(ctx);
        let inner_id = *sui::object::uid_as_inner(&voter_uid);
        let mut voter = Voter<SailCoinType> {
            id: voter_uid,
            flag_distribution: false,
            governors: sui::vec_set::empty<sui::object::ID>(),
            epoch_governors: sui::vec_set::empty<sui::object::ID>(),
            emergency_council: sui::object::id_from_address(@0x0),
            is_alive: sui::table::new<GaugeID, bool>(ctx),
            total_weight: 0,
            used_weights: sui::table::new<LockID, u64>(ctx),
            pools: std::vector::empty<PoolID>(),
            pool_to_gauger: sui::table::new<PoolID, GaugeID>(ctx),
            gauge_represents: sui::table::new<GaugeID, GaugeRepresent>(ctx),
            votes: sui::table::new<LockID, sui::table::Table<PoolID, u64>>(ctx),
            rewards: sui::table::new<GaugeID, sui::balance::Balance<SailCoinType>>(ctx),
            weights: sui::table::new<GaugeID, u64>(ctx),
            epoch: 0,
            voter_cap: distribution::voter_cap::create_voter_cap(inner_id, ctx),
            balances: sui::bag::new(ctx),
            index: 0,
            supply_index: sui::table::new<GaugeID, u128>(ctx),
            claimable: sui::table::new<GaugeID, u64>(ctx),
            is_whitelisted_token: sui::table::new<std::type_name::TypeName, bool>(ctx),
            is_whitelisted_nft: sui::table::new<LockID, bool>(ctx),
            max_voting_num: 10,
            last_voted: sui::table::new<LockID, u64>(ctx),
            pool_vote: sui::table::new<LockID, vector<PoolID>>(ctx),
            gauge_to_fee_authorized_cap: distribution::reward_authorized_cap::create(inner_id, ctx),
            gauge_to_fee: sui::table::new<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(ctx),
            gauge_to_bribe_authorized_cap: distribution::reward_authorized_cap::create(inner_id, ctx),
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
        let voter_id = sui::object::id<Voter<SailCoinType>>(&voter);
        (voter, distribution::notify_reward_cap::create_internal(voter_id, ctx))
    }

    public fun deposit_managed<T0>(
        arg0: &mut Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &mut distribution::voting_escrow::Lock,
        arg3: &mut distribution::voting_escrow::Lock,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        assert_only_new_epoch<T0>(arg0, v0, arg4);
        assert!(
            distribution::voting_escrow::owner_of<T0>(arg1, v0.id) == sui::tx_context::sender(arg5),
            9223375275260116991
        );
        assert!(!distribution::voting_escrow::deactivated<T0>(arg1, v0.id), 9223375275262279714);
        let v1 = distribution::voting_escrow::id_to_managed<T0>(arg1, v0.id);
        assert!(v1 == sui::object::id<distribution::voting_escrow::Lock>(arg3), 9223375292439986175);
        let v2 = distribution::common::current_timestamp(arg4);
        assert!(v2 <= distribution::common::epoch_vote_end(v2), 9223375301033263156);
        if (sui::table::contains<LockID, u64>(&arg0.last_voted, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.last_voted, v0);
        };
        sui::table::add<LockID, u64>(&mut arg0.last_voted, v0, v2);
        distribution::voting_escrow::deposit_managed<T0>(arg1, &arg0.voter_cap, arg2, v1, arg4, arg5);
        let balance = distribution::voting_escrow::balance_of_nft_at<T0>(arg1, v0.id, v2);
        poke_internal<T0>(arg0, arg1, arg3, balance, arg4, arg5);
    }

    public fun withdraw_managed<T0>(
        arg0: &mut Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &mut distribution::voting_escrow::Lock,
        arg3: &mut distribution::voting_escrow::Lock,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        assert_only_new_epoch<T0>(arg0, v0, arg4);
        let v1 = distribution::voting_escrow::id_to_managed<T0>(arg1, v0.id);
        assert!(v1 == sui::object::id<distribution::voting_escrow::Lock>(arg3), 9223375378339332095);
        let v2 = distribution::voting_escrow::balance_of_nft_at<T0>(
            arg1,
            v1,
            distribution::common::current_timestamp(arg4)
        );
        if (v2 == 0) {
            reset_internal<T0>(arg0, arg1, arg3, arg4, arg5);
            if (sui::table::contains<LockID, u64>(&arg0.last_voted, into_lock_id(v1))) {
                sui::table::remove<LockID, u64>(&mut arg0.last_voted, into_lock_id(v1));
            };
        } else {
            poke_internal<T0>(arg0, arg1, arg3, v2, arg4, arg5);
        };
        let proof = distribution::voting_escrow::owner_proof<T0>(arg1, arg2, arg5);
        let balance = distribution::voting_escrow::withdraw_managed<T0>(
            arg1,
            &arg0.voter_cap,
            v0.id,
            proof,
            arg4,
            arg5
        );
        sui::transfer::public_transfer<sui::coin::Coin<T0>>(
            sui::coin::from_balance<T0>(balance, arg5),
            sui::tx_context::sender(arg5)
        );
    }

    public fun add_epoch_governor<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::voter_cap::GovernorCap,
        arg2: address,
        arg3: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        sui::transfer::public_transfer<distribution::voter_cap::EpochGovernorCap>(
            distribution::voter_cap::create_epoch_governor_cap(sui::object::id<Voter<T0>>(arg0), arg3),
            arg2
        );
        let v0 = EventAddEpochGovernor { who: arg2 };
        sui::event::emit<EventAddEpochGovernor>(v0);
    }

    public fun add_governor<T0>(
        arg0: &mut Voter<T0>,
        _arg1: &sui::package::Publisher,
        arg2: address,
        arg3: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_transfer<distribution::voter_cap::GovernorCap>(
            distribution::voter_cap::create_governor_cap(sui::object::id<Voter<T0>>(arg0), arg2, arg3),
            arg2
        );
        sui::vec_set::insert<sui::object::ID>(&mut arg0.governors, sui::object::id_from_address(arg2));
        let v0 = EventAddGovernor { who: arg2 };
        sui::event::emit<EventAddGovernor>(v0);
    }

    fun assert_only_new_epoch<T0>(arg0: &Voter<T0>, arg1: LockID, arg2: &sui::clock::Clock) {
        let v0 = distribution::common::current_timestamp(arg2);
        assert!(
            !sui::table::contains<LockID, u64>(&arg0.last_voted, arg1) || distribution::common::epoch_start(
                v0
            ) > *sui::table::borrow<LockID, u64>(&arg0.last_voted, arg1),
            9223373329641701404
        );
        assert!(v0 > distribution::common::epoch_vote_start(v0), 9223373333936799774);
    }

    public fun borrow_bribe_voting_reward<T0>(
        arg0: &Voter<T0>,
        arg1: sui::object::ID
    ): &distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
            &arg0.gauge_to_bribe,
            into_gauge_id(arg1)
        )
    }

    public fun borrow_bribe_voting_reward_mut<T0>(
        arg0: &mut Voter<T0>,
        arg1: sui::object::ID
    ): &mut distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
            &mut arg0.gauge_to_bribe,
            into_gauge_id(arg1)
        )
    }

    public fun borrow_fee_voting_reward<T0>(
        arg0: &Voter<T0>,
        arg1: sui::object::ID
    ): &distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &arg0.gauge_to_fee,
            into_gauge_id(arg1)
        )
    }

    public fun borrow_fee_voting_reward_mut<T0>(
        arg0: &mut Voter<T0>,
        arg1: sui::object::ID
    ): &mut distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
            &mut arg0.gauge_to_fee,
            into_gauge_id(arg1)
        )
    }

    public fun borrow_voter_cap<T0>(
        arg0: &Voter<T0>,
        arg1: &distribution::notify_reward_cap::NotifyRewardCap
    ): &distribution::voter_cap::VoterCap {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        &arg0.voter_cap
    }

    fun check_vote<T0>(arg0: &Voter<T0>, arg1: &vector<sui::object::ID>, arg2: &vector<u64>) {
        let v0 = std::vector::length<sui::object::ID>(arg1);
        assert!(v0 == std::vector::length<u64>(arg2), 9223374162864308236);
        assert!(v0 <= arg0.max_voting_num, 9223374167160586272);
        let mut v1 = 0;
        while (v1 < v0) {
            assert!(
                sui::table::contains<PoolID, GaugeID>(
                    &arg0.pool_to_gauger,
                    into_pool_id(*std::vector::borrow<sui::object::ID>(arg1, v1))
                ),
                9223374184339275790
            );
            assert!(*std::vector::borrow<u64>(arg2, v1) <= 10000, 9223374188634374160);
            v1 = v1 + 1;
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
            distribution::bribe_voting_reward::get_reward<SailCoinType, BribeCoinType>(
                sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
                    &mut voter.gauge_to_bribe,
                    *sui::table::borrow<PoolID, GaugeID>(
                        &voter.pool_to_gauger,
                        voted_pools[i]
                    )
                ),
                voting_escrow,
                lock,
                clock,
                ctx
            );
            i = i + 1;
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
            distribution::fee_voting_reward::get_reward<SailCoinType, FeeCoinType>(
                sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                    &mut voter.gauge_to_fee,
                    *sui::table::borrow<PoolID, GaugeID>(
                        &voter.pool_to_gauger,
                        voted_pools[i]
                    )
                ),
                voting_escrow,
                lock,
                clock,
                ctx
            );
            i = i + 1;
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
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        governor_cap: &distribution::voter_cap::GovernorCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
        distribution::voter_cap::validate_governor_voter_id(governor_cap, sui::object::id<Voter<SailCoinType>>(voter));
        assert!(is_governor<SailCoinType>(voter, distribution::voter_cap::who(governor_cap)), ENotAGovernorOfTheVoter);
        let mut gauge = return_new_gauge<CoinTypeA, CoinTypeB, SailCoinType>(create_cap, pool, ctx);
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
        gauge
    }

    public fun distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let gauge_id = into_gauge_id(sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge));
        let gauge_represent = sui::table::borrow<GaugeID, GaugeRepresent>(&voter.gauge_represents, gauge_id);
        assert!(
            gauge_represent.pool_id == sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) && gauge_represent.gauger_id == gauge_id.id,
            EDistributeGaugeInvalidGaugeRepresent
        );
        let claimable_balance = extract_claimable_for<SailCoinType>(voter, gauge_id.id);
        let balance_value = claimable_balance.value<SailCoinType>();
        let (fee_reward_a, fee_reward_b) = distribution::gauge::notify_reward<CoinTypeA, CoinTypeB, SailCoinType>(
            gauge,
            &voter.voter_cap,
            pool,
            claimable_balance,
            clock,
            ctx
        );
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
        balance_value
    }

    fun extract_claimable_for<SailCoinType>(voter: &mut Voter<SailCoinType>, gauge_id: sui::object::ID): sui::balance::Balance<SailCoinType> {
        let gauge_id = into_gauge_id(gauge_id);
        update_for_internal<SailCoinType>(voter, gauge_id);
        let amount = *sui::table::borrow<GaugeID, u64>(&voter.claimable, gauge_id);
        assert!(amount > 604800, EExtractClaimableForLessThanMin);
        sui::table::remove<GaugeID, u64>(&mut voter.claimable, gauge_id);
        sui::table::add<GaugeID, u64>(&mut voter.claimable, gauge_id, 0);
        let v2 = EventExtractClaimable {
            gauger: gauge_id.id,
            amount,
        };
        sui::event::emit<EventExtractClaimable>(v2);
        sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<SailCoinType>>(
            &mut voter.balances,
            std::type_name::get<SailCoinType>()
        ).split<SailCoinType>(amount)
    }

    public fun fee_voting_reward_balance<T0, T1>(arg0: &Voter<T0>, arg1: sui::object::ID): u64 {
        distribution::fee_voting_reward::balance<T1>(
            sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                &arg0.gauge_to_fee,
                into_gauge_id(arg1)
            )
        )
    }

    public fun get_gauge_weight<T0>(arg0: &Voter<T0>, arg1: GaugeID): u64 {
        *sui::table::borrow<GaugeID, u64>(&arg0.weights, arg1)
    }

    public fun get_pool_weight<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): u64 {
        get_gauge_weight<T0>(arg0, *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, into_pool_id(arg1)))
    }

    public fun get_total_weight<T0>(arg0: &Voter<T0>): u64 {
        arg0.total_weight
    }

    public fun get_votes<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): &sui::table::Table<PoolID, u64> {
        let v0 = into_lock_id(arg1);
        assert!(sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), 9223375618857500671);
        sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0)
    }

    fun init(arg0: VOTER, arg1: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<VOTER>(arg0, arg1);
    }

    public(package) fun into_gauge_id(arg0: sui::object::ID): GaugeID {
        GaugeID { id: arg0 }
    }

    public(package) fun into_lock_id(arg0: sui::object::ID): LockID {
        LockID { id: arg0 }
    }

    public(package) fun into_pool_id(arg0: sui::object::ID): PoolID {
        PoolID { id: arg0 }
    }

    fun is_gauge_alive<T0>(arg0: &Voter<T0>, arg1: GaugeID): bool {
        sui::table::contains<GaugeID, bool>(&arg0.is_alive, arg1) && *sui::table::borrow<GaugeID, bool>(
            &arg0.is_alive,
            arg1
        ) == true
    }

    public fun is_governor<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): bool {
        sui::vec_set::contains<sui::object::ID>(&arg0.governors, &arg1)
    }

    public fun is_whitelisted_token<T0, T1>(arg0: &Voter<T0>): bool {
        let v0 = std::type_name::get<T1>();
        if (sui::table::contains<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, v0)) {
            let v2 = true;
            &v2 == sui::table::borrow<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, v0)
        } else {
            false
        }
    }

    public fun kill_gauger<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::emergency_council::EmergencyCouncilCap,
        arg2: sui::object::ID,
        _arg3: &sui::clock::Clock
    ): sui::balance::Balance<T0> {
        distribution::emergency_council::validate_emergency_council_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = into_gauge_id(arg2);
        assert!(sui::table::contains<GaugeID, bool>(&arg0.is_alive, v0), 9223374012540190728);
        let v1 = true;
        assert!(sui::table::borrow<GaugeID, bool>(&arg0.is_alive, v0) == &v1, 9223374016835944468);
        update_for_internal<T0>(arg0, v0);
        let v2 = sui::table::remove<GaugeID, u64>(&mut arg0.claimable, v0);
        let mut v3 = sui::balance::zero<T0>();
        if (v2 > 0) {
            sui::balance::join<T0>(
                &mut v3,
                sui::balance::split<T0>(
                    sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<T0>>(
                        &mut arg0.balances,
                        std::type_name::get<T0>()
                    ),
                    v2
                )
            );
        };
        sui::table::remove<GaugeID, bool>(&mut arg0.is_alive, v0);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, false);
        let v4 = EventKillGauge { id: v0.id };
        sui::event::emit<EventKillGauge>(v4);
        v3
    }

    public fun notify_rewards<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::notify_reward_cap::NotifyRewardCap,
        arg2: sui::coin::Coin<T0>
    ) {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = sui::coin::into_balance<T0>(arg2);
        let v1 = sui::balance::value<T0>(&v0);
        let v2 = std::type_name::get<T0>();
        let v3 = if (sui::bag::contains<std::type_name::TypeName>(&arg0.balances, v2)) {
            sui::bag::remove<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v2)
        } else {
            sui::balance::zero<T0>()
        };
        let mut v4 = v3;
        sui::balance::join<T0>(&mut v4, v0);
        sui::bag::add<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v2, v4);
        let v5 = if (arg0.total_weight == 0) {
            1
        } else {
            arg0.total_weight
        };
        let v6 = integer_mate::full_math_u128::mul_div_floor(v1 as u128, 1<<64, v5 as u128);
        if (v6 > 0) {
            arg0.index = arg0.index + v6;
        };
        let v7 = EventNotifyReward {
            notifier: distribution::notify_reward_cap::who(arg1),
            token: v2,
            amount: v1,
        };
        sui::event::emit<EventNotifyReward>(v7);
    }

    public fun poke<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time > distribution::common::epoch_vote_start(current_time), EVotingNotStartedYet);
        let voting_power = distribution::voting_escrow::get_voting_power<SailCoinType>(voting_escrow, lock, clock);
        poke_internal<SailCoinType>(voter, voting_escrow, lock, voting_power, clock, ctx);
    }

    fun poke_internal<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
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
            assert!(sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                EPokeLockNotVoted
            );
            while (i < pool_vote_count) {
                std::vector::push_back<sui::object::ID>(
                    &mut pools_voted_ids,
                    std::vector::borrow<PoolID>(pools_voted, i).id
                );
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
                    *sui::table::borrow<PoolID, u64>(vote_amount_by_pool, *std::vector::borrow<PoolID>(pools_voted, i))
                );
                i = i + 1;
            };
            vote_internal<SailCoinType>(
                voter,
                voting_escrow,
                lock,
                voting_power,
                pools_voted_ids,
                vote_amounts,
                clock,
                ctx
            );
        };
    }

    public fun pool_to_gauge<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): sui::object::ID {
        sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, into_pool_id(arg1)).id
    }

    public fun prove_pair_whitelisted<T0, T1, T2>(
        arg0: &Voter<T0>
    ): distribution::whitelisted_tokens::WhitelistedTokenPair {
        assert!(is_whitelisted_token<T0, T1>(arg0), 9223373870805811199);
        assert!(is_whitelisted_token<T0, T2>(arg0), 9223373875100778495);
        distribution::whitelisted_tokens::create_pair<T1, T2>(sui::object::id<Voter<T0>>(arg0))
    }

    public fun prove_token_whitelisted<T0, T1>(arg0: &Voter<T0>): distribution::whitelisted_tokens::WhitelistedToken {
        assert!(is_whitelisted_token<T0, T1>(arg0), 9223373853625942015);
        distribution::whitelisted_tokens::create<T1>(sui::object::id<Voter<T0>>(arg0))
    }

    public fun receive_gauger<T0, T1, T2>(
        arg0: &mut Voter<T2>,
        arg1: &distribution::voter_cap::GovernorCap,
        arg2: &mut distribution::gauge::Gauge<T0, T1, T2>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T2>>(arg0));
        let v0 = into_gauge_id(sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg2));
        let v1 = into_pool_id(distribution::gauge::pool_id<T0, T1, T2>(arg2));
        assert!(!sui::table::contains<GaugeID, GaugeRepresent>(&arg0.gauge_represents, v0), 9223373720482283526);
        assert!(!sui::table::contains<PoolID, GaugeID>(&arg0.pool_to_gauger, v1), 9223373724779872302);
        let v2 = GaugeRepresent {
            gauger_id: sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg2),
            pool_id: distribution::gauge::pool_id<T0, T1, T2>(arg2),
            weight: 0,
            last_reward_time: sui::clock::timestamp_ms(arg3),
        };
        sui::table::add<GaugeID, GaugeRepresent>(&mut arg0.gauge_represents, v0, v2);
        sui::table::add<GaugeID, sui::balance::Balance<T2>>(&mut arg0.rewards, v0, sui::balance::zero<T2>());
        sui::table::add<GaugeID, u64>(&mut arg0.weights, v0, 0);
        std::vector::push_back<PoolID>(&mut arg0.pools, v1);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, true);
        sui::table::add<PoolID, GaugeID>(&mut arg0.pool_to_gauger, v1, v0);
        distribution::gauge::set_voter<T0, T1, T2>(arg2, sui::object::id<Voter<T2>>(arg0));
        whitelist_token<T2, T0>(arg0, arg1, true, arg4);
        whitelist_token<T2, T1>(arg0, arg1, true, arg4);
        if (!is_whitelisted_token<T2, T2>(arg0)) {
            whitelist_token<T2, T2>(arg0, arg1, true, arg4);
        };
    }

    public fun remove_epoch_governor<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::voter_cap::GovernorCap,
        arg2: address
    ) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = sui::object::id_from_address(arg2);
        sui::vec_set::remove<sui::object::ID>(&mut arg0.epoch_governors, &v0);
        let v1 = EventRemoveEpochGovernor { who: arg2 };
        sui::event::emit<EventRemoveEpochGovernor>(v1);
    }

    public fun remove_governor<T0>(arg0: &mut Voter<T0>, _arg1: &sui::package::Publisher, arg2: address) {
        let v0 = sui::object::id_from_address(arg2);
        sui::vec_set::remove<sui::object::ID>(&mut arg0.governors, &v0);
        let v1 = EventRemoveGovernor { who: arg2 };
        sui::event::emit<EventRemoveGovernor>(v1);
    }

    public fun reset<T0>(
        arg0: &mut Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &distribution::voting_escrow::Lock,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        assert_only_new_epoch<T0>(arg0, into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2)), arg3);
        reset_internal<T0>(arg0, arg1, arg2, arg3, arg4);
    }

    fun reset_internal<T0>(
        arg0: &mut Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &distribution::voting_escrow::Lock,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        let v1 = if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
            std::vector::length<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0))
        } else {
            0
        };
        let mut v2 = 0;
        let mut v3 = 0;
        while (v3 < v1) {
            let v4 = *std::vector::borrow<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0), v3);
            let v5 = *sui::table::borrow<PoolID, u64>(
                sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0),
                v4
            );
            let v6 = *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, v4);
            if (v5 != 0) {
                update_for_internal<T0>(arg0, v6);
                let weight = sui::table::remove<GaugeID, u64>(&mut arg0.weights, v6) - v5;
                sui::table::add<GaugeID, u64>(&mut arg0.weights, v6, weight);
                sui::table::remove<PoolID, u64>(
                    sui::table::borrow_mut<LockID, sui::table::Table<PoolID, u64>>(&mut arg0.votes, v0),
                    v4
                );
                distribution::fee_voting_reward::withdraw(
                    sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(
                        &mut arg0.gauge_to_fee,
                        v6
                    ),
                    &arg0.gauge_to_fee_authorized_cap,
                    v5,
                    v0.id,
                    arg3,
                    arg4
                );
                distribution::bribe_voting_reward::withdraw(
                    sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(
                        &mut arg0.gauge_to_bribe,
                        v6
                    ),
                    &arg0.gauge_to_bribe_authorized_cap,
                    v5,
                    v0.id,
                    arg3,
                    arg4
                );
                v2 = v2 + v5;
                let v7 = EventAbstained {
                    sender: sui::tx_context::sender(arg4),
                    pool: v4.id,
                    lock: v0.id,
                    votes: v5,
                    pool_weight: *sui::table::borrow<GaugeID, u64>(&arg0.weights, v6),
                };
                sui::event::emit<EventAbstained>(v7);
            };
            v3 = v3 + 1;
        };
        distribution::voting_escrow::voting<T0>(arg1, &arg0.voter_cap, v0.id, false);
        arg0.total_weight = arg0.total_weight - v2;
        if (sui::table::contains<LockID, u64>(&arg0.used_weights, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.used_weights, v0);
        };
        if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
            sui::table::remove<LockID, vector<PoolID>>(&mut arg0.pool_vote, v0);
        };
    }

    public(package) fun return_new_gauge<T0, T1, T2>(
        arg0: &gauge_cap::gauge_cap::CreateCap,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: &mut sui::tx_context::TxContext
    ): distribution::gauge::Gauge<T0, T1, T2> {
        let v0 = sui::object::id<clmm_pool::pool::Pool<T0, T1>>(arg1);
        let mut v1 = distribution::gauge::create<T0, T1, T2>(v0, arg2);
        let v2 = gauge_cap::gauge_cap::create_gauge_cap(
            arg0,
            v0,
            sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(&v1),
            arg2
        );
        clmm_pool::pool::init_magma_distribution_gauge<T0, T1>(arg1, &v2);
        distribution::gauge::receive_gauge_cap<T0, T1, T2>(&mut v1, v2);
        v1
    }

    public fun revive_gauger<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::emergency_council::EmergencyCouncilCap,
        arg2: sui::object::ID
    ) {
        distribution::emergency_council::validate_emergency_council_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = into_gauge_id(arg2);
        assert!(sui::table::contains<GaugeID, bool>(&arg0.is_alive, v0), 9223374115619405832);
        let v1 = false;
        assert!(sui::table::borrow<GaugeID, bool>(&arg0.is_alive, v0) == &v1, 9223374124208881663);
        sui::table::remove<GaugeID, bool>(&mut arg0.is_alive, v0);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, true);
        let v2 = EventReviveGauge { id: v0.id };
        sui::event::emit<EventReviveGauge>(v2);
    }

    public fun set_max_voting_num<T0>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: u64) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373183612551192);
        assert!(arg2 >= 10, 9223373187907649562);
        assert!(arg2 != arg0.max_voting_num, 9223373196495945727);
        arg0.max_voting_num = arg2;
    }

    public fun total_weight<T0>(arg0: &Voter<T0>): u64 {
        arg0.total_weight
    }

    public fun update_for<T0>(arg0: &mut Voter<T0>, arg1: sui::object::ID) {
        update_for_internal<T0>(arg0, into_gauge_id(arg1));
    }

    fun update_for_internal<T0>(arg0: &mut Voter<T0>, arg1: GaugeID) {
        let v0 = if (sui::table::contains<GaugeID, u64>(&arg0.weights, arg1)) {
            *sui::table::borrow<GaugeID, u64>(&arg0.weights, arg1)
        } else {
            0
        };
        if (v0 > 0) {
            let v1 = if (sui::table::contains<GaugeID, u128>(&arg0.supply_index, arg1)) {
                sui::table::remove<GaugeID, u128>(&mut arg0.supply_index, arg1)
            } else {
                0
            };
            let v2 = arg0.index;
            sui::table::add<GaugeID, u128>(&mut arg0.supply_index, arg1, v2);
            let v3 = v2 - v1;
            if (v3 > 0) {
                let v4 = if (sui::table::contains<GaugeID, bool>(&arg0.is_alive, arg1)) {
                    let v5 = true;
                    sui::table::borrow<GaugeID, bool>(&arg0.is_alive, arg1) == &v5
                } else {
                    false
                };
                assert!(v4, 9223375717644828720);
                let v6 = if (sui::table::contains<GaugeID, u64>(&arg0.claimable, arg1)) {
                    sui::table::remove<GaugeID, u64>(&mut arg0.claimable, arg1)
                } else {
                    0
                };
                sui::table::add<GaugeID, u64>(
                    &mut arg0.claimable,
                    arg1,
                    v6 + (integer_mate::full_math_u128::mul_div_floor(v0 as u128, v3, 1<<64) as u64)
                );
            };
        } else {
            if (sui::table::contains<GaugeID, u128>(&arg0.supply_index, arg1)) {
                sui::table::remove<GaugeID, u128>(&mut arg0.supply_index, arg1);
            };
            sui::table::add<GaugeID, u128>(&mut arg0.supply_index, arg1, arg0.index);
        };
        // TODO: looks like this function was disabled, check why
        // return
        // abort 9223375717644828720
    }

    public fun update_for_many<T0>(arg0: &mut Voter<T0>, arg1: vector<sui::object::ID>) {
        let mut v0 = 0;
        while (v0 < std::vector::length<sui::object::ID>(&arg1)) {
            update_for_internal<T0>(arg0, into_gauge_id(*std::vector::borrow<sui::object::ID>(&arg1, v0)));
            v0 = v0 + 1;
        };
    }

    public fun update_for_range<T0>(arg0: &mut Voter<T0>, arg1: u64, arg2: u64) {
        let mut v0 = 0;
        while (arg1 + v0 < arg2) {
            let pool_id = *std::vector::borrow<PoolID>(&arg0.pools, arg1 + v0);
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, pool_id);
            update_for_internal<T0>(arg0, gauge_id);
            v0 = v0 + 1;
        };
    }

    public fun used_weights<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): u64 {
        *sui::table::borrow<LockID, u64>(&arg0.used_weights, into_lock_id(arg1))
    }

    public fun vote<SailCoinType>(
        voter: &mut Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        pools: vector<sui::object::ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        assert_only_new_epoch<SailCoinType>(voter, lock_id, clock);
        check_vote<SailCoinType>(voter, &pools, &weights);
        // TODO check flag_distribution, probably useless flag
        assert!(!voter.flag_distribution, EVoteFlagDistribution);
        assert!(
            !distribution::voting_escrow::deactivated<SailCoinType>(voting_escrow, lock_id.id),
            EVoteVotingEscrowDeactivated
        );
        let current_time = distribution::common::current_timestamp(clock);
        let not_whitelisted = (
            current_time > distribution::common::epoch_vote_end(current_time)
        ) && (
            !sui::table::contains<LockID, bool>(&voter.is_whitelisted_nft, lock_id) ||
                *sui::table::borrow<LockID, bool>(&voter.is_whitelisted_nft, lock_id) == false
        );
        if (not_whitelisted) {
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
        lock: &distribution::voting_escrow::Lock,
        voting_power: u64,
        pools: vector<sui::object::ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(lock));
        reset_internal<SailCoinType>(voter, voting_escrow, lock, clock, ctx);
        let mut voted_weight = 0;
        let mut v2 = 0;
        let mut v3 = 0;
        let mut i = 0;
        let pools_length = std::vector::length<sui::object::ID>(&pools);
        while (i < pools_length) {
            let weight_i = std::vector::borrow<u64>(&weights, i);
            voted_weight = voted_weight + *weight_i;
            i = i + 1;
        };
        i = 0;
        while (i < pools_length) {
            let pool_id = into_pool_id(pools[i]);
            assert!(sui::table::contains<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id), EVoteInternalGaugeDoesNotExist);
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&voter.pool_to_gauger, pool_id);
            assert!(is_gauge_alive<SailCoinType>(voter, gauge_id), EVoteInternalGaugeNotAlive);
            let votes_for_pool = integer_mate::full_math_u64::mul_div_floor(
                weights[i],
                voting_power,
                voted_weight
            );
            let v10 = if (sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id)) {
                if (sui::table::contains<PoolID, u64>(
                    sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                    pool_id
                )) {
                    let v11 = 0;
                    sui::table::borrow<PoolID, u64>(
                        sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&voter.votes, lock_id),
                        pool_id
                    ) != &v11
                } else {
                    false
                }
            } else {
                false
            };
            if (v10) {
                abort 9223374832881041448
            };
            assert!(votes_for_pool > 0, 9223374841471107114);
            update_for_internal<SailCoinType>(voter, gauge_id);
            if (!sui::table::contains<LockID, vector<PoolID>>(&voter.pool_vote, lock_id)) {
                sui::table::add<LockID, vector<PoolID>>(&mut voter.pool_vote, lock_id, std::vector::empty<PoolID>());
            };
            std::vector::push_back<PoolID>(sui::table::borrow_mut<LockID, vector<PoolID>>(&mut voter.pool_vote, lock_id),
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
            v2 = v2 + votes_for_pool;
            v3 = v3 + votes_for_pool;
            let v15 = EventVoted {
                sender: sui::tx_context::sender(ctx),
                pool: pool_id.id,
                lock: lock_id.id,
                voting_weight: votes_for_pool,
                pool_weight: *sui::table::borrow<GaugeID, u64>(&voter.weights, gauge_id),
            };
            sui::event::emit<EventVoted>(v15);
            i = i + 1;
        };
        if (v2 > 0) {
            distribution::voting_escrow::voting<SailCoinType>(voting_escrow, &voter.voter_cap, lock_id.id, true);
        };
        voter.total_weight = voter.total_weight + v3;
        if (sui::table::contains<LockID, u64>(&voter.used_weights, lock_id)) {
            sui::table::remove<LockID, u64>(&mut voter.used_weights, lock_id);
        };
        sui::table::add<LockID, u64>(&mut voter.used_weights, lock_id, v2);
    }

    public fun voted_pools<T0>(arg0: &Voter<T0>, arg1: sui::object::ID): vector<sui::object::ID> {
        let mut v0 = std::vector::empty<sui::object::ID>();
        let v1 = into_lock_id(arg1);
        let v2 = if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v1)) {
            sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v1)
        } else {
            let v3 = std::vector::empty<PoolID>();
            &v3
        };
        let mut v4 = 0;
        while (v4 < std::vector::length<PoolID>(v2)) {
            std::vector::push_back<sui::object::ID>(&mut v0, std::vector::borrow<PoolID>(v2, v4).id);
            v4 = v4 + 1;
        };
        v0
    }

    public fun whitelist_nft<T0>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::voter_cap::GovernorCap,
        arg2: sui::object::ID,
        arg3: bool,
        arg4: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373956706664472);
        let v0 = into_lock_id(arg2);
        if (sui::table::contains<LockID, bool>(&arg0.is_whitelisted_nft, v0)) {
            sui::table::remove<LockID, bool>(&mut arg0.is_whitelisted_nft, v0);
        };
        sui::table::add<LockID, bool>(&mut arg0.is_whitelisted_nft, v0, arg3);
        let v1 = EventWhitelistNFT {
            sender: sui::tx_context::sender(arg4),
            id: arg2,
            listed: arg3,
        };
        sui::event::emit<EventWhitelistNFT>(v1);
    }

    public fun whitelist_token<T0, T1>(
        arg0: &mut Voter<T0>,
        arg1: &distribution::voter_cap::GovernorCap,
        arg2: bool,
        arg3: &mut sui::tx_context::TxContext
    ) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373896577122328);
        whitelist_token_internal<T0>(arg0, std::type_name::get<T1>(), arg2, sui::tx_context::sender(arg3));
    }

    fun whitelist_token_internal<T0>(arg0: &mut Voter<T0>, arg1: std::type_name::TypeName, arg2: bool, arg3: address) {
        if (sui::table::contains<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, arg1)) {
            sui::table::remove<std::type_name::TypeName, bool>(&mut arg0.is_whitelisted_token, arg1);
        };
        sui::table::add<std::type_name::TypeName, bool>(&mut arg0.is_whitelisted_token, arg1, arg2);
        let v0 = EventWhitelistToken {
            sender: arg3,
            token: arg1,
            listed: arg2,
        };
        sui::event::emit<EventWhitelistToken>(v0);
    }

    // decompiled from Move bytecode v6
}



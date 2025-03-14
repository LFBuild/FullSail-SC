module distribution::gauge {
    public struct TRANSFORMER has drop {}

    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct EventNotifyReward has copy, drop, store {
        sender: sui::object::ID,
        amount: u64,
    }

    public struct EventClaimFees has copy, drop, store {
        amount_a: u64,
        amount_b: u64,
    }

    public struct RewardProfile has store {
        growth_inside: u128,
        amount: u64,
        last_update_time: u64,
    }

    public struct EventClaimReward has copy, drop, store {
        from: address,
        position_id: sui::object::ID,
        receiver: address,
        amount: u64,
    }

    public struct EventWithdrawPosition has copy, drop, store {
        position_id: sui::object::ID,
        gauger_id: sui::object::ID,
    }

    public struct EventDepositGauge has copy, drop, store {
        gauger_id: sui::object::ID,
        pool_id: sui::object::ID,
        position_id: sui::object::ID,
    }

    public struct EventGaugeCreated has copy, drop, store {
        id: sui::object::ID,
        pool_id: sui::object::ID,
    }

    public struct EventGaugeSetVoter has copy, drop, store {
        id: sui::object::ID,
        voter_id: sui::object::ID,
    }

    public struct Gauge<phantom T0, phantom T1, phantom T2> has store, key {
        id: sui::object::UID,
        pool_id: sui::object::ID,
        gauge_cap: std::option::Option<gauge_cap::gauge_cap::GaugeCap>,
        staked_positions: sui::object_table::ObjectTable<sui::object::ID, clmm_pool::position::Position>,
        staked_position_infos: sui::table::Table<sui::object::ID, PositionStakeInfo>,
        reserves_balance: sui::balance::Balance<T2>,
        fee_a: sui::balance::Balance<T0>,
        fee_b: sui::balance::Balance<T1>,
        voter: std::option::Option<sui::object::ID>,
        reward_rate: u128,
        period_finish: u64,
        reward_rate_by_epoch: sui::table::Table<u64, u128>,
        stakes: sui::table::Table<address, vector<sui::object::ID>>,
        rewards: sui::table::Table<sui::object::ID, RewardProfile>,
    }

    public struct PositionStakeInfo has drop, store {
        from: address,
        received: bool,
    }

    public fun pool_id<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>): sui::object::ID {
        arg0.pool_id
    }

    public fun check_gauger_pool<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>, arg1: &clmm_pool::pool::Pool<T0, T1>): bool {
        (arg0.pool_id != sui::object::id<clmm_pool::pool::Pool<T0, T1>>(
            arg1
        ) || clmm_pool::pool::get_magma_distribution_gauger_id<T0, T1>(arg1) != sui::object::id<Gauge<T0, T1, T2>>(
            arg0
        )) && false || true
    }

    fun check_voter_cap<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>, arg1: &distribution::voter_cap::VoterCap) {
        let v0 = distribution::voter_cap::get_voter_id(arg1);
        assert!(&v0 == std::option::borrow<sui::object::ID>(&arg0.voter), 9223373656058429456);
    }

    public fun claim_fees<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        _arg1: &distribution::notify_reward_cap::NotifyRewardCap,
        arg2: &mut clmm_pool::pool::Pool<T0, T1>
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        claim_fees_internal<T0, T1, T2>(arg0, arg2)
    }

    fun claim_fees_internal<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        let (v0, v1) = clmm_pool::pool::collect_magma_distribution_gauger_fees<T0, T1>(
            arg1,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap)
        );
        let v2 = v1;
        let v3 = v0;
        if (sui::balance::value<T0>(&v3) > 0 || sui::balance::value<T1>(&v2) > 0) {
            let v4 = sui::balance::join<T0>(&mut arg0.fee_a, v3);
            let v5 = sui::balance::join<T1>(&mut arg0.fee_b, v2);
            let v6 = if (v4 > clmm_pool::config::week()) {
                sui::balance::withdraw_all<T0>(&mut arg0.fee_a)
            } else {
                sui::balance::zero<T0>()
            };
            let v7 = if (v5 > clmm_pool::config::week()) {
                sui::balance::withdraw_all<T1>(&mut arg0.fee_b)
            } else {
                sui::balance::zero<T1>()
            };
            let v8 = EventClaimFees {
                amount_a: v4,
                amount_b: v5,
            };
            sui::event::emit<EventClaimFees>(v8);
            return (v6, v7)
        };
        sui::balance::destroy_zero<T0>(v3);
        sui::balance::destroy_zero<T1>(v2);
        (sui::balance::zero<T0>(), sui::balance::zero<T1>())
    }

    public(package) fun create<T0, T1, T2>(
        arg0: sui::object::ID,
        arg1: &mut sui::tx_context::TxContext
    ): Gauge<T0, T1, T2> {
        let v0 = sui::object::new(arg1);
        let v1 = EventGaugeCreated {
            id: sui::object::uid_to_inner(&v0),
            pool_id: arg0,
        };
        sui::event::emit<EventGaugeCreated>(v1);
        Gauge<T0, T1, T2> {
            id: v0,
            pool_id: arg0,
            gauge_cap: std::option::none<gauge_cap::gauge_cap::GaugeCap>(),
            staked_positions: sui::object_table::new<sui::object::ID, clmm_pool::position::Position>(arg1),
            staked_position_infos: sui::table::new<sui::object::ID, PositionStakeInfo>(arg1),
            reserves_balance: sui::balance::zero<T2>(),
            fee_a: sui::balance::zero<T0>(),
            fee_b: sui::balance::zero<T1>(),
            voter: std::option::none<sui::object::ID>(),
            reward_rate: 0,
            period_finish: 0,
            reward_rate_by_epoch: sui::table::new<u64, u128>(arg1),
            stakes: sui::table::new<address, vector<sui::object::ID>>(arg1),
            rewards: sui::table::new<sui::object::ID, RewardProfile>(arg1),
        }
    }

    public fun deposit_position<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Gauge<T0, T1, T2>,
        arg2: &mut clmm_pool::pool::Pool<T0, T1>,
        arg3: clmm_pool::position::Position,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        let v0 = sui::tx_context::sender(arg5);
        let v1 = sui::object::id<clmm_pool::pool::Pool<T0, T1>>(arg2);
        let v2 = sui::object::id<clmm_pool::position::Position>(&arg3);
        assert!(clmm_pool::config::is_gauge_alive(arg0, sui::object::id<Gauge<T0, T1, T2>>(arg1)), 9223373157842747416);
        assert!(check_gauger_pool<T0, T1, T2>(arg1, arg2), 9223373162136666120);
        assert!(clmm_pool::position::pool_id(&arg3) == v1, 9223373166431764490);
        assert!(
            !clmm_pool::position::is_staked(
                clmm_pool::position::borrow_position_info(clmm_pool::pool::position_manager<T0, T1>(arg2), v2)
            ),
            9223373175021174786
        );
        let v3 = PositionStakeInfo {
            from: v0,
            received: false,
        };
        sui::table::add<sui::object::ID, PositionStakeInfo>(&mut arg1.staked_position_infos, v2, v3);
        let (v4, v5) = clmm_pool::pool::collect_fee<T0, T1>(arg0, arg2, &arg3, true);
        sui::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::from_balance<T0>(v4, arg5), v0);
        sui::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::from_balance<T1>(v5, arg5), v0);
        let (v6, v7) = clmm_pool::position::tick_range(&arg3);
        if (!sui::table::contains<address, vector<sui::object::ID>>(&arg1.stakes, v0)) {
            let mut v8 = std::vector::empty<sui::object::ID>();
            std::vector::push_back<sui::object::ID>(&mut v8, v2);
            sui::table::add<address, vector<sui::object::ID>>(&mut arg1.stakes, v0, v8);
        } else {
            std::vector::push_back<sui::object::ID>(
                sui::table::borrow_mut<address, vector<sui::object::ID>>(&mut arg1.stakes, v0),
                v2
            );
        };
        let positionLiquidity = clmm_pool::position::liquidity(&arg3);
        sui::object_table::add<sui::object::ID, clmm_pool::position::Position>(&mut arg1.staked_positions, v2, arg3);
        if (!sui::table::contains<sui::object::ID, RewardProfile>(&arg1.rewards, v2)) {
            let v9 = RewardProfile {
                growth_inside: clmm_pool::pool::get_magma_distribution_growth_inside<T0, T1>(arg2, v6, v7, 0),
                amount: 0,
                last_update_time: sui::clock::timestamp_ms(arg4) / 1000,
            };
            sui::table::add<sui::object::ID, RewardProfile>(&mut arg1.rewards, v2, v9);
        } else {
            let v10 = sui::table::borrow_mut<sui::object::ID, RewardProfile>(&mut arg1.rewards, v2);
            v10.growth_inside = clmm_pool::pool::get_magma_distribution_growth_inside<T0, T1>(arg2, v6, v7, 0);
            v10.last_update_time = sui::clock::timestamp_ms(arg4) / 1000;
        };
        clmm_pool::pool::mark_position_staked<T0, T1>(
            arg2,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg1.gauge_cap),
            v2
        );
        sui::table::borrow_mut<sui::object::ID, PositionStakeInfo>(&mut arg1.staked_position_infos, v2).received = true;
        clmm_pool::pool::stake_in_magma_distribution<T0, T1>(
            arg2,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg1.gauge_cap),
            positionLiquidity,
            v6,
            v7,
            arg4
        );
        let v11 = EventDepositGauge {
            gauger_id: sui::object::id<Gauge<T0, T1, T2>>(arg1),
            pool_id: v1,
            position_id: v2,
        };
        sui::event::emit<EventDepositGauge>(v11);
    }

    public fun earned_by_account<T0, T1, T2>(
        arg0: &Gauge<T0, T1, T2>,
        arg1: &clmm_pool::pool::Pool<T0, T1>,
        arg2: address,
        arg3: &sui::clock::Clock
    ): u64 {
        assert!(check_gauger_pool<T0, T1, T2>(arg0, arg1), 9223372724050001928);
        let v0 = sui::table::borrow<address, vector<sui::object::ID>>(&arg0.stakes, arg2);
        let mut v1 = 0;
        let mut v2 = 0;
        while (v1 < std::vector::length<sui::object::ID>(v0)) {
            v2 = v2 + earned_internal<T0, T1, T2>(
                arg0,
                arg1,
                *std::vector::borrow<sui::object::ID>(v0, v1),
                sui::clock::timestamp_ms(arg3) / 1000
            );
            v1 = v1 + 1;
        };
        v2
    }

    public fun earned_by_position<T0, T1, T2>(
        arg0: &Gauge<T0, T1, T2>,
        arg1: &clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock
    ): u64 {
        assert!(check_gauger_pool<T0, T1, T2>(arg0, arg1), 9223372693985230856);
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(&arg0.staked_positions, arg2),
            9223372698279936004
        );
        earned_internal<T0, T1, T2>(arg0, arg1, arg2, sui::clock::timestamp_ms(arg3) / 1000)
    }

    fun earned_internal<T0, T1, T2>(
        arg0: &Gauge<T0, T1, T2>,
        arg1: &clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: u64
    ): u64 {
        let v0 = arg3 - clmm_pool::pool::get_magma_distribution_last_updated<T0, T1>(arg1);
        let v1 = clmm_pool::pool::get_magma_distribution_growth_global<T0, T1>(arg1);
        let mut v2 = v1;
        let v3 = (clmm_pool::pool::get_magma_distribution_reserve<T0, T1>(arg1) as u128) * 18446744073709551616;
        let v4 = clmm_pool::pool::get_magma_distribution_staked_liquidity<T0, T1>(arg1);
        let v5 = if (v0 >= 0) {
            if (v3 > 0) {
                v4 > 0
            } else {
                false
            }
        } else {
            false
        };
        if (v5) {
            let v6 = arg0.reward_rate * (v0 as u128);
            let mut v7 = v6;
            if (v6 > v3) {
                v7 = v3;
            };
            v2 = v1 + integer_mate::math_u128::checked_div_round(v7, v4, false);
        };
        let v8 = sui::object_table::borrow<sui::object::ID, clmm_pool::position::Position>(
            &arg0.staked_positions,
            arg2
        );
        let (v9, v10) = clmm_pool::position::tick_range(v8);
        integer_mate::full_math_u128::mul_div_floor(
            clmm_pool::pool::get_magma_distribution_growth_inside<T0, T1>(
                arg1,
                v9,
                v10,
                v2
            ) - sui::table::borrow<sui::object::ID, RewardProfile>(&arg0.rewards, arg2).growth_inside,
            clmm_pool::position::liquidity(v8),
            18446744073709551616
        ) as u64
    }

    public fun get_position_reward<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        assert!(check_gauger_pool<T0, T1, T2>(arg0, arg1), 9223373428424638472);
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(&arg0.staked_positions, arg2),
            9223373432719343620
        );
        get_reward_internal<T0, T1, T2>(arg0, arg1, arg2, arg3, arg4);
    }

    public fun get_reward<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: &sui::clock::Clock,
        arg3: &mut sui::tx_context::TxContext
    ) {
        assert!(check_gauger_pool<T0, T1, T2>(arg0, arg1), 9223373454194442248);
        let v0 = sui::tx_context::sender(arg3);
        assert!(sui::table::contains<address, vector<sui::object::ID>>(&arg0.stakes, v0), 9223373462784638988);
        let v1 = sui::table::borrow<address, vector<sui::object::ID>>(&arg0.stakes, v0);
        let mut v2 = std::vector::empty<sui::object::ID>();
        let mut v3 = 0;
        while (v3 < std::vector::length<sui::object::ID>(v1)) {
            std::vector::push_back<sui::object::ID>(&mut v2, *std::vector::borrow<sui::object::ID>(v1, v3));
            v3 = v3 + 1;
        };
        let v4 = v2;
        let mut v5 = 0;
        while (v5 < std::vector::length<sui::object::ID>(&v4)) {
            get_reward_internal<T0, T1, T2>(arg0, arg1, *std::vector::borrow<sui::object::ID>(&v4, v5), arg2, arg3);
            v5 = v5 + 1;
        };
    }

    public fun get_reward_for<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: address,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        assert!(check_gauger_pool<T0, T1, T2>(arg0, arg1), 9223373510029017096);
        assert!(sui::table::contains<address, vector<sui::object::ID>>(&arg0.stakes, arg2), 9223373514324246540);
        let v0 = sui::table::borrow<address, vector<sui::object::ID>>(&arg0.stakes, arg2);
        let mut v1 = std::vector::empty<sui::object::ID>();
        let mut v2 = 0;
        while (v2 < std::vector::length<sui::object::ID>(v0)) {
            std::vector::push_back<sui::object::ID>(&mut v1, *std::vector::borrow<sui::object::ID>(v0, v2));
            v2 = v2 + 1;
        };
        let v3 = v1;
        let mut v4 = 0;
        while (v4 < std::vector::length<sui::object::ID>(&v3)) {
            get_reward_internal<T0, T1, T2>(arg0, arg1, *std::vector::borrow<sui::object::ID>(&v3, v4), arg3, arg4);
            v4 = v4 + 1;
        };
    }

    fun get_reward_internal<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1) = clmm_pool::position::tick_range(
            sui::object_table::borrow<sui::object::ID, clmm_pool::position::Position>(&arg0.staked_positions, arg2)
        );
        let v2 = update_reward_internal<T0, T1, T2>(arg0, arg1, arg2, v0, v1, arg3);
        if (sui::balance::value<T2>(&v2) > 0) {
            let v3 = sui::table::borrow<sui::object::ID, PositionStakeInfo>(&arg0.staked_position_infos, arg2).from;
            let amount = sui::balance::value<T2>(&v2);
            sui::transfer::public_transfer<sui::coin::Coin<T2>>(sui::coin::from_balance<T2>(v2, arg4), v3);
            let v4 = EventClaimReward {
                from: sui::tx_context::sender(arg4),
                position_id: arg2,
                receiver: v3,
                amount,
            };
            sui::event::emit<EventClaimReward>(v4);
        } else {
            sui::balance::destroy_zero<T2>(v2);
        };
    }

    public fun notify_reward<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &distribution::voter_cap::VoterCap,
        arg2: &mut clmm_pool::pool::Pool<T0, T1>,
        arg3: sui::balance::Balance<T2>,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        check_voter_cap<T0, T1, T2>(arg0, arg1);
        let v0 = sui::balance::value<T2>(&arg3);
        assert!(v0 > 0, 9223373716188102674);
        sui::balance::join<T2>(&mut arg0.reserves_balance, arg3);
        let (v1, v2) = claim_fees_internal<T0, T1, T2>(arg0, arg2);
        notify_reward_amount_internal<T0, T1, T2>(arg0, arg2, v0, arg4);
        let v3 = EventNotifyReward {
            sender: sui::object::id_from_address(sui::tx_context::sender(arg5)),
            amount: v0,
        };
        sui::event::emit<EventNotifyReward>(v3);
        (v1, v2)
    }

    fun notify_reward_amount_internal<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: u64,
        arg3: &sui::clock::Clock
    ) {
        let v0 = sui::clock::timestamp_ms(arg3) / 1000;
        let v1 = clmm_pool::config::epoch_next(v0) - v0;
        clmm_pool::pool::update_magma_distribution_growth_global<T0, T1>(
            arg1,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
            arg3
        );
        let v2 = v0 + v1;
        let v3 = arg2 + clmm_pool::pool::get_magma_distribution_rollover<T0, T1>(arg1);
        if (v0 >= arg0.period_finish) {
            arg0.reward_rate = integer_mate::full_math_u128::mul_div_floor(
                v3 as u128,
                18446744073709551616,
                v1 as u128
            );
            clmm_pool::pool::sync_magma_distribution_reward<T0, T1>(
                arg1,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
                arg0.reward_rate,
                sui::balance::value<T2>(&arg0.reserves_balance),
                v2
            );
        } else {
            let v4 = (v1 as u128) * arg0.reward_rate;
            arg0.reward_rate = integer_mate::full_math_u128::mul_div_floor(
                (v3 as u128) + v4,
                18446744073709551616,
                v1 as u128
            );
            clmm_pool::pool::sync_magma_distribution_reward<T0, T1>(
                arg1,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
                arg0.reward_rate,
                sui::balance::value<T2>(&arg0.reserves_balance) + ((v4 / 18446744073709551616) as u64),
                v2
            );
        };
        sui::table::add<u64, u128>(
            &mut arg0.reward_rate_by_epoch,
            clmm_pool::config::epoch_start(v0),
            arg0.reward_rate
        );
        assert!(arg0.reward_rate != 0, 9223373952411435028);
        assert!(
            arg0.reward_rate <= integer_mate::full_math_u128::mul_div_floor(
                sui::balance::value<T2>(&arg0.reserves_balance) as u128,
                18446744073709551616,
                v1 as u128
            ),
            9223373956706533398
        );
        arg0.period_finish = v2;
        let v5 = EventNotifyReward {
            sender: *std::option::borrow<sui::object::ID>(&arg0.voter),
            amount: v3,
        };
        sui::event::emit<EventNotifyReward>(v5);
    }

    public fun notify_reward_without_claim<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &distribution::voter_cap::VoterCap,
        arg2: &mut clmm_pool::pool::Pool<T0, T1>,
        arg3: sui::balance::Balance<T2>,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        check_voter_cap<T0, T1, T2>(arg0, arg1);
        let v0 = sui::balance::value<T2>(&arg3);
        assert!(v0 > 0, 9223373819267317778);
        sui::balance::join<T2>(&mut arg0.reserves_balance, arg3);
        notify_reward_amount_internal<T0, T1, T2>(arg0, arg2, v0, arg4);
        let v1 = EventNotifyReward {
            sender: sui::object::id_from_address(sui::tx_context::sender(arg5)),
            amount: v0,
        };
        sui::event::emit<EventNotifyReward>(v1);
    }

    public fun period_finish<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>): u64 {
        arg0.period_finish
    }

    public(package) fun receive_gauge_cap<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: gauge_cap::gauge_cap::GaugeCap
    ) {
        assert!(arg0.pool_id == gauge_cap::gauge_cap::get_pool_id(&arg1), 9223373119186534399);
        std::option::fill<gauge_cap::gauge_cap::GaugeCap>(&mut arg0.gauge_cap, arg1);
    }

    public fun reserves_balance<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>): u64 {
        sui::balance::value<T2>(&arg0.reserves_balance)
    }

    public fun reward_rate<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>): u128 {
        arg0.reward_rate
    }

    public fun reward_rate_by_epoch<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>, arg1: u64): u128 {
        *sui::table::borrow<u64, u128>(&arg0.reward_rate_by_epoch, arg1)
    }

    public(package) fun set_voter<T0, T1, T2>(arg0: &mut Gauge<T0, T1, T2>, arg1: sui::object::ID) {
        std::option::fill<sui::object::ID>(&mut arg0.voter, arg1);
        let v0 = EventGaugeSetVoter {
            id: sui::object::id<Gauge<T0, T1, T2>>(arg0),
            voter_id: arg1,
        };
        sui::event::emit<EventGaugeSetVoter>(v0);
    }

    public fun stakes<T0, T1, T2>(arg0: &Gauge<T0, T1, T2>, arg1: address): vector<sui::object::ID> {
        let v0 = sui::table::borrow<address, vector<sui::object::ID>>(&arg0.stakes, arg1);
        let mut v1 = std::vector::empty<sui::object::ID>();
        let mut v2 = 0;
        while (v2 < std::vector::length<sui::object::ID>(v0)) {
            std::vector::push_back<sui::object::ID>(&mut v1, *std::vector::borrow<sui::object::ID>(v0, v2));
            v2 = v2 + 1;
        };
        v1
    }

    fun update_reward_internal<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: integer_mate::i32::I32,
        arg4: integer_mate::i32::I32,
        arg5: &sui::clock::Clock
    ): sui::balance::Balance<T2> {
        let v0 = sui::clock::timestamp_ms(arg5) / 1000;
        let amount_earned = earned_internal<T0, T1, T2>(arg0, arg1, arg2, v0);
        let v1 = sui::table::borrow_mut<sui::object::ID, RewardProfile>(&mut arg0.rewards, arg2);
        if (v1.last_update_time >= v0) {
            v1.amount = 0;
            return sui::balance::split<T2>(&mut arg0.reserves_balance, v1.amount)
        };
        clmm_pool::pool::update_magma_distribution_growth_global<T0, T1>(
            arg1,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
            arg5
        );
        v1.last_update_time = v0;
        v1.amount = v1.amount + amount_earned;
        v1.growth_inside = clmm_pool::pool::get_magma_distribution_growth_inside<T0, T1>(arg1, arg3, arg4, 0);
        v1.amount = 0;
        sui::balance::split<T2>(&mut arg0.reserves_balance, v1.amount)
    }

    public fun withdraw_position<T0, T1, T2>(
        arg0: &mut Gauge<T0, T1, T2>,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(
                &arg0.staked_positions,
                arg2
            ) && sui::table::contains<sui::object::ID, PositionStakeInfo>(&arg0.staked_position_infos, arg2),
            9223373570158297092
        );
        let v0 = sui::table::remove<sui::object::ID, PositionStakeInfo>(&mut arg0.staked_position_infos, arg2);
        assert!(v0.received, 9223373578748887054);
        if (v0.from != sui::tx_context::sender(arg4)) {
            sui::table::add<sui::object::ID, PositionStakeInfo>(&mut arg0.staked_position_infos, arg2, v0);
        } else {
            let v1 = sui::object_table::remove<sui::object::ID, clmm_pool::position::Position>(
                &mut arg0.staked_positions,
                arg2
            );
            let v2 = clmm_pool::position::liquidity(&v1);
            if (v2 > 0) {
                let (v3, v4) = clmm_pool::position::tick_range(&v1);
                clmm_pool::pool::unstake_from_magma_distribution<T0, T1>(
                    arg1,
                    std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
                    v2,
                    v3,
                    v4,
                    arg3
                );
            };
            clmm_pool::pool::mark_position_unstaked<T0, T1>(
                arg1,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&arg0.gauge_cap),
                arg2
            );
            sui::transfer::public_transfer<clmm_pool::position::Position>(v1, v0.from);
            let v5 = EventWithdrawPosition {
                position_id: arg2,
                gauger_id: sui::object::id<Gauge<T0, T1, T2>>(arg0),
            };
            sui::event::emit<EventWithdrawPosition>(v5);
        };
    }

    // decompiled from Move bytecode v6
}


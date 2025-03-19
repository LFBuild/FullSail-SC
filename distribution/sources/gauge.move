module distribution::gauge {

    const EInvalidVoter: u64 = 9223373656058429456;

    const ENontifyRewardInvalidAmount: u64 = 9223373716188102674;

    const EDepositPositionGaugeNotAlive: u64 = 9223373157842747416;
    const EDepositPositionGaugeDoesNotMatchPool: u64 = 9223373162136666120;
    const EDepositPositionPositionDoesNotMatchPool: u64 = 9223373166431764490;
    const EDepositPositionPositionAlreadyStaked: u64 = 9223373175021174786;

    const EEarnedByAccountGaugeDoesNotMatchPool: u64 = 9223372724050001928;

    const EGetPositionRewardGaugeDoesNotMatchPool: u64 = 9223373428424638472;
    const EGetPositionRewardPositionNotStaked: u64 = 9223373432719343620;

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

    public struct Gauge<phantom CoinTypeA, phantom CoinTypeB, phantom SailCoinType> has store, key {
        id: sui::object::UID,
        pool_id: sui::object::ID,
        gauge_cap: std::option::Option<gauge_cap::gauge_cap::GaugeCap>,
        staked_positions: sui::object_table::ObjectTable<sui::object::ID, clmm_pool::position::Position>,
        staked_position_infos: sui::table::Table<sui::object::ID, PositionStakeInfo>,
        reserves_balance: sui::balance::Balance<SailCoinType>,
        fee_a: sui::balance::Balance<CoinTypeA>,
        fee_b: sui::balance::Balance<CoinTypeB>,
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

    public fun pool_id<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>
    ): sui::object::ID {
        gauge.pool_id
    }

    public fun check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): bool {
        (gauge.pool_id != sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(
            pool
        ) || clmm_pool::pool::get_magma_distribution_gauger_id<CoinTypeA, CoinTypeB>(
            pool
        ) != sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(
            gauge
        )) && false || true
    }

    fun check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap
    ) {
        let voter_id = distribution::voter_cap::get_voter_id(voter_cap);
        assert!(&voter_id == std::option::borrow<sui::object::ID>(&gauge.voter), EInvalidVoter);
    }

    public fun claim_fees<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        _notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool)
    }

    fun claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let (fee_a, fee_b) = clmm_pool::pool::collect_magma_distribution_gauger_fees<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap)
        );
        if (fee_a.value<CoinTypeA>() > 0 || fee_b.value<CoinTypeB>() > 0) {
            let amount_a = gauge.fee_a.join<CoinTypeA>(fee_a);
            let amount_b = gauge.fee_b.join<CoinTypeB>(fee_b);
            let withdrawn_a = if (amount_a > clmm_pool::config::week()) {
                gauge.fee_a.withdraw_all<CoinTypeA>()
            } else {
                sui::balance::zero<CoinTypeA>()
            };
            let withdraw_b = if (amount_b > clmm_pool::config::week()) {
                gauge.fee_b.withdraw_all<CoinTypeB>()
            } else {
                sui::balance::zero<CoinTypeB>()
            };
            let claim_fees_event = EventClaimFees {
                amount_a,
                amount_b,
            };
            sui::event::emit<EventClaimFees>(claim_fees_event);
            return (withdrawn_a, withdraw_b)
        };
        sui::balance::destroy_zero<CoinTypeA>(fee_a);
        sui::balance::destroy_zero<CoinTypeB>(fee_b);
        (sui::balance::zero<CoinTypeA>(), sui::balance::zero<CoinTypeB>())
    }

    public(package) fun create<CoinTypeA, CoinTypeB, SailCoinType>(
        pool_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ): Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
        let id = sui::object::new(ctx);
        let gauge_created_event = EventGaugeCreated {
            id: sui::object::uid_to_inner(&id),
            pool_id,
        };
        sui::event::emit<EventGaugeCreated>(gauge_created_event);
        Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
            id,
            pool_id,
            gauge_cap: std::option::none<gauge_cap::gauge_cap::GaugeCap>(),
            staked_positions: sui::object_table::new<sui::object::ID, clmm_pool::position::Position>(ctx),
            staked_position_infos: sui::table::new<sui::object::ID, PositionStakeInfo>(ctx),
            reserves_balance: sui::balance::zero<SailCoinType>(),
            fee_a: sui::balance::zero<CoinTypeA>(),
            fee_b: sui::balance::zero<CoinTypeB>(),
            voter: std::option::none<sui::object::ID>(),
            reward_rate: 0,
            period_finish: 0,
            reward_rate_by_epoch: sui::table::new<u64, u128>(ctx),
            stakes: sui::table::new<address, vector<sui::object::ID>>(ctx),
            rewards: sui::table::new<sui::object::ID, RewardProfile>(ctx),
        }
    }

    public fun deposit_position<CoinTypeA, CoinTypeB, SailCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: clmm_pool::position::Position,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let sender = sui::tx_context::sender(ctx);
        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let position_id = sui::object::id<clmm_pool::position::Position>(&position);
        assert!(
            clmm_pool::config::is_gauge_alive(
                global_config,
                sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)
            ),
            EDepositPositionGaugeNotAlive
        );
        assert!(
            check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool),
            EDepositPositionGaugeDoesNotMatchPool
        );
        assert!(clmm_pool::position::pool_id(&position) == pool_id, EDepositPositionPositionDoesNotMatchPool);
        assert!(
            !clmm_pool::position::is_staked(
                clmm_pool::position::borrow_position_info(
                    clmm_pool::pool::position_manager<CoinTypeA, CoinTypeB>(pool),
                    position_id
                )
            ),
            EDepositPositionPositionAlreadyStaked
        );
        let position_stake = PositionStakeInfo {
            from: sender,
            received: false,
        };
        sui::table::add<sui::object::ID, PositionStakeInfo>(
            &mut gauge.staked_position_infos,
            position_id,
            position_stake
        );
        let (fee_a, fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &position,
            true
        );
        sui::transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(
            sui::coin::from_balance<CoinTypeA>(fee_a, ctx),
            sender
        );
        sui::transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(
            sui::coin::from_balance<CoinTypeB>(fee_b, ctx),
            sender
        );
        let (lower_tick, upper_tick) = clmm_pool::position::tick_range(&position);
        if (!sui::table::contains<address, vector<sui::object::ID>>(&gauge.stakes, sender)) {
            let mut position_ids = std::vector::empty<sui::object::ID>();
            std::vector::push_back<sui::object::ID>(&mut position_ids, position_id);
            sui::table::add<address, vector<sui::object::ID>>(&mut gauge.stakes, sender, position_ids);
        } else {
            std::vector::push_back<sui::object::ID>(
                sui::table::borrow_mut<address, vector<sui::object::ID>>(&mut gauge.stakes, sender),
                position_id
            );
        };
        let position_liquidity = clmm_pool::position::liquidity(&position);
        sui::object_table::add<sui::object::ID, clmm_pool::position::Position>(
            &mut gauge.staked_positions,
            position_id,
            position
        );
        if (!sui::table::contains<sui::object::ID, RewardProfile>(&gauge.rewards, position_id)) {
            let new_reward_profile = RewardProfile {
                growth_inside: clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                    pool,
                    lower_tick,
                    upper_tick,
                    0
                ),
                amount: 0,
                last_update_time: sui::clock::timestamp_ms(clock) / 1000,
            };
            sui::table::add<sui::object::ID, RewardProfile>(&mut gauge.rewards, position_id, new_reward_profile);
        } else {
            let reward_profile = sui::table::borrow_mut<sui::object::ID, RewardProfile>(&mut gauge.rewards, position_id);
            reward_profile.growth_inside = clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                pool,
                lower_tick,
                upper_tick,
                0
            );
            reward_profile.last_update_time = sui::clock::timestamp_ms(clock) / 1000;
        };
        clmm_pool::pool::mark_position_staked<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            position_id
        );
        sui::table::borrow_mut<sui::object::ID, PositionStakeInfo>(
            &mut gauge.staked_position_infos,
            position_id
        ).received = true;
        clmm_pool::pool::stake_in_magma_distribution<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            position_liquidity,
            lower_tick,
            upper_tick,
            clock
        );
        let deposit_gauge_event = EventDepositGauge {
            gauger_id: sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            pool_id,
            position_id,
        };
        sui::event::emit<EventDepositGauge>(deposit_gauge_event);
    }

    public fun earned_by_account<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        account: address,
        clock: &sui::clock::Clock
    ): u64 {
        assert!(check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool), EEarnedByAccountGaugeDoesNotMatchPool);
        let position_ids = sui::table::borrow<address, vector<sui::object::ID>>(&gauge.stakes, account);
        let mut i = 0;
        let mut total_earned = 0;
        while (i < std::vector::length<sui::object::ID>(position_ids)) {
            total_earned = total_earned + earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
                gauge,
                pool,
                position_ids[i],
                sui::clock::timestamp_ms(clock) / 1000
            );
            i = i + 1;
        };
        total_earned
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

    fun earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        time: u64
    ): u64 {
        let time_since_last_update = time - clmm_pool::pool::get_magma_distribution_last_updated<CoinTypeA, CoinTypeB>(pool);
        let mut current_growth_global = clmm_pool::pool::get_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(pool);
        let distribution_reseve_x64 = (clmm_pool::pool::get_magma_distribution_reserve<CoinTypeA, CoinTypeB>(pool) as u128) * 1<<64;
        let staked_liquidity = clmm_pool::pool::get_magma_distribution_staked_liquidity<CoinTypeA, CoinTypeB>(pool);
        let should_update_growth = if (time_since_last_update >= 0) {
            if (distribution_reseve_x64 > 0) {
                staked_liquidity > 0
            } else {
                false
            }
        } else {
            false
        };
        if (should_update_growth) {
            let mut potential_reward_amount = gauge.reward_rate * (time_since_last_update as u128);
            if (potential_reward_amount > distribution_reseve_x64) {
                potential_reward_amount = distribution_reseve_x64;
            };
            current_growth_global = current_growth_global + integer_mate::math_u128::checked_div_round(
                potential_reward_amount,
                staked_liquidity,
                false
            );
        };
        let position = sui::object_table::borrow<sui::object::ID, clmm_pool::position::Position>(
            &gauge.staked_positions,
            position_id
        );
        let (lower_tick, upper_tick) = clmm_pool::position::tick_range(position);
        integer_mate::full_math_u128::mul_div_floor(
            clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                pool,
                lower_tick,
                upper_tick,
                current_growth_global
            ) - sui::table::borrow<sui::object::ID, RewardProfile>(
                &gauge.rewards,
                position_id
            ).growth_inside,
            clmm_pool::position::liquidity(position),
            1<<64
        ) as u64
    }

    public fun get_position_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool), EGetPositionRewardGaugeDoesNotMatchPool);
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(
                &gauge.staked_positions,
                position_id
            ),
            EGetPositionRewardPositionNotStaked
        );
        get_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, position_id, clock, ctx);
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

    public fun notify_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        balance: sui::balance::Balance<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(gauge, voter_cap);
        let balance_value = balance.value<SailCoinType>();
        assert!(balance_value > 0, ENontifyRewardInvalidAmount);
        gauge.reserves_balance.join<SailCoinType>(balance);
        let (fee_a, fee_b) = claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool);
        notify_reward_amount_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, balance_value, clock);
        let event_notify_reward = EventNotifyReward {
            sender: sui::object::id_from_address(sui::tx_context::sender(ctx)),
            amount: balance_value,
        };
        sui::event::emit<EventNotifyReward>(event_notify_reward);
        (fee_a, fee_b)
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


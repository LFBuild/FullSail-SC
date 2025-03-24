module clmm_pool::pool {
    public struct POOL has drop {}

    public struct Pool<phantom CoinTypeA, phantom CoinTypeB> has store, key {
        id: sui::object::UID,
        coin_a: sui::balance::Balance<CoinTypeA>,
        coin_b: sui::balance::Balance<CoinTypeB>,
        tick_spacing: u32,
        fee_rate: u64,
        liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: integer_mate::i32::I32,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        fee_protocol_coin_a: u64,
        fee_protocol_coin_b: u64,
        tick_manager: clmm_pool::tick::TickManager,
        rewarder_manager: clmm_pool::rewarder::RewarderManager,
        position_manager: clmm_pool::position::PositionManager,
        is_pause: bool,
        index: u64,
        url: std::string::String,
        unstaked_liquidity_fee_rate: u64,
        magma_distribution_gauger_id: std::option::Option<sui::object::ID>,
        magma_distribution_growth_global: u128,
        magma_distribution_rate: u128,
        magma_distribution_reserve: u64,
        magma_distribution_period_finish: u64,
        magma_distribution_rollover: u64,
        magma_distribution_last_updated: u64,
        magma_distribution_staked_liquidity: u128,
        magma_distribution_gauger_fee: PoolFee,
    }

    public struct PoolFee has drop, store {
        coin_a: u64,
        coin_b: u64,
    }

    public struct SwapResult has copy, drop {
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        protocol_fee_amount: u64,
        ref_fee_amount: u64,
        gauge_fee_amount: u64,
        steps: u64,
    }

    public struct FlashSwapReceipt<phantom CoinTypeA, phantom CoinTypeB> {
        pool_id: sui::object::ID,
        a2b: bool,
        partner_id: sui::object::ID,
        pay_amount: u64,
        fee_amount: u64,
        protocol_fee_amount: u64,
        ref_fee_amount: u64,
        gauge_fee_amount: u64,
    }

    public struct AddLiquidityReceipt<phantom CoinTypeA, phantom CoinTypeB> {
        pool_id: sui::object::ID,
        amount_a: u64,
        amount_b: u64,
    }

    public struct CalculatedSwapResult has copy, drop, store {
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        fee_rate: u64,
        ref_fee_amount: u64,
        gauge_fee_amount: u64,
        protocol_fee_amount: u64,
        after_sqrt_price: u128,
        is_exceed: bool,
        step_results: vector<SwapStepResult>,
    }

    public struct SwapStepResult has copy, drop, store {
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        current_liquidity: u128,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        remainder_amount: u64,
    }

    public struct OpenPositionEvent has copy, drop, store {
        pool: sui::object::ID,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        position: sui::object::ID,
    }

    public struct ClosePositionEvent has copy, drop, store {
        pool: sui::object::ID,
        position: sui::object::ID,
    }

    public struct AddLiquidityEvent has copy, drop, store {
        pool: sui::object::ID,
        position: sui::object::ID,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        liquidity: u128,
        after_liquidity: u128,
        amount_a: u64,
        amount_b: u64,
    }

    public struct RemoveLiquidityEvent has copy, drop, store {
        pool: sui::object::ID,
        position: sui::object::ID,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        liquidity: u128,
        after_liquidity: u128,
        amount_a: u64,
        amount_b: u64,
    }

    public struct SwapEvent has copy, drop, store {
        atob: bool,
        pool: sui::object::ID,
        partner: sui::object::ID,
        amount_in: u64,
        amount_out: u64,
        magma_fee_amount: u64,
        protocol_fee_amount: u64,
        ref_fee_amount: u64,
        fee_amount: u64,
        vault_a_amount: u64,
        vault_b_amount: u64,
        before_sqrt_price: u128,
        after_sqrt_price: u128,
        steps: u64,
    }

    public struct CollectProtocolFeeEvent has copy, drop, store {
        pool: sui::object::ID,
        amount_a: u64,
        amount_b: u64,
    }

    public struct CollectFeeEvent has copy, drop, store {
        position: sui::object::ID,
        pool: sui::object::ID,
        amount_a: u64,
        amount_b: u64,
    }

    public struct UpdateFeeRateEvent has copy, drop, store {
        pool: sui::object::ID,
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    public struct UpdateEmissionEvent has copy, drop, store {
        pool: sui::object::ID,
        rewarder_type: std::type_name::TypeName,
        emissions_per_second: u128,
    }

    public struct AddRewarderEvent has copy, drop, store {
        pool: sui::object::ID,
        rewarder_type: std::type_name::TypeName,
    }

    public struct CollectRewardEvent has copy, drop, store {
        position: sui::object::ID,
        pool: sui::object::ID,
        amount: u64,
    }

    public struct CollectGaugeFeeEvent has copy, drop, store {
        pool: sui::object::ID,
        amount_a: u64,
        amount_b: u64,
    }

    public struct UpdateUnstakedLiquidityFeeRateEvent has copy, drop, store {
        pool: sui::object::ID,
        old_fee_rate: u64,
        new_fee_rate: u64,
    }
    public(package) fun new<CoinTypeA, CoinTypeB>(
        tick_spacing: u32,
        initial_sqrt_price: u128,
        fee_rate: u64,
        pool_url: std::string::String,
        pool_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): Pool<CoinTypeA, CoinTypeB> {
        let initial_pool_fee = PoolFee {
            coin_a: 0,
            coin_b: 0,
        };
        Pool<CoinTypeA, CoinTypeB> {
            id: sui::object::new(ctx),
            coin_a: sui::balance::zero<CoinTypeA>(),
            coin_b: sui::balance::zero<CoinTypeB>(),
            tick_spacing,
            fee_rate,
            liquidity: 0,
            current_sqrt_price: initial_sqrt_price,
            current_tick_index: clmm_pool::tick_math::get_tick_at_sqrt_price(initial_sqrt_price),
            fee_growth_global_a: 0,
            fee_growth_global_b: 0,
            fee_protocol_coin_a: 0,
            fee_protocol_coin_b: 0,
            tick_manager: clmm_pool::tick::new(tick_spacing, sui::clock::timestamp_ms(clock), ctx),
            rewarder_manager: clmm_pool::rewarder::new(),
            position_manager: clmm_pool::position::new(tick_spacing, ctx),
            is_pause: false,
            index: pool_index,
            url: pool_url,
            unstaked_liquidity_fee_rate: clmm_pool::config::default_unstaked_fee_rate(),
            magma_distribution_gauger_id: std::option::none<sui::object::ID>(),
            magma_distribution_growth_global: 0,
            magma_distribution_rate: 0,
            magma_distribution_reserve: 0,
            magma_distribution_period_finish: 0,
            magma_distribution_rollover: 0,
            magma_distribution_last_updated: sui::clock::timestamp_ms(clock) / 1000,
            magma_distribution_staked_liquidity: 0,
            magma_distribution_gauger_fee: initial_pool_fee,
        }
    }
    
    public fun get_amount_by_liquidity(
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        current_tick: integer_mate::i32::I32,
        current_sqrt_price: u128,
        liquidity: u128,
        round_up: bool
    ): (u64, u64) {
        if (liquidity == 0) {
            return (0, 0)
        };
        if (integer_mate::i32::lt(current_tick, tick_lower)) {
            (clmm_pool::clmm_math::get_delta_a(
                clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                liquidity,
                round_up
            ), 0)
        } else {
            let (amount_a, amount_b) = if (integer_mate::i32::lt(current_tick, tick_upper)) {
                (clmm_pool::clmm_math::get_delta_a(
                    current_sqrt_price,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    liquidity,
                    round_up
                ), clmm_pool::clmm_math::get_delta_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    current_sqrt_price,
                    liquidity,
                    round_up
                ))
            } else {
                (0, clmm_pool::clmm_math::get_delta_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    liquidity,
                    round_up
                ))
            };
            (amount_a, amount_b)
        }
    }
    public fun unstaked_liquidity_fee_rate<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
        pool.unstaked_liquidity_fee_rate
    }

    public fun borrow_position_info<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): &clmm_pool::position::PositionInfo {
        clmm_pool::position::borrow_position_info(&pool.position_manager, position_id)
    }

    public fun close_position<CoinTypeA, CoinTypeB>(
        config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: clmm_pool::position::Position
    ) {
        clmm_pool::config::checked_package_version(config);
        assert!(!pool.is_pause, 13);
        let position_id = sui::object::id<clmm_pool::position::Position>(&position);
        clmm_pool::position::close_position(&mut pool.position_manager, position);
        let event = ClosePositionEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            position: position_id,
        };
        sui::event::emit<ClosePositionEvent>(event);
    }
    public fun fetch_positions<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        position_ids: vector<sui::object::ID>,
        limit: u64
    ): vector<clmm_pool::position::PositionInfo> {
        clmm_pool::position::fetch_positions(&pool.position_manager, position_ids, limit)
    }

    public fun is_position_exist<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>, 
        position_id: sui::object::ID
    ): bool {
        clmm_pool::position::is_position_exist(&pool.position_manager, position_id)
    }

    public fun liquidity<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>
    ): u128 {
        pool.liquidity
    }

    public fun mark_position_staked<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap,
        position_id: sui::object::ID
    ) {
        assert!(!pool.is_pause, 13);
        check_gauge_cap<CoinTypeA, CoinTypeB>(pool, gauge_cap);
        clmm_pool::position::mark_position_staked(&mut pool.position_manager, position_id, true);
    }
    public fun open_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        ctx: &mut sui::tx_context::TxContext
    ): clmm_pool::position::Position {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let tick_lower_i32 = integer_mate::i32::from_u32(tick_lower);
        let tick_upper_i32 = integer_mate::i32::from_u32(tick_upper);
        let pool_id = sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool);
        let position = clmm_pool::position::open_position<CoinTypeA, CoinTypeB>(
            &mut pool.position_manager,
            pool_id,
            pool.index,
            pool.url,
            tick_lower_i32,
            tick_upper_i32,
            ctx
        );
        let event = OpenPositionEvent {
            pool: pool_id,
            tick_lower: tick_lower_i32,
            tick_upper: tick_upper_i32,
            position: sui::object::id<clmm_pool::position::Position>(&position),
        };
        sui::event::emit<OpenPositionEvent>(event);
        position
    }
    public fun update_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        rewarder_global_vault: &clmm_pool::rewarder::RewarderGlobalVault,
        emissions_per_second: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::config::check_rewarder_manager_role(global_config, sui::tx_context::sender(ctx));
        clmm_pool::rewarder::update_emission<RewardCoinType>(
            rewarder_global_vault,
            &mut pool.rewarder_manager,
            pool.liquidity,
            emissions_per_second,
            sui::clock::timestamp_ms(clock) / 1000
        );
        let event = UpdateEmissionEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            rewarder_type: std::type_name::get<RewardCoinType>(),
            emissions_per_second: emissions_per_second,
        };
        sui::event::emit<UpdateEmissionEvent>(event);
    }
    public fun borrow_tick<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_index: integer_mate::i32::I32
    ): &clmm_pool::tick::Tick {
        clmm_pool::tick::borrow_tick(&pool.tick_manager, tick_index)
    }

    public fun fetch_ticks<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>, 
        tick_indexes: vector<u32>,
        limit: u64
    ): vector<clmm_pool::tick::Tick> {
        clmm_pool::tick::fetch_ticks(&pool.tick_manager, tick_indexes, limit)
    }

    public fun index<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>
    ): u64 {
        pool.index
    }
    
    public fun add_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        delta_liquidity: u128,
        clock: &sui::clock::Clock
    ): AddLiquidityReceipt<CoinTypeA, CoinTypeB> {
        clmm_pool::config::checked_package_version(global_config);
        assert!(delta_liquidity != 0, 3);
        add_liquidity_internal<CoinTypeA, CoinTypeB>(
            pool,
            position,
            false,
            delta_liquidity,
            0,
            false,
            sui::clock::timestamp_ms(clock) / 1000
        )
    }
    public fun add_liquidity_fix_coin<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        amount_in: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock
    ): AddLiquidityReceipt<CoinTypeA, CoinTypeB> {
        clmm_pool::config::checked_package_version(global_config);
        assert!(amount_in > 0, 0);
        add_liquidity_internal<CoinTypeA, CoinTypeB>(
            pool,
            position,
            true,
            0,
            amount_in,
            fix_amount_a,
            sui::clock::timestamp_ms(clock) / 1000
        )
    }
    
    fun add_liquidity_internal<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        is_fix_amount: bool,
        liquidity_delta: u128,
        amount_in: u64,
        is_fix_amount_a: bool,
        timestamp: u64
    ): AddLiquidityReceipt<CoinTypeA, CoinTypeB> {
        assert!(!pool.is_pause, 13);
        validate_pool_position<CoinTypeA, CoinTypeB>(pool, position);
        clmm_pool::rewarder::settle(&mut pool.rewarder_manager, pool.liquidity, timestamp);

        let (tick_lower, tick_upper) = clmm_pool::position::tick_range(position);

        let (liquidity, amount_a, amount_b) = if (is_fix_amount) {
            let (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower,
                tick_upper,
                pool.current_tick_index,
                pool.current_sqrt_price,
                amount_in,
                is_fix_amount_a
            );
            (liquidity_calc, amount_a_calc, amount_b_calc)
        } else {
            let (amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
                tick_lower,
                tick_upper,
                pool.current_tick_index,
                pool.current_sqrt_price,
                liquidity_delta,
                true
            );
            (liquidity_delta, amount_a_calc, amount_b_calc)
        };

        let (fee_growth_a, fee_growth_b, rewards_growth, points_growth, magma_growth) = 
            get_all_growths_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);

        clmm_pool::tick::increase_liquidity(
            &mut pool.tick_manager,
            pool.current_tick_index,
            tick_lower,
            tick_upper,
            liquidity,
            pool.fee_growth_global_a,
            pool.fee_growth_global_b,
            clmm_pool::rewarder::points_growth_global(&pool.rewarder_manager),
            clmm_pool::rewarder::rewards_growth_global(&pool.rewarder_manager),
            pool.magma_distribution_growth_global
        );

        if (integer_mate::i32::gte(pool.current_tick_index, tick_lower) && 
            integer_mate::i32::lt(pool.current_tick_index, tick_upper)) {
            assert!(integer_mate::math_u128::add_check(pool.liquidity, liquidity), 1);
            pool.liquidity = pool.liquidity + liquidity;
        };

        let event = AddLiquidityEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            position: sui::object::id<clmm_pool::position::Position>(position),
            tick_lower,
            tick_upper,
            liquidity: liquidity_delta,
            after_liquidity: clmm_pool::position::increase_liquidity(
                &mut pool.position_manager,
                position,
                liquidity,
                fee_growth_a,
                fee_growth_b,
                points_growth,
                rewards_growth,
                magma_growth
            ),
            amount_a,
            amount_b,
        };

        sui::event::emit<AddLiquidityEvent>(event);

        AddLiquidityReceipt<CoinTypeA, CoinTypeB> {
            pool_id: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            amount_a,
            amount_b,
        }
    }

    public fun add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(receipt: &AddLiquidityReceipt<CoinTypeA, CoinTypeB>): (u64, u64) {
        (receipt.amount_a, receipt.amount_b)
    }

    fun apply_unstaked_fees(fee_amount: u128, total_amount: u128, unstaked_fee_rate: u64): (u128, u128) {
        let unstaked_fee = integer_mate::full_math_u128::mul_div_ceil(fee_amount, unstaked_fee_rate as u128, 10000);
        (fee_amount - unstaked_fee, total_amount + unstaked_fee)
    }

    public fun balances<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): (u64, u64) {
        (sui::balance::value<CoinTypeA>(&pool.coin_a), sui::balance::value<CoinTypeB>(&pool.coin_b))
    }
    public fun calculate_and_update_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): (u64, u64) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let position_info = clmm_pool::position::borrow_position_info(&pool.position_manager, position_id);
        if (clmm_pool::position::info_liquidity(position_info) != 0) {
            let (tick_lower, tick_upper) = clmm_pool::position::info_tick_range(position_info);
            let (fee_growth_a, fee_growth_b) = get_fee_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);
            let (fee_a, fee_b) = clmm_pool::position::update_fee(&mut pool.position_manager, position_id, fee_growth_a, fee_growth_b);
            (fee_a, fee_b)
        } else {
            let (fee_a, fee_b) = clmm_pool::position::info_fee_owned(position_info);
            (fee_a, fee_b)
        }
    }
    public fun calculate_and_update_magma_distribution<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): u64 {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let position_info = clmm_pool::position::borrow_position_info(&pool.position_manager, position_id);
        if (clmm_pool::position::info_liquidity(position_info) != 0) {
            let (tick_lower, tick_upper) = clmm_pool::position::info_tick_range(position_info);
            clmm_pool::position::update_magma_distribution(
                &mut pool.position_manager,
                position_id,
                clmm_pool::tick::get_magma_distribution_growth_in_range(
                    pool.current_tick_index,
                    pool.magma_distribution_growth_global,
                    clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower),
                    clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper)
                )
            )
        } else {
            clmm_pool::position::info_magma_distribution_owned(position_info)
        }
    }
    public fun calculate_and_update_points<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u128 {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::rewarder::settle(&mut pool.rewarder_manager, pool.liquidity, sui::clock::timestamp_ms(clock) / 1000);
        let position_info = clmm_pool::position::borrow_position_info(&pool.position_manager, position_id);
        if (clmm_pool::position::info_liquidity(position_info) != 0) {
            let (tick_lower, tick_upper) = clmm_pool::position::info_tick_range(position_info);
            let points = get_points_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);
            let position_manager = &mut pool.position_manager;
            clmm_pool::position::update_points(position_manager, position_id, points)
        } else {
            clmm_pool::position::info_points_owned(
                clmm_pool::position::borrow_position_info(&pool.position_manager, position_id)
            )
        }
    }
    public fun calculate_and_update_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u64 {
        let mut rewarder_idx = clmm_pool::rewarder::rewarder_index<RewardCoinType>(&pool.rewarder_manager);
        assert!(std::option::is_some<u64>(&rewarder_idx), 17);
        let rewards = calculate_and_update_rewards<CoinTypeA, CoinTypeB>(global_config, pool, position_id, clock);
        *std::vector::borrow<u64>(&rewards, std::option::extract<u64>(&mut rewarder_idx))
    }
    public fun calculate_and_update_rewards<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): vector<u64> {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::rewarder::settle(&mut pool.rewarder_manager, pool.liquidity, sui::clock::timestamp_ms(clock) / 1000);
        let position_info = clmm_pool::position::borrow_position_info(&pool.position_manager, position_id);
        if (clmm_pool::position::info_liquidity(position_info) != 0) {
            let (tick_lower, tick_upper) = clmm_pool::position::info_tick_range(position_info);
            let rewards = get_rewards_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);
            let position_manager = &mut pool.position_manager;
            clmm_pool::position::update_rewards(position_manager, position_id, rewards)
        } else {
            clmm_pool::position::rewards_amount_owned(&pool.position_manager, position_id)
        }
    }
    fun calculate_fees<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        fee_amount: u64,
        total_liquidity: u128,
        staked_liquidity: u128,
        unstaked_fee_rate: u64
    ): (u128, u64) {
        if (total_liquidity == pool.magma_distribution_staked_liquidity) {
            (0, fee_amount)
        } else {
            let (staked_fee, unstaked_fee) = if (staked_liquidity == 0) {
                let (unstaked_amount, unstaked_fee_amount) = apply_unstaked_fees(fee_amount as u128, 0, unstaked_fee_rate);
                (integer_mate::full_math_u128::mul_div_floor(unstaked_amount, 18446744073709551616, total_liquidity), unstaked_fee_amount as u64)
            } else {
                let (staked_amount, unstaked_fee_amount) = split_fees(fee_amount, total_liquidity, staked_liquidity, unstaked_fee_rate);
                (integer_mate::full_math_u128::mul_div_floor(staked_amount as u128, 18446744073709551616, total_liquidity - staked_liquidity), unstaked_fee_amount)
            };
            (staked_fee, unstaked_fee)
        }
    }
    public fun calculate_swap_result<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64
    ): CalculatedSwapResult {
        let mut current_sqrt_price = pool.current_sqrt_price;
        let mut current_liquidity = pool.liquidity;
        let mut staked_liquidity = pool.magma_distribution_staked_liquidity;
        let mut swap_result = default_swap_result();
        let mut remaining_amount = amount;
        let mut next_tick = clmm_pool::tick::first_score_for_swap(&pool.tick_manager, pool.current_tick_index, a2b);
        let mut calculated_result = CalculatedSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: pool.fee_rate,
            ref_fee_amount: 0,
            gauge_fee_amount: 0,
            protocol_fee_amount: 0,
            after_sqrt_price: pool.current_sqrt_price,
            is_exceed: false,
            step_results: std::vector::empty<SwapStepResult>(),
        };
        let unstaked_fee_rate = if (pool.unstaked_liquidity_fee_rate == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(global_config)
        } else {
            pool.unstaked_liquidity_fee_rate
        };
        while (remaining_amount > 0) {
            if (move_stl::option_u64::is_none(&next_tick)) {
                calculated_result.is_exceed = true;
                break
            };
            let (tick, next_tick_score) = clmm_pool::tick::borrow_tick_for_swap(
                &pool.tick_manager,
                move_stl::option_u64::borrow(&next_tick),
                a2b
            );
            next_tick = next_tick_score;
            let target_sqrt_price = clmm_pool::tick::sqrt_price(tick);
            let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_pool::clmm_math::compute_swap_step(
                current_sqrt_price,
                target_sqrt_price,
                current_liquidity,
                remaining_amount,
                pool.fee_rate,
                a2b,
                by_amount_in
            );
            if (amount_in != 0 || fee_amount != 0) {
                let new_remaining_amount = if (by_amount_in) {
                    let after_amount_in = check_remainer_amount_sub(remaining_amount, amount_in);
                    check_remainer_amount_sub(after_amount_in, fee_amount)
                } else {
                    check_remainer_amount_sub(remaining_amount, amount_out)
                };
                remaining_amount = new_remaining_amount;
                let protocol_fee = integer_mate::full_math_u64::mul_div_ceil(
                    fee_amount,
                    clmm_pool::config::protocol_fee_rate(global_config),
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let (_, gauge_fee) = calculate_fees<CoinTypeA, CoinTypeB>(
                    pool,
                    fee_amount - protocol_fee,
                    pool.liquidity,
                    pool.magma_distribution_staked_liquidity,
                    unstaked_fee_rate
                );
                update_swap_result(&mut swap_result, amount_in, amount_out, fee_amount, protocol_fee, 0, gauge_fee);
            };
            let step_result = SwapStepResult {
                current_sqrt_price,
                target_sqrt_price,
                current_liquidity,
                amount_in,
                amount_out,
                fee_amount,
                remainder_amount: remaining_amount,
            };
            std::vector::push_back<SwapStepResult>(&mut calculated_result.step_results, step_result);
            if (next_sqrt_price == target_sqrt_price) {
                current_sqrt_price = target_sqrt_price;
                let (liquidity_delta, staked_liquidity_delta) = if (a2b) {
                    (integer_mate::i128::neg(clmm_pool::tick::liquidity_net(tick)), integer_mate::i128::neg(
                        clmm_pool::tick::magma_distribution_staked_liquidity_net(tick)
                    ))
                } else {
                    (clmm_pool::tick::liquidity_net(tick), clmm_pool::tick::magma_distribution_staked_liquidity_net(tick))
                };
                let liquidity_abs = integer_mate::i128::abs_u128(liquidity_delta);
                let staked_liquidity_abs = integer_mate::i128::abs_u128(staked_liquidity_delta);
                if (!integer_mate::i128::is_neg(liquidity_delta)) {
                    assert!(integer_mate::math_u128::add_check(current_liquidity, liquidity_abs), 1);
                    current_liquidity = current_liquidity + liquidity_abs;
                } else {
                    assert!(current_liquidity >= liquidity_abs, 1);
                    current_liquidity = current_liquidity - liquidity_abs;
                };
                if (!integer_mate::i128::is_neg(staked_liquidity_delta)) {
                    assert!(integer_mate::math_u128::add_check(staked_liquidity, staked_liquidity_abs), 1);
                    staked_liquidity = staked_liquidity + staked_liquidity_abs;
                    continue
                };
                assert!(staked_liquidity >= staked_liquidity_abs, 1);
                staked_liquidity = staked_liquidity - staked_liquidity_abs;
                continue
            };
            current_sqrt_price = next_sqrt_price;
        };
        calculated_result.amount_in = swap_result.amount_in;
        calculated_result.amount_out = swap_result.amount_out;
        calculated_result.fee_amount = swap_result.fee_amount;
        calculated_result.gauge_fee_amount = swap_result.gauge_fee_amount;
        calculated_result.protocol_fee_amount = swap_result.protocol_fee_amount;
        calculated_result.after_sqrt_price = current_sqrt_price;
        calculated_result
    }
    public fun calculate_swap_result_step_results(calculated_swap_result: &CalculatedSwapResult): &vector<SwapStepResult> {
        &calculated_swap_result.step_results
    }
    public fun calculate_swap_result_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        ref_fee_rate: u64
    ): CalculatedSwapResult {
        let mut current_sqrt_price = pool.current_sqrt_price;
        let mut current_liquidity = pool.liquidity;
        let mut staked_liquidity = pool.magma_distribution_staked_liquidity;
        let mut swap_result = default_swap_result();
        let mut remaining_amount = amount;
        let mut next_tick = clmm_pool::tick::first_score_for_swap(&pool.tick_manager, pool.current_tick_index, a2b);
        let mut calculated_result = CalculatedSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: pool.fee_rate,
            ref_fee_amount: 0,
            gauge_fee_amount: 0,
            protocol_fee_amount: 0,
            after_sqrt_price: pool.current_sqrt_price,
            is_exceed: false,
            step_results: std::vector::empty<SwapStepResult>(),
        };
        let unstaked_fee_rate = if (pool.unstaked_liquidity_fee_rate == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(global_config)
        } else {
            pool.unstaked_liquidity_fee_rate
        };
        while (remaining_amount > 0) {
            if (move_stl::option_u64::is_none(&next_tick)) {
                calculated_result.is_exceed = true;
                break
            };
            let (tick, next_tick_score) = clmm_pool::tick::borrow_tick_for_swap(
                &pool.tick_manager,
                move_stl::option_u64::borrow(&next_tick),
                a2b
            );
            next_tick = next_tick_score;
            let target_sqrt_price = clmm_pool::tick::sqrt_price(tick);
            let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_pool::clmm_math::compute_swap_step(
                current_sqrt_price,
                target_sqrt_price,
                current_liquidity,
                remaining_amount,
                pool.fee_rate,
                a2b,
                by_amount_in
            );
            if (amount_in != 0 || fee_amount != 0) {
                let new_remaining_amount = if (by_amount_in) {
                    let amount_after_in = check_remainer_amount_sub(remaining_amount, amount_in);
                    check_remainer_amount_sub(amount_after_in, fee_amount)
                } else {
                    check_remainer_amount_sub(remaining_amount, amount_out)
                };
                remaining_amount = new_remaining_amount;
                let ref_fee = integer_mate::full_math_u64::mul_div_ceil(
                    fee_amount,
                    ref_fee_rate,
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let remaining_fee = fee_amount - ref_fee;
                let mut gauge_fee = 0;
                let mut protocol_fee = 0;
                if (remaining_fee > 0) {
                    let protocol_fee_amount = integer_mate::full_math_u64::mul_div_ceil(
                        remaining_fee,
                        clmm_pool::config::protocol_fee_rate(global_config),
                        clmm_pool::config::protocol_fee_rate_denom()
                    );
                    protocol_fee = protocol_fee_amount;
                    let fee_after_protocol = remaining_fee - protocol_fee_amount;
                    if (fee_after_protocol > 0) {
                        let (_, gauge_fee_amount) = calculate_fees<CoinTypeA, CoinTypeB>(
                            pool,
                            fee_after_protocol,
                            pool.liquidity,
                            pool.magma_distribution_staked_liquidity,
                            unstaked_fee_rate
                        );
                        gauge_fee = gauge_fee_amount;
                    };
                };
                update_swap_result(&mut swap_result, amount_in, amount_out, fee_amount, protocol_fee, ref_fee, gauge_fee);
            };
            let step_result = SwapStepResult {
                current_sqrt_price,
                target_sqrt_price,
                current_liquidity,
                amount_in,
                amount_out,
                fee_amount,
                remainder_amount: remaining_amount,
            };
            std::vector::push_back<SwapStepResult>(&mut calculated_result.step_results, step_result);
            if (next_sqrt_price == target_sqrt_price) {
                current_sqrt_price = target_sqrt_price;
                let (liquidity_delta, staked_liquidity_delta) = if (a2b) {
                    (integer_mate::i128::neg(clmm_pool::tick::liquidity_net(tick)), integer_mate::i128::neg(
                        clmm_pool::tick::magma_distribution_staked_liquidity_net(tick)
                    ))
                } else {
                    (clmm_pool::tick::liquidity_net(tick), clmm_pool::tick::magma_distribution_staked_liquidity_net(tick))
                };
                let liquidity_abs = integer_mate::i128::abs_u128(liquidity_delta);
                let staked_liquidity_abs = integer_mate::i128::abs_u128(staked_liquidity_delta);
                if (!integer_mate::i128::is_neg(liquidity_delta)) {
                    assert!(integer_mate::math_u128::add_check(current_liquidity, liquidity_abs), 1);
                    current_liquidity = current_liquidity + liquidity_abs;
                } else {
                    assert!(current_liquidity >= liquidity_abs, 1);
                    current_liquidity = current_liquidity - liquidity_abs;
                };
                if (!integer_mate::i128::is_neg(staked_liquidity_delta)) {
                    assert!(integer_mate::math_u128::add_check(staked_liquidity, staked_liquidity_abs), 1);
                    staked_liquidity = staked_liquidity + staked_liquidity_abs;
                    continue
                };
                assert!(staked_liquidity >= staked_liquidity_abs, 1);
                staked_liquidity = staked_liquidity - staked_liquidity_abs;
                continue
            };
            current_sqrt_price = next_sqrt_price;
        };
        calculated_result.amount_in = swap_result.amount_in;
        calculated_result.amount_out = swap_result.amount_out;
        calculated_result.fee_amount = swap_result.fee_amount;
        calculated_result.gauge_fee_amount = swap_result.gauge_fee_amount;
        calculated_result.protocol_fee_amount = swap_result.protocol_fee_amount;
        calculated_result.ref_fee_amount = swap_result.ref_fee_amount;
        calculated_result.after_sqrt_price = current_sqrt_price;
        calculated_result
    }
    public fun calculated_swap_result_after_sqrt_price(swap_result: &CalculatedSwapResult): u128 {
        swap_result.after_sqrt_price
    }

    public fun calculated_swap_result_amount_in(swap_result: &CalculatedSwapResult): u64 {
        swap_result.amount_in
    }

    public fun calculated_swap_result_amount_out(swap_result: &CalculatedSwapResult): u64 {
        swap_result.amount_out
    }

    public fun calculated_swap_result_fees_amount(swap_result: &CalculatedSwapResult): (u64, u64, u64, u64) {
        (swap_result.fee_amount, swap_result.ref_fee_amount, swap_result.protocol_fee_amount, swap_result.gauge_fee_amount)
    }

    public fun calculated_swap_result_is_exceed(swap_result: &CalculatedSwapResult): bool {
        swap_result.is_exceed
    }

    public fun calculated_swap_result_step_swap_result(swap_result: &CalculatedSwapResult, step_index: u64): &SwapStepResult {
        std::vector::borrow<SwapStepResult>(&swap_result.step_results, step_index)
    }

    public fun calculated_swap_result_steps_length(swap_result: &CalculatedSwapResult): u64 {
        std::vector::length<SwapStepResult>(&swap_result.step_results)
    }
    fun check_gauge_cap<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>, 
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap
    ) {
        let is_valid = if (gauge_cap::gauge_cap::get_pool_id(gauge_cap) == sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool)) {
            let gauger_id = &pool.magma_distribution_gauger_id;
            let has_valid_gauge = if (std::option::is_some<sui::object::ID>(gauger_id)) {
                let cap_gauge_id = gauge_cap::gauge_cap::get_gauge_id(gauge_cap);
                std::option::borrow<sui::object::ID>(gauger_id) == &cap_gauge_id
            } else {
                false
            };
            has_valid_gauge
        } else {
            false
        };
        assert!(is_valid, 9223379355479048191);
    }

    fun check_remainer_amount_sub(amount: u64, sub_amount: u64): u64 {
        assert!(amount >= sub_amount, 5);
        amount - sub_amount
    }
    fun check_tick_range(tick_lower: integer_mate::i32::I32, tick_upper: integer_mate::i32::I32): bool {
        let is_invalid = if (integer_mate::i32::gte(tick_lower, tick_upper)) {
            true
        } else {
            if (integer_mate::i32::lt(tick_lower, clmm_pool::tick_math::min_tick())) {
                true
            } else {
                integer_mate::i32::gt(tick_upper, clmm_pool::tick_math::max_tick())
            }
        };
        if (is_invalid) {
            return false
        };
        true
    }
    
    public fun collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &clmm_pool::position::Position,
        update_fee: bool
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let position_id = sui::object::id<clmm_pool::position::Position>(position);
        if (clmm_pool::position::is_staked(borrow_position_info<CoinTypeA, CoinTypeB>(pool, position_id))) {
            return (sui::balance::zero<CoinTypeA>(), sui::balance::zero<CoinTypeB>())
        };
        let (tick_lower, tick_upper) = clmm_pool::position::tick_range(position);
        let (fee_amount_a, fee_amount_b) = if (update_fee && clmm_pool::position::liquidity(position) != 0) {
            let (fee_growth_a, fee_growth_b) = get_fee_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);
            let (amount_a, amount_b) = clmm_pool::position::update_and_reset_fee(&mut pool.position_manager, position_id, fee_growth_a, fee_growth_b);
            (amount_a, amount_b)
        } else {
            let (amount_a, amount_b) = clmm_pool::position::reset_fee(&mut pool.position_manager, position_id);
            (amount_a, amount_b)
        };
        let collect_fee_event = CollectFeeEvent {
            position: position_id,
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            amount_a: fee_amount_a,
            amount_b: fee_amount_b,
        };
        sui::event::emit<CollectFeeEvent>(collect_fee_event);
        (sui::balance::split<CoinTypeA>(&mut pool.coin_a, fee_amount_a), sui::balance::split<CoinTypeB>(&mut pool.coin_b, fee_amount_b))
    }
    
    public fun collect_magma_distribution_gauger_fees<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        assert!(!pool.is_pause, 13);
        check_gauge_cap<CoinTypeA, CoinTypeB>(pool, gauge_cap);
        let mut balance_a = sui::balance::zero<CoinTypeA>();
        let mut balance_b = sui::balance::zero<CoinTypeB>();
        
        if (pool.magma_distribution_gauger_fee.coin_a > 0) {
            sui::balance::join<CoinTypeA>(
                &mut balance_a,
                sui::balance::split<CoinTypeA>(&mut pool.coin_a, pool.magma_distribution_gauger_fee.coin_a)
            );
            pool.magma_distribution_gauger_fee.coin_a = 0;
        };

        if (pool.magma_distribution_gauger_fee.coin_b > 0) {
            sui::balance::join<CoinTypeB>(
                &mut balance_b,
                sui::balance::split<CoinTypeB>(&mut pool.coin_b, pool.magma_distribution_gauger_fee.coin_b)
            );
            pool.magma_distribution_gauger_fee.coin_b = 0;
        };

        let event = CollectGaugeFeeEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            amount_a: sui::balance::value<CoinTypeA>(&balance_a),
            amount_b: sui::balance::value<CoinTypeB>(&balance_b),
        };
        sui::event::emit<CollectGaugeFeeEvent>(event);
        (balance_a, balance_b)
    }
    
    public fun collect_protocol_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>, 
        ctx: &mut sui::tx_context::TxContext
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::config::check_protocol_fee_claim_role(global_config, sui::tx_context::sender(ctx));
        
        let fee_amount_a = pool.fee_protocol_coin_a;
        let fee_amount_b = pool.fee_protocol_coin_b;
        pool.fee_protocol_coin_a = 0;
        pool.fee_protocol_coin_b = 0;

        let event = CollectProtocolFeeEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            amount_a: fee_amount_a,
            amount_b: fee_amount_b,
        };
        sui::event::emit<CollectProtocolFeeEvent>(event);
        
        (sui::balance::split<CoinTypeA>(&mut pool.coin_a, fee_amount_a), 
         sui::balance::split<CoinTypeB>(&mut pool.coin_b, fee_amount_b))
    }
    public fun collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &clmm_pool::position::Position,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        update_rewards: bool,
        clock: &sui::clock::Clock
    ): sui::balance::Balance<RewardCoinType> {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::rewarder::settle(&mut pool.rewarder_manager, pool.liquidity, sui::clock::timestamp_ms(clock) / 1000);
        let position_id = sui::object::id<clmm_pool::position::Position>(position);
        let mut rewarder_idx = clmm_pool::rewarder::rewarder_index<RewardCoinType>(&pool.rewarder_manager);
        assert!(std::option::is_some<u64>(&rewarder_idx), 17);
        let rewarder_index = std::option::extract<u64>(&mut rewarder_idx);
        let reward_amount = if (update_rewards && clmm_pool::position::liquidity(position) != 0 || clmm_pool::position::inited_rewards_count(
            &pool.position_manager,
            position_id
        ) <= rewarder_index) {
            let (tick_lower, tick_upper) = clmm_pool::position::tick_range(position);
            let rewards = get_rewards_in_tick_range<CoinTypeA, CoinTypeB>(pool, tick_lower, tick_upper);
            let position_manager = &mut pool.position_manager;
            clmm_pool::position::update_and_reset_rewards(position_manager, position_id, rewards, rewarder_index)
        } else {
            clmm_pool::position::reset_rewarder(&mut pool.position_manager, position_id, rewarder_index)
        };
        let event = CollectRewardEvent {
            position: position_id,
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            amount: reward_amount,
        };
        sui::event::emit<CollectRewardEvent>(event);
        clmm_pool::rewarder::withdraw_reward<RewardCoinType>(rewarder_vault, reward_amount)
    }
    
    public fun current_sqrt_price<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u128 {
        pool.current_sqrt_price
    }

    public fun current_tick_index<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): integer_mate::i32::I32 {
        pool.current_tick_index
    }

    fun default_swap_result(): SwapResult {
        SwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            protocol_fee_amount: 0,
            ref_fee_amount: 0,
            gauge_fee_amount: 0,
            steps: 0,
        }
    }
    public fun fee_rate<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
        pool.fee_rate
    }

    public fun fees_amount<CoinTypeA, CoinTypeB>(receipt: &FlashSwapReceipt<CoinTypeA, CoinTypeB>): (u64, u64, u64, u64) {
        (receipt.fee_amount, receipt.ref_fee_amount, receipt.protocol_fee_amount, receipt.gauge_fee_amount)
    }

    public fun fees_growth_global<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): (u128, u128) {
        (pool.fee_growth_global_a, pool.fee_growth_global_b)
    }
    public fun flash_swap<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        flash_swap_internal<CoinTypeA, CoinTypeB>(
            pool,
            global_config,
            sui::object::id_from_address(@0x0),
            0,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        )
    }
    fun flash_swap_internal<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        global_config: &clmm_pool::config::GlobalConfig,
        partner_id: sui::object::ID,
        ref_fee_rate: u64,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
        assert!(amount > 0, 0);
        clmm_pool::rewarder::settle(&mut pool.rewarder_manager, pool.liquidity, sui::clock::timestamp_ms(clock) / 1000);
        if (a2b) {
            assert!(pool.current_sqrt_price > sqrt_price_limit && sqrt_price_limit >= clmm_pool::tick_math::min_sqrt_price(), 11);
        } else {
            assert!(pool.current_sqrt_price < sqrt_price_limit && sqrt_price_limit <= clmm_pool::tick_math::max_sqrt_price(), 11);
        };
        let unstaked_fee_rate = pool.unstaked_liquidity_fee_rate;
        let final_unstaked_fee_rate = if (unstaked_fee_rate == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(global_config)
        } else {
            unstaked_fee_rate
        };
        let swap_result = swap_in_pool<CoinTypeA, CoinTypeB>(
            pool,
            a2b,
            by_amount_in,
            sqrt_price_limit,
            amount,
            final_unstaked_fee_rate,
            clmm_pool::config::protocol_fee_rate(global_config),
            ref_fee_rate,
            clock
        );
        assert!(swap_result.amount_out > 0, 18);
        let (balance_b, balance_a) = if (a2b) {
            (sui::balance::split<CoinTypeB>(&mut pool.coin_b, swap_result.amount_out), sui::balance::zero<CoinTypeA>())
        } else {
            (sui::balance::zero<CoinTypeB>(), sui::balance::split<CoinTypeA>(&mut pool.coin_a, swap_result.amount_out))
        };
        let swap_event = SwapEvent {
            atob: a2b,
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            partner: partner_id,
            amount_in: swap_result.amount_in + swap_result.fee_amount,
            amount_out: swap_result.amount_out,
            magma_fee_amount: swap_result.gauge_fee_amount,
            protocol_fee_amount: swap_result.protocol_fee_amount,
            ref_fee_amount: swap_result.ref_fee_amount,
            fee_amount: swap_result.fee_amount,
            vault_a_amount: sui::balance::value<CoinTypeA>(&pool.coin_a),
            vault_b_amount: sui::balance::value<CoinTypeB>(&pool.coin_b),
            before_sqrt_price: pool.current_sqrt_price,
            after_sqrt_price: pool.current_sqrt_price,
            steps: swap_result.steps,
        };
        sui::event::emit<SwapEvent>(swap_event);
        let receipt = FlashSwapReceipt<CoinTypeA, CoinTypeB> {
            pool_id: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            a2b: a2b,
            partner_id: partner_id,
            pay_amount: swap_result.amount_in + swap_result.fee_amount,
            fee_amount: swap_result.fee_amount,
            protocol_fee_amount: swap_result.protocol_fee_amount,
            ref_fee_amount: swap_result.ref_fee_amount,
            gauge_fee_amount: swap_result.gauge_fee_amount,
        };
        (balance_a, balance_b, receipt)
    }

    public fun flash_swap_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        partner: &clmm_pool::partner::Partner,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        flash_swap_internal<CoinTypeA, CoinTypeB>(
            pool,
            global_config,
            sui::object::id<clmm_pool::partner::Partner>(partner),
            clmm_pool::partner::current_ref_fee_rate(partner, sui::clock::timestamp_ms(clock) / 1000),
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        )
    }
    public fun get_all_growths_in_tick_range<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32
    ): (u128, u128, vector<u128>, u128, u128) {
        let tick_lower_info = clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower);
        let tick_upper_info = clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper);
        let (fee_growth_a, fee_growth_b) = clmm_pool::tick::get_fee_in_range(
            pool.current_tick_index,
            pool.fee_growth_global_a,
            pool.fee_growth_global_b,
            tick_lower_info,
            tick_upper_info
        );
        (
            fee_growth_a,
            fee_growth_b,
            clmm_pool::tick::get_rewards_in_range(
                pool.current_tick_index,
                clmm_pool::rewarder::rewards_growth_global(&pool.rewarder_manager),
                tick_lower_info,
                tick_upper_info
            ),
            clmm_pool::tick::get_points_in_range(
                pool.current_tick_index,
                clmm_pool::rewarder::points_growth_global(&pool.rewarder_manager),
                tick_lower_info,
                tick_upper_info
            ),
            clmm_pool::tick::get_magma_distribution_growth_in_range(
                pool.current_tick_index,
                pool.magma_distribution_growth_global,
                tick_lower_info,
                tick_upper_info
            )
        )
    }
    public fun get_fee_in_tick_range<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32
    ): (u128, u128) {
        clmm_pool::tick::get_fee_in_range(
            pool.current_tick_index,
            pool.fee_growth_global_a,
            pool.fee_growth_global_b,
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower),
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper)
        )
    }
    public fun get_liquidity_from_amount(
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        current_tick: integer_mate::i32::I32,
        current_sqrt_price: u128,
        amount: u64,
        a2b: bool
    ): (u128, u64, u64) {
        if (a2b) {
            let (liquidity_a, amount_b) = if (integer_mate::i32::lt(current_tick, tick_lower)) {
                (clmm_pool::clmm_math::get_liquidity_from_a(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    amount,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::lt(current_tick, tick_upper), 19);
                let liquidity_current = clmm_pool::clmm_math::get_liquidity_from_a(
                    current_sqrt_price,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    amount,
                    false
                );
                (liquidity_current, clmm_pool::clmm_math::get_delta_b(
                    current_sqrt_price,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    liquidity_current,
                    true
                ))
            };
            (liquidity_a, amount, amount_b)
        } else {
            let (liquidity_b, amount_a) = if (integer_mate::i32::gte(current_tick, tick_upper)) {
                (clmm_pool::clmm_math::get_liquidity_from_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    amount,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::gte(current_tick, tick_lower), 19);
                let liquidity_current = clmm_pool::clmm_math::get_liquidity_from_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    current_sqrt_price,
                    amount,
                    false
                );
                (liquidity_current, clmm_pool::clmm_math::get_delta_a(
                    current_sqrt_price,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    liquidity_current,
                    true
                ))
            };
            (liquidity_b, amount_a, amount)
        }
    }
    public fun get_magma_distribution_gauger_id<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): sui::object::ID {
        assert!(std::option::is_some<sui::object::ID>(&pool.magma_distribution_gauger_id), 9223379295349506047);
        *std::option::borrow<sui::object::ID>(&pool.magma_distribution_gauger_id)
    }

    public fun get_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u128 {
        pool.magma_distribution_growth_global
    }
    public fun get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        mut growth_global: u128
    ): u128 {
        assert!(check_tick_range(tick_lower, tick_upper), 9223378947457155071);
        if (growth_global == 0) {
            growth_global = pool.magma_distribution_growth_global;
        };
        clmm_pool::tick::get_magma_distribution_growth_in_range(
            pool.current_tick_index,
            growth_global,
            std::option::some<clmm_pool::tick::Tick>(*borrow_tick<CoinTypeA, CoinTypeB>(pool, tick_lower)),
            std::option::some<clmm_pool::tick::Tick>(*borrow_tick<CoinTypeA, CoinTypeB>(pool, tick_upper))
        )
    }
    public fun get_magma_distribution_last_updated<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
        pool.magma_distribution_last_updated
    }

    public fun get_magma_distribution_reserve<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
        pool.magma_distribution_reserve
    }

    public fun get_magma_distribution_rollover<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u64 {
        pool.magma_distribution_rollover
    }

    public fun get_magma_distribution_staked_liquidity<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u128 {
        pool.magma_distribution_staked_liquidity
    }

    public fun get_points_in_tick_range<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32
    ): u128 {
        clmm_pool::tick::get_points_in_range(
            pool.current_tick_index,
            clmm_pool::rewarder::points_growth_global(&pool.rewarder_manager),
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower),
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper)
        )
    }

    public fun get_position_amounts<CoinTypeA, CoinTypeB>(
        pool_state: &mut Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): (u64, u64) {
        let current_position = clmm_pool::position::borrow_position_info(&pool_state.position_manager, position_id);
        let (tick_lower, tick_upper) = clmm_pool::position::info_tick_range(current_position);
        get_amount_by_liquidity(
            tick_lower,
            tick_upper, 
            pool_state.current_tick_index,
            pool_state.current_sqrt_price,
            clmm_pool::position::info_liquidity(current_position),
            false
        )
    }
    public fun get_position_fee<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): (u64, u64) {
        clmm_pool::position::info_fee_owned(
            clmm_pool::position::borrow_position_info(&pool.position_manager, position_id)
        )
    }

    public fun get_position_points<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>, 
        position_id: sui::object::ID
    ): u128 {
        clmm_pool::position::info_points_owned(
            clmm_pool::position::borrow_position_info(&pool.position_manager, position_id)
        )
    }
    
    public fun get_position_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID
    ): u64 {
        let mut rewarder_idx = clmm_pool::rewarder::rewarder_index<RewardCoinType>(&pool.rewarder_manager);
        assert!(std::option::is_some<u64>(&rewarder_idx), 17);
        let rewards = clmm_pool::position::rewards_amount_owned(&pool.position_manager, position_id);
        *std::vector::borrow<u64>(&rewards, std::option::extract<u64>(&mut rewarder_idx))
    }

    public fun get_position_rewards<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>, 
        position_id: sui::object::ID
    ): vector<u64> {
        clmm_pool::position::rewards_amount_owned(&pool.position_manager, position_id)
    }

    public fun get_rewards_in_tick_range<CoinTypeA, CoinTypeB>(
        pool: &Pool<CoinTypeA, CoinTypeB>,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32
    ): vector<u128> {
        clmm_pool::tick::get_rewards_in_range(
            pool.current_tick_index,
            clmm_pool::rewarder::rewards_growth_global(&pool.rewarder_manager),
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower),
            clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper)
        )
    }

    fun init(pool: POOL, ctx: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer<sui::package::Publisher>(
            sui::package::claim<POOL>(pool, ctx),
            sui::tx_context::sender(ctx)
        );
    }
    public fun init_magma_distribution_gauge<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap
    ) {
        assert!(
            gauge_cap::gauge_cap::get_pool_id(gauge_cap) == sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            9223379334004211711
        );
        std::option::fill<sui::object::ID>(
            &mut pool.magma_distribution_gauger_id,
            gauge_cap::gauge_cap::get_gauge_id(gauge_cap)
        );
    }

    public fun initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::config::check_rewarder_manager_role(global_config, sui::tx_context::sender(ctx));
        clmm_pool::rewarder::add_rewarder<RewardCoinType>(&mut pool.rewarder_manager);
        let event = AddRewarderEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            rewarder_type: std::type_name::get<RewardCoinType>(),
        };
        sui::event::emit<AddRewarderEvent>(event);
    }

    public fun is_pause<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): bool {
        pool.is_pause
    }

    public fun magma_distribution_gauger_fee<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): PoolFee {
        PoolFee {
            coin_a: pool.magma_distribution_gauger_fee.coin_a,
            coin_b: pool.magma_distribution_gauger_fee.coin_b,
        }
    }

    public fun mark_position_unstaked<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap,
        position_id: sui::object::ID
    ) {
        assert!(!pool.is_pause, 13);
        check_gauge_cap<CoinTypeA, CoinTypeB>(pool, gauge_cap);
        clmm_pool::position::mark_position_staked(&mut pool.position_manager, position_id, false);
    }

    public fun pause<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        clmm_pool::config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(!pool.is_pause, 9223376739843964927);
        pool.is_pause = true;
    }

    public fun pool_fee_a_b(pool_fee: &PoolFee): (u64, u64) {
        (pool_fee.coin_a, pool_fee.coin_b)
    }

    public fun position_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &clmm_pool::position::PositionManager {
        &pool.position_manager
    }

    public fun protocol_fee<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): (u64, u64) {
        (pool.fee_protocol_coin_a, pool.fee_protocol_coin_b)
    }
    
    public fun remove_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        clock: &sui::clock::Clock
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        assert!(liquidity > 0, 3);
        
        clmm_pool::rewarder::settle(
            &mut pool.rewarder_manager, 
            pool.liquidity, 
            sui::clock::timestamp_ms(clock) / 1000
        );

        let (tick_lower, tick_upper) = clmm_pool::position::tick_range(position);
        
        let (
            fee_growth_a,
            fee_growth_b,
            rewards_growth,
            points_growth,
            magma_growth,
        ) = get_all_growths_in_tick_range<CoinTypeA, CoinTypeB>(
            pool,
            tick_lower,
            tick_upper
        );

        clmm_pool::tick::decrease_liquidity(
            &mut pool.tick_manager,
            pool.current_tick_index,
            tick_lower,
            tick_upper,
            liquidity,
            pool.fee_growth_global_a,
            pool.fee_growth_global_b,
            clmm_pool::rewarder::points_growth_global(&pool.rewarder_manager),
            clmm_pool::rewarder::rewards_growth_global(&pool.rewarder_manager),
            pool.magma_distribution_growth_global
        );

        if (integer_mate::i32::lte(tick_lower, pool.current_tick_index) && 
            integer_mate::i32::lt(pool.current_tick_index, tick_upper)) {
            pool.liquidity = pool.liquidity - liquidity;
        };

        let (amount_a, amount_b) = get_amount_by_liquidity(
            tick_lower,
            tick_upper,
            pool.current_tick_index,
            pool.current_sqrt_price,
            liquidity,
            false
        );

        let event = RemoveLiquidityEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            position: sui::object::id<clmm_pool::position::Position>(position),
            tick_lower,
            tick_upper,
            liquidity,
            after_liquidity: clmm_pool::position::decrease_liquidity(
                &mut pool.position_manager,
                position,
                liquidity,
                fee_growth_a,
                fee_growth_b,
                points_growth,
                rewards_growth,
                magma_growth
            ),
            amount_a,
            amount_b,
        };

        sui::event::emit<RemoveLiquidityEvent>(event);

        (
            sui::balance::split<CoinTypeA>(&mut pool.coin_a, amount_a),
            sui::balance::split<CoinTypeB>(&mut pool.coin_b, amount_b)
        )
    }
    public fun repay_add_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        balance_a: sui::balance::Balance<CoinTypeA>,
        balance_b: sui::balance::Balance<CoinTypeB>,
        receipt: AddLiquidityReceipt<CoinTypeA, CoinTypeB>
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let AddLiquidityReceipt {
            pool_id,
            amount_a,
            amount_b,
        } = receipt;
        assert!(sui::balance::value<CoinTypeA>(&balance_a) == amount_a, 0);
        assert!(sui::balance::value<CoinTypeB>(&balance_b) == amount_b, 0);
        assert!(sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool) == pool_id, 12);
        sui::balance::join<CoinTypeA>(&mut pool.coin_a, balance_a);
        sui::balance::join<CoinTypeB>(&mut pool.coin_b, balance_b);
    }

    public fun repay_flash_swap<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        balance_a: sui::balance::Balance<CoinTypeA>,
        balance_b: sui::balance::Balance<CoinTypeB>,
        receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let FlashSwapReceipt {
            pool_id,
            a2b,
            partner_id: _,
            pay_amount,
            fee_amount: _,
            protocol_fee_amount: _,
            ref_fee_amount,
            gauge_fee_amount: _,
        } = receipt;
        assert!(sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool) == pool_id, 14);
        assert!(ref_fee_amount == 0, 14);
        if (a2b) {
            assert!(sui::balance::value<CoinTypeA>(&balance_a) == pay_amount, 0);
            sui::balance::join<CoinTypeA>(&mut pool.coin_a, balance_a);
            sui::balance::destroy_zero<CoinTypeB>(balance_b);
        } else {
            assert!(sui::balance::value<CoinTypeB>(&balance_b) == pay_amount, 0);
            sui::balance::join<CoinTypeB>(&mut pool.coin_b, balance_b);
            sui::balance::destroy_zero<CoinTypeA>(balance_a);
        };
    }
    public fun repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        partner: &mut clmm_pool::partner::Partner,
        mut balance_a: sui::balance::Balance<CoinTypeA>,
        mut balance_b: sui::balance::Balance<CoinTypeB>,
        receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let FlashSwapReceipt {
            pool_id: pool_id,
            a2b: a2b,
            partner_id: partner_id,
            pay_amount: pay_amount,
            fee_amount: _,
            protocol_fee_amount: _,
            ref_fee_amount: ref_fee_amount,
            gauge_fee_amount: _,
        } = receipt;
        assert!(sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool) == pool_id, 14);
        assert!(sui::object::id<clmm_pool::partner::Partner>(partner) == partner_id, 14);
        if (a2b) {
            assert!(sui::balance::value<CoinTypeA>(&balance_a) == pay_amount, 0);
            if (ref_fee_amount > 0) {
                clmm_pool::partner::receive_ref_fee<CoinTypeA>(partner, sui::balance::split<CoinTypeA>(&mut balance_a, ref_fee_amount));
            };
            sui::balance::join<CoinTypeA>(&mut pool.coin_a, balance_a);
            sui::balance::destroy_zero<CoinTypeB>(balance_b);
        } else {
            assert!(sui::balance::value<CoinTypeB>(&balance_b) == pay_amount, 0);
            if (ref_fee_amount > 0) {
                clmm_pool::partner::receive_ref_fee<CoinTypeB>(partner, sui::balance::split<CoinTypeB>(&mut balance_b, ref_fee_amount));
            };
            sui::balance::join<CoinTypeB>(&mut pool.coin_b, balance_b);
            sui::balance::destroy_zero<CoinTypeA>(balance_a);
        };
    }

    public fun rewarder_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &clmm_pool::rewarder::RewarderManager {
        &pool.rewarder_manager
    }
    public fun set_display<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        publisher: &sui::package::Publisher,
        name: std::string::String,
        description: std::string::String,
        image_url: std::string::String,
        link: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let mut keys = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"name"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"coin_a"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"coin_b"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"link"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"image_url"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"description"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"project_url"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"creator"));
        let mut values = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut values, name);
        std::vector::push_back<std::string::String>(
            &mut values,
            std::string::from_ascii(std::type_name::into_string(std::type_name::get<CoinTypeA>()))
        );
        std::vector::push_back<std::string::String>(
            &mut values,
            std::string::from_ascii(std::type_name::into_string(std::type_name::get<CoinTypeB>()))
        );
        std::vector::push_back<std::string::String>(&mut values, link);
        std::vector::push_back<std::string::String>(&mut values, image_url);
        std::vector::push_back<std::string::String>(&mut values, description);
        std::vector::push_back<std::string::String>(&mut values, project_url);
        std::vector::push_back<std::string::String>(&mut values, creator);
        let mut display = sui::display::new_with_fields<Pool<CoinTypeA, CoinTypeB>>(publisher, keys, values, ctx);
        sui::display::update_version<Pool<CoinTypeA, CoinTypeB>>(&mut display);
        sui::transfer::public_transfer<sui::display::Display<Pool<CoinTypeA, CoinTypeB>>>(display, sui::tx_context::sender(ctx));
    }
    fun split_fees(
        fee_amount: u64,
        total_growth: u128,
        growth_inside: u128,
        unstaked_fee_rate: u64
    ): (u64, u64) {
        let inside_amount = integer_mate::full_math_u128::mul_div_ceil(
            fee_amount as u128,
            growth_inside,
            total_growth
        );
        let (staked_amount, unstaked_amount) = apply_unstaked_fees(
            (fee_amount as u128) - inside_amount,
            inside_amount,
            unstaked_fee_rate
        );
        (staked_amount as u64, unstaked_amount as u64)
    }

    public fun stake_in_magma_distribution<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        gauge_cap: &gauge_cap::gauge_cap::GaugeCap, 
        liquidity: u128,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        clock: &sui::clock::Clock
    ) {
        assert!(!pool.is_pause, 13);
        assert!(liquidity != 0, 9223379140730683391);
        check_gauge_cap<CoinTypeA, CoinTypeB>(pool, gauge_cap);
        update_magma_distribution_internal<CoinTypeA, CoinTypeB>(
            pool,
            integer_mate::i128::from(liquidity),
            tick_lower,
            tick_upper,
            clock
        );
    }
    public fun step_swap_result_amount_in(result: &SwapStepResult): u64 {
        result.amount_in
    }

    public fun step_swap_result_amount_out(result: &SwapStepResult): u64 {
        result.amount_out
    }

    public fun step_swap_result_current_liquidity(result: &SwapStepResult): u128 {
        result.current_liquidity
    }

    public fun step_swap_result_current_sqrt_price(result: &SwapStepResult): u128 {
        result.current_sqrt_price
    }

    public fun step_swap_result_fee_amount(result: &SwapStepResult): u64 {
        result.fee_amount
    }

    public fun step_swap_result_remainder_amount(result: &SwapStepResult): u64 {
        result.remainder_amount
    }

    public fun step_swap_result_target_sqrt_price(result: &SwapStepResult): u128 {
        result.target_sqrt_price
    }
    fun swap_in_pool<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        sqrt_price_limit: u128,
        amount: u64,
        unstaked_fee_rate: u64,
        protocol_fee_rate: u64,
        ref_fee_rate: u64,
        clock: &sui::clock::Clock
    ): SwapResult {
        assert!(ref_fee_rate <= 10000, 16);
        let mut swap_result = default_swap_result();
        let mut remaining_amount = amount;
        let mut next_tick_score = clmm_pool::tick::first_score_for_swap(&pool.tick_manager, pool.current_tick_index, a2b);
        while (remaining_amount > 0 && pool.current_sqrt_price != sqrt_price_limit) {
            if (move_stl::option_u64::is_none(&next_tick_score)) {
                abort 20
            };
            let (tick_info, next_score) = clmm_pool::tick::borrow_tick_for_swap(
                &pool.tick_manager,
                move_stl::option_u64::borrow(&next_tick_score),
                a2b
            );
            next_tick_score = next_score;
            let tick_index = clmm_pool::tick::index(tick_info);
            let tick_sqrt_price = clmm_pool::tick::sqrt_price(tick_info);
            let target_sqrt_price = if (a2b) {
                integer_mate::math_u128::max(sqrt_price_limit, tick_sqrt_price)
            } else {
                integer_mate::math_u128::min(sqrt_price_limit, tick_sqrt_price)
            };
            let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_pool::clmm_math::compute_swap_step(
                pool.current_sqrt_price,
                target_sqrt_price,
                pool.liquidity,
                remaining_amount,
                pool.fee_rate,
                a2b,
                by_amount_in
            );
            if (amount_in != 0 || fee_amount != 0) {
                if (by_amount_in) {
                    let amount_after_in = check_remainer_amount_sub(remaining_amount, amount_in);
                    remaining_amount = check_remainer_amount_sub(amount_after_in, fee_amount);
                } else {
                    remaining_amount = check_remainer_amount_sub(remaining_amount, amount_out);
                };
                let protocol_fee = integer_mate::full_math_u64::mul_div_ceil(
                    fee_amount,
                    protocol_fee_rate,
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let remaining_fee = fee_amount - protocol_fee;
                let mut fee_after_protocol = remaining_fee;
                let mut gauge_fee = 0;
                let mut ref_fee = 0;
                if (remaining_fee > 0) {
                    let ref_fee_amount = integer_mate::full_math_u64::mul_div_ceil(
                        remaining_fee,
                        ref_fee_rate,
                        clmm_pool::config::protocol_fee_rate_denom()
                    );
                    ref_fee = ref_fee_amount;
                    let fee_after_ref = remaining_fee - ref_fee_amount;
                    fee_after_protocol = fee_after_ref;
                    if (fee_after_ref > 0) {
                        let (_, gauge_fee_amount) = calculate_fees<CoinTypeA, CoinTypeB>(
                            pool,
                            fee_after_ref,
                            pool.liquidity,
                            pool.magma_distribution_staked_liquidity,
                            unstaked_fee_rate
                        );
                        gauge_fee = gauge_fee_amount;
                        fee_after_protocol = fee_after_ref - gauge_fee_amount;
                    };
                };
                update_swap_result(&mut swap_result, amount_in, amount_out, fee_amount, ref_fee, protocol_fee, gauge_fee);
                if (fee_after_protocol > 0) {
                    update_fee_growth_global<CoinTypeA, CoinTypeB>(pool, fee_after_protocol, a2b);
                };
            };
            if (next_sqrt_price == tick_sqrt_price) {
                pool.current_sqrt_price = target_sqrt_price;
                let next_tick_index = if (a2b) {
                    integer_mate::i32::sub(tick_index, integer_mate::i32::from(1))
                } else {
                    tick_index
                };
                pool.current_tick_index = next_tick_index;
                update_magma_distribution_growth_global_internal<CoinTypeA, CoinTypeB>(pool, clock);
                let (new_liquidity, new_staked_liquidity) = clmm_pool::tick::cross_by_swap(
                    &mut pool.tick_manager,
                    tick_index,
                    a2b,
                    pool.liquidity,
                    pool.magma_distribution_staked_liquidity,
                    pool.fee_growth_global_a,
                    pool.fee_growth_global_b,
                    clmm_pool::rewarder::points_growth_global(&pool.rewarder_manager),
                    clmm_pool::rewarder::rewards_growth_global(&pool.rewarder_manager),
                    pool.magma_distribution_growth_global
                );
                pool.liquidity = new_liquidity;
                pool.magma_distribution_staked_liquidity = new_staked_liquidity;
                continue
            };
            if (pool.current_sqrt_price != next_sqrt_price) {
                pool.current_sqrt_price = next_sqrt_price;
                pool.current_tick_index = clmm_pool::tick_math::get_tick_at_sqrt_price(next_sqrt_price);
                continue
            };
        };
        if (a2b) {
            pool.fee_protocol_coin_a = pool.fee_protocol_coin_a + swap_result.protocol_fee_amount;
            pool.magma_distribution_gauger_fee.coin_a = pool.magma_distribution_gauger_fee.coin_a + swap_result.gauge_fee_amount;
        } else {
            pool.fee_protocol_coin_b = pool.fee_protocol_coin_b + swap_result.protocol_fee_amount;
            pool.magma_distribution_gauger_fee.coin_b = pool.magma_distribution_gauger_fee.coin_b + swap_result.gauge_fee_amount;
        };
        swap_result
    }
    public fun swap_pay_amount<CoinTypeA, CoinTypeB>(receipt: &FlashSwapReceipt<CoinTypeA, CoinTypeB>): u64 {
        receipt.pay_amount
    }

    public fun sync_magma_distribution_reward<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: u128,
        arg3: u64,
        arg4: u64
    ) {
        assert!(!arg0.is_pause, 13);
        check_gauge_cap<T0, T1>(arg0, arg1);
        arg0.magma_distribution_rate = arg2;
        arg0.magma_distribution_reserve = arg3;
        arg0.magma_distribution_period_finish = arg4;
        arg0.magma_distribution_rollover = 0;
    }

    public fun tick_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): &clmm_pool::tick::TickManager {
        &pool.tick_manager
    }

    public fun tick_spacing<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): u32 {
        pool.tick_spacing
    }
    public fun unpause<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        clmm_pool::config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(pool.is_pause, 9223378204427812863);
        pool.is_pause = false;
    }

    public fun unstake_from_magma_distribution<CoinTypeA, CoinTypeB>(
        arg0: &mut Pool<CoinTypeA, CoinTypeB>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: u128,
        arg3: integer_mate::i32::I32,
        arg4: integer_mate::i32::I32,
        arg5: &sui::clock::Clock
    ) {
        assert!(!arg0.is_pause, 13);
        assert!(arg2 != 0, 9223379200860225535);
        check_gauge_cap<CoinTypeA, CoinTypeB>(arg0, arg1);
        update_magma_distribution_internal<CoinTypeA, CoinTypeB>(
            arg0,
            integer_mate::i128::neg(integer_mate::i128::from(arg2)),
            arg3,
            arg4,
            arg5
        );
    }
    
    fun update_fee_growth_global<CoinTypeA, CoinTypeB>(pool: &mut Pool<CoinTypeA, CoinTypeB>, fee_after_protocol: u64, a2b: bool) {
        if (fee_after_protocol == 0 || pool.liquidity == 0) {
            return
        };
        if (a2b) {
            pool.fee_growth_global_a = integer_mate::math_u128::wrapping_add(
                pool.fee_growth_global_a,
                ((fee_after_protocol as u128) << 64) / pool.liquidity
            );
        } else {
            pool.fee_growth_global_b = integer_mate::math_u128::wrapping_add(
                pool.fee_growth_global_b,
                ((fee_after_protocol as u128) << 64) / pool.liquidity
            );
        };
    }
    public fun update_fee_rate<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        if (fee_rate > clmm_pool::config::max_fee_rate()) {
            abort 9
        };
        clmm_pool::config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        pool.fee_rate = fee_rate;
        let event = UpdateFeeRateEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            old_fee_rate: pool.fee_rate,
            new_fee_rate: fee_rate,
        };
        sui::event::emit<UpdateFeeRateEvent>(event);
    }

    public fun update_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(
        arg0: &mut Pool<CoinTypeA, CoinTypeB>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: &sui::clock::Clock
    ) {
        assert!(!arg0.is_pause, 13);
        check_gauge_cap<CoinTypeA, CoinTypeB>(arg0, arg1);
        update_magma_distribution_growth_global_internal<CoinTypeA, CoinTypeB>(arg0, arg2);
    }
    fun update_magma_distribution_growth_global_internal<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ): u64 {
        let current_timestamp = sui::clock::timestamp_ms(clock) / 1000;
        let time_delta = current_timestamp - pool.magma_distribution_last_updated;
        let mut distributed_amount = 0;
        if (time_delta != 0) {
            if (pool.magma_distribution_reserve > 0) {
                let calculated_distribution = integer_mate::full_math_u128::mul_div_floor(
                    pool.magma_distribution_rate,
                    time_delta as u128,
                    18446744073709551616
                ) as u64;
                let mut actual_distribution = calculated_distribution;
                if (calculated_distribution > pool.magma_distribution_reserve) {
                    actual_distribution = pool.magma_distribution_reserve;
                };
                pool.magma_distribution_reserve = pool.magma_distribution_reserve - actual_distribution;
                if (pool.magma_distribution_staked_liquidity > 0) {
                    pool.magma_distribution_growth_global = pool.magma_distribution_growth_global + integer_mate::full_math_u128::mul_div_floor(
                        actual_distribution as u128,
                        18446744073709551616,
                        pool.magma_distribution_staked_liquidity
                    );
                } else {
                    pool.magma_distribution_rollover = pool.magma_distribution_rollover + actual_distribution;
                };
                distributed_amount = actual_distribution;
            };
            pool.magma_distribution_last_updated = current_timestamp;
        };
        distributed_amount
    }
    
    fun update_magma_distribution_internal<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        liquidity_delta: integer_mate::i128::I128,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        clock: &sui::clock::Clock
    ) {
        if (integer_mate::i32::gte(pool.current_tick_index, tick_lower) && integer_mate::i32::lt(
            pool.current_tick_index,
            tick_upper
        )) {
            update_magma_distribution_growth_global_internal<CoinTypeA, CoinTypeB>(pool, clock);
            if (integer_mate::i128::is_neg(liquidity_delta)) {
                assert!(
                    pool.magma_distribution_staked_liquidity >= integer_mate::i128::abs_u128(liquidity_delta),
                    9223379024766566399
                );
            } else {
                let (_, overflow) = integer_mate::i128::overflowing_add(
                    integer_mate::i128::from(pool.magma_distribution_staked_liquidity),
                    liquidity_delta
                );
                assert!(!overflow, 9223379033357877270);
            };
            pool.magma_distribution_staked_liquidity = integer_mate::i128::as_u128(
                integer_mate::i128::add(integer_mate::i128::from(pool.magma_distribution_staked_liquidity), liquidity_delta)
            );
        };
        let tick_lower_opt = clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_lower);
        let tick_upper_opt = clmm_pool::tick::try_borrow_tick(&pool.tick_manager, tick_upper);
        if (std::option::is_some<clmm_pool::tick::Tick>(&tick_lower_opt)) {
            clmm_pool::tick::update_magma_stake(&mut pool.tick_manager, tick_lower, liquidity_delta, false);
        };
        if (std::option::is_some<clmm_pool::tick::Tick>(&tick_upper_opt)) {
            clmm_pool::tick::update_magma_stake(&mut pool.tick_manager, tick_upper, liquidity_delta, true);
        };
    }
    public fun update_position_url<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        new_url: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        pool.url = new_url;
    }
    fun update_swap_result(
        swap_result: &mut SwapResult,
        amount_in_delta: u64,
        amount_out_delta: u64,
        fee_amount_delta: u64,
        protocol_fee_delta: u64,
        ref_fee_delta: u64,
        gauge_fee_delta: u64
    ) {
        assert!(integer_mate::math_u64::add_check(swap_result.amount_in, amount_in_delta), 6);
        assert!(integer_mate::math_u64::add_check(swap_result.amount_out, amount_out_delta), 7);
        assert!(integer_mate::math_u64::add_check(swap_result.fee_amount, fee_amount_delta), 8);
        swap_result.amount_in = swap_result.amount_in + amount_in_delta;
        swap_result.amount_out = swap_result.amount_out + amount_out_delta;
        swap_result.fee_amount = swap_result.fee_amount + fee_amount_delta;
        swap_result.protocol_fee_amount = swap_result.protocol_fee_amount + protocol_fee_delta;
        swap_result.gauge_fee_amount = swap_result.gauge_fee_amount + gauge_fee_delta;
        swap_result.ref_fee_amount = swap_result.ref_fee_amount + ref_fee_delta;
        swap_result.steps = swap_result.steps + 1;
    }
    public fun update_unstaked_liquidity_fee_rate<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>, 
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        assert!(
            new_fee_rate == clmm_pool::config::default_unstaked_fee_rate() || 
            new_fee_rate <= clmm_pool::config::max_unstaked_liquidity_fee_rate(),
            9
        );
        assert!(new_fee_rate != pool.unstaked_liquidity_fee_rate, 9);
        clmm_pool::config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        pool.unstaked_liquidity_fee_rate = new_fee_rate;
        let event = UpdateUnstakedLiquidityFeeRateEvent {
            pool: sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            old_fee_rate: pool.unstaked_liquidity_fee_rate,
            new_fee_rate: new_fee_rate,
        };
        sui::event::emit<UpdateUnstakedLiquidityFeeRateEvent>(event);
    }

    public fun url<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>): std::string::String {
        pool.url
    }

    fun validate_pool_position<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>, position: &clmm_pool::position::Position) {
        assert!(sui::object::id<Pool<CoinTypeA, CoinTypeB>>(pool) == clmm_pool::position::pool_id(position), 9223373806381301759);
    }

    // decompiled from Move bytecode v6
}


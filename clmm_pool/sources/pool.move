module clmm_pool::pool {
    public struct POOL has drop {}

    public struct Pool<phantom T0, phantom T1> has store, key {
        id: sui::object::UID,
        coin_a: sui::balance::Balance<T0>,
        coin_b: sui::balance::Balance<T1>,
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

    public struct FlashSwapReceipt<phantom T0, phantom T1> {
        pool_id: sui::object::ID,
        a2b: bool,
        partner_id: sui::object::ID,
        pay_amount: u64,
        fee_amount: u64,
        protocol_fee_amount: u64,
        ref_fee_amount: u64,
        gauge_fee_amount: u64,
    }

    public struct AddLiquidityReceipt<phantom T0, phantom T1> {
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

    public(package) fun new<T0, T1>(tick_spacing: u32, sqrt_price: u128, fee_rate: u64, url: std::string::String, index: u64, clock: &sui::clock::Clock, ctx: &mut sui::tx_context::TxContext) : Pool<T0, T1> {
        let gauger_fee = PoolFee{
            coin_a : 0, 
            coin_b : 0,
        };
        Pool<T0, T1>{
            id                                  : sui::object::new(ctx), 
            coin_a                              : sui::balance::zero<T0>(), 
            coin_b                              : sui::balance::zero<T1>(), 
            tick_spacing                        : tick_spacing, 
            fee_rate                            : fee_rate, 
            liquidity                           : 0, 
            current_sqrt_price                  : sqrt_price, 
            current_tick_index                  : clmm_pool::tick_math::get_tick_at_sqrt_price(sqrt_price), 
            fee_growth_global_a                 : 0, 
            fee_growth_global_b                 : 0, 
            fee_protocol_coin_a                 : 0, 
            fee_protocol_coin_b                 : 0, 
            tick_manager                        : clmm_pool::tick::new(tick_spacing, sui::clock::timestamp_ms(clock), ctx), 
            rewarder_manager                    : clmm_pool::rewarder::new(), 
            position_manager                    : clmm_pool::position::new(tick_spacing, ctx), 
            is_pause                            : false, 
            index                               : index, 
            url                                 : url, 
            unstaked_liquidity_fee_rate         : clmm_pool::config::default_unstaked_fee_rate(), 
            magma_distribution_gauger_id        : std::option::none<sui::object::ID>(), 
            magma_distribution_growth_global    : 0, 
            magma_distribution_rate             : 0, 
            magma_distribution_reserve          : 0, 
            magma_distribution_period_finish    : 0, 
            magma_distribution_rollover         : 0, 
            magma_distribution_last_updated     : sui::clock::timestamp_ms(clock) / 1000, 
            magma_distribution_staked_liquidity : 0, 
            magma_distribution_gauger_fee       : gauger_fee,
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
            (clmm_pool::clmm_math::get_delta_a(clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower), clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), liquidity, round_up), 0)
        } else {
            let (amount_a, amount_b) = if (integer_mate::i32::lt(current_tick, tick_upper)) {
                (clmm_pool::clmm_math::get_delta_a(current_sqrt_price, clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), liquidity, round_up), clmm_pool::clmm_math::get_delta_b(clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower), current_sqrt_price, liquidity, round_up))
            } else {
                (0, clmm_pool::clmm_math::get_delta_b(clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower), clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), liquidity, round_up))
            };
            (amount_a, amount_b)
        }
    }
    
    public fun unstaked_liquidity_fee_rate<T0, T1>(pool: &Pool<T0, T1>) : u64 {
        pool.unstaked_liquidity_fee_rate
    }
    
    public fun borrow_position_info<T0, T1>(pool: &Pool<T0, T1>, position_id: sui::object::ID) : &clmm_pool::position::PositionInfo {
        clmm_pool::position::borrow_position_info(&pool.position_manager, position_id)
    }
    
    public fun close_position<T0, T1>(global_config: &clmm_pool::config::GlobalConfig, pool: &mut Pool<T0, T1>, position: clmm_pool::position::Position) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let position_id = sui::object::id<clmm_pool::position::Position>(&position);
        clmm_pool::position::close_position(&mut pool.position_manager, position);
        let event = ClosePositionEvent{
            pool     : sui::object::id<Pool<T0, T1>>(pool), 
            position : position_id,
        };
        sui::event::emit<ClosePositionEvent>(event);
    }
    
    public fun fetch_positions<T0, T1>(pool: &Pool<T0, T1>, position_ids: vector<sui::object::ID>, limit: u64) : vector<clmm_pool::position::PositionInfo> {
        clmm_pool::position::fetch_positions(&pool.position_manager, position_ids, limit)
    }
    
    public fun is_position_exist<T0, T1>(pool: &Pool<T0, T1>, position_id: sui::object::ID) : bool {
        clmm_pool::position::is_position_exist(&pool.position_manager, position_id)
    }
    
    public fun liquidity<T0, T1>(pool: &Pool<T0, T1>) : u128 {
        pool.liquidity
    }
    
    public fun mark_position_staked<T0, T1>(pool: &mut Pool<T0, T1>, gauge_cap: &gauge_cap::gauge_cap::GaugeCap, position_id: sui::object::ID) {
        assert!(!pool.is_pause, 13);
        check_gauge_cap<T0, T1>(pool, gauge_cap);
        clmm_pool::position::mark_position_staked(&mut pool.position_manager, position_id, true);
    }
    
    public fun open_position<T0, T1>(global_config: &clmm_pool::config::GlobalConfig, pool: &mut Pool<T0, T1>, tick_lower: u32, tick_upper: u32, ctx: &mut sui::tx_context::TxContext) : clmm_pool::position::Position {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        let tick_lower_i32 = integer_mate::i32::from_u32(tick_lower);
        let tick_upper_i32 = integer_mate::i32::from_u32(tick_upper);
        let pool_id = sui::object::id<Pool<T0, T1>>(pool);
        let position = clmm_pool::position::open_position<T0, T1>(&mut pool.position_manager, pool_id, pool.index, pool.url, tick_lower_i32, tick_upper_i32, ctx);
        let event = OpenPositionEvent{
            pool       : pool_id, 
            tick_lower : tick_lower_i32, 
            tick_upper : tick_upper_i32, 
            position   : sui::object::id<clmm_pool::position::Position>(&position),
        };
        sui::event::emit<OpenPositionEvent>(event);
        position
    }
    
    public fun update_emission<T0, T1, T2>(global_config: &clmm_pool::config::GlobalConfig, pool: &mut Pool<T0, T1>, rewarder_vault: &clmm_pool::rewarder::RewarderGlobalVault, emissions_per_second: u128, clock: &sui::clock::Clock, ctx: &mut sui::tx_context::TxContext) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(!pool.is_pause, 13);
        clmm_pool::config::check_rewarder_manager_role(global_config, sui::tx_context::sender(ctx));
        clmm_pool::rewarder::update_emission<T2>(rewarder_vault, &mut pool.rewarder_manager, pool.liquidity, emissions_per_second, sui::clock::timestamp_ms(clock) / 1000);
        let event = UpdateEmissionEvent{
            pool                 : sui::object::id<Pool<T0, T1>>(pool), 
            rewarder_type        : std::type_name::get<T2>(), 
            emissions_per_second : emissions_per_second,
        };
        sui::event::emit<UpdateEmissionEvent>(event);
    }
    
    public fun borrow_tick<T0, T1>(pool: &Pool<T0, T1>, tick: integer_mate::i32::I32) : &clmm_pool::tick::Tick {
        clmm_pool::tick::borrow_tick(&pool.tick_manager, tick)
    }
    
    public fun fetch_ticks<T0, T1>(pool: &Pool<T0, T1>, ticks: vector<u32>, limit: u64) : vector<clmm_pool::tick::Tick> {
        clmm_pool::tick::fetch_ticks(&pool.tick_manager, ticks, limit)
    }
    
    public fun index<T0, T1>(pool: &Pool<T0, T1>) : u64 {
        pool.index
    }

    public fun add_liquidity<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut clmm_pool::position::Position,
        arg3: u128,
        arg4: &sui::clock::Clock
    ): AddLiquidityReceipt<T0, T1> {
        clmm_pool::config::checked_package_version(arg0);
        assert!(arg3 != 0, 3);
        add_liquidity_internal<T0, T1>(arg1, arg2, false, arg3, 0, false, sui::clock::timestamp_ms(arg4) / 1000)
    }

    public fun add_liquidity_fix_coin<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut clmm_pool::position::Position,
        arg3: u64,
        arg4: bool,
        arg5: &sui::clock::Clock
    ): AddLiquidityReceipt<T0, T1> {
        clmm_pool::config::checked_package_version(arg0);
        assert!(arg3 > 0, 0);
        add_liquidity_internal<T0, T1>(arg1, arg2, true, 0, arg3, arg4, sui::clock::timestamp_ms(arg5) / 1000)
    }

    fun add_liquidity_internal<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &mut clmm_pool::position::Position,
        arg2: bool,
        arg3: u128,
        arg4: u64,
        arg5: bool,
        arg6: u64
    ): AddLiquidityReceipt<T0, T1> {
        assert!(!arg0.is_pause, 13);
        validate_pool_position<T0, T1>(arg0, arg1);
        clmm_pool::rewarder::settle(&mut arg0.rewarder_manager, arg0.liquidity, arg6);
        let (v0, v1) = clmm_pool::position::tick_range(arg1);
        let (v2, v3, v4) = if (arg2) {
            let (v5, v6, v7) = clmm_pool::clmm_math::get_liquidity_by_amount(
                v0,
                v1,
                arg0.current_tick_index,
                arg0.current_sqrt_price,
                arg4,
                arg5
            );
            (v5, v6, v7)
        } else {
            let (v8, v9) = clmm_pool::clmm_math::get_amount_by_liquidity(
                v0,
                v1,
                arg0.current_tick_index,
                arg0.current_sqrt_price,
                arg3,
                true
            );
            (arg3, v8, v9)
        };
        let (v10, v11, v12, v13, v14) = get_all_growths_in_tick_range<T0, T1>(arg0, v0, v1);
        clmm_pool::tick::increase_liquidity(
            &mut arg0.tick_manager,
            arg0.current_tick_index,
            v0,
            v1,
            v2,
            arg0.fee_growth_global_a,
            arg0.fee_growth_global_b,
            clmm_pool::rewarder::points_growth_global(&arg0.rewarder_manager),
            clmm_pool::rewarder::rewards_growth_global(&arg0.rewarder_manager),
            arg0.magma_distribution_growth_global
        );
        if (integer_mate::i32::gte(arg0.current_tick_index, v0) && integer_mate::i32::lt(arg0.current_tick_index, v1)) {
            assert!(integer_mate::math_u128::add_check(arg0.liquidity, v2), 1);
            arg0.liquidity = arg0.liquidity + v2;
        };
        let v15 = AddLiquidityEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg0),
            position: sui::object::id<clmm_pool::position::Position>(arg1),
            tick_lower: v0,
            tick_upper: v1,
            liquidity: arg3,
            after_liquidity: clmm_pool::position::increase_liquidity(
                &mut arg0.position_manager,
                arg1,
                v2,
                v10,
                v11,
                v13,
                v12,
                v14
            ),
            amount_a: v3,
            amount_b: v4,
        };
        sui::event::emit<AddLiquidityEvent>(v15);
        AddLiquidityReceipt<T0, T1> {
            pool_id: sui::object::id<Pool<T0, T1>>(arg0),
            amount_a: v3,
            amount_b: v4,
        }
    }

    public fun add_liquidity_pay_amount<T0, T1>(arg0: &AddLiquidityReceipt<T0, T1>): (u64, u64) {
        (arg0.amount_a, arg0.amount_b)
    }

    fun apply_unstaked_fees(arg0: u128, arg1: u128, arg2: u64): (u128, u128) {
        let v0 = integer_mate::full_math_u128::mul_div_ceil(arg0, arg2 as u128, 10000);
        (arg0 - v0, arg1 + v0)
    }

    public fun balances<T0, T1>(arg0: &Pool<T0, T1>): (u64, u64) {
        (sui::balance::value<T0>(&arg0.coin_a), sui::balance::value<T1>(&arg0.coin_b))
    }

    public fun calculate_and_update_fee<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::object::ID
    ): (u64, u64) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        let v0 = clmm_pool::position::borrow_position_info(&arg1.position_manager, arg2);
        if (clmm_pool::position::info_liquidity(v0) != 0) {
            let (v3, v4) = clmm_pool::position::info_tick_range(v0);
            let (v5, v6) = get_fee_in_tick_range<T0, T1>(arg1, v3, v4);
            let (v7, v8) = clmm_pool::position::update_fee(&mut arg1.position_manager, arg2, v5, v6);
            (v7, v8)
        } else {
            let (v9, v10) = clmm_pool::position::info_fee_owned(v0);
            (v9, v10)
        }
    }

    public fun calculate_and_update_magma_distribution<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::object::ID
    ): u64 {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        let v0 = clmm_pool::position::borrow_position_info(&arg1.position_manager, arg2);
        if (clmm_pool::position::info_liquidity(v0) != 0) {
            let (v2, v3) = clmm_pool::position::info_tick_range(v0);
            clmm_pool::position::update_magma_distribution(
                &mut arg1.position_manager,
                arg2,
                clmm_pool::tick::get_magma_distribution_growth_in_range(
                    arg1.current_tick_index,
                    arg1.magma_distribution_growth_global,
                    clmm_pool::tick::try_borrow_tick(&arg1.tick_manager, v2),
                    clmm_pool::tick::try_borrow_tick(&arg1.tick_manager, v3)
                )
            )
        } else {
            clmm_pool::position::info_magma_distribution_owned(v0)
        }
    }

    public fun calculate_and_update_points<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock
    ): u128 {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::rewarder::settle(&mut arg1.rewarder_manager, arg1.liquidity, sui::clock::timestamp_ms(arg3) / 1000);
        let v0 = clmm_pool::position::borrow_position_info(&arg1.position_manager, arg2);
        if (clmm_pool::position::info_liquidity(v0) != 0) {
            let (v2, v3) = clmm_pool::position::info_tick_range(v0);
            let points = get_points_in_tick_range<T0, T1>(arg1, v2, v3);
            let positionManager = &mut arg1.position_manager;
            clmm_pool::position::update_points(positionManager, arg2, points)
        } else {
            clmm_pool::position::info_points_owned(
                clmm_pool::position::borrow_position_info(&arg1.position_manager, arg2)
            )
        }
    }

    public fun calculate_and_update_reward<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock
    ): u64 {
        let mut v0 = clmm_pool::rewarder::rewarder_index<T2>(&arg1.rewarder_manager);
        assert!(std::option::is_some<u64>(&v0), 17);
        let v1 = calculate_and_update_rewards<T0, T1>(arg0, arg1, arg2, arg3);
        *std::vector::borrow<u64>(&v1, std::option::extract<u64>(&mut v0))
    }

    public fun calculate_and_update_rewards<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock
    ): vector<u64> {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::rewarder::settle(&mut arg1.rewarder_manager, arg1.liquidity, sui::clock::timestamp_ms(arg3) / 1000);
        let v0 = clmm_pool::position::borrow_position_info(&arg1.position_manager, arg2);
        if (clmm_pool::position::info_liquidity(v0) != 0) {
            let (v2, v3) = clmm_pool::position::info_tick_range(v0);
            let rewards = get_rewards_in_tick_range<T0, T1>(arg1, v2, v3);
            let positionManager = &mut arg1.position_manager;
            clmm_pool::position::update_rewards(positionManager, arg2, rewards)
        } else {
            clmm_pool::position::rewards_amount_owned(&arg1.position_manager, arg2)
        }
    }

    fun calculate_fees<T0, T1>(arg0: &Pool<T0, T1>, arg1: u64, arg2: u128, arg3: u128, arg4: u64): (u128, u64) {
        if (arg2 == arg0.magma_distribution_staked_liquidity) {
            (0, arg1)
        } else {
            let (v2, v3) = if (arg3 == 0) {
                let (v4, v5) = apply_unstaked_fees(arg1 as u128, 0, arg4);
                (integer_mate::full_math_u128::mul_div_floor(v4, 18446744073709551616, arg2), v5 as u64)
            } else {
                let (v6, v7) = split_fees(arg1, arg2, arg3, arg4);
                (integer_mate::full_math_u128::mul_div_floor(v6 as u128, 18446744073709551616, arg2 - arg3), v7)
            };
            (v2, v3)
        }
    }

    public fun calculate_swap_result<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &Pool<T0, T1>,
        arg2: bool,
        arg3: bool,
        arg4: u64
    ): CalculatedSwapResult {
        let mut v0 = arg1.current_sqrt_price;
        let mut v1 = arg1.liquidity;
        let mut v2 = arg1.magma_distribution_staked_liquidity;
        let mut v3 = default_swap_result();
        let mut v4 = arg4;
        let mut v5 = clmm_pool::tick::first_score_for_swap(&arg1.tick_manager, arg1.current_tick_index, arg2);
        let mut v6 = CalculatedSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: arg1.fee_rate,
            ref_fee_amount: 0,
            gauge_fee_amount: 0,
            protocol_fee_amount: 0,
            after_sqrt_price: arg1.current_sqrt_price,
            is_exceed: false,
            step_results: std::vector::empty<SwapStepResult>(),
        };
        let v7 = if (arg1.unstaked_liquidity_fee_rate == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(arg0)
        } else {
            arg1.unstaked_liquidity_fee_rate
        };
        while (v4 > 0) {
            if (move_stl::option_u64::is_none(&v5)) {
                v6.is_exceed = true;
                break
            };
            let (v8, v9) = clmm_pool::tick::borrow_tick_for_swap(
                &arg1.tick_manager,
                move_stl::option_u64::borrow(&v5),
                arg2
            );
            v5 = v9;
            let v10 = clmm_pool::tick::sqrt_price(v8);
            let (v11, v12, v13, v14) = clmm_pool::clmm_math::compute_swap_step(
                v0,
                v10,
                v1,
                v4,
                arg1.fee_rate,
                arg2,
                arg3
            );
            if (v11 != 0 || v14 != 0) {
                let v15 = if (arg3) {
                    let v16 = check_remainer_amount_sub(v4, v11);
                    check_remainer_amount_sub(v16, v14)
                } else {
                    check_remainer_amount_sub(v4, v12)
                };
                v4 = v15;
                let v17 = integer_mate::full_math_u64::mul_div_ceil(
                    v14,
                    clmm_pool::config::protocol_fee_rate(arg0),
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let (_, v19) = calculate_fees<T0, T1>(
                    arg1,
                    v14 - v17,
                    arg1.liquidity,
                    arg1.magma_distribution_staked_liquidity,
                    v7
                );
                update_swap_result(&mut v3, v11, v12, v14, v17, 0, v19);
            };
            let v20 = SwapStepResult {
                current_sqrt_price: v0,
                target_sqrt_price: v10,
                current_liquidity: v1,
                amount_in: v11,
                amount_out: v12,
                fee_amount: v14,
                remainder_amount: v4,
            };
            std::vector::push_back<SwapStepResult>(&mut v6.step_results, v20);
            if (v13 == v10) {
                v0 = v10;
                let (v21, v22) = if (arg2) {
                    (integer_mate::i128::neg(clmm_pool::tick::liquidity_net(v8)), integer_mate::i128::neg(
                        clmm_pool::tick::magma_distribution_staked_liquidity_net(v8)
                    ))
                } else {
                    (clmm_pool::tick::liquidity_net(v8), clmm_pool::tick::magma_distribution_staked_liquidity_net(v8))
                };
                let v23 = integer_mate::i128::abs_u128(v21);
                let v24 = integer_mate::i128::abs_u128(v22);
                if (!integer_mate::i128::is_neg(v21)) {
                    assert!(integer_mate::math_u128::add_check(v1, v23), 1);
                    v1 = v1 + v23;
                } else {
                    assert!(v1 >= v23, 1);
                    v1 = v1 - v23;
                };
                if (!integer_mate::i128::is_neg(v22)) {
                    assert!(integer_mate::math_u128::add_check(v2, v24), 1);
                    v2 = v2 + v24;
                    continue
                };
                assert!(v2 >= v24, 1);
                v2 = v2 - v24;
                continue
            };
            v0 = v13;
        };
        v6.amount_in = v3.amount_in;
        v6.amount_out = v3.amount_out;
        v6.fee_amount = v3.fee_amount;
        v6.gauge_fee_amount = v3.gauge_fee_amount;
        v6.protocol_fee_amount = v3.protocol_fee_amount;
        v6.after_sqrt_price = v0;
        v6
    }

    public fun calculate_swap_result_step_results(arg0: &CalculatedSwapResult): &vector<SwapStepResult> {
        &arg0.step_results
    }

    public fun calculate_swap_result_with_partner<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &Pool<T0, T1>,
        arg2: bool,
        arg3: bool,
        arg4: u64,
        arg5: u64
    ): CalculatedSwapResult {
        let mut v0 = arg1.current_sqrt_price;
        let mut v1 = arg1.liquidity;
        let mut v2 = arg1.magma_distribution_staked_liquidity;
        let mut v3 = default_swap_result();
        let mut v4 = arg4;
        let mut v5 = clmm_pool::tick::first_score_for_swap(&arg1.tick_manager, arg1.current_tick_index, arg2);
        let mut v6 = CalculatedSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: arg1.fee_rate,
            ref_fee_amount: 0,
            gauge_fee_amount: 0,
            protocol_fee_amount: 0,
            after_sqrt_price: arg1.current_sqrt_price,
            is_exceed: false,
            step_results: std::vector::empty<SwapStepResult>(),
        };
        let v7 = if (arg1.unstaked_liquidity_fee_rate == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(arg0)
        } else {
            arg1.unstaked_liquidity_fee_rate
        };
        while (v4 > 0) {
            if (move_stl::option_u64::is_none(&v5)) {
                v6.is_exceed = true;
                break
            };
            let (v8, v9) = clmm_pool::tick::borrow_tick_for_swap(
                &arg1.tick_manager,
                move_stl::option_u64::borrow(&v5),
                arg2
            );
            v5 = v9;
            let v10 = clmm_pool::tick::sqrt_price(v8);
            let (v11, v12, v13, v14) = clmm_pool::clmm_math::compute_swap_step(
                v0,
                v10,
                v1,
                v4,
                arg1.fee_rate,
                arg2,
                arg3
            );
            if (v11 != 0 || v14 != 0) {
                let v15 = if (arg3) {
                    let v16 = check_remainer_amount_sub(v4, v11);
                    check_remainer_amount_sub(v16, v14)
                } else {
                    check_remainer_amount_sub(v4, v12)
                };
                v4 = v15;
                let v17 = integer_mate::full_math_u64::mul_div_ceil(
                    v14,
                    arg5,
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let v18 = v14 - v17;
                let mut v19 = 0;
                let mut v20 = 0;
                if (v18 > 0) {
                    let v21 = integer_mate::full_math_u64::mul_div_ceil(
                        v18,
                        clmm_pool::config::protocol_fee_rate(arg0),
                        clmm_pool::config::protocol_fee_rate_denom()
                    );
                    v20 = v21;
                    let v22 = v18 - v21;
                    if (v22 > 0) {
                        let (_, v24) = calculate_fees<T0, T1>(
                            arg1,
                            v22,
                            arg1.liquidity,
                            arg1.magma_distribution_staked_liquidity,
                            v7
                        );
                        v19 = v24;
                    };
                };
                update_swap_result(&mut v3, v11, v12, v14, v20, v17, v19);
            };
            let v25 = SwapStepResult {
                current_sqrt_price: v0,
                target_sqrt_price: v10,
                current_liquidity: v1,
                amount_in: v11,
                amount_out: v12,
                fee_amount: v14,
                remainder_amount: v4,
            };
            std::vector::push_back<SwapStepResult>(&mut v6.step_results, v25);
            if (v13 == v10) {
                v0 = v10;
                let (v26, v27) = if (arg2) {
                    (integer_mate::i128::neg(clmm_pool::tick::liquidity_net(v8)), integer_mate::i128::neg(
                        clmm_pool::tick::magma_distribution_staked_liquidity_net(v8)
                    ))
                } else {
                    (clmm_pool::tick::liquidity_net(v8), clmm_pool::tick::magma_distribution_staked_liquidity_net(v8))
                };
                let v28 = integer_mate::i128::abs_u128(v26);
                let v29 = integer_mate::i128::abs_u128(v27);
                if (!integer_mate::i128::is_neg(v26)) {
                    assert!(integer_mate::math_u128::add_check(v1, v28), 1);
                    v1 = v1 + v28;
                } else {
                    assert!(v1 >= v28, 1);
                    v1 = v1 - v28;
                };
                if (!integer_mate::i128::is_neg(v27)) {
                    assert!(integer_mate::math_u128::add_check(v2, v29), 1);
                    v2 = v2 + v29;
                    continue
                };
                assert!(v2 >= v29, 1);
                v2 = v2 - v29;
                continue
            };
            v0 = v13;
        };
        v6.amount_in = v3.amount_in;
        v6.amount_out = v3.amount_out;
        v6.fee_amount = v3.fee_amount;
        v6.gauge_fee_amount = v3.gauge_fee_amount;
        v6.protocol_fee_amount = v3.protocol_fee_amount;
        v6.ref_fee_amount = v3.ref_fee_amount;
        v6.after_sqrt_price = v0;
        v6
    }

    public fun calculated_swap_result_after_sqrt_price(arg0: &CalculatedSwapResult): u128 {
        arg0.after_sqrt_price
    }

    public fun calculated_swap_result_amount_in(arg0: &CalculatedSwapResult): u64 {
        arg0.amount_in
    }

    public fun calculated_swap_result_amount_out(arg0: &CalculatedSwapResult): u64 {
        arg0.amount_out
    }

    public fun calculated_swap_result_fees_amount(arg0: &CalculatedSwapResult): (u64, u64, u64, u64) {
        (arg0.fee_amount, arg0.ref_fee_amount, arg0.protocol_fee_amount, arg0.gauge_fee_amount)
    }

    public fun calculated_swap_result_is_exceed(arg0: &CalculatedSwapResult): bool {
        arg0.is_exceed
    }

    public fun calculated_swap_result_step_swap_result(arg0: &CalculatedSwapResult, arg1: u64): &SwapStepResult {
        std::vector::borrow<SwapStepResult>(&arg0.step_results, arg1)
    }

    public fun calculated_swap_result_steps_length(arg0: &CalculatedSwapResult): u64 {
        std::vector::length<SwapStepResult>(&arg0.step_results)
    }

    fun check_gauge_cap<T0, T1>(arg0: &Pool<T0, T1>, arg1: &gauge_cap::gauge_cap::GaugeCap) {
        let v0 = if (gauge_cap::gauge_cap::get_pool_id(arg1) == sui::object::id<Pool<T0, T1>>(arg0)) {
            let v1 = &arg0.magma_distribution_gauger_id;
            let v2 = if (std::option::is_some<sui::object::ID>(v1)) {
                let v3 = gauge_cap::gauge_cap::get_gauge_id(arg1);
                std::option::borrow<sui::object::ID>(v1) == &v3
            } else {
                false
            };
            v2
        } else {
            false
        };
        assert!(v0, 9223379355479048191);
    }

    fun check_remainer_amount_sub(arg0: u64, arg1: u64): u64 {
        assert!(arg0 >= arg1, 5);
        arg0 - arg1
    }

    fun check_tick_range(arg0: integer_mate::i32::I32, arg1: integer_mate::i32::I32): bool {
        let v0 = if (integer_mate::i32::gte(arg0, arg1)) {
            true
        } else {
            if (integer_mate::i32::lt(arg0, clmm_pool::tick_math::min_tick())) {
                true
            } else {
                integer_mate::i32::gt(arg1, clmm_pool::tick_math::max_tick())
            }
        };
        if (v0) {
            return false
        };
        true
    }

    public fun collect_fee<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &clmm_pool::position::Position,
        arg3: bool
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        let v0 = sui::object::id<clmm_pool::position::Position>(arg2);
        if (clmm_pool::position::is_staked(borrow_position_info<T0, T1>(arg1, v0))) {
            return (sui::balance::zero<T0>(), sui::balance::zero<T1>())
        };
        let (v1, v2) = clmm_pool::position::tick_range(arg2);
        let (v3, v4) = if (arg3 && clmm_pool::position::liquidity(arg2) != 0) {
            let (v5, v6) = get_fee_in_tick_range<T0, T1>(arg1, v1, v2);
            let (v7, v8) = clmm_pool::position::update_and_reset_fee(&mut arg1.position_manager, v0, v5, v6);
            (v7, v8)
        } else {
            let (v9, v10) = clmm_pool::position::reset_fee(&mut arg1.position_manager, v0);
            (v9, v10)
        };
        let v11 = CollectFeeEvent {
            position: v0,
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            amount_a: v3,
            amount_b: v4,
        };
        sui::event::emit<CollectFeeEvent>(v11);
        (sui::balance::split<T0>(&mut arg1.coin_a, v3), sui::balance::split<T1>(&mut arg1.coin_b, v4))
    }

    public fun collect_magma_distribution_gauger_fees<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        assert!(!arg0.is_pause, 13);
        check_gauge_cap<T0, T1>(arg0, arg1);
        let mut v0 = sui::balance::zero<T0>();
        let mut v1 = sui::balance::zero<T1>();
        if (arg0.magma_distribution_gauger_fee.coin_a > 0) {
            sui::balance::join<T0>(
                &mut v0,
                sui::balance::split<T0>(&mut arg0.coin_a, arg0.magma_distribution_gauger_fee.coin_a)
            );
            arg0.magma_distribution_gauger_fee.coin_a = 0;
        };
        if (arg0.magma_distribution_gauger_fee.coin_b > 0) {
            sui::balance::join<T1>(
                &mut v1,
                sui::balance::split<T1>(&mut arg0.coin_b, arg0.magma_distribution_gauger_fee.coin_b)
            );
            arg0.magma_distribution_gauger_fee.coin_b = 0;
        };
        let v2 = CollectGaugeFeeEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg0),
            amount_a: sui::balance::value<T0>(&v0),
            amount_b: sui::balance::value<T1>(&v1),
        };
        sui::event::emit<CollectGaugeFeeEvent>(v2);
        (v0, v1)
    }

    public fun collect_protocol_fee<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut sui::tx_context::TxContext
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::config::check_protocol_fee_claim_role(arg0, sui::tx_context::sender(arg2));
        let v0 = arg1.fee_protocol_coin_a;
        let v1 = arg1.fee_protocol_coin_b;
        arg1.fee_protocol_coin_a = 0;
        arg1.fee_protocol_coin_b = 0;
        let v2 = CollectProtocolFeeEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            amount_a: v0,
            amount_b: v1,
        };
        sui::event::emit<CollectProtocolFeeEvent>(v2);
        (sui::balance::split<T0>(&mut arg1.coin_a, v0), sui::balance::split<T1>(&mut arg1.coin_b, v1))
    }

    public fun collect_reward<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &clmm_pool::position::Position,
        arg3: &mut clmm_pool::rewarder::RewarderGlobalVault,
        arg4: bool,
        arg5: &sui::clock::Clock
    ): sui::balance::Balance<T2> {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::rewarder::settle(&mut arg1.rewarder_manager, arg1.liquidity, sui::clock::timestamp_ms(arg5) / 1000);
        let v0 = sui::object::id<clmm_pool::position::Position>(arg2);
        let mut v1 = clmm_pool::rewarder::rewarder_index<T2>(&arg1.rewarder_manager);
        assert!(std::option::is_some<u64>(&v1), 17);
        let v2 = std::option::extract<u64>(&mut v1);
        let v3 = if (arg4 && clmm_pool::position::liquidity(arg2) != 0 || clmm_pool::position::inited_rewards_count(
            &arg1.position_manager,
            v0
        ) <= v2) {
            let (v4, v5) = clmm_pool::position::tick_range(arg2);
            let rewards = get_rewards_in_tick_range<T0, T1>(arg1, v4, v5);
            let positionManager = &mut arg1.position_manager;
            clmm_pool::position::update_and_reset_rewards(positionManager, v0, rewards, v2)
        } else {
            clmm_pool::position::reset_rewarder(&mut arg1.position_manager, v0, v2)
        };
        let v6 = CollectRewardEvent {
            position: v0,
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            amount: v3,
        };
        sui::event::emit<CollectRewardEvent>(v6);
        clmm_pool::rewarder::withdraw_reward<T2>(arg3, v3)
    }

    public fun current_sqrt_price<T0, T1>(arg0: &Pool<T0, T1>): u128 {
        arg0.current_sqrt_price
    }

    public fun current_tick_index<T0, T1>(arg0: &Pool<T0, T1>): integer_mate::i32::I32 {
        arg0.current_tick_index
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

    public fun fee_rate<T0, T1>(arg0: &Pool<T0, T1>): u64 {
        arg0.fee_rate
    }

    public fun fees_amount<T0, T1>(arg0: &FlashSwapReceipt<T0, T1>): (u64, u64, u64, u64) {
        (arg0.fee_amount, arg0.ref_fee_amount, arg0.protocol_fee_amount, arg0.gauge_fee_amount)
    }

    public fun fees_growth_global<T0, T1>(arg0: &Pool<T0, T1>): (u128, u128) {
        (arg0.fee_growth_global_a, arg0.fee_growth_global_b)
    }

    public fun flash_swap<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: bool,
        arg3: bool,
        arg4: u64,
        arg5: u128,
        arg6: &sui::clock::Clock
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>, FlashSwapReceipt<T0, T1>) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        flash_swap_internal<T0, T1>(arg1, arg0, sui::object::id_from_address(@0x0), 0, arg2, arg3, arg4, arg5, arg6)
    }

    fun flash_swap_internal<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &clmm_pool::config::GlobalConfig,
        arg2: sui::object::ID,
        arg3: u64,
        arg4: bool,
        arg5: bool,
        arg6: u64,
        arg7: u128,
        arg8: &sui::clock::Clock
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>, FlashSwapReceipt<T0, T1>) {
        assert!(arg6 > 0, 0);
        clmm_pool::rewarder::settle(&mut arg0.rewarder_manager, arg0.liquidity, sui::clock::timestamp_ms(arg8) / 1000);
        if (arg4) {
            assert!(arg0.current_sqrt_price > arg7 && arg7 >= clmm_pool::tick_math::min_sqrt_price(), 11);
        } else {
            assert!(arg0.current_sqrt_price < arg7 && arg7 <= clmm_pool::tick_math::max_sqrt_price(), 11);
        };
        let v0 = arg0.unstaked_liquidity_fee_rate;
        let v1 = if (v0 == clmm_pool::config::default_unstaked_fee_rate()) {
            clmm_pool::config::unstaked_liquidity_fee_rate(arg1)
        } else {
            v0
        };
        let v2 = swap_in_pool<T0, T1>(
            arg0,
            arg4,
            arg5,
            arg7,
            arg6,
            v1,
            clmm_pool::config::protocol_fee_rate(arg1),
            arg3,
            arg8
        );
        assert!(v2.amount_out > 0, 18);
        let (v3, v4) = if (arg4) {
            (sui::balance::split<T1>(&mut arg0.coin_b, v2.amount_out), sui::balance::zero<T0>())
        } else {
            (sui::balance::zero<T1>(), sui::balance::split<T0>(&mut arg0.coin_a, v2.amount_out))
        };
        let v5 = SwapEvent {
            atob: arg4,
            pool: sui::object::id<Pool<T0, T1>>(arg0),
            partner: arg2,
            amount_in: v2.amount_in + v2.fee_amount,
            amount_out: v2.amount_out,
            magma_fee_amount: v2.gauge_fee_amount,
            protocol_fee_amount: v2.protocol_fee_amount,
            ref_fee_amount: v2.ref_fee_amount,
            fee_amount: v2.fee_amount,
            vault_a_amount: sui::balance::value<T0>(&arg0.coin_a),
            vault_b_amount: sui::balance::value<T1>(&arg0.coin_b),
            before_sqrt_price: arg0.current_sqrt_price,
            after_sqrt_price: arg0.current_sqrt_price,
            steps: v2.steps,
        };
        sui::event::emit<SwapEvent>(v5);
        let v6 = FlashSwapReceipt<T0, T1> {
            pool_id: sui::object::id<Pool<T0, T1>>(arg0),
            a2b: arg4,
            partner_id: arg2,
            pay_amount: v2.amount_in + v2.fee_amount,
            fee_amount: v2.fee_amount,
            protocol_fee_amount: v2.protocol_fee_amount,
            ref_fee_amount: v2.ref_fee_amount,
            gauge_fee_amount: v2.gauge_fee_amount,
        };
        (v4, v3, v6)
    }

    public fun flash_swap_with_partner<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &clmm_pool::partner::Partner,
        arg3: bool,
        arg4: bool,
        arg5: u64,
        arg6: u128,
        arg7: &sui::clock::Clock
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>, FlashSwapReceipt<T0, T1>) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        flash_swap_internal<T0, T1>(
            arg1,
            arg0,
            sui::object::id<clmm_pool::partner::Partner>(arg2),
            clmm_pool::partner::current_ref_fee_rate(arg2, sui::clock::timestamp_ms(arg7) / 1000),
            arg3,
            arg4,
            arg5,
            arg6,
            arg7
        )
    }

    public fun get_all_growths_in_tick_range<T0, T1>(
        arg0: &Pool<T0, T1>,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32
    ): (u128, u128, vector<u128>, u128, u128) {
        let v0 = clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg1);
        let v1 = clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg2);
        let (v2, v3) = clmm_pool::tick::get_fee_in_range(
            arg0.current_tick_index,
            arg0.fee_growth_global_a,
            arg0.fee_growth_global_b,
            v0,
            v1
        );
        (v2, v3, clmm_pool::tick::get_rewards_in_range(
            arg0.current_tick_index,
            clmm_pool::rewarder::rewards_growth_global(&arg0.rewarder_manager),
            v0,
            v1
        ), clmm_pool::tick::get_points_in_range(
            arg0.current_tick_index,
            clmm_pool::rewarder::points_growth_global(&arg0.rewarder_manager),
            v0,
            v1
        ), clmm_pool::tick::get_magma_distribution_growth_in_range(
            arg0.current_tick_index,
            arg0.magma_distribution_growth_global,
            v0,
            v1
        ))
    }

    public fun get_fee_in_tick_range<T0, T1>(
        arg0: &Pool<T0, T1>,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32
    ): (u128, u128) {
        clmm_pool::tick::get_fee_in_range(
            arg0.current_tick_index,
            arg0.fee_growth_global_a,
            arg0.fee_growth_global_b,
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg1),
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg2)
        )
    }

    public fun get_liquidity_from_amount(
        arg0: integer_mate::i32::I32,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32,
        arg3: u128,
        arg4: u64,
        arg5: bool
    ): (u128, u64, u64) {
        if (arg5) {
            let (v3, v4) = if (integer_mate::i32::lt(arg2, arg0)) {
                (clmm_pool::clmm_math::get_liquidity_from_a(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg0),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg1),
                    arg4,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::lt(arg2, arg1), 19);
                let v5 = clmm_pool::clmm_math::get_liquidity_from_a(
                    arg3,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg1),
                    arg4,
                    false
                );
                (v5, clmm_pool::clmm_math::get_delta_b(
                    arg3,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg0),
                    v5,
                    true
                ))
            };
            (v3, arg4, v4)
        } else {
            let (v6, v7) = if (integer_mate::i32::gte(arg2, arg1)) {
                (clmm_pool::clmm_math::get_liquidity_from_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg0),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg1),
                    arg4,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::gte(arg2, arg0), 19);
                let v8 = clmm_pool::clmm_math::get_liquidity_from_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg0),
                    arg3,
                    arg4,
                    false
                );
                (v8, clmm_pool::clmm_math::get_delta_a(
                    arg3,
                    clmm_pool::tick_math::get_sqrt_price_at_tick(arg1),
                    v8,
                    true
                ))
            };
            (v6, v7, arg4)
        }
    }

    public fun get_magma_distribution_gauger_id<T0, T1>(arg0: &Pool<T0, T1>): sui::object::ID {
        assert!(std::option::is_some<sui::object::ID>(&arg0.magma_distribution_gauger_id), 9223379295349506047);
        *std::option::borrow<sui::object::ID>(&arg0.magma_distribution_gauger_id)
    }

    public fun get_magma_distribution_growth_global<T0, T1>(arg0: &Pool<T0, T1>): u128 {
        arg0.magma_distribution_growth_global
    }

    public fun get_magma_distribution_growth_inside<T0, T1>(
        arg0: &Pool<T0, T1>,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32,
        mut arg3: u128
    ): u128 {
        assert!(check_tick_range(arg1, arg2), 9223378947457155071);
        if (arg3 == 0) {
            arg3 = arg0.magma_distribution_growth_global;
        };
        clmm_pool::tick::get_magma_distribution_growth_in_range(
            arg0.current_tick_index,
            arg3,
            std::option::some<clmm_pool::tick::Tick>(*borrow_tick<T0, T1>(arg0, arg1)),
            std::option::some<clmm_pool::tick::Tick>(*borrow_tick<T0, T1>(arg0, arg2))
        )
    }

    public fun get_magma_distribution_last_updated<T0, T1>(arg0: &Pool<T0, T1>): u64 {
        arg0.magma_distribution_last_updated
    }

    public fun get_magma_distribution_reserve<T0, T1>(arg0: &Pool<T0, T1>): u64 {
        arg0.magma_distribution_reserve
    }

    public fun get_magma_distribution_rollover<T0, T1>(arg0: &Pool<T0, T1>): u64 {
        arg0.magma_distribution_rollover
    }

    public fun get_magma_distribution_staked_liquidity<T0, T1>(arg0: &Pool<T0, T1>): u128 {
        arg0.magma_distribution_staked_liquidity
    }

    public fun get_points_in_tick_range<T0, T1>(
        arg0: &Pool<T0, T1>,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32
    ): u128 {
        clmm_pool::tick::get_points_in_range(
            arg0.current_tick_index,
            clmm_pool::rewarder::points_growth_global(&arg0.rewarder_manager),
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg1),
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg2)
        )
    }

    public fun get_position_amounts<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::object::ID): (u64, u64) {
        let v0 = clmm_pool::position::borrow_position_info(&arg0.position_manager, arg1);
        let (v1, v2) = clmm_pool::position::info_tick_range(v0);
        get_amount_by_liquidity(
            v1,
            v2,
            arg0.current_tick_index,
            arg0.current_sqrt_price,
            clmm_pool::position::info_liquidity(v0),
            false
        )
    }

    public fun get_position_fee<T0, T1>(arg0: &Pool<T0, T1>, arg1: sui::object::ID): (u64, u64) {
        clmm_pool::position::info_fee_owned(clmm_pool::position::borrow_position_info(&arg0.position_manager, arg1))
    }

    public fun get_position_points<T0, T1>(arg0: &Pool<T0, T1>, arg1: sui::object::ID): u128 {
        clmm_pool::position::info_points_owned(clmm_pool::position::borrow_position_info(&arg0.position_manager, arg1))
    }

    public fun get_position_reward<T0, T1, T2>(arg0: &Pool<T0, T1>, arg1: sui::object::ID): u64 {
        let mut v0 = clmm_pool::rewarder::rewarder_index<T2>(&arg0.rewarder_manager);
        assert!(std::option::is_some<u64>(&v0), 17);
        let v1 = clmm_pool::position::rewards_amount_owned(&arg0.position_manager, arg1);
        *std::vector::borrow<u64>(&v1, std::option::extract<u64>(&mut v0))
    }

    public fun get_position_rewards<T0, T1>(arg0: &Pool<T0, T1>, arg1: sui::object::ID): vector<u64> {
        clmm_pool::position::rewards_amount_owned(&arg0.position_manager, arg1)
    }

    public fun get_rewards_in_tick_range<T0, T1>(
        arg0: &Pool<T0, T1>,
        arg1: integer_mate::i32::I32,
        arg2: integer_mate::i32::I32
    ): vector<u128> {
        clmm_pool::tick::get_rewards_in_range(
            arg0.current_tick_index,
            clmm_pool::rewarder::rewards_growth_global(&arg0.rewarder_manager),
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg1),
            clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg2)
        )
    }

    fun init(arg0: POOL, arg1: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer<sui::package::Publisher>(
            sui::package::claim<POOL>(arg0, arg1),
            sui::tx_context::sender(arg1)
        );
    }

    public fun init_magma_distribution_gauge<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: &gauge_cap::gauge_cap::GaugeCap) {
        assert!(gauge_cap::gauge_cap::get_pool_id(arg1) == sui::object::id<Pool<T0, T1>>(arg0), 9223379334004211711);
        std::option::fill<sui::object::ID>(
            &mut arg0.magma_distribution_gauger_id,
            gauge_cap::gauge_cap::get_gauge_id(arg1)
        );
    }

    public fun initialize_rewarder<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::config::check_rewarder_manager_role(arg0, sui::tx_context::sender(arg2));
        clmm_pool::rewarder::add_rewarder<T2>(&mut arg1.rewarder_manager);
        let v0 = AddRewarderEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            rewarder_type: std::type_name::get<T2>(),
        };
        sui::event::emit<AddRewarderEvent>(v0);
    }

    public fun is_pause<T0, T1>(arg0: &Pool<T0, T1>): bool {
        arg0.is_pause
    }

    public fun magma_distribution_gauger_fee<T0, T1>(arg0: &Pool<T0, T1>): PoolFee {
        PoolFee {
            coin_a: arg0.magma_distribution_gauger_fee.coin_a,
            coin_b: arg0.magma_distribution_gauger_fee.coin_b,
        }
    }

    public fun mark_position_unstaked<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: sui::object::ID
    ) {
        assert!(!arg0.is_pause, 13);
        check_gauge_cap<T0, T1>(arg0, arg1);
        clmm_pool::position::mark_position_staked(&mut arg0.position_manager, arg2, false);
    }

    public fun pause<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        clmm_pool::config::check_pool_manager_role(arg0, sui::tx_context::sender(arg2));
        assert!(!arg1.is_pause, 9223376739843964927);
        arg1.is_pause = true;
    }

    public fun pool_fee_a_b(arg0: &PoolFee): (u64, u64) {
        (arg0.coin_a, arg0.coin_b)
    }

    public fun position_manager<T0, T1>(arg0: &Pool<T0, T1>): &clmm_pool::position::PositionManager {
        &arg0.position_manager
    }

    public fun protocol_fee<T0, T1>(arg0: &Pool<T0, T1>): (u64, u64) {
        (arg0.fee_protocol_coin_a, arg0.fee_protocol_coin_b)
    }

    public fun remove_liquidity<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut clmm_pool::position::Position,
        arg3: u128,
        arg4: &sui::clock::Clock
    ): (sui::balance::Balance<T0>, sui::balance::Balance<T1>) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        assert!(arg3 > 0, 3);
        clmm_pool::rewarder::settle(&mut arg1.rewarder_manager, arg1.liquidity, sui::clock::timestamp_ms(arg4) / 1000);
        let (v0, v1) = clmm_pool::position::tick_range(arg2);
        let (v2, v3, v4, v5, v6) = get_all_growths_in_tick_range<T0, T1>(arg1, v0, v1);
        clmm_pool::tick::decrease_liquidity(
            &mut arg1.tick_manager,
            arg1.current_tick_index,
            v0,
            v1,
            arg3,
            arg1.fee_growth_global_a,
            arg1.fee_growth_global_b,
            clmm_pool::rewarder::points_growth_global(&arg1.rewarder_manager),
            clmm_pool::rewarder::rewards_growth_global(&arg1.rewarder_manager),
            arg1.magma_distribution_growth_global
        );
        if (integer_mate::i32::lte(v0, arg1.current_tick_index) && integer_mate::i32::lt(arg1.current_tick_index, v1)) {
            arg1.liquidity = arg1.liquidity - arg3;
        };
        let (v7, v8) = get_amount_by_liquidity(v0, v1, arg1.current_tick_index, arg1.current_sqrt_price, arg3, false);
        let v9 = RemoveLiquidityEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            position: sui::object::id<clmm_pool::position::Position>(arg2),
            tick_lower: v0,
            tick_upper: v1,
            liquidity: arg3,
            after_liquidity: clmm_pool::position::decrease_liquidity(
                &mut arg1.position_manager,
                arg2,
                arg3,
                v2,
                v3,
                v5,
                v4,
                v6
            ),
            amount_a: v7,
            amount_b: v8,
        };
        sui::event::emit<RemoveLiquidityEvent>(v9);
        (sui::balance::split<T0>(&mut arg1.coin_a, v7), sui::balance::split<T1>(&mut arg1.coin_b, v8))
    }

    public fun repay_add_liquidity<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::balance::Balance<T0>,
        arg3: sui::balance::Balance<T1>,
        arg4: AddLiquidityReceipt<T0, T1>
    ) {
        clmm_pool::config::checked_package_version(arg0);
        let AddLiquidityReceipt {
            pool_id: v0,
            amount_a: v1,
            amount_b: v2,
        } = arg4;
        assert!(sui::balance::value<T0>(&arg2) == v1, 0);
        assert!(sui::balance::value<T1>(&arg3) == v2, 0);
        assert!(sui::object::id<Pool<T0, T1>>(arg1) == v0, 12);
        sui::balance::join<T0>(&mut arg1.coin_a, arg2);
        sui::balance::join<T1>(&mut arg1.coin_b, arg3);
    }

    public fun repay_flash_swap<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: sui::balance::Balance<T0>,
        arg3: sui::balance::Balance<T1>,
        arg4: FlashSwapReceipt<T0, T1>
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        let FlashSwapReceipt {
            pool_id: v0,
            a2b: v1,
            partner_id: _,
            pay_amount: v3,
            fee_amount: _,
            protocol_fee_amount: _,
            ref_fee_amount: v6,
            gauge_fee_amount: _,
        } = arg4;
        assert!(sui::object::id<Pool<T0, T1>>(arg1) == v0, 14);
        assert!(v6 == 0, 14);
        if (v1) {
            assert!(sui::balance::value<T0>(&arg2) == v3, 0);
            sui::balance::join<T0>(&mut arg1.coin_a, arg2);
            sui::balance::destroy_zero<T1>(arg3);
        } else {
            assert!(sui::balance::value<T1>(&arg3) == v3, 0);
            sui::balance::join<T1>(&mut arg1.coin_b, arg3);
            sui::balance::destroy_zero<T0>(arg2);
        };
    }

    public fun repay_flash_swap_with_partner<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut clmm_pool::partner::Partner,
        mut arg3: sui::balance::Balance<T0>,
        mut arg4: sui::balance::Balance<T1>,
        arg5: FlashSwapReceipt<T0, T1>
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        let FlashSwapReceipt {
            pool_id: v0,
            a2b: v1,
            partner_id: v2,
            pay_amount: v3,
            fee_amount: _,
            protocol_fee_amount: _,
            ref_fee_amount: v6,
            gauge_fee_amount: _,
        } = arg5;
        assert!(sui::object::id<Pool<T0, T1>>(arg1) == v0, 14);
        assert!(sui::object::id<clmm_pool::partner::Partner>(arg2) == v2, 14);
        if (v1) {
            assert!(sui::balance::value<T0>(&arg3) == v3, 0);
            if (v6 > 0) {
                clmm_pool::partner::receive_ref_fee<T0>(arg2, sui::balance::split<T0>(&mut arg3, v6));
            };
            sui::balance::join<T0>(&mut arg1.coin_a, arg3);
            sui::balance::destroy_zero<T1>(arg4);
        } else {
            assert!(sui::balance::value<T1>(&arg4) == v3, 0);
            if (v6 > 0) {
                clmm_pool::partner::receive_ref_fee<T1>(arg2, sui::balance::split<T1>(&mut arg4, v6));
            };
            sui::balance::join<T1>(&mut arg1.coin_b, arg4);
            sui::balance::destroy_zero<T0>(arg3);
        };
    }

    public fun rewarder_manager<T0, T1>(arg0: &Pool<T0, T1>): &clmm_pool::rewarder::RewarderManager {
        &arg0.rewarder_manager
    }

    public fun set_display<T0, T1>(
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
        let mut v0 = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"name"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"coin_a"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"coin_b"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"link"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"image_url"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"description"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"project_url"));
        std::vector::push_back<std::string::String>(&mut v0, std::string::utf8(b"creator"));
        let mut v1 = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut v1, name);
        std::vector::push_back<std::string::String>(
            &mut v1,
            std::string::from_ascii(std::type_name::into_string(std::type_name::get<T0>()))
        );
        std::vector::push_back<std::string::String>(
            &mut v1,
            std::string::from_ascii(std::type_name::into_string(std::type_name::get<T1>()))
        );
        std::vector::push_back<std::string::String>(&mut v1, link);
        std::vector::push_back<std::string::String>(&mut v1, image_url);
        std::vector::push_back<std::string::String>(&mut v1, description);
        std::vector::push_back<std::string::String>(&mut v1, project_url);
        std::vector::push_back<std::string::String>(&mut v1, creator);
        let mut v2 = sui::display::new_with_fields<Pool<T0, T1>>(publisher, v0, v1, ctx);
        sui::display::update_version<Pool<T0, T1>>(&mut v2);
        sui::transfer::public_transfer<sui::display::Display<Pool<T0, T1>>>(v2, sui::tx_context::sender(ctx));
    }

    fun split_fees(arg0: u64, arg1: u128, arg2: u128, arg3: u64): (u64, u64) {
        let v0 = integer_mate::full_math_u128::mul_div_ceil(arg0 as u128, arg2, arg1);
        let (v1, v2) = apply_unstaked_fees((arg0 as u128) - v0, v0, arg3);
        (v1 as u64, v2 as u64)
    }

    public fun stake_in_magma_distribution<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: u128,
        arg3: integer_mate::i32::I32,
        arg4: integer_mate::i32::I32,
        arg5: &sui::clock::Clock
    ) {
        assert!(!arg0.is_pause, 13);
        assert!(arg2 != 0, 9223379140730683391);
        check_gauge_cap<T0, T1>(arg0, arg1);
        update_magma_distribution_internal<T0, T1>(arg0, integer_mate::i128::from(arg2), arg3, arg4, arg5);
    }

    public fun step_swap_result_amount_in(arg0: &SwapStepResult): u64 {
        arg0.amount_in
    }

    public fun step_swap_result_amount_out(arg0: &SwapStepResult): u64 {
        arg0.amount_out
    }

    public fun step_swap_result_current_liquidity(arg0: &SwapStepResult): u128 {
        arg0.current_liquidity
    }

    public fun step_swap_result_current_sqrt_price(arg0: &SwapStepResult): u128 {
        arg0.current_sqrt_price
    }

    public fun step_swap_result_fee_amount(arg0: &SwapStepResult): u64 {
        arg0.fee_amount
    }

    public fun step_swap_result_remainder_amount(arg0: &SwapStepResult): u64 {
        arg0.remainder_amount
    }

    public fun step_swap_result_target_sqrt_price(arg0: &SwapStepResult): u128 {
        arg0.target_sqrt_price
    }

    fun swap_in_pool<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: bool,
        arg2: bool,
        arg3: u128,
        arg4: u64,
        arg5: u64,
        arg6: u64,
        arg7: u64,
        arg8: &sui::clock::Clock
    ): SwapResult {
        assert!(arg7 <= 10000, 16);
        let mut v0 = default_swap_result();
        let mut v1 = arg4;
        let mut v2 = clmm_pool::tick::first_score_for_swap(&arg0.tick_manager, arg0.current_tick_index, arg1);
        while (v1 > 0 && arg0.current_sqrt_price != arg3) {
            if (move_stl::option_u64::is_none(&v2)) {
                abort 20
            };
            let (v3, v4) = clmm_pool::tick::borrow_tick_for_swap(
                &arg0.tick_manager,
                move_stl::option_u64::borrow(&v2),
                arg1
            );
            v2 = v4;
            let v5 = clmm_pool::tick::index(v3);
            let v6 = clmm_pool::tick::sqrt_price(v3);
            let v7 = if (arg1) {
                integer_mate::math_u128::max(arg3, v6)
            } else {
                integer_mate::math_u128::min(arg3, v6)
            };
            let (v8, v9, v10, v11) = clmm_pool::clmm_math::compute_swap_step(
                arg0.current_sqrt_price,
                v7,
                arg0.liquidity,
                v1,
                arg0.fee_rate,
                arg1,
                arg2
            );
            if (v8 != 0 || v11 != 0) {
                if (arg2) {
                    let v12 = check_remainer_amount_sub(v1, v8);
                    v1 = check_remainer_amount_sub(v12, v11);
                } else {
                    v1 = check_remainer_amount_sub(v1, v9);
                };
                let v13 = integer_mate::full_math_u64::mul_div_ceil(
                    v11,
                    arg7,
                    clmm_pool::config::protocol_fee_rate_denom()
                );
                let v14 = v11 - v13;
                let mut v15 = v14;
                let mut v16 = 0;
                let mut v17 = 0;
                if (v14 > 0) {
                    let v18 = integer_mate::full_math_u64::mul_div_ceil(
                        v14,
                        arg6,
                        clmm_pool::config::protocol_fee_rate_denom()
                    );
                    v17 = v18;
                    let v19 = v14 - v18;
                    v15 = v19;
                    if (v19 > 0) {
                        let (_, v21) = calculate_fees<T0, T1>(
                            arg0,
                            v19,
                            arg0.liquidity,
                            arg0.magma_distribution_staked_liquidity,
                            arg5
                        );
                        v16 = v21;
                        v15 = v19 - v21;
                    };
                };
                update_swap_result(&mut v0, v8, v9, v11, v17, v13, v16);
                if (v15 > 0) {
                    update_fee_growth_global<T0, T1>(arg0, v15, arg1);
                };
            };
            if (v10 == v6) {
                arg0.current_sqrt_price = v7;
                let v22 = if (arg1) {
                    integer_mate::i32::sub(v5, integer_mate::i32::from(1))
                } else {
                    v5
                };
                arg0.current_tick_index = v22;
                update_magma_distribution_growth_global_internal<T0, T1>(arg0, arg8);
                let (v23, v24) = clmm_pool::tick::cross_by_swap(
                    &mut arg0.tick_manager,
                    v5,
                    arg1,
                    arg0.liquidity,
                    arg0.magma_distribution_staked_liquidity,
                    arg0.fee_growth_global_a,
                    arg0.fee_growth_global_b,
                    clmm_pool::rewarder::points_growth_global(&arg0.rewarder_manager),
                    clmm_pool::rewarder::rewards_growth_global(&arg0.rewarder_manager),
                    arg0.magma_distribution_growth_global
                );
                arg0.liquidity = v23;
                arg0.magma_distribution_staked_liquidity = v24;
                continue
            };
            if (arg0.current_sqrt_price != v10) {
                arg0.current_sqrt_price = v10;
                arg0.current_tick_index = clmm_pool::tick_math::get_tick_at_sqrt_price(v10);
                continue
            };
        };
        if (arg1) {
            arg0.fee_protocol_coin_a = arg0.fee_protocol_coin_a + v0.protocol_fee_amount;
            arg0.magma_distribution_gauger_fee.coin_a = arg0.magma_distribution_gauger_fee.coin_a + v0.gauge_fee_amount;
        } else {
            arg0.fee_protocol_coin_b = arg0.fee_protocol_coin_b + v0.protocol_fee_amount;
            arg0.magma_distribution_gauger_fee.coin_b = arg0.magma_distribution_gauger_fee.coin_b + v0.gauge_fee_amount;
        };
        v0
    }

    public fun swap_pay_amount<T0, T1>(arg0: &FlashSwapReceipt<T0, T1>): u64 {
        arg0.pay_amount
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

    public fun tick_manager<T0, T1>(arg0: &Pool<T0, T1>): &clmm_pool::tick::TickManager {
        &arg0.tick_manager
    }

    public fun tick_spacing<T0, T1>(arg0: &Pool<T0, T1>): u32 {
        arg0.tick_spacing
    }

    public fun unpause<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        clmm_pool::config::check_pool_manager_role(arg0, sui::tx_context::sender(arg2));
        assert!(arg1.is_pause, 9223378204427812863);
        arg1.is_pause = false;
    }

    public fun unstake_from_magma_distribution<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: u128,
        arg3: integer_mate::i32::I32,
        arg4: integer_mate::i32::I32,
        arg5: &sui::clock::Clock
    ) {
        assert!(!arg0.is_pause, 13);
        assert!(arg2 != 0, 9223379200860225535);
        check_gauge_cap<T0, T1>(arg0, arg1);
        update_magma_distribution_internal<T0, T1>(
            arg0,
            integer_mate::i128::neg(integer_mate::i128::from(arg2)),
            arg3,
            arg4,
            arg5
        );
    }

    fun update_fee_growth_global<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: u64, arg2: bool) {
        if (arg1 == 0 || arg0.liquidity == 0) {
            return
        };
        if (arg2) {
            arg0.fee_growth_global_a = integer_mate::math_u128::wrapping_add(
                arg0.fee_growth_global_a,
                ((arg1 as u128) << 64) / arg0.liquidity
            );
        } else {
            arg0.fee_growth_global_b = integer_mate::math_u128::wrapping_add(
                arg0.fee_growth_global_b,
                ((arg1 as u128) << 64) / arg0.liquidity
            );
        };
    }

    public fun update_fee_rate<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: u64,
        arg3: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        if (arg2 > clmm_pool::config::max_fee_rate()) {
            abort 9
        };
        clmm_pool::config::check_pool_manager_role(arg0, sui::tx_context::sender(arg3));
        arg1.fee_rate = arg2;
        let v0 = UpdateFeeRateEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            old_fee_rate: arg1.fee_rate,
            new_fee_rate: arg2,
        };
        sui::event::emit<UpdateFeeRateEvent>(v0);
    }

    public fun update_magma_distribution_growth_global<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &gauge_cap::gauge_cap::GaugeCap,
        arg2: &sui::clock::Clock
    ) {
        assert!(!arg0.is_pause, 13);
        check_gauge_cap<T0, T1>(arg0, arg1);
        update_magma_distribution_growth_global_internal<T0, T1>(arg0, arg2);
    }

    fun update_magma_distribution_growth_global_internal<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: &sui::clock::Clock
    ): u64 {
        let v0 = sui::clock::timestamp_ms(arg1) / 1000;
        let v1 = v0 - arg0.magma_distribution_last_updated;
        let mut v2 = 0;
        if (v1 != 0) {
            if (arg0.magma_distribution_reserve > 0) {
                let v3 = integer_mate::full_math_u128::mul_div_floor(
                    arg0.magma_distribution_rate,
                    v1 as u128,
                    18446744073709551616
                ) as u64;
                let mut v4 = v3;
                if (v3 > arg0.magma_distribution_reserve) {
                    v4 = arg0.magma_distribution_reserve;
                };
                arg0.magma_distribution_reserve = arg0.magma_distribution_reserve - v4;
                if (arg0.magma_distribution_staked_liquidity > 0) {
                    arg0.magma_distribution_growth_global = arg0.magma_distribution_growth_global + integer_mate::full_math_u128::mul_div_floor(
                        v4 as u128,
                        18446744073709551616,
                        arg0.magma_distribution_staked_liquidity
                    );
                } else {
                    arg0.magma_distribution_rollover = arg0.magma_distribution_rollover + v4;
                };
                v2 = v4;
            };
            arg0.magma_distribution_last_updated = v0;
        };
        v2
    }

    fun update_magma_distribution_internal<T0, T1>(
        arg0: &mut Pool<T0, T1>,
        arg1: integer_mate::i128::I128,
        arg2: integer_mate::i32::I32,
        arg3: integer_mate::i32::I32,
        arg4: &sui::clock::Clock
    ) {
        if (integer_mate::i32::gte(arg0.current_tick_index, arg2) && integer_mate::i32::lt(
            arg0.current_tick_index,
            arg3
        )) {
            update_magma_distribution_growth_global_internal<T0, T1>(arg0, arg4);
            if (integer_mate::i128::is_neg(arg1)) {
                assert!(
                    arg0.magma_distribution_staked_liquidity >= integer_mate::i128::abs_u128(arg1),
                    9223379024766566399
                );
            } else {
                let (_, v1) = integer_mate::i128::overflowing_add(
                    integer_mate::i128::from(arg0.magma_distribution_staked_liquidity),
                    arg1
                );
                assert!(!v1, 9223379033357877270);
            };
            arg0.magma_distribution_staked_liquidity = integer_mate::i128::as_u128(
                integer_mate::i128::add(integer_mate::i128::from(arg0.magma_distribution_staked_liquidity), arg1)
            );
        };
        let v2 = clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg2);
        let v3 = clmm_pool::tick::try_borrow_tick(&arg0.tick_manager, arg3);
        if (std::option::is_some<clmm_pool::tick::Tick>(&v2)) {
            clmm_pool::tick::update_magma_stake(&mut arg0.tick_manager, arg2, arg1, false);
        };
        if (std::option::is_some<clmm_pool::tick::Tick>(&v3)) {
            clmm_pool::tick::update_magma_stake(&mut arg0.tick_manager, arg3, arg1, true);
        };
    }

    public fun update_position_url<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: std::string::String,
        arg3: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        clmm_pool::config::check_pool_manager_role(arg0, sui::tx_context::sender(arg3));
        arg1.url = arg2;
    }

    fun update_swap_result(arg0: &mut SwapResult, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: u64) {
        assert!(integer_mate::math_u64::add_check(arg0.amount_in, arg1), 6);
        assert!(integer_mate::math_u64::add_check(arg0.amount_out, arg2), 7);
        assert!(integer_mate::math_u64::add_check(arg0.fee_amount, arg3), 8);
        arg0.amount_in = arg0.amount_in + arg1;
        arg0.amount_out = arg0.amount_out + arg2;
        arg0.fee_amount = arg0.fee_amount + arg3;
        arg0.protocol_fee_amount = arg0.protocol_fee_amount + arg4;
        arg0.gauge_fee_amount = arg0.gauge_fee_amount + arg6;
        arg0.ref_fee_amount = arg0.ref_fee_amount + arg5;
        arg0.steps = arg0.steps + 1;
    }

    public fun update_unstaked_liquidity_fee_rate<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut Pool<T0, T1>,
        arg2: u64,
        arg3: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(arg0);
        assert!(!arg1.is_pause, 13);
        assert!(
            arg2 == clmm_pool::config::default_unstaked_fee_rate(
            ) || arg2 <= clmm_pool::config::max_unstaked_liquidity_fee_rate(),
            9
        );
        assert!(arg2 != arg1.unstaked_liquidity_fee_rate, 9);
        clmm_pool::config::check_pool_manager_role(arg0, sui::tx_context::sender(arg3));
        arg1.unstaked_liquidity_fee_rate = arg2;
        let v0 = UpdateUnstakedLiquidityFeeRateEvent {
            pool: sui::object::id<Pool<T0, T1>>(arg1),
            old_fee_rate: arg1.unstaked_liquidity_fee_rate,
            new_fee_rate: arg2,
        };
        sui::event::emit<UpdateUnstakedLiquidityFeeRateEvent>(v0);
    }

    public fun url<T0, T1>(arg0: &Pool<T0, T1>): std::string::String {
        arg0.url
    }

    fun validate_pool_position<T0, T1>(arg0: &Pool<T0, T1>, arg1: &clmm_pool::position::Position) {
        assert!(sui::object::id<Pool<T0, T1>>(arg0) == clmm_pool::position::pool_id(arg1), 9223373806381301759);
    }

    // decompiled from Move bytecode v6
}


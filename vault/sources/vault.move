module vault::vault {
    public struct LiquidityRange has drop, store {
        lower_offset: u32,
        upper_offset: u32,
        rebalance_threshold: u32, // минимальное отклонение тиков для ребаланса
    }
    
    public struct ClmmVault has store {
        pool_id: sui::object::ID,
        coin_a: std::type_name::TypeName,
        coin_b: std::type_name::TypeName,
        liquidity_range: LiquidityRange,
        wrapped_position: std::option::Option<governance::gauge::StakedPosition>,
    }
    
    public struct MigrateLiquidity has copy, drop {
        old_position: sui::object::ID,
        new_position: sui::object::ID,
        old_tick_lower: integer_mate::i32::I32,
        old_tick_upper: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
        new_tick_lower: integer_mate::i32::I32,
        amount_a: u64,
        amount_b: u64,
    }

    public fun new<CoinTypeA, CoinTypeB>(
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32,
        upper_offset: u32, 
        rebalance_threshold: u32,
        mut start_balance_a: sui::balance::Balance<CoinTypeA>,
        mut start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : ClmmVault {
        let liquidity_range = LiquidityRange{
            lower_offset        : lower_offset,
            upper_offset        : upper_offset, 
            rebalance_threshold : rebalance_threshold,
        };
        let (tick_lower, tick_upper) = next_position_range(
            liquidity_range.lower_offset, 
            liquidity_range.upper_offset, 
            pool.tick_spacing(), 
            pool.current_tick_index()
        );
        let mut position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            pool, 
            integer_mate::i32::as_u32(tick_lower), 
            integer_mate::i32::as_u32(tick_upper), 
            ctx
        );
        let (_, _, _) = increase_liquidity_internal<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            clmm_vault,
            pool, 
            &mut position,
            &mut start_balance_a,
            &mut start_balance_b, 
            clock
        );
        transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(sui::coin::from_balance<CoinTypeA>(start_balance_a, ctx), ctx.sender());
        transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(sui::coin::from_balance<CoinTypeB>(start_balance_b, ctx), ctx.sender());

        let staked_position = governance::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );
        
        ClmmVault{
            pool_id          : sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            coin_a           : std::type_name::with_defining_ids<CoinTypeA>(), 
            coin_b           : std::type_name::with_defining_ids<CoinTypeB>(), 
            liquidity_range  : liquidity_range, 
            wrapped_position : std::option::some<governance::gauge::StakedPosition>(
                staked_position
            ),
        }
    }

    public fun next_position_range(
        lower_offset: u32, 
        upper_offset: u32, 
        tick_spacing: u32, 
        current_tick: integer_mate::i32::I32
    ) : (integer_mate::i32::I32, integer_mate::i32::I32) {
        (
            round_tick_to_spacing(
                integer_mate::i32::sub(current_tick, integer_mate::i32::from_u32(lower_offset)), 
                tick_spacing
            ), 
            round_tick_to_spacing(
                integer_mate::i32::add(current_tick, integer_mate::i32::from_u32(upper_offset)), 
                tick_spacing
            )
        )
    }

    fun round_tick_to_spacing(tick: integer_mate::i32::I32, tick_spacing: u32) : integer_mate::i32::I32 {
        if (tick.is_neg()) {
            tick.add(integer_mate::i32::from_u32(tick.abs_u32() % tick_spacing))
        } else {
            tick.sub(integer_mate::i32::from_u32(tick.abs_u32() % tick_spacing))
        }
    }

    public fun rebalance<CoinTypeA, CoinTypeB>(
        vault: &mut ClmmVault, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        mut balance_a: sui::balance::Balance<CoinTypeA>, 
        mut balance_b: sui::balance::Balance<CoinTypeB>, 
        tick_lower: integer_mate::i32::I32, 
        tick_upper: integer_mate::i32::I32, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, MigrateLiquidity) {
        let staked_position = std::option::extract<governance::gauge::StakedPosition>(&mut vault.wrapped_position);
        let mut position = gauge.withdraw_position<CoinTypeA, CoinTypeB>(
            distribution_config,
            pool,
            staked_position,
            clock,
            ctx,
        );

        let old_position_id = sui::object::id<clmm_pool::position::Position>(&position);
        let (old_tick_lower, old_tick_upper) = clmm_pool::position::tick_range(&position);
        let liquidity = clmm_pool::position::liquidity(&position);
        if (liquidity > 0) {
            std::debug::print(&std::string::utf8("remove_liquidity"));
            let (removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
                clmm_global_config,
                clmm_vault,
                pool, 
                &mut position, 
                liquidity, 
                clock
            );
            balance_a.join(removed_a); 
            balance_b.join(removed_b);
        };
        let amount_a = sui::balance::value<CoinTypeA>(&balance_a);
        let amount_b = sui::balance::value<CoinTypeB>(&balance_b);
        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            pool,
            position
        );
        let mut new_position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            pool,
            integer_mate::i32::as_u32(tick_lower), 
            integer_mate::i32::as_u32(tick_upper), 
            ctx
        );

        let new_position_id = sui::object::id<clmm_pool::position::Position>(&new_position);

        let (_, _, _) = increase_liquidity_internal<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            clmm_vault,
            pool, 
            &mut new_position,
            &mut balance_a, 
            &mut balance_b, 
            clock
        );
        let new_staked_position = governance::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            distribution_config,
            gauge,
            pool,
            new_position,
            clock,
            ctx
        );

        std::option::fill<governance::gauge::StakedPosition>(&mut vault.wrapped_position, new_staked_position);

        let migrate_liquidity = MigrateLiquidity{
            old_position   : old_position_id, 
            new_position   : new_position_id,
            old_tick_lower : old_tick_lower, 
            old_tick_upper : old_tick_upper, 
            new_tick_upper : tick_upper, 
            new_tick_lower : tick_lower, 
            amount_a       : amount_a, 
            amount_b       : amount_b,
        };
        (balance_a, balance_b, migrate_liquidity)
    }

    public fun decrease_liquidity<CoinTypeA, CoinTypeB>(
        vault: &mut ClmmVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        liquidity: u128, 
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        gauge.decrease_liquidity<CoinTypeA, CoinTypeB>(
            distribution_config,
            clmm_global_config,
            clmm_vault,
            pool,
            std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position),
            liquidity,
            clock,
            ctx
        )
    }

    public fun increase_liquidity<CoinTypeA, CoinTypeB>(
        vault: &mut ClmmVault,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        balance_a: &mut sui::balance::Balance<CoinTypeA>, 
        balance_b: &mut sui::balance::Balance<CoinTypeB>, 
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : (u64, u64, u128) {
        let mut position = gauge.withdraw_position<CoinTypeA, CoinTypeB>(
            distribution_config,
            pool,
            vault.wrapped_position.extract(),
            clock,
            ctx
        );

        let (pay_amount_a, pay_amount_b, liqudity_calc_finish) = increase_liquidity_internal<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            clmm_vault, 
            pool, 
            &mut position, 
            balance_a, 
            balance_b, 
            clock
        );

        let new_staked_position = governance::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        std::option::fill<governance::gauge::StakedPosition>(&mut vault.wrapped_position, new_staked_position);

        (pay_amount_a, pay_amount_b, liqudity_calc_finish)
    }
    
    fun increase_liquidity_internal<CoinTypeA, CoinTypeB>(
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        balance_a: &mut sui::balance::Balance<CoinTypeA>,
        balance_b: &mut sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock
    ) : (u64, u64, u128) {
        let amount_a = sui::balance::value<CoinTypeA>(balance_a);
        let amount_b = sui::balance::value<CoinTypeB>(balance_b);   
        let current_tick_index = pool.current_tick_index<CoinTypeA, CoinTypeB>();
        let current_sqrt_price = pool.current_sqrt_price<CoinTypeA, CoinTypeB>();
        let (tick_lower, tick_upper) = clmm_pool::position::tick_range(position);
        let (liqudity_calc, _, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
            tick_lower, 
            tick_upper,
            current_tick_index, 
            current_sqrt_price, 
            amount_a,
            true
        );
        let liqudity_calc_finish = if (amount_b_calc <= amount_b) {
            liqudity_calc
        } else {
            let (liqudity_calc_finish, _, _) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower, 
                tick_upper, 
                current_tick_index, 
                current_sqrt_price, 
                amount_b, 
                false
            );
            liqudity_calc_finish
        };
        if (liqudity_calc_finish == 0) {
            return (0, 0, 0)
        };
        let receipt = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            clmm_vault,
            pool,
            position,
            liqudity_calc_finish,
            clock
        );
        let (pay_amount_a, pay_amount_b) = clmm_pool::pool::add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        assert!(pay_amount_a <= amount_a, vault::error::amount_in_above_max_limit());
        assert!(pay_amount_b <= amount_b, vault::error::amount_in_above_max_limit());
        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            pool, 
            sui::balance::split<CoinTypeA>(balance_a, pay_amount_a), 
            sui::balance::split<CoinTypeB>(balance_b, pay_amount_b), 
            receipt
        );
        (pay_amount_a, pay_amount_b, liqudity_calc_finish)
    }
    
    public fun collect_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
        vault: &ClmmVault,
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : sui::balance::Balance<OsailCoinType> {
       sui::coin::into_balance<OsailCoinType>(governance::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
            minter,
            distribution_config,
            gauge,
            pool,
            std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position),
            clock,
            ctx
        ))
    }
    
    public fun collect_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        vault: &ClmmVault, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ) : sui::balance::Balance<RewardCoinType> {

        governance::gauge::get_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
            clmm_global_config,
            rewarder_vault,
            gauge,
            distribution_config,
            pool,
            std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position),
            clock
        )
    }
    
    // public fun assert_fee_reward_claimed<CoinTypeA, CoinTypeB>(
    //     vault: &ClmmVault, 
    //     clmm_global_config: &clmm_pool::config::GlobalConfig,
    //     clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
    //     pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
    //     clock: &sui::clock::Clock
    //     ) {
    //     let staked_position = std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position);
    //     let staked_position_id = sui::object::id<governance::gauge::StakedPosition>(staked_position);
    //     let (fee_a, fee_b) = clmm_pool::pool::calculate_and_update_fee<CoinTypeA, CoinTypeB>(
    //         clmm_global_config, 
    //         pool, 
    //         staked_position_id
    //     );
    //     assert!(fee_a == 0 && fee_b == 0, vault::error::fee_claim_err());
    //     let rewards = clmm_pool::pool::calculate_and_update_rewards<CoinTypeA, CoinTypeB>(
    //         clmm_global_config,
    //         clmm_vault,
    //         pool,
    //         staked_position.position_id(),
    //         clock
    //     );
    //     let i = 0; 
    //     while (i < std::vector::length<u64>(&rewards)) {
    //         let reward = std::vector::borrow<u64>(&rewards, i);
    //         assert!(reward == 0, vault::error::mining_claim_err());    
    //         i = i + 1;
    //     };
    // }
    
    public fun borrow_staked_position(vault: &ClmmVault) : &governance::gauge::StakedPosition {
        vault.wrapped_position.borrow()
    }
    
    public fun coin_types(vault: &ClmmVault) : (std::type_name::TypeName, std::type_name::TypeName) {
        (vault.coin_a, vault.coin_b)
    }
    
    public fun get_liquidity_range(vault: &ClmmVault) : (u32, u32, u32) {
        (vault.liquidity_range.lower_offset, vault.liquidity_range.upper_offset, vault.liquidity_range.rebalance_threshold)
    }
    
    public fun get_position_liquidity<CoinTypeA, CoinTypeB>(
        vault: &ClmmVault, 
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>
        ) : u128 {
        clmm_pool::position::liquidity(
            gauge.borrow_position<CoinTypeA, CoinTypeB>(
                std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position)
            )
        )
    }

    public fun get_position_tick_range<CoinTypeA, CoinTypeB>(
        vault: &ClmmVault, 
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>
        ) : (integer_mate::i32::I32, integer_mate::i32::I32) {
        clmm_pool::position::tick_range(
            gauge.borrow_position<CoinTypeA, CoinTypeB>(
                std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position)
            )
        )
    }
    
    public fun liquidity_value<CoinTypeA, CoinTypeB>(
        vault: &ClmmVault, 
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ) : (u64, u64) {
        let position = gauge.borrow_position<CoinTypeA, CoinTypeB>(
            std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position)
        );
        let (tick_lower, tick_upper) = position.tick_range();
        clmm_pool::clmm_math::get_amount_by_liquidity(
            tick_lower, 
            tick_upper, 
            pool.current_tick_index<CoinTypeA, CoinTypeB>(), 
            pool.current_sqrt_price<CoinTypeA, CoinTypeB>(), 
            position.liquidity(), 
            false
        )
    }
    
    public fun pool_id(vault: &ClmmVault) : sui::object::ID {
        vault.pool_id
    }
    
    public fun rebalance_threshold(vault: &ClmmVault) : u32 {
        vault.liquidity_range.rebalance_threshold
    }
    
    public fun update_liquidity_offset(vault: &mut ClmmVault, lower_offset: u32, upper_offset: u32) {
        assert!(lower_offset > 0 && upper_offset > 0, vault::error::invalid_liquidity_range());
        vault.liquidity_range.lower_offset = lower_offset;
        vault.liquidity_range.upper_offset = upper_offset;
    }
    
    public fun update_rebalance_threshold(vault: &mut ClmmVault, rebalance_threshold: u32) {
        vault.liquidity_range.rebalance_threshold = rebalance_threshold;
    }
}


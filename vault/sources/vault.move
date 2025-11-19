module vault::vault {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    public struct LiquidityRange has drop, store {
        lower_offset: u32,
        upper_offset: u32,
        rebalance_threshold: u32, // minimum tick deviation required for rebalancing
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

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    /// Initializes a new `ClmmVault` and stakes an initial position in the CLMM pool.
    ///
    /// Opens a position using the provided tick offsets, deposits the starting
    /// balances, stakes the position in the gauge, and returns a vault object
    /// encapsulating the staking state.
    ///
    /// # Arguments
    /// * `clmm_global_config` – global configuration of the CLMM module
    /// * `clmm_vault` – global reward vault for CLMM incentives
    /// * `distribution_config` – reward distribution configuration used when staking
    /// * `gauge` – gauge receiving the staked position
    /// * `pool` – CLMM pool where the position is opened
    /// * `lower_offset` – lower tick offset from the current price
    /// * `upper_offset` – upper tick offset from the current price
    /// * `rebalance_threshold` – threshold that triggers future rebalancing
    /// * `start_balance_a` – initial balance for coin `CoinTypeA`
    /// * `start_balance_b` – initial balance for coin `CoinTypeB`
    /// * `clock` – clock object for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    ///
    /// # Returns
    /// * newly constructed `ClmmVault` containing the staked position
    ///
    /// # Aborts
    /// * if opening the position or increasing liquidity aborts internally
    public fun new<CoinTypeA, CoinTypeB>(
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32,
        upper_offset: u32, 
        rebalance_threshold: u32,
        start_balance_a: sui::balance::Balance<CoinTypeA>,
        start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : ClmmVault {
        let liquidity_range = LiquidityRange{
            lower_offset        : lower_offset,
            upper_offset        : upper_offset, 
            rebalance_threshold : rebalance_threshold,
        };
        
        let (staked_position, start_balance_a, start_balance_b) = create_staked_position<CoinTypeA, CoinTypeB>(
            distribution_config,
            gauge,
            clmm_global_config, 
            clmm_vault,
            pool,
            liquidity_range.lower_offset, 
            liquidity_range.upper_offset,
            start_balance_a,
            start_balance_b,
            clock,
            ctx
        );

        transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(sui::coin::from_balance<CoinTypeA>(start_balance_a, ctx), ctx.sender());
        transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(sui::coin::from_balance<CoinTypeB>(start_balance_b, ctx), ctx.sender());
        
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

    fun create_staked_position<CoinTypeA, CoinTypeB>(
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lower_offset: u32,
        upper_offset: u32,
        mut start_balance_a: sui::balance::Balance<CoinTypeA>,
        mut start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : (governance::gauge::StakedPosition, sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let (tick_lower, tick_upper) = next_position_range(
            lower_offset, 
            upper_offset, 
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

        let staked_position = governance::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            clmm_global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        (staked_position, start_balance_a, start_balance_b)
    }

    /// Calculates the next tick range for a CLMM position using offsets.
    ///
    /// Adjusts the current tick by the provided offsets and rounds the resulting bounds
    /// to the pool’s tick spacing.
    ///
    /// # Arguments
    /// * `lower_offset` – number of ticks to subtract from the current tick
    /// * `upper_offset` – number of ticks to add to the current tick
    /// * `tick_spacing` – pool tick spacing used for rounding
    /// * `current_tick` – current pool tick
    ///
    /// # Returns
    /// * tuple `(tick_lower, tick_upper)` representing the rounded range
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

    /// Rebalances the vault position to a new tick range and returns leftover balances.
    ///
    /// Withdraws the staked position from the gauge, removes existing liquidity,
    /// closes the old position, opens a new one with provided ticks, reinvests the
    /// available balances, re-stakes the position, and returns remaining balances
    /// alongside migration metadata.
    ///
    /// # Arguments
    /// * `vault` – mutable reference to the `ClmmVault` being rebalanced
    /// * `distribution_config` – reward distribution configuration used during staking
    /// * `gauge` – gauge controlling the staked position
    /// * `clmm_global_config` – global configuration for the CLMM module
    /// * `clmm_vault` – global reward vault for CLMM incentives
    /// * `pool` – CLMM pool in which the position exists
    /// * `balance_a` – buffer balance for coin `CoinTypeA`
    /// * `balance_b` – buffer balance for coin `CoinTypeB`
    /// * `tick_lower` – lower tick for the new position
    /// * `tick_upper` – upper tick for the new position
    /// * `clock` – clock object for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    ///
    /// # Returns
    /// * tuple `(balance_a, balance_b, migrate_info)` with leftover balances and migration data
    ///
    /// # Aborts
    /// * if removing or adding liquidity, or staking operations abort internally
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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());
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

    /// Removes liquidity from the staked position and returns withdrawn balances.
    ///
    /// Delegates to the gauge to decrease liquidity for the wrapped position while
    /// maintaining staking state.
    ///
    /// # Arguments
    /// * `vault` – mutable reference to the `ClmmVault` holding the staked position
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – gauge managing the staked position
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `clmm_vault` – CLMM reward vault
    /// * `pool` – CLMM pool associated with the position
    /// * `liquidity` – amount of liquidity to remove
    /// * `clock` – clock object for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    ///
    /// # Returns
    /// * tuple of balances `(balance_a, balance_b)` withdrawn from the pool
    ///
    /// # Aborts
    /// * if the gauge operation aborts internally
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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());
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

    /// Adds liquidity to the staked position using buffered balances.
    ///
    /// Temporarily withdraws the position from the gauge, increases liquidity with the
    /// provided balances, re-stakes the position, and returns the amounts consumed.
    ///
    /// # Arguments
    /// * `vault` – mutable reference to the `ClmmVault` with the staked position
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `clmm_vault` – CLMM reward vault used when adding liquidity
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – gauge managing the staked position
    /// * `pool` – CLMM pool where liquidity is added
    /// * `balance_a` – mutable balance of coin `CoinTypeA` used for the operation
    /// * `balance_b` – mutable balance of coin `CoinTypeB` used for the operation
    /// * `clock` – clock object for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    ///
    /// # Returns
    /// * tuple `(amount_a, amount_b, liquidity_added)` describing the resources consumed
    ///
    /// # Aborts
    /// * if gauge or CLMM operations abort internally
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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());
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

    /// Halts the CLMM vault by withdrawing the entire staked position’s liquidity,
    /// closing the position, and returning the extracted balances.
    ///
    /// Pulls the position out of the gauge, removes any remaining liquidity from the pool,
    /// and closes the underlying CLMM position. The vault’s `wrapped_position` is cleared
    /// in the process.
    ///
    /// # Arguments
    /// * `vault` – mutable reference to the `ClmmVault` that currently holds a position
    /// * `clmm_global_config` – CLMM global configuration
    /// * `clmm_vault` – CLMM rewarder global vault used for liquidity incentives
    /// * `distribution_config` – governance distribution configuration
    /// * `gauge` – gauge managing the staked position
    /// * `pool` – CLMM pool from which liquidity is removed
    /// * `clock` – clock resource for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the CLMM pair
    /// * `CoinTypeB` – second coin type in the CLMM pair
    ///
    /// # Returns
    /// * tuple containing the balances withdrawn from the position
    public fun stop_vault<CoinTypeA, CoinTypeB>(
        vault: &mut ClmmVault,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) : (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());

        let mut position = gauge.withdraw_position<CoinTypeA, CoinTypeB>(
            distribution_config,
            pool,
            vault.wrapped_position.extract(),
            clock,
            ctx
        );

        let mut balance_a = sui::balance::zero<CoinTypeA>();
        let mut balance_b = sui::balance::zero<CoinTypeB>();
        let liquidity = clmm_pool::position::liquidity(&position);
        if (liquidity > 0) {
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

        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            pool,
            position
        );

        (balance_a, balance_b)
    }

    /// Starts the CLMM vault by creating and staking a new position, returning any unused
    /// portions of the supplied starting balances.
    ///
    /// Delegates the bootstrap to `create_staked_position`, which deposits liquidity into
    /// the pool, configures the tick range, and registers the staked position in the gauge.
    /// After this call the vault stores the resulting `wrapped_position`.
    ///
    /// # Arguments
    /// * `vault` – mutable reference to the `ClmmVault` that must not already contain a position
    /// * `clmm_global_config` – CLMM global configuration
    /// * `clmm_vault` – CLMM rewarder global vault used for liquidity incentives
    /// * `distribution_config` – governance distribution configuration
    /// * `gauge` – gauge responsible for managing the staked position
    /// * `pool` – CLMM pool that receives the liquidity
    /// * `start_balance_a` – starting balance for the first coin type
    /// * `start_balance_b` – starting balance for the second coin type
    /// * `clock` – clock resource for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the CLMM pair
    /// * `CoinTypeB` – second coin type in the CLMM pair
    ///
    /// # Returns
    /// * tuple containing the remaining balances after the position is created
    public fun start_vault<CoinTypeA, CoinTypeB>(
        vault: &mut ClmmVault,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        start_balance_a: sui::balance::Balance<CoinTypeA>,
        start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) : (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        assert!(vault.wrapped_position.is_none(), vault::error::vault_started());

        let (staked_position, start_balance_a, start_balance_b) = create_staked_position<CoinTypeA, CoinTypeB>(
            distribution_config,
            gauge,
            clmm_global_config,
            clmm_vault,
            pool,
            vault.liquidity_range.lower_offset,
            vault.liquidity_range.upper_offset,
            start_balance_a,
            start_balance_b,
            clock,
            ctx
        );

        std::option::fill<governance::gauge::StakedPosition>(&mut vault.wrapped_position, staked_position);

        (start_balance_a, start_balance_b)
    }

    /// Collects OSAIL rewards earned by the vault’s staked position.
    ///
    /// Delegates reward retrieval to the minter via the gauge and returns the result as
    /// a balance.
    ///
    /// # Arguments
    /// * `vault` – reference to the `ClmmVault` holding the staked position
    /// * `minter` – minter responsible for distributing Sail/OSAIL rewards
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – gauge managing the staked position
    /// * `pool` – CLMM pool associated with the position
    /// * `clock` – clock object for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    /// * `SailCoinType` – Sail token type handled by the minter
    /// * `OsailCoinType` – epoch-specific OSAIL token type
    ///
    /// # Returns
    /// * balance of OSAIL rewards collected for the position
    public fun collect_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
        vault: &ClmmVault,
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : sui::balance::Balance<OsailCoinType> {
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());

        sui::coin::into_balance<OsailCoinType>(
            governance::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
                minter,
                distribution_config,
                gauge,
                pool,
                std::option::borrow<governance::gauge::StakedPosition>(&vault.wrapped_position),
                clock,
                ctx
            )
        )
    }
    
    /// Collects pool reward balances earned by the staked position.
    ///
    /// Pulls rewards via the gauge from the CLMM rewarder vault and returns them as a
    /// balance.
    ///
    /// # Arguments
    /// * `vault` – reference to the `ClmmVault` holding the staked position
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – gauge managing the staked position
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `rewarder_vault` – CLMM rewarder global vault
    /// * `pool` – CLMM pool associated with the position
    /// * `clock` – clock object for time-based validations
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    /// * `RewardCoinType` – reward coin type being collected
    ///
    /// # Returns
    /// * balance of rewards collected for the position
    public fun collect_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        vault: &ClmmVault, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ) : sui::balance::Balance<RewardCoinType> {
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());

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
    
    public fun borrow_staked_position(vault: &ClmmVault) : &governance::gauge::StakedPosition {
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());

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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());
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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());
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
        assert!(vault.wrapped_position.is_some(), vault::error::vault_stopped());

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

    public fun is_stopped(vault: &ClmmVault) : bool {
        vault.wrapped_position.is_none()
    }
}


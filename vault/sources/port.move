module vault::port {
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use std::type_name::{TypeName, with_defining_ids};
    use sui::object::ID;
    use sui::coin::Coin;
    use sui::balance::Balance;
    use sui::linked_table::{Self, LinkedTable};
    use sui::tx_context::TxContext;

    public struct PORT has drop {}

    public struct PortRegistry has store, key {
        id: sui::object::UID,
        index: u64,
        ports: sui::table::Table<ID, ID>,
    }
    
    public struct Port has key {
        id: sui::object::UID,
        is_pause: bool,
        vault: vault::vault::ClmmVault,
        buffer_assets: vault::balance_bag::BalanceBag,
        protocol_fees: sui::bag::Bag,
        hard_cap: u128,
        quote_type: std::option::Option<TypeName>,
        status: Status,
        protocol_fee_rate: u64,
        total_volume: u64,

        reward_growth: sui::vec_map::VecMap<TypeName, u128>, // per volume
        last_update_growth_time_ms: sui::vec_map::VecMap<TypeName, u64>,

        osail_reward_balances: vault::balance_bag::BalanceBag,
        osail_growth_global: LinkedTable<TypeName, u128>,
        last_update_osail_growth_time_ms: u64,

        managers: LinkedTable<address, bool>,
    }

    public struct PortEntry has store, key {
        id: sui::object::UID,
        port_id: ID,
        volume: u64,
        entry_reward_growth: sui::vec_map::VecMap<TypeName, u128>
    }
    
    public struct Status has store {
        last_aum: u128, // only pool assets
        last_calculate_aum_tx: vector<u8>,
        last_deposit_tx: vector<u8>,
        last_withdraw_tx: vector<u8>,
    }
    
    public struct CreateEvent has copy, drop {
        id: ID,
        pool: ID,
        vault_position_id: ID,
        lower_offset: u32,
        upper_offset: u32,
        rebalance_threshold: u32,
        quote_type: std::option::Option<TypeName>,
        hard_cap: u128,
        start_volume: u64,
    }
    
    public struct InitEvent has copy, drop {
        registry_id: ID,
    }
    
    public struct PauseEvent has copy, drop {
        port_id: ID,
    }
    
    public struct UnpauseEvent has copy, drop {
        port_id: ID,
    }
    
    public struct UpdateHardCapEvent has copy, drop {
        port_id: ID,
        old_hard_cap: u128,
        new_hard_cap: u128,
    }
    
    public struct PortEntryCreatedEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        volume: u64,
        entry_reward_growth: sui::vec_map::VecMap<TypeName, u128>,
    }
    
    public struct IncreaseLiquidityEvent has copy, drop {
        port_id: ID,
        before_aum: u128,
        user_tvl: u128,
        before_total_volume: u64,
        volume: u64,
        amount_a: u64,
        amount_b: u64,
    }

    public struct PortEntryIncreasedLiquidityEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        volume: u64,
    }
    
    public struct WithdrawEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        volume_withdraw: u64,
        liquidity: u128,
        amount_a: u64,
        amount_b: u64,
        remained_a: u64,
        remained_b: u64,
    }

    public struct PortEntryDestroyedEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
    }
    
    public struct FlashLoanEvent has copy, drop {
        port_id: ID,
        loan_type: TypeName,
        repay_type: TypeName,
        loan_amount: u64,
        repay_amount: u64,
        base_to_quote_price: u64,
        base_price: u64,
        quote_price: u64,
    }
    
    public struct RepayFlashLoanEvent has copy, drop {
        port_id: ID,
        repay_type: TypeName,
        repay_amount: u64,
    }
    
    public struct OsailRewardUpdatedEvent has copy, drop {
        port_id: ID,
        osail_coin_type: TypeName,
        amount_osail: u64,
        new_growth: u128,
        update_time: u64,
    }

    public struct OsailRewardClaimedEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        osail_coin_type: TypeName,
        amount_osail: u64,
        new_growth: u128,
        update_time: u64,
    }
    
    public struct ClaimProtocolFeeEvent has copy, drop {
        port_id: ID,
        amount: u64,
        type_name: TypeName,
    }

    public struct UpdatePoolRewardEvent has copy, drop {
        port_id: ID,
        reward_type: TypeName,
        amount: u64,
        new_growth: u128,
        update_time: u64,
    }
    
    public struct PoolRewardClaimedEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        reward_type: TypeName,
        amount: u64,
        new_growth: u128,
        update_time: u64,
    }
    
    public struct AddLiquidityEvent has copy, drop {
        port_id: ID,
        amount_a: u64,
        amount_b: u64,
        delta_liquidity: u128,
        current_sqrt_price: u128,
        total_volume: u64,
        remained_a: u64,
        remained_b: u64,
    }
    
    public struct RebalanceEvent has copy, drop {
        port_id: ID,
        data: vault::vault::MigrateLiquidity,
        remained_a: u64,
        remained_b: u64,
    }
    
    public struct UpdateLiquidityOffsetEvent has copy, drop {
        port_id: ID,
        old_lower_offset: u32,
        old_upper_offset: u32,
        new_lower_offset: u32,
        new_upper_offset: u32,
    }
    
    public struct UpdateRebalanceThresholdEvent has copy, drop {
        port_id: ID,
        old_rebalance_threshold: u32,
        new_rebalance_threshold: u32,
    }
    
    public struct UpdateProtocolFeeEvent has copy, drop {
        port_id: ID,
        old_protocol_fee_rate: u64,
        new_protocol_fee_rate: u64,
    }

    public struct StartVaultEvent has copy, drop {
        port_id: ID,
        buffer_balance_a: u64,
        buffer_balance_b: u64,
    }

    public struct StopVaultEvent has copy, drop {
        port_id: ID,
        buffer_balance_a: u64,
        buffer_balance_b: u64,
    }
    
    public struct FlashLoanCert {
        port_id: ID,
        repay_type: TypeName,
        repay_amount: u64,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    fun init(witness: PORT, ctx: &mut TxContext) {
        let publisher = sui::package::claim(witness, ctx);

        sui::transfer::public_transfer<sui::package::Publisher>(publisher, sui::tx_context::sender(ctx));

        let port = PortRegistry{
            id    : sui::object::new(ctx), 
            index : 0, 
            ports : sui::table::new<ID, ID>(ctx),
        };
        let event = InitEvent{registry_id: sui::object::id<PortRegistry>(&port)};
        sui::event::emit<InitEvent>(event);
        sui::transfer::share_object<PortRegistry>(port);
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
         let port = PortRegistry{
            id    : sui::object::new(ctx), 
            index : 0, 
            ports : sui::table::new<ID, ID>(ctx),
        };
        sui::transfer::share_object<PortRegistry>(port);
    }

    /// Creates and registers a new port.
    ///
    /// The function prepares the initial port state from the provided balances,
    /// evaluates the total value locked (TVL) using the selected quote asset, and
    /// delegates the actual creation to the internal helper.
    ///
    /// # Arguments
    /// * `global_config` – global configuration of the `vault` module
    /// * `port_registry` – registry that stores created ports
    /// * `port_oracle` – price oracle used to value assets
    /// * `treasury_cap` – `TreasuryCap` for minting the port LP tokens
    /// * `clmm_global_config` – global configuration of the CLMM pool
    /// * `clmm_vault` – CLMM global reward vault
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – `Gauge` associated with the CLMM pool
    /// * `pool` – CLMM pool for the port
    /// * `lower_offset` – lower price offset for rebalancing range
    /// * `upper_offset` – upper price offset for rebalancing range
    /// * `rebalance_threshold` – threshold that triggers rebalancing
    /// * `quote_type_a` – flag indicating whether coin A is used as the quote asset
    /// * `hard_cap` – maximum allowed port size
    /// * `start_balance_a` – initial balance of coin A
    /// * `start_balance_b` – initial balance of coin B
    /// * `clock` – clock object for time-dependent checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pair
    /// * `CoinTypeB` – second coin type in the pair
    ///
    /// # Aborts
    /// * if TVL calculation or port creation in the helper function fails
    public fun create_port<CoinTypeA, CoinTypeB>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry,
        port_oracle: &vault::port_oracle::PortOracle,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32, 
        upper_offset: u32, 
        rebalance_threshold: u32, 
        quote_type_a: bool,
        hard_cap: u128,
        start_balance_a: sui::balance::Balance<CoinTypeA>,
        start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {

        let mut balances = sui::vec_map::empty<TypeName, u64>(); 
        balances.insert(with_defining_ids<CoinTypeA>(), start_balance_a.value());
        balances.insert(with_defining_ids<CoinTypeB>(), start_balance_b.value());

        let quote_type = if (quote_type_a) {
            std::option::some<TypeName>(with_defining_ids<CoinTypeA>())
        } else {
            std::option::some<TypeName>(with_defining_ids<CoinTypeB>())
        };

        let tvl = calculate_tvl_base_on_quote(port_oracle, &balances, quote_type, clock);

        create_port_internal<CoinTypeA, CoinTypeB>(
            global_config,
            port_registry,
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            lower_offset,
            upper_offset,
            rebalance_threshold,
            quote_type_a,
            hard_cap,
            tvl,
            start_balance_a,
            start_balance_b,
            clock,
            ctx
        );
    }

    #[test_only]
    public fun test_create_port_internal<CoinTypeA, CoinTypeB>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32, 
        upper_offset: u32, 
        rebalance_threshold: u32, 
        quote_type_a: bool,
        hard_cap: u128,
        tvl: u128,
        start_balance_a: sui::balance::Balance<CoinTypeA>,
        start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        create_port_internal<CoinTypeA, CoinTypeB>(
            global_config,
            port_registry,
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            lower_offset,
            upper_offset,
            rebalance_threshold,
            quote_type_a,
            hard_cap,
            tvl,
            start_balance_a,
            start_balance_b,
            clock,
            ctx
        );
    }

    fun create_port_internal<CoinTypeA, CoinTypeB>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32, 
        upper_offset: u32, 
        rebalance_threshold: u32, 
        quote_type_a: bool,
        hard_cap: u128,
        tvl: u128,
        start_balance_a: sui::balance::Balance<CoinTypeA>,
        start_balance_b: sui::balance::Balance<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();

        let quote_type = if (quote_type_a) {
            std::option::some<TypeName>(with_defining_ids<CoinTypeA>())
        } else {
            std::option::some<TypeName>(with_defining_ids<CoinTypeB>())
        };
        let current_time = clock.timestamp_ms();
        let mut new_port = Port{
            id                : sui::object::new(ctx), 
            is_pause          : false, 
            vault             : vault::vault::new<CoinTypeA, CoinTypeB>(
                clmm_global_config,
                clmm_vault,
                distribution_config,
                gauge,
                pool, 
                lower_offset, 
                upper_offset, 
                rebalance_threshold,
                start_balance_a,
                start_balance_b,
                clock,
                ctx
            ), 
            buffer_assets     : vault::balance_bag::new_balance_bag(ctx),
            protocol_fees     : sui::bag::new(ctx),
            total_volume      : 0,
            hard_cap          : hard_cap, 
            quote_type        : quote_type, 
            status            : new_status(), 
            protocol_fee_rate : global_config.get_protocol_fee_rate(),
            reward_growth     : sui::vec_map::empty<TypeName, u128>(),
            osail_growth_global : linked_table::new<TypeName, u128>(ctx),
            osail_reward_balances : vault::balance_bag::new_balance_bag(ctx),
            last_update_growth_time_ms: sui::vec_map::empty<TypeName, u64>(),
            last_update_osail_growth_time_ms: current_time,
            managers: linked_table::new<address, bool>(ctx),
        };
        new_port.managers.push_back(sui::tx_context::sender(ctx), true);

        new_port.buffer_assets.join<CoinTypeA>(sui::balance::zero<CoinTypeA>()); 
        new_port.buffer_assets.join<CoinTypeB>(sui::balance::zero<CoinTypeB>());
        port_registry.ports.add<ID, ID>(
            sui::object::id<Port>(&new_port), 
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool)
        );

        let pool_rewarders = pool.rewarder_manager().rewarders();
        let mut i = 0;
        while (i < pool_rewarders.length()) {
            let rewarder = pool_rewarders.borrow(i);
            let rewarder_type = clmm_pool::rewarder::reward_coin(rewarder);
            new_port.reward_growth.insert(rewarder_type, rewarder.growth_global());
            new_port.last_update_growth_time_ms.insert(rewarder_type, current_time);

            i = i + 1;
        };

        let start_volume = get_volume_by_tvl(new_port.total_volume, tvl, new_port.status.last_aum);

        new_port.total_volume = start_volume as u64;

        let vault_position_id = new_port.vault.borrow_staked_position().position_id();
        
        let event = CreateEvent{
            id                  : sui::object::id<Port>(&new_port), 
            pool                : sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            vault_position_id   : vault_position_id,
            lower_offset        : lower_offset, 
            upper_offset        : upper_offset, 
            rebalance_threshold : rebalance_threshold, 
            quote_type          : quote_type, 
            hard_cap            : hard_cap,
            start_volume        : start_volume as u64,
        };
        sui::event::emit<CreateEvent>(event);
        sui::transfer::share_object<Port>(new_port);
    }

    fun new_status() : Status {
        Status{
            last_aum              : 0, 
            last_calculate_aum_tx : std::vector::empty<u8>(), 
            last_deposit_tx       : std::vector::empty<u8>(), 
            last_withdraw_tx      : std::vector::empty<u8>(),
        }
    }
    
    /// Rebalances the port position within the configured price range.
    ///
    /// The function validates permissions and current pool state, determines whether
    /// rebalancing is required, and delegates the actual liquidity adjustments to
    /// `rebalance_internal`. It ensures the caller has the proper role, the port is
    /// active, and the associated CLMM pool matches the stored port state.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port that will be rebalanced
    /// * `distribution_config` – configuration for distributing accrued rewards
    /// * `gauge` – gauge tracking the port’s staked position in the CLMM pool
    /// * `global_config` – global configuration of the `vault` module
    /// * `clmm_vault` – global reward vault for CLMM incentives
    /// * `clmm_global_config` – CLMM global configuration parameters
    /// * `pool` – CLMM pool providing current tick and spacing data
    /// * `clock` – clock object used for time-based validations
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the package version, caller role, or pool state checks fail
    /// * if rebalancing is not required according to `check_need_rebalance`
    public fun rebalance<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_rebalance_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        let (need_rebalance, tick_lower, tick_upper) = check_need_rebalance<CoinTypeA, CoinTypeB>(
            port,
            gauge,
            pool.tick_spacing(), 
            pool.current_tick_index(), 
            port.vault.rebalance_threshold()
        );
        assert!(need_rebalance, vault::error::pool_not_need_rebalance());
        rebalance_internal<CoinTypeA, CoinTypeB>(
            port, 
            distribution_config,
            gauge,
            clmm_global_config, 
            clmm_vault,
            pool, 
            tick_lower, 
            tick_upper, 
            clock, 
            ctx
        );
    }

    fun rebalance_internal<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        tick_lower: integer_mate::i32::I32, 
        tick_upper: integer_mate::i32::I32, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        check_updated_rewards(port, pool, clock);

        let (balance_a, balance_b, migrate_liquidity) = port.vault.rebalance<CoinTypeA, CoinTypeB>(
            distribution_config,
            gauge,
            clmm_global_config,
            clmm_vault,
            pool, 
            port.buffer_assets.withdraw_all<CoinTypeA>(),
            port.buffer_assets.withdraw_all<CoinTypeB>(), 
            tick_lower, 
            tick_upper, 
            clock, 
            ctx
        );

        port.buffer_assets.join<CoinTypeA>(balance_a);
        port.buffer_assets.join<CoinTypeB>(balance_b);

        let event = RebalanceEvent{
            port_id : sui::object::id<Port>(port), 
            data    : migrate_liquidity,
            remained_a         : port.buffer_assets.value<CoinTypeA>(),
            remained_b         : port.buffer_assets.value<CoinTypeB>(),
        };
        sui::event::emit<RebalanceEvent>(event);
    }

    /// Updates the target liquidity range for the port and optionally rebalances.
    ///
    /// The function checks manager permissions, ensures the port is active, updates
    /// the stored tick offsets, and triggers a rebalance when the new range requires it.
    /// It also emits an event describing the change in offsets.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port being updated
    /// * `global_config` – global configuration used for version and role checks
    /// * `distribution_config` – reward distribution settings passed to rebalancing
    /// * `gauge` – gauge that tracks the port’s CLMM stake
    /// * `clmm_global_config` – global CLMM configuration parameters
    /// * `clmm_vault` – CLMM reward vault used during rebalancing
    /// * `pool` – CLMM pool containing current tick data
    /// * `lower_offset` – new lower tick offset relative to the current tick
    /// * `upper_offset` – new upper tick offset relative to the current tick
    /// * `clock` – clock object for time-based checks inside rebalancing
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the caller lacks the pool manager role or the port is paused
    /// * if the offsets are unchanged
    /// * if the internal rebalance aborts
    public fun update_liquidity_offset<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        lower_offset: u32, 
        upper_offset: u32, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_pool_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_pool_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        let (current_lower_offset, current_upper_offset, _) = port.vault.get_liquidity_range();
        assert!(lower_offset != current_lower_offset || upper_offset != current_upper_offset, vault::error::liquidity_range_not_change());
        port.vault.update_liquidity_offset(lower_offset, upper_offset);

        let (need_rebalance, tick_lower, tick_upper) = check_need_rebalance<CoinTypeA, CoinTypeB>(
            port,
            gauge,
            pool.tick_spacing(), 
            pool.current_tick_index(), 
            1
        );
        if (need_rebalance) {
            rebalance_internal<CoinTypeA, CoinTypeB>(
                port, 
                distribution_config,
                gauge,
                clmm_global_config,
                clmm_vault,
                pool, 
                tick_lower, 
                tick_upper, 
                clock, 
                ctx
            );
        };
        let event = UpdateLiquidityOffsetEvent{
            port_id          : sui::object::id<Port>(port), 
            old_lower_offset : current_lower_offset, 
            old_upper_offset : current_upper_offset, 
            new_lower_offset : lower_offset, 
            new_upper_offset : upper_offset,
        };
        sui::event::emit<UpdateLiquidityOffsetEvent>(event);
    }

    fun check_need_rebalance<CoinTypeA, CoinTypeB>(
        port: &Port, 
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        tick_spacing: u32, 
        current_tick: integer_mate::i32::I32, 
        rebalance_threshold: u32
    ) : (bool, integer_mate::i32::I32, integer_mate::i32::I32) {
        let (lower_offset, upper_offset, _) = port.vault.get_liquidity_range();
        let (next_tick_lower, next_tick_upper) = vault::vault::next_position_range(
            lower_offset, 
            upper_offset, 
            tick_spacing, 
            current_tick
        );
        let (current_tick_lower, current_tick_upper) = port.vault.get_position_tick_range(gauge); 
        if (integer_mate::i32::lte(next_tick_upper, current_tick_lower) || integer_mate::i32::gte(next_tick_lower, current_tick_upper)) {
            return (true, next_tick_lower, next_tick_upper)
        };

        let need_rebalance =
        (
            integer_mate::i32::abs_u32(
                integer_mate::i32::sub(next_tick_lower, current_tick_lower)
            ) >= rebalance_threshold
        ) || (
            integer_mate::i32::abs_u32(integer_mate::i32::sub(next_tick_upper, current_tick_upper)) >= rebalance_threshold
        );
        
        (need_rebalance, next_tick_lower, next_tick_upper)
    }
    
    /// Updates the rebalance threshold used to decide when rebalancing is required.
    ///
    /// Ensures the caller has manager permissions, verifies the port is active, updates
    /// the stored threshold, and emits an event describing the change.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port being updated
    /// * `global_config` – global configuration used for version and role checks
    /// * `rebalance_threshold` – new threshold value
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    ///
    /// # Aborts
    /// * if the caller lacks the pool manager role or the port is paused
    public fun update_rebalance_threshold(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,
        rebalance_threshold: u32,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_pool_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_pool_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        let (_, _, current_rebalance_threshold) = port.vault.get_liquidity_range();
        port.vault.update_rebalance_threshold(rebalance_threshold);
        let event = UpdateRebalanceThresholdEvent{
            port_id                 : sui::object::id<Port>(port), 
            old_rebalance_threshold : current_rebalance_threshold, 
            new_rebalance_threshold : rebalance_threshold,
        };
        sui::event::emit<UpdateRebalanceThresholdEvent>(event);
    }
    
    /// Calculates the assets-under-management (AUM) value for the port.
    ///
    /// Validates pool alignment, refreshes reward accounting, aggregates balances from
    /// both the vault position and buffer assets, and uses oracle prices to compute TVL.
    /// The resulting AUM is stored in the port status and guarded against duplicate
    /// calculations within the same transaction.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port whose AUM is computed
    /// * `global_config` – configuration enforcing package version checks
    /// * `port_oracle` – price oracle used for valuation
    /// * `gauge` – gauge managing the port’s CLMM position
    /// * `pool` – CLMM pool associated with the port
    /// * `clock` – clock object for oracle freshness checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the port is paused or linked to a different pool
    /// * if the calculation is attempted repeatedly within the same transaction
    public fun calculate_aum<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig, 
        port_oracle: &vault::port_oracle::PortOracle,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        let pool_rewarders = pool.rewarder_manager().rewarders();
        assert!(pool_rewarders.length() == port.last_update_growth_time_ms.length(), vault::error::reward_types_not_match());

        if (port.reward_growth.contains(&with_defining_ids<CoinTypeA>())) {
            let current_growth_time_ms = port.last_update_growth_time_ms.get(&with_defining_ids<CoinTypeA>());
            assert!(current_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_reward_growth_time());
        };
        if (port.reward_growth.contains(&with_defining_ids<CoinTypeB>())) {
            let current_growth_time_ms = port.last_update_growth_time_ms.get(&with_defining_ids<CoinTypeB>());
            assert!(current_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_reward_growth_time());
        };

        let (amount_a, amount_b) = port.vault.liquidity_value<CoinTypeA, CoinTypeB>(gauge, pool); 
        let mut i = 0;
        let mut balances = sui::vec_map::empty<TypeName, u64>();
        let buffer_balances = *port.buffer_assets.balances(); 
        while (i < buffer_balances.length()) {
            let (type_name_ptr, amount_ptr) = buffer_balances.get_entry_by_idx(i);
            let type_name = *type_name_ptr;
            let amount = *amount_ptr;
            let mut pool_coin_amount = amount;
            if (with_defining_ids<CoinTypeA>() == type_name) {
                pool_coin_amount = amount + amount_a;
            } else {
                if (with_defining_ids<CoinTypeB>() == type_name) {
                    pool_coin_amount = amount + amount_b;
                };
            };
            if (!port_oracle.contain_oracle_info(type_name) || pool_coin_amount == 0) {
                i = i + 1;
                continue
            };
            balances.insert(type_name, pool_coin_amount); 
            i = i + 1;
        };
        port.status.last_aum = calculate_tvl_base_on_quote(port_oracle, &balances, port.quote_type, clock); 
        let digest = *ctx.digest();
        assert!(digest != port.status.last_calculate_aum_tx, vault::error::operation_not_allowed());
        port.status.last_calculate_aum_tx = digest;
    }

    #[test_only]
    public fun test_calculate_aum<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig, 
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tvl: u128,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        check_updated_rewards(port, pool, clock);

        port.status.last_aum = tvl; 
        let digest = *ctx.digest();
        assert!(digest != port.status.last_calculate_aum_tx, vault::error::operation_not_allowed());
        port.status.last_calculate_aum_tx = digest;
    }
    
    fun calculate_tvl_base_on_quote(
        port_oracle: &vault::port_oracle::PortOracle, 
        balances: &sui::vec_map::VecMap<TypeName, u64>, 
        quote_type: std::option::Option<TypeName>, 
        clock: &sui::clock::Clock
    ) : u128 {
        let quote_price = if (std::option::is_none<TypeName>(&quote_type)) {
            vault::port_oracle::new_price(
                1 * std::u64::pow(10, vault::port_oracle::price_multiplier_decimal()), 
                vault::port_oracle::price_multiplier_decimal()
            )
        } else {
            vault::port_oracle::get_price_by_type(
                port_oracle, 
                *std::option::borrow<TypeName>(&quote_type), 
                clock
            )
        };
        let mut tvl = 0;
        let mut i = 0;
        while (i < sui::vec_map::length<TypeName, u64>(balances)) {
            let (type_name, type_balance) = sui::vec_map::get_entry_by_idx<TypeName, u64>(balances, i);
            let price_by_type = vault::port_oracle::get_price_by_type(port_oracle, *type_name, clock);
            let (price_in_quote, _) = vault::port_oracle::calculate_prices(&price_by_type, &quote_price);
            tvl = tvl + integer_mate::full_math_u128::mul_div_floor(
                (price_in_quote as u128), 
                (*type_balance as u128), 
                (std::u64::pow(10, vault::port_oracle::price_multiplier_decimal()) as u128)
            );

            i = i + 1;
        };

        tvl
    }

    #[test_only]
    public fun test_calculate_tvl_base_on_quote(
        port_oracle: &vault::port_oracle::PortOracle, 
        balances: &sui::vec_map::VecMap<TypeName, u64>, 
        quote_type: std::option::Option<TypeName>, 
        clock: &sui::clock::Clock
    ) : u128 {
        calculate_tvl_base_on_quote(port_oracle, balances, quote_type, clock)
    }
    
    /// Claims accumulated protocol fees for the port.
    ///
    /// Performs version and role validation, withdraws the stored fee balance, emits
    /// an event recording the claim, and returns the fees as a coin.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port holding protocol fees
    /// * `global_config` – global configuration for version and access checks
    /// * `ctx` – transaction context used to mint the returned coin
    ///
    /// # Type Parameters
    /// * `ProtocolFeeCoin` – coin type in which protocol fees are accumulated
    ///
    /// # Aborts
    /// * if the caller lacks permission to claim protocol fees
    public fun claim_protocol_fee<ProtocolFeeCoin>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        ctx: &mut TxContext
    ) : Coin<ProtocolFeeCoin> {
        global_config.checked_package_version();
        assert!(
            global_config.is_protocol_fee_claim_role(sui::tx_context::sender(ctx)),
            vault::error::no_protocol_fee_claim_permission()
        );
        let protocol_fee = port.take_protocol_asset<ProtocolFeeCoin>();
        let event = ClaimProtocolFeeEvent{
            port_id : sui::object::id<Port>(port), 
            amount  : sui::balance::value<ProtocolFeeCoin>(&protocol_fee), 
            type_name : with_defining_ids<ProtocolFeeCoin>(),
        };
        sui::event::emit<ClaimProtocolFeeEvent>(event);
        sui::coin::from_balance<ProtocolFeeCoin>(protocol_fee, ctx)
    }

    fun take_protocol_asset<RewardCoinType>(port: &mut Port) : Balance<RewardCoinType> {
        let (balance, _) = vault::vault_utils::remove_balance_from_bag<RewardCoinType>(&mut port.protocol_fees, 0, true); 
        balance
    }
    
    /// Deposits a pair of coins into the port and mints a `PortEntry` NFT.
    ///
    /// Calculates the contribution TVL using oracle prices, then delegates the full
    /// deposit workflow—including CLMM interactions and reward updates—to
    /// `deposit_internal`.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port receiving liquidity
    /// * `global_config` – global configuration updated during the deposit
    /// * `port_oracle` – price oracle used to value the incoming assets
    /// * `clmm_global_config` – configuration for the CLMM module
    /// * `clmm_vault` – CLMM reward vault tracking incentives
    /// * `distribution_config` – reward distribution parameters
    /// * `gauge` – gauge managing the port’s CLMM stake
    /// * `pool` – CLMM pool where liquidity is deployed
    /// * `coin_a` – deposited coin of type `CoinTypeA`
    /// * `coin_b` – deposited coin of type `CoinTypeB`
    /// * `clock` – clock object for oracle freshness checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pair
    /// * `CoinTypeB` – second coin type in the pair
    ///
    /// # Returns
    /// * Newly minted `PortEntry` NFT representing the depositor’s position
    ///
    /// # Aborts
    /// * if internal deposit or oracle lookups fail
    public fun deposit<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        port_oracle: &vault::port_oracle::PortOracle, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        let mut balances = sui::vec_map::empty<TypeName, u64>(); 
        balances.insert(with_defining_ids<CoinTypeA>(), sui::coin::value<CoinTypeA>(&coin_a)); 
        balances.insert(with_defining_ids<CoinTypeB>(), sui::coin::value<CoinTypeB>(&coin_b));

        let tvl = calculate_tvl_base_on_quote(port_oracle, &balances, port.quote_type, clock);

        port.deposit_internal(
            global_config,
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            coin_a,
            coin_b,
            tvl,
            port_oracle.get_price<CoinTypeA>(clock),
            port_oracle.get_price<CoinTypeB>(clock),
            clock,
            ctx
        )
    }

    #[test_only]
    public fun test_deposit<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
        tvl: u128,
        price_a: vault::port_oracle::Price,
        price_b: vault::port_oracle::Price,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        port.deposit_internal(
            global_config,
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            coin_a,
            coin_b,
            tvl,
            price_a,
            price_b,
            clock,
            ctx
        )
    }

    fun deposit_internal<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>,
        tvl: u128,
        price_a: vault::port_oracle::Price,
        price_b: vault::port_oracle::Price,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry {

        let volume = before_increase_liquidity(
            port, 
            global_config,
            pool,
            coin_a, 
            coin_b, 
            tvl,
            clock, 
            ctx
        );

        let mut entry_reward_growth = sui::vec_map::empty<TypeName, u128>();
    
        let mut i = 0;
        while (i < port.reward_growth.length()) {
            let (reward_type, current_arpl) = port.reward_growth.get_entry_by_idx(i);
            entry_reward_growth.insert(*reward_type, *current_arpl);
            i = i + 1;
        };

        let last_osail_type_opt = port.osail_growth_global.back();
        if (!last_osail_type_opt.is_some()) {
            abort
        };
        let last_osail_type = last_osail_type_opt.borrow();
        entry_reward_growth.insert(
            *last_osail_type, 
            *port.osail_growth_global.borrow(*last_osail_type)
        );

        let port_entry = PortEntry {
            id: sui::object::new(ctx),
            port_id: sui::object::id<Port>(port),
            volume: volume,
            entry_reward_growth,
        };

        let event = PortEntryCreatedEvent{
            port_id: sui::object::id<Port>(port),
            port_entry_id: sui::object::id<PortEntry>(&port_entry),
            volume: port_entry.volume,
            entry_reward_growth,
        };
        sui::event::emit<PortEntryCreatedEvent>(event);
    
        port.add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config,  
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            price_a.price_value(),
            price_a.price_coin_decimal(),
            price_b.price_value(),
            price_b.price_coin_decimal(),
            clock,
            ctx
        );

        port_entry
    }

    /// Adds additional liquidity to an existing `PortEntry`.
    ///
    /// Values the contributed coins via oracle prices, validates reward state,
    /// updates the depositor’s LP balance, and calls `add_liquidity_internal` to deploy the
    /// new liquidity in the CLMM pool.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port managing the position
    /// * `global_config` – global configuration updated during liquidity changes
    /// * `port_oracle` – oracle providing prices for valuation
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `clmm_vault` – CLMM reward vault used when adding liquidity
    /// * `distribution_config` – reward distribution settings
    /// * `gauge` – gauge tracking the CLMM position
    /// * `pool` – CLMM pool where liquidity is added
    /// * `port_entry` – depositor’s entry receiving additional LP tokens
    /// * `coin_a` – additional amount of coin `CoinTypeA`
    /// * `coin_b` – additional amount of coin `CoinTypeB`
    /// * `clock` – clock object for oracle freshness checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if reward checks or internal liquidity adjustments fail
    public fun increase_liquidity<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        port_oracle: &vault::port_oracle::PortOracle, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        port_entry: &mut PortEntry,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());

        let mut balances = sui::vec_map::empty<TypeName, u64>(); 
        balances.insert(with_defining_ids<CoinTypeA>(), sui::coin::value<CoinTypeA>(&coin_a)); 
        balances.insert(with_defining_ids<CoinTypeB>(), sui::coin::value<CoinTypeB>(&coin_b));

        let tvl = calculate_tvl_base_on_quote(port_oracle, &balances, port.quote_type, clock);

        let price_a = port_oracle.get_price<CoinTypeA>(clock);
        let price_b = port_oracle.get_price<CoinTypeB>(clock);

        let volume = before_increase_liquidity(
            port, 
            global_config,
            pool,
            coin_a,
            coin_b, 
            tvl,
            clock, 
            ctx
        );
        check_claimed_rewards(
            port, 
            pool,
            port_entry, 
            clock
        );

        port_entry.volume = port_entry.volume + volume;

        let event = PortEntryIncreasedLiquidityEvent{
            port_id: sui::object::id<Port>(port),
            port_entry_id: sui::object::id<PortEntry>(port_entry),
            volume: port_entry.volume,
        };
        sui::event::emit<PortEntryIncreasedLiquidityEvent>(event);

        port.add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config, 
            clmm_global_config, 
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            price_a.price_value(),
            price_a.price_coin_decimal(),
            price_b.price_value(),
            price_b.price_coin_decimal(),
            clock,
            ctx
        );
    }

    #[test_only]
    public fun test_increase_liquidity<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &mut vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        port_entry: &mut PortEntry,
        tvl: u128,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        price_a: vault::port_oracle::Price,
        price_b: vault::port_oracle::Price,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let volume = before_increase_liquidity(
            port, 
            global_config,
            pool,
            coin_a,
            coin_b, 
            tvl,
            clock, 
            ctx
        );
        check_claimed_rewards(
            port, 
            pool,
            port_entry, 
            clock
        );

        port_entry.volume = port_entry.volume + volume;

        let event = PortEntryIncreasedLiquidityEvent{
            port_id: sui::object::id<Port>(port),
            port_entry_id: sui::object::id<PortEntry>(port_entry),
            volume: port_entry.volume,
        };
        sui::event::emit<PortEntryIncreasedLiquidityEvent>(event);

        port.add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config, 
            clmm_global_config, 
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            price_a.price_value(),
            price_a.price_coin_decimal(),
            price_b.price_value(),
            price_b.price_coin_decimal(),
            clock,
            ctx
        );
    }

    fun before_increase_liquidity<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        tvl: u128,
        clock: &sui::clock::Clock,
        ctx: &TxContext
    ) : u64 {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        let amount_a = sui::coin::value<CoinTypeA>(&coin_a);
        let amount_b = sui::coin::value<CoinTypeB>(&coin_b);
        assert!(amount_a > 0 || amount_b > 0, vault::error::token_amount_is_zero());
        let digest = *sui::tx_context::digest(ctx);
        assert!(digest == port.status.last_calculate_aum_tx, vault::error::aum_done_err());
        assert!(digest != port.status.last_deposit_tx, vault::error::operation_not_allowed());
        assert!(digest != port.status.last_withdraw_tx, vault::error::operation_not_allowed()); 

        check_updated_rewards(port, pool, clock);

        port.status.last_deposit_tx = digest;

        let total_volume = port.total_volume;
        assert!(port.hard_cap == 0 || (port.status.last_aum + tvl <= port.hard_cap), vault::error::hard_cap_reached());

        let volume = get_volume_by_tvl(total_volume, tvl, port.status.last_aum);
        assert!(volume > 0, vault::error::token_amount_is_zero()); 
        assert!(volume < (1<<64) - 1 - (total_volume as u128), vault::error::token_amount_overflow());
        port.buffer_assets.join<CoinTypeA>(coin_a.into_balance());
        port.buffer_assets.join<CoinTypeB>(coin_b.into_balance());

        let event = IncreaseLiquidityEvent{
            port_id       : sui::object::id<Port>(port), 
            before_aum    : port.status.last_aum, 
            user_tvl      : tvl, 
            before_total_volume : total_volume, 
            volume     : (volume as u64), 
            amount_a      : amount_a, 
            amount_b      : amount_b,
        };
        sui::event::emit<IncreaseLiquidityEvent>(event);

        port.status.last_aum = port.status.last_aum + tvl;

        port.total_volume = port.total_volume + (volume as u64);

        volume as u64
    }

    /// Moves buffered assets into the CLMM pool and emits an `AddLiquidityEvent`.
    ///
    /// Confirms the port state, validates oracle-derived price deviation, drains the
    /// buffer balances, and calls into the vault to increase liquidity. Any leftovers
    /// are returned to the buffer and the final state is recorded via an event.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port dispatching liquidity
    /// * `global_config` – global configuration for version checks
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `clmm_vault` – CLMM reward vault to credit incentives
    /// * `distribution_config` – reward distribution settings
    /// * `gauge` – gauge managing the CLMM stake
    /// * `pool` – CLMM pool where liquidity is provided
    /// * `port_oracle` – oracle providing prices for valuation
    /// * `clock` – clock object ensuring price freshness
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the port is paused or bound to a different pool
    /// * if price deviation exceeds the configured limits
    /// 
    public fun add_liquidity<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        port_oracle: &vault::port_oracle::PortOracle,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        let price_a = port_oracle.get_price<CoinTypeA>(clock);
        let price_b = port_oracle.get_price<CoinTypeB>(clock);

        port.add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config, 
            clmm_global_config, 
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            price_a.price_value(),
            price_a.price_coin_decimal(),
            price_b.price_value(),
            price_b.price_coin_decimal(),
            clock,
            ctx
        );
    }

    #[test_only]
    public fun test_add_liquidity<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_a: vault::port_oracle::Price,
        price_b: vault::port_oracle::Price,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        port.add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config, 
            clmm_global_config, 
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            price_a.price_value(),
            price_a.price_coin_decimal(),
            price_b.price_value(),
            price_b.price_coin_decimal(),
            clock,
            ctx
        );
    }

    fun add_liquidity_internal<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_a: u64,
        coin_a_decimal: u8,
        price_b: u64,
        coin_b_decimal: u8,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let diff_price = integer_mate::full_math_u64::mul_div_floor(
            price_a, 
            std::u64::pow(10, vault::port_oracle::price_multiplier_decimal()),
            price_b
        );
        if (
            (
                (vault::vault_config::get_protocol_fee_denominator() as u128) * std::u128::diff(
                    (diff_price as u128),
                    vault::vault_utils::sqrt_price_to_price(
                        pool.current_sqrt_price(), 
                        coin_a_decimal,
                        coin_b_decimal,
                        vault::port_oracle::price_multiplier_decimal()
                    )
                ) / (diff_price as u128) 
            ) > (
                (vault::vault_config::get_max_price_deviation_bps(global_config) as u128)
            )
        ) {
            return
        };
        let mut balance_a = port.buffer_assets.withdraw_all<CoinTypeA>();
        let mut balance_b = port.buffer_assets.withdraw_all<CoinTypeB>();

        let (amount_a, amount_b, delta_liquidity) = port.vault.increase_liquidity<CoinTypeA, CoinTypeB>(
            clmm_global_config, 
            clmm_vault,
            distribution_config,
            gauge,
            pool, 
            &mut balance_a, 
            &mut balance_b, 
            clock,
            ctx
        );
        port.buffer_assets.join<CoinTypeA>(balance_a);
        port.buffer_assets.join<CoinTypeB>(balance_b);
        let event = AddLiquidityEvent{
            port_id            : sui::object::id<Port>(port),
            amount_a           : amount_a, 
            amount_b           : amount_b, 
            delta_liquidity    : delta_liquidity, 
            current_sqrt_price : clmm_pool::pool::current_sqrt_price<CoinTypeA, CoinTypeB>(pool), 
            total_volume       : port.total_volume,
            remained_a         : port.buffer_assets.value<CoinTypeA>(),
            remained_b         : port.buffer_assets.value<CoinTypeB>(),
        };
        sui::event::emit<AddLiquidityEvent>(event);
    }

    fun get_volume_by_tvl(total_volume: u64, tvl: u128, last_aum: u128) : u128 {
        if (total_volume == 0) {
            return tvl
        };
        if (last_aum == 0) {
            abort vault::error::invalid_last_aum()
        };
        integer_mate::full_math_u128::mul_div_round((total_volume as u128), tvl, last_aum)
    }

    /// Stops the CLMM vault and buffers the withdrawn assets.
    ///
    /// Confirms the package version, ensures the caller holds the operator role,
    /// checks the bound pool, and delegates to the vault to close the CLMM position.
    /// The withdrawn Coin A and Coin B balances are returned to the port’s buffer
    /// and a `StopVaultEvent` is emitted to record the operation. Callers should
    /// make sure all position (osail) and pool rewards have been updated before invoking
    /// this function so that the position closes with the latest accounting.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port managing the vault
    /// * `global_config` – global configuration used for version checks
    /// * `clmm_global_config` – CLMM configuration applied during shutdown
    /// * `clmm_vault` – CLMM reward vault receiving final accounting
    /// * `distribution_config` – reward distribution settings
    /// * `gauge` – gauge responsible for the CLMM stake
    /// * `pool` – CLMM pool whose position is being closed
    /// * `clock` – clock object forwarded to the vault
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the caller lacks the operator role
    /// * if the port is paused
    /// * if the provided pool does not match the port configuration
    public fun stop_vault<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_operation_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        let (balance_a, balance_b) = port.vault.stop_vault(
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            clock,
            ctx
        );

        let event = StopVaultEvent{
            port_id: sui::object::id<Port>(port),
            buffer_balance_a: port.buffer_assets.value<CoinTypeA>(),
            buffer_balance_b: port.buffer_assets.value<CoinTypeB>(),
        };

        port.buffer_assets.join<CoinTypeA>(balance_a);
        port.buffer_assets.join<CoinTypeB>(balance_b);

        sui::event::emit<StopVaultEvent>(event);
    }

    /// Starts the CLMM vault using the buffers accumulated in the port.
    ///
    /// Ensures the caller has operator permissions, validates the configured pool,
    /// and rehydrates the vault position with the entire buffer balances. Any
    /// leftovers are returned to the buffer and a `StartVaultEvent` captures the
    /// resulting holdings. For best efficiency, rebalance the buffer assets before
    /// invoking this function so the supplied inventory matches the target range.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port that owns the vault
    /// * `global_config` – global configuration used for version checks
    /// * `clmm_global_config` – CLMM parameters applied during initialization
    /// * `clmm_vault` – CLMM reward vault receiving accounting updates
    /// * `distribution_config` – reward distribution settings
    /// * `gauge` – gauge responsible for the CLMM stake
    /// * `pool` – CLMM pool whose position is being opened
    /// * `clock` – clock object forwarded to the vault logic
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the caller lacks the operator role
    /// * if the port is paused
    /// * if the provided pool does not match the port configuration
    public fun start_vault<CoinTypeA, CoinTypeB>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_operation_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());

        let (remained_balance_a, remained_balance_b) = port.vault.start_vault(
            clmm_global_config,
            clmm_vault,
            distribution_config,
            gauge,
            pool,
            port.buffer_assets.withdraw_all<CoinTypeA>(),
            port.buffer_assets.withdraw_all<CoinTypeB>(),
            clock,
            ctx
        );

        if (remained_balance_a.value() > 0) {
            port.buffer_assets.join<CoinTypeA>(remained_balance_a);
        } else {
            remained_balance_a.destroy_zero();
        };
        if (remained_balance_b.value() > 0) {
            port.buffer_assets.join<CoinTypeB>(remained_balance_b);
        } else {
            remained_balance_b.destroy_zero();
        };

        let event = StartVaultEvent{
            port_id: sui::object::id<Port>(port),
            buffer_balance_a: port.buffer_assets.value<CoinTypeA>(),
            buffer_balance_b: port.buffer_assets.value<CoinTypeB>(),
        };

        sui::event::emit<StartVaultEvent>(event);
    }

    public fun is_stopped(port: &Port) : bool {
        port.vault.is_stopped()
    }
    
    /// Performs a flash loan from the port’s buffer for rebalancing operations.
    ///
    /// Validates caller permissions, pauses the port, prices the borrowed asset,
    /// computes the repayment amount, emits an event, and returns both the borrowed
    /// coins and a certificate required for repayment.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port providing the flash loan
    /// * `global_config` – global configuration for version and role checks
    /// * `port_oracle` – oracle used to price the loaned and repayment assets
    /// * `loan_amount` – amount of `CoinTypeOut` requested
    /// * `clock` – clock object for oracle freshness checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeOut` – asset borrowed from the port
    /// * `CoinTypeIn` – asset required for repayment
    ///
    /// # Returns
    /// * tuple containing the borrowed coin and a `FlashLoanCert`
    ///
    /// # Aborts
    /// * if the caller lacks operation permissions or the port is paused
    /// * if the loan amount is zero or the repayment asset type is invalid
    public fun flash_loan<CoinTypeOut, CoinTypeIn>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,  
        port_oracle: &vault::port_oracle::PortOracle, 
        loan_amount: u64,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext 
    ) : (Coin<CoinTypeOut>, FlashLoanCert) {
        global_config.checked_package_version(); 
        assert!(
            global_config.is_operation_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        port.is_pause = true;
        assert!(loan_amount > 0, vault::error::token_amount_is_zero());
        let price_coin_in = port_oracle.get_price<CoinTypeIn>(clock); 
        let price_coin_out = port_oracle.get_price<CoinTypeOut>(clock); 

        flash_loan_internal<CoinTypeOut, CoinTypeIn>(
            port,
            global_config,
            price_coin_in,
            price_coin_out,
            loan_amount,
            ctx
        )
    }

    #[test_only]
    public fun test_flash_loan<CoinTypeOut, CoinTypeIn>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,  
        price_coin_in: vault::port_oracle::Price,
        price_coin_out: vault::port_oracle::Price,
        loan_amount: u64,
        ctx: &mut TxContext 
    ) : (Coin<CoinTypeOut>, FlashLoanCert) {
        global_config.checked_package_version(); 
        assert!(
            global_config.is_operation_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        port.is_pause = true;
        assert!(loan_amount > 0, vault::error::token_amount_is_zero());

        flash_loan_internal<CoinTypeOut, CoinTypeIn>(
            port,
            global_config,
            price_coin_in,
            price_coin_out,
            loan_amount,
            ctx
        )
    }

    fun flash_loan_internal<CoinTypeOut, CoinTypeIn>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,  
        price_coin_in: vault::port_oracle::Price,
        price_coin_out: vault::port_oracle::Price,
        loan_amount: u64,
        ctx: &mut TxContext 
    ) : (Coin<CoinTypeOut>, FlashLoanCert) {
        let (price_coin_out_in_quote, _) = vault::port_oracle::calculate_prices(&price_coin_out, &price_coin_in);
        let repay_amount = integer_mate::full_math_u64::mul_div_ceil(
            integer_mate::full_math_u64::mul_div_floor(
                price_coin_out_in_quote, 
                loan_amount, 
                std::u64::pow(10, vault::port_oracle::price_multiplier_decimal())
            ),
            vault::vault_config::get_swap_slippage_denominator() - (global_config.get_swap_slippage<CoinTypeOut>() + global_config.get_swap_slippage<CoinTypeIn>()) / 2, 
            vault::vault_config::get_swap_slippage_denominator()
        );

        let repay_type = with_defining_ids<CoinTypeIn>();
        let (coin_type_a, coin_type_b) = port.vault.coin_types();
        assert!(repay_type == coin_type_a || repay_type == coin_type_b, vault::error::incorrect_repay_type());
        let flash_loan_cert = FlashLoanCert{
            port_id      : sui::object::id<Port>(port),  
            repay_type   : repay_type,  
            repay_amount : repay_amount,
        };
        let flash_loan_event = FlashLoanEvent{
            port_id             : sui::object::id<Port>(port), 
            loan_type           : with_defining_ids<CoinTypeOut>(), 
            repay_type          : repay_type, 
            loan_amount         : loan_amount, 
            repay_amount        : repay_amount, 
            base_to_quote_price : price_coin_out_in_quote, 
            base_price          : price_coin_out.price_value(), 
            quote_price         : price_coin_in.price_value(),
        };
        sui::event::emit<FlashLoanEvent>(flash_loan_event);

        (
            sui::coin::from_balance<CoinTypeOut>(
                port.buffer_assets.split<CoinTypeOut>(loan_amount), ctx
            ), 
            flash_loan_cert
        )
    }

    /// Repays a previously issued flash loan and resumes the port.
    ///
    /// Validates permissions, checks the repayment certificate, returns the funds to
    /// the buffer, emits a repayment event, and unpauses the port.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port receiving repayment
    /// * `global_config` – global configuration for version and role checks
    /// * `flash_loan_cert` – certificate issued with the original flash loan
    /// * `coin` – repayment coin
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `RepayCoinType` – coin type used to repay the flash loan
    ///
    /// # Aborts
    /// * if the caller lacks operation permissions
    /// * if the repayment type, amount, or port identifier is invalid
    public fun repay_flash_loan<RepayCoinType>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,
        flash_loan_cert: FlashLoanCert, 
        coin: Coin<RepayCoinType>, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_operation_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_operation_manager_permission()
        );
        assert!(port.is_pause, vault::error::port_is_pause());
        port.is_pause = false;

        assert!(with_defining_ids<RepayCoinType>() == flash_loan_cert.repay_type, vault::error::incorrect_repay_type());
        assert!(coin.value() >= flash_loan_cert.repay_amount, vault::error::incorrect_repay_amount());
        assert!(sui::object::id<Port>(port) == flash_loan_cert.port_id, vault::error::incorrect_repay_port_id());

        let _repay_amount = coin.value();
        port.buffer_assets.join<RepayCoinType>(coin.into_balance()); 

        let FlashLoanCert {
            port_id      : _,
            repay_type   : _,
            repay_amount : _,
        } = flash_loan_cert;
        
        let event = RepayFlashLoanEvent{
            port_id      : sui::object::id<Port>(port), 
            repay_type   : with_defining_ids<RepayCoinType>(), 
            repay_amount : _repay_amount,
        };
        sui::event::emit<RepayFlashLoanEvent>(event);
    }

    /// Withdraws liquidity from a `PortEntry` proportional to the provided LP amount.
    ///
    /// Validates pool alignment and transaction uniqueness, checks reward state,
    /// calculates the user’s share of buffer assets and on-chain liquidity, and burns
    /// the corresponding LP tokens. Emits a `WithdrawEvent` with the resulting amounts.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port managing the position
    /// * `global_config` – global configuration for version checks
    /// * `distribution_config` – configuration for distributing rewards
    /// * `gauge` – gauge tracking the CLMM position
    /// * `clmm_global_config` – configuration for CLMM operations
    /// * `clmm_vault` – CLMM reward vault interacting with liquidity
    /// * `pool` – CLMM pool from which liquidity is withdrawn
    /// * `port_entry` – depositor’s entry being reduced
    /// * `volume_withdraw` – amount of volume to withdraw
    /// * `clock` – clock object used in reward checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Returns
    /// * tuple of coins `CoinTypeA` and `CoinTypeB` representing withdrawn assets
    ///
    /// # Aborts
    /// * if the port is paused, LP amount is invalid, or the transaction repeats
    /// * if reward checks or internal liquidity updates fail
    public fun withdraw<CoinTypeA, CoinTypeB>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        port_entry: &mut PortEntry,
        volume_withdraw: u64,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(),
            vault::error::clmm_pool_not_match()
        );
        assert!(volume_withdraw > 0, vault::error::token_amount_is_zero());
        assert!(volume_withdraw <= port_entry.volume, vault::error::token_amount_not_enough());  
        let digest = *sui::tx_context::digest(ctx);
        assert!(digest != port.status.last_deposit_tx, vault::error::operation_not_allowed()); 
        assert!(digest != port.status.last_withdraw_tx, vault::error::operation_not_allowed()); 
        port.status.last_withdraw_tx = digest;
        check_updated_rewards(port, pool, clock);
        check_claimed_rewards(
            port, 
            pool,
            port_entry, 
            clock
        );

        port_entry.volume = port_entry.volume - volume_withdraw;

        let total_volume = port.total_volume; 
        let mut balances = *port.buffer_assets.balances();
        let coin_a_type = with_defining_ids<CoinTypeA>(); 
        let (_, coin_a_amount) = balances.remove( &coin_a_type);
        let coin_b_type = with_defining_ids<CoinTypeB>();
        let (_, coin_b_amount) = balances.remove(&coin_b_type);
        let mut coin_a_balance = port.buffer_assets.split<CoinTypeA>(
            (get_user_share_by_volume(total_volume, volume_withdraw, (coin_a_amount as u128)) as u64)
        );
        let mut coin_b_balance = port.buffer_assets.split<CoinTypeB>(
            (get_user_share_by_volume(total_volume, volume_withdraw, (coin_b_amount as u128)) as u64)
        );
        let liquidity = get_user_share_by_volume(total_volume, volume_withdraw, port.vault.get_position_liquidity(gauge));
        let (liquidity_balance_a, liquidity_balance_b) = if (liquidity > 0) {
            port.vault.decrease_liquidity<CoinTypeA, CoinTypeB>(
                distribution_config,
                gauge, 
                clmm_global_config, 
                clmm_vault, 
                pool, 
                liquidity, 
                clock, 
                ctx
            )
        } else {
            (sui::balance::zero<CoinTypeA>(), sui::balance::zero<CoinTypeB>())
        };
        coin_a_balance.join(liquidity_balance_a);
        coin_b_balance.join(liquidity_balance_b);

        let remained_a = port.buffer_assets.value<CoinTypeA>();
        let remained_b = port.buffer_assets.value<CoinTypeB>();

        let event = WithdrawEvent{
            port_id   : sui::object::id<Port>(port),
            port_entry_id: sui::object::id<PortEntry>(port_entry),
            volume_withdraw : volume_withdraw,
            liquidity : liquidity, 
            amount_a  : coin_a_balance.value(), 
            amount_b  : coin_b_balance.value(),
            remained_a  : remained_a,
            remained_b  : remained_b,
        };
        sui::event::emit<WithdrawEvent>(event);

        port.total_volume = port.total_volume - volume_withdraw;

        (
            sui::coin::from_balance<CoinTypeA>(coin_a_balance, ctx), 
            sui::coin::from_balance<CoinTypeB>(coin_b_balance, ctx)
        )
    }

    fun check_claimed_rewards<CoinTypeA, CoinTypeB>(
        port: &Port,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        port_entry: &PortEntry,
        clock: &sui::clock::Clock
    ) {
        assert!(!port.is_pause, vault::error::port_is_pause());

        check_updated_rewards(port, pool, clock);

        let last_osail_type_opt = port.osail_growth_global.back();
        if (last_osail_type_opt.is_some()) {
            let last_osail_type = last_osail_type_opt.borrow();
            assert!(port_entry.entry_reward_growth.contains(last_osail_type) &&
            *port_entry.entry_reward_growth.get(last_osail_type) == *port.osail_growth_global.borrow(*last_osail_type),
            vault::error::osail_reward_not_claimed());
        };

        let balances = *port.buffer_assets.balances();
        let coin_a_type = with_defining_ids<CoinTypeA>();
        let coin_b_type = with_defining_ids<CoinTypeB>();
        let mut i = 0;
        while (i < balances.length()) {
            let (buffer_coin_type, _) = balances.get_entry_by_idx(i);
            // pool coins have already been processed
            if (*buffer_coin_type == coin_a_type || *buffer_coin_type == coin_b_type) {
                i = i + 1;
                continue
            };
            assert!(
                port_entry.entry_reward_growth.contains(buffer_coin_type)
                &&
                port.reward_growth.contains(buffer_coin_type)
                &&
                *port_entry.entry_reward_growth.get(buffer_coin_type) == *port.reward_growth.get(buffer_coin_type),
                vault::error::reward_growth_not_match()
            );

            i = i + 1;
        }
    }

    /// Destroys an empty `PortEntry` after rewards are claimed and liquidity is withdrawn.
    ///
    /// Checks port state, verifies ownership, ensures the LP balance is zero, emits
    /// a destruction event, and removes the underlying object.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port owning the entry
    /// * `global_config` – global configuration enforcing version checks
    /// * `port_entry` – entry to be destroyed
    ///
    /// # Aborts
    /// * if the port is paused or the entry is not empty or mismatched
    public fun destory_port_entry(
        port: &Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        port_entry: PortEntry
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());
        assert!(port_entry.volume == 0, vault::error::port_entry_volume_not_empty());

        let PortEntry {
            id              : port_entry_id,
            port_id         : _,
            volume          : _,
            entry_reward_growth : _,
        } = port_entry;

        let event = PortEntryDestroyedEvent{
            port_id: sui::object::id<Port>(port),
            port_entry_id: *sui::object::uid_as_inner(&port_entry_id),
        };
        sui::event::emit<PortEntryDestroyedEvent>(event);

        sui::object::delete(port_entry_id);
    }

    /// Collects OSAIL rewards from the CLMM position and updates global growth metrics.
    ///
    /// Ensures the port and pool are aligned, pulls rewards via the minter, merges
    /// them into protocol balances, updates per-token growth tracking, and emits an
    /// `OsailRewardUpdatedEvent`.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port accumulating rewards
    /// * `global_config` – configuration enforcing package version checks
    /// * `minter` – minter responsible for distributing OSAIL rewards
    /// * `distribution_config` – reward distribution configuration
    /// * `gauge` – gauge managing the CLMM position
    /// * `pool` – CLMM pool associated with the port
    /// * `clock` – clock object for timestamp comparisons
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type of the pool
    /// * `CoinTypeB` – second coin type of the pool
    /// * `SailCoinType` – Sail token type handled by the minter
    /// * `CurrentOsailCoinType` – current epoch-specific OSAIL token type
    ///
    /// # Aborts
    /// * if the port is paused or linked to a different pool
    /// * if growth calculations overflow
    public fun update_position_reward<CoinTypeA, CoinTypeB, SailCoinType, CurrentOsailCoinType>(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig, 
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(),
            vault::error::clmm_pool_not_match()
        );
        let osail_coin_type = with_defining_ids<CurrentOsailCoinType>();

        let mut osail_reward = port.vault.collect_position_reward<CoinTypeA, CoinTypeB, SailCoinType, CurrentOsailCoinType>(
            minter,
            distribution_config,
            gauge,
            pool,
            clock,
            ctx
        );
        merge_protocol_asset<CurrentOsailCoinType>(port, &mut osail_reward); 
        let amount_osail = sui::balance::value<CurrentOsailCoinType>(&osail_reward);

        port.osail_reward_balances.join<CurrentOsailCoinType>(osail_reward);

        let total_volume = port.total_volume;
        let current_growth = if (port.osail_growth_global.contains(osail_coin_type)) {
            port.osail_growth_global.remove(osail_coin_type)
        } else {
            let last_osail_type_opt = port.osail_growth_global.back();
            if (last_osail_type_opt.is_some()) {
                // take the growth of the last type
                let last_osail_type = last_osail_type_opt.borrow();
                *port.osail_growth_global.borrow(*last_osail_type)
            } else {
                0
            }
        };

        let (new_growth, overflow) = integer_mate::math_u128::overflowing_add(
            current_growth,
            integer_mate::full_math_u128::mul_div_floor(
                (amount_osail as u128), 
                1, 
                (total_volume as u128)
            )
        );
        assert!(!overflow, vault::error::growth_overflow());
        port.osail_growth_global.push_back(osail_coin_type, new_growth);
        port.last_update_osail_growth_time_ms = sui::clock::timestamp_ms(clock); 

        let event = OsailRewardUpdatedEvent{
            port_id  : sui::object::id<Port>(port),
            osail_coin_type: osail_coin_type,
            amount_osail : amount_osail, 
            new_growth : new_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<OsailRewardUpdatedEvent>(event);
    }

    /// Verifies that OSAIL reward growth was updated in the current transaction.
    ///
    /// Ensures the port is active, checks the stored timestamps against the current
    /// clock value, and validates that the rewarder metadata matches.
    ///
    /// # Arguments
    /// * `port` – reference to the port being validated
    /// * `pool` – CLMM pool providing rewarder metadata
    /// * `clock` – clock object providing the current timestamp
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool pair
    /// * `CoinTypeB` – second coin type in the pool pair
    ///
    /// # Aborts
    /// * if the port is paused or growth timestamps do not match the clock
    public fun check_updated_rewards<CoinTypeA, CoinTypeB>(
        port: &Port,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ) {
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port.last_update_osail_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_osail_growth_time());

        let pool_rewarders = pool.rewarder_manager().rewarders();
        assert!(pool_rewarders.length() == port.last_update_growth_time_ms.length(), vault::error::reward_types_not_match());

        let mut i = 0;
        while (i < port.last_update_growth_time_ms.length()) {
            let (_, current_growth_time_ms) = port.last_update_growth_time_ms.get_entry_by_idx(i);
            assert!(current_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_reward_growth_time());
            i = i + 1;
        };
    }

    /// Claims OSAIL rewards for a port entry based on ownership share and growth.
    ///
    /// Ensures the port and entry are valid, updates rewards if needed, calculates the
    /// claimable amount, updates entry growth tracking, emits an event, and returns the
    /// claimed OSAIL coins.
    ///
    /// # Arguments
    /// * `global_config` – configuration enforcing package version checks
    /// * `port` – mutable reference to the port aggregating rewards
    /// * `port_entry` – depositor’s entry claiming rewards
    /// * `minter` – minter handling Sail token emissions
    /// * `distribution_config` – reward distribution parameters
    /// * `gauge` – gauge managing the CLMM position
    /// * `pool` – CLMM pool tied to the port
    /// * `clock` – clock object for timestamp checks
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    /// * `SailCoinType` – Sail token type
    /// * `OsailCoinType` – epoch-specific OSAIL token type
    ///
    /// # Returns
    /// * claimed OSAIL coin
    ///
    /// # Aborts
    /// * if the port is paused or the entry is invalid
    /// * if rewards are not updated or no OSAIL is available
    public fun claim_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
        global_config: &vault::vault_config::GlobalConfig,
        port: &mut Port,
        port_entry: &mut PortEntry,
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) : Coin<OsailCoinType> {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());

        if (port.last_update_osail_growth_time_ms != clock.timestamp_ms()) { 
            update_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
                port,
                global_config,
                minter,
                distribution_config,
                gauge,
                pool,
                clock,
                ctx
            );
        };
        assert!(port.last_update_osail_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_osail_growth_time());
        assert!(port_entry.volume != 0, vault::error::port_entry_volume_empty()); 

        let osail_coin_type = with_defining_ids<OsailCoinType>();
        assert!(port.osail_growth_global.contains(osail_coin_type), vault::error::osail_growth_not_match());

        // check claim of previous osail
        let prev_osail_type_opt = port.osail_growth_global.prev(osail_coin_type);
        if (prev_osail_type_opt.is_some()) {
            let prev_osail_type = prev_osail_type_opt.borrow();
            let prev_osail_growth = port.osail_growth_global.borrow(*prev_osail_type_opt.borrow());
            assert!(
                port_entry.entry_reward_growth.contains(prev_osail_type) 
                &&
                port_entry.entry_reward_growth.get(prev_osail_type) == prev_osail_growth, 
                vault::error::not_claimed_previous_osail_reward()
            );
        };  

        let (osail_reward_amount, osail_growth) = get_osail_amount_to_claim<OsailCoinType>(port, port_entry, clock);

        assert!(osail_reward_amount > 0, vault::error::osail_reward_empty());

        assert!(port.osail_reward_balances.value<OsailCoinType>() >= osail_reward_amount, vault::error::osail_reward_not_enough());
        let osail_reward = port.osail_reward_balances.split<OsailCoinType>(osail_reward_amount);

        if (port_entry.entry_reward_growth.contains(&osail_coin_type)) {
            port_entry.entry_reward_growth.remove(&osail_coin_type);
        };
        port_entry.entry_reward_growth.insert(osail_coin_type, osail_growth);

        let event = OsailRewardClaimedEvent{
            port_id  : sui::object::id<Port>(port),
            port_entry_id: sui::object::id<PortEntry>(port_entry),
            osail_coin_type: osail_coin_type,
            amount_osail : osail_reward_amount, 
            new_growth : osail_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<OsailRewardClaimedEvent>(event);

        sui::coin::from_balance<OsailCoinType>(osail_reward, ctx)
    }

    /// Determines which OSAIL type the entry is eligible to claim next.
    ///
    /// Traverses the recorded growth history to find the earliest unclaimed OSAIL
    /// type, respecting the order in which rewards accrued.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port maintaining reward growth
    /// * `port_entry` – entry requesting the next claimable OSAIL type
    ///
    /// # Returns
    /// * type identifier of the claimable OSAIL reward
    ///
    /// # Aborts
    /// * if the port is paused, entry does not belong to the port, or no rewards remain
    public fun get_osail_type_to_claim(
        port: &Port,
        port_entry: &PortEntry
    ) : TypeName {
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());

        let mut last_osail_type_opt = port.osail_growth_global.back();
        while (last_osail_type_opt.is_some()) {
            let last_osail_type = last_osail_type_opt.borrow();
            if (port_entry.entry_reward_growth.contains(last_osail_type)) {
                if (port.osail_growth_global.borrow(*last_osail_type) == port_entry.entry_reward_growth.get(last_osail_type)) {
                    // the current OSAIL is fully claimed, you can claim the next one
                    let next_osail_type_opt = port.osail_growth_global.next(*last_osail_type);
                    if (next_osail_type_opt.is_some()) {
                        return *next_osail_type_opt.borrow()
                    } else {
                        return *last_osail_type
                    }
                } else {
                    return *last_osail_type
                }
            } else {
                last_osail_type_opt = port.osail_growth_global.prev(*last_osail_type);
            };
        };

        abort vault::error::no_available_osail_reward()
    }

    /// Returns a vector of OSAIL types that are eligible to claim.
    ///
    /// Traverses the recorded growth history to find all OSAIL types that have not
    /// been fully claimed, respecting the order in which rewards accrued.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port maintaining reward growth
    /// * `port_entry` – entry requesting the next claimable OSAIL type
    ///
    /// # Returns
    /// * vector of type identifiers of the claimable OSAIL rewards
    ///   Important: the returned vector is ordered in reverse; claiming should start from the end of the vector
    ///
    /// # Aborts
    /// * if the port is paused or the entry does not belong to the port
    public fun get_osail_types_to_claim(
        port: &Port,
        port_entry: &PortEntry
    ) : vector<TypeName> {
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());

        let mut osail_types = vector::empty<TypeName>();
        let mut last_osail_type_opt = port.osail_growth_global.back();
        while (last_osail_type_opt.is_some()) {
            let last_osail_type = last_osail_type_opt.borrow();
            if (port_entry.entry_reward_growth.contains(last_osail_type)) {
                if (port.osail_growth_global.borrow(*last_osail_type) == port_entry.entry_reward_growth.get(last_osail_type)) {
                    break
                } else {
                    osail_types.push_back(*last_osail_type);
                }
            } else {
                osail_types.push_back(*last_osail_type);
                last_osail_type_opt = port.osail_growth_global.prev(*last_osail_type);
            };
        };

        return osail_types
    }

    /// Computes the claimable OSAIL amount for a port entry.
    ///
    /// Confirms rewards were refreshed, verifies growth ordering, calculates the
    /// accrued reward delta, and returns both the claimable amount and the latest
    /// growth value.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port maintaining growth state
    /// * `port_entry` – entry requesting the reward calculation
    /// * `clock` – clock object ensuring reward freshness
    ///
    /// # Type Parameters
    /// * `OsailCoinType` – OSAIL token type being claimed
    ///
    /// # Returns
    /// * tuple `(amount, growth)` indicating claimable OSAIL and updated growth
    ///
    /// # Aborts
    /// * if the port is paused, rewards are stale, or growth order is violated
    public fun get_osail_amount_to_claim<OsailCoinType>(
        port: &Port,
        port_entry: &PortEntry,
        clock: &sui::clock::Clock
    ) : (u64, u128) {
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());
        assert!(port.last_update_osail_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_osail_growth_time());
        if (port_entry.volume == 0) {
            return (0, 0)
        };

        let osail_coin_type = with_defining_ids<OsailCoinType>();
        assert!(port.osail_growth_global.contains(osail_coin_type), vault::error::osail_growth_not_match());

        let osail_growth = port.osail_growth_global.borrow(osail_coin_type);
        let mut entry_osail_growth = if (port_entry.entry_reward_growth.contains(&osail_coin_type)) {
            *port_entry.entry_reward_growth.get(&osail_coin_type)
        } else {
            0
        };
        if (entry_osail_growth >= *osail_growth) {
            return (0, *osail_growth)
        };

        let prev_osail_type_opt = port.osail_growth_global.prev(osail_coin_type);
        if (prev_osail_type_opt.is_some()) {
            let prev_osail_growth = port.osail_growth_global.borrow(*prev_osail_type_opt.borrow());
            if (*prev_osail_growth > entry_osail_growth) {
                entry_osail_growth = *prev_osail_growth;
            }
        };   

        let accumulated_osail_reward_growth = *osail_growth - entry_osail_growth;
        let (osail_reward_amount , overflow) = integer_mate::math_u64::overflowing_mul(
            port_entry.volume,
            (accumulated_osail_reward_growth as u64)
        );
        assert!(!overflow, vault::error::token_amount_overflow());

        (osail_reward_amount, *osail_growth)
    }
    
    /// Collects pool rewards, updates per-token growth, and records the update time.
    ///
    /// Pulls rewards from the CLMM vault, merges them into port balances, updates the
    /// growth accumulator for the reward type, and emits an event capturing the new
    /// state.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port updating rewards
    /// * `global_config` – configuration enforcing package version checks
    /// * `distribution_config` – distribution configuration passed to the vault
    /// * `gauge` – gauge managing the CLMM position
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `rewarder_vault` – global reward vault for the CLMM
    /// * `pool` – CLMM pool tied to the port
    /// * `clock` – clock object storing the update timestamp
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    /// * `RewardCoinType` – coin type of the accrued reward
    ///
    /// # Aborts
    /// * if the port is paused or bound to a different pool
    /// * if growth calculations overflow
    public fun update_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault, 
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        clock: &sui::clock::Clock
    ) {
        global_config.checked_package_version();  
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), 
            vault::error::clmm_pool_not_match()
        );
        let mut reward_balance = port.vault.collect_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
            distribution_config,
            gauge,
            clmm_global_config, 
            rewarder_vault,
            pool, 
            clock
        );
        let reward_type = with_defining_ids<RewardCoinType>();
        let amount = reward_balance.value();
        let (new_growth) = if (amount > 0) {
            merge_protocol_asset<RewardCoinType>(port, &mut reward_balance); 
            port.buffer_assets.join<RewardCoinType>(reward_balance);

            let total_volume = port.total_volume;
            
            let current_growth = if (port.reward_growth.contains(&reward_type)) {
                let (_, _current_growth) =  port.reward_growth.remove(&reward_type);
                _current_growth
            } else {
                0
            };
            let (new_growth, overflow) = integer_mate::math_u128::overflowing_add(
                current_growth,
                integer_mate::full_math_u128::mul_div_floor(
                    (amount as u128), 
                    1, 
                    (total_volume as u128)
                )
            );
            assert!(!overflow, vault::error::growth_overflow());
            port.reward_growth.insert(reward_type, new_growth);

            new_growth
        } else {
            reward_balance.destroy_zero();
            let current_growth = if (port.reward_growth.contains(&reward_type)) {
                *port.reward_growth.get(&reward_type)
            } else {
                0
            };
            current_growth
        };
    
        if (port.last_update_growth_time_ms.contains(&reward_type)) {
            port.last_update_growth_time_ms.remove(&reward_type);
        };
        port.last_update_growth_time_ms.insert(reward_type, clock.timestamp_ms());
    
        let event = UpdatePoolRewardEvent{
            port_id     : sui::object::id<Port>(port),
            reward_type : with_defining_ids<RewardCoinType>(), 
            amount      : amount, 
            new_growth  : new_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<UpdatePoolRewardEvent>(event);
    }

    /// Computes the claimable pool reward amount for a port entry.
    ///
    /// Confirms rewards were refreshed, verifies growth ordering, calculates the
    /// accrued reward delta, and returns both the claimable amount and the latest
    /// growth value.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port maintaining growth state
    /// * `port_entry` – entry requesting the reward calculation
    /// * `clock` – clock object ensuring reward freshness
    ///
    /// # Type Parameters
    /// * `RewardCoinType` – reward coin type being claimed
    ///
    /// # Returns
    /// * tuple `(amount, growth)` indicating claimable pool reward and updated growth
    ///
    /// # Aborts
    /// * if the port is paused, rewards are stale, or growth order is violated
    public fun get_pool_reward_amount_to_claim<RewardCoinType>(
        global_config: &vault::vault_config::GlobalConfig,
        port: &mut Port,
        port_entry: &mut PortEntry,
        clock: &sui::clock::Clock
    ) : (u64, u128) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());
        let reward_coin_type = with_defining_ids<RewardCoinType>();
        assert!(
            port.last_update_growth_time_ms.contains(&reward_coin_type) &&
            *port.last_update_growth_time_ms.get(&reward_coin_type) == clock.timestamp_ms(), 
            vault::error::port_entry_time_not_match()
        );
        assert!(port_entry.volume != 0, vault::error::port_entry_volume_not_empty());
        
        let start_growth = if (port_entry.entry_reward_growth.contains(&reward_coin_type)) {
            let (_, _start_growth) = port_entry.entry_reward_growth.remove(&reward_coin_type);
            _start_growth
        } else {
            0
        };
        
        let current_growth = if (port.reward_growth.contains(&reward_coin_type)) {
            *port.reward_growth.get(&reward_coin_type)
        } else {
            0
        };
        let accumulated_growth_reward = current_growth - start_growth;
        let (reward_amount , overflow) = integer_mate::math_u64::overflowing_mul(port_entry.volume, (accumulated_growth_reward as u64));
        assert!(!overflow, vault::error::token_amount_overflow());

        (reward_amount, current_growth)
    }

    /// Claims pool rewards for a port entry based on LP ownership.
    ///
    /// Refreshes the port’s reward state, calculates the accumulated growth for the
    /// entry, emits a claim event, and returns the payout coin (or zero if nothing is
    /// owed).
    ///
    /// # Arguments
    /// * `global_config` – configuration enforcing package version checks
    /// * `port` – mutable reference to the port tracking rewards
    /// * `port_entry` – depositor’s entry claiming rewards
    /// * `distribution_config` – reward distribution settings
    /// * `gauge` – gauge managing the CLMM position
    /// * `clmm_global_config` – CLMM configuration parameters
    /// * `rewarder_vault` – CLMM reward vault holding accrued incentives
    /// * `pool` – CLMM pool linked to the port
    /// * `clock` – clock object for timestamp validation
    /// * `ctx` – transaction context
    ///
    /// # Type Parameters
    /// * `CoinTypeA` – first coin type in the pool
    /// * `CoinTypeB` – second coin type in the pool
    /// * `RewardCoinType` – reward coin type being claimed
    ///
    /// # Returns
    /// * claimed reward coin (or zero coin if nothing accrued)
    ///
    /// # Aborts
    /// * if the port is paused, entry is invalid, or growth timestamps mismatch
    public fun claim_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &vault::vault_config::GlobalConfig,
        port: &mut Port,
        port_entry: &mut PortEntry,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : Coin<RewardCoinType> {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port>(port), vault::error::port_entry_port_id_not_match());

        update_pool_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
            port,
            global_config,
            distribution_config,
            gauge,
            clmm_global_config,
            rewarder_vault,
            pool,
            clock
        );
        let reward_coin_type = with_defining_ids<RewardCoinType>();
        assert!(
            port.last_update_growth_time_ms.contains(&reward_coin_type) &&
            *port.last_update_growth_time_ms.get(&reward_coin_type) == clock.timestamp_ms(), 
            vault::error::port_entry_time_not_match()
        );
        assert!(port_entry.volume != 0, vault::error::port_entry_volume_not_empty());
        
        let start_growth = if (port_entry.entry_reward_growth.contains(&reward_coin_type)) {
            let (_, _start_growth) = port_entry.entry_reward_growth.remove(&reward_coin_type);
            _start_growth
        } else {
            0
        };
        
        let current_growth = if (port.reward_growth.contains(&reward_coin_type)) {
            *port.reward_growth.get(&reward_coin_type)
        } else {
            0
        };
        let accumulated_growth_reward = current_growth - start_growth;
        let (reward_amount , overflow) = integer_mate::math_u64::overflowing_mul(port_entry.volume, (accumulated_growth_reward as u64));
        assert!(!overflow, vault::error::token_amount_overflow());
        port_entry.entry_reward_growth.insert(with_defining_ids<RewardCoinType>(), current_growth);

        let port_entry_id = sui::object::id<PortEntry>(port_entry);
        let event = PoolRewardClaimedEvent{
            port_id     : sui::object::id<Port>(port),
            port_entry_id : port_entry_id,
            reward_type : with_defining_ids<RewardCoinType>(),
            amount      : reward_amount, 
            new_growth  : current_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<PoolRewardClaimedEvent>(event);

        if (reward_amount > 0) {
            sui::coin::from_balance<RewardCoinType>(port.buffer_assets.split<RewardCoinType>(reward_amount), ctx)
        } else {
            sui::coin::zero<RewardCoinType>(ctx)
        }
    }
    
    fun merge_protocol_asset<RewardCoinType>(port: &mut Port, reward_balance: &mut Balance<RewardCoinType>) {
        let amount = reward_balance.value();
        vault::vault_utils::add_balance_to_bag<RewardCoinType>(
            &mut port.protocol_fees, 
            reward_balance.split<RewardCoinType>( 
                integer_mate::full_math_u64::mul_div_floor(
                    amount, 
                    port.protocol_fee_rate, 
                    vault::vault_config::get_protocol_fee_denominator()
                )
            )
        );
    }
    
    public fun total_volume(port: &Port) : u64 {
        port.total_volume
    }
    
    /// Updates the hard cap for the port and emits a corresponding event.
    ///
    /// Performs manager role validation, ensures the port is active, records the old
    /// limit, writes the new value, and emits `UpdateHardCapEvent`.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port being updated
    /// * `global_config` – configuration enforcing version and role checks
    /// * `new_hard_cap` – updated capacity limit
    /// * `ctx` – transaction context
    ///
    /// # Aborts
    /// * if the caller lacks manager permissions or the port is paused
    public fun update_hard_cap(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig, 
        new_hard_cap: u128, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(
            global_config.is_pool_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_pool_manager_permission()
        );
        assert!(!port.is_pause, vault::error::port_is_pause());
        let old_hard_cap = port.hard_cap;
        port.hard_cap = new_hard_cap;
        let event = UpdateHardCapEvent{
            port_id      : sui::object::id<Port>(port), 
            old_hard_cap : old_hard_cap, 
            new_hard_cap : new_hard_cap,
        };
        sui::event::emit<UpdateHardCapEvent>(event);
    }
    
    /// Updates the protocol fee rate for the port.
    ///
    /// Checks manager permissions, validates the new rate against the configured
    /// maximum, updates the stored value, and emits `UpdateProtocolFeeEvent`.
    ///
    /// # Arguments
    /// * `port` – mutable reference to the port
    /// * `global_config` – configuration enforcing version and role checks
    /// * `new_protocol_fee_rate` – new protocol fee rate in BPS
    /// * `ctx` – transaction context
    ///
    /// # Aborts
    /// * if the caller lacks manager permissions, the port is paused, or the rate exceeds the maximum
    public fun update_protocol_fee(
        port: &mut Port,
        global_config: &vault::vault_config::GlobalConfig,
        new_protocol_fee_rate: u64,
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        global_config.check_pool_manager_role(sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::port_is_pause());
        assert!(new_protocol_fee_rate <= vault::vault_config::get_max_protocol_fee_rate(), vault::error::invalid_protocol_fee_rate()); 
        let old_protocol_fee_rate = port.protocol_fee_rate;
        port.protocol_fee_rate = new_protocol_fee_rate;
        let event = UpdateProtocolFeeEvent{
            port_id               : sui::object::id<Port>(port), 
            old_protocol_fee_rate : old_protocol_fee_rate, 
            new_protocol_fee_rate : new_protocol_fee_rate,
        };
        sui::event::emit<UpdateProtocolFeeEvent>(event);
    }

    fun get_user_share_by_volume(total_volume: u64, volume: u64, total_amount: u128) : u128 {
        integer_mate::full_math_u128::mul_div_round((volume as u128), total_amount, (total_volume as u128))
    }

    public fun pause(port: &mut Port, global_config: &vault::vault_config::GlobalConfig, ctx: &mut TxContext) {
        global_config.checked_package_version();
        assert!(
            global_config.is_pool_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_pool_manager_permission()
        );
        port.is_pause = true;
        let event = PauseEvent{port_id: sui::object::id<Port>(port)};
        sui::event::emit<PauseEvent>(event);
    }

    public fun unpause(port: &mut Port, global_config: &vault::vault_config::GlobalConfig, ctx: &mut TxContext) {
        global_config.checked_package_version();
        assert!(
            global_config.is_pool_manager_role(sui::tx_context::sender(ctx))
            ||
            port.managers.contains(sui::tx_context::sender(ctx)),
            vault::error::no_pool_manager_permission()
        );
        port.is_pause = false;
        let event = UnpauseEvent{port_id: sui::object::id<Port>(port)};
        sui::event::emit<UnpauseEvent>(event);
    }

    public fun get_position_tick_range<CoinTypeA, CoinTypeB>(
        port: &Port,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>
    ) : (integer_mate::i32::I32, integer_mate::i32::I32) {
        port.vault.get_position_tick_range<CoinTypeA, CoinTypeB>(gauge)
    }

    public fun rebalance_threshold(port: &Port) : u32 {
        port.vault.rebalance_threshold()
    }

    public fun get_port_pause_status(port: &Port) : bool {
        port.is_pause 
    }

    public fun get_buffer_asset_value<CoinType>(port: &Port) : u64 {
        port.buffer_assets.value<CoinType>()
    }

    public fun get_protocol_fees_value<CoinType>(port: &Port) : u64 {
        let balance = port.protocol_fees.borrow<TypeName, sui::balance::Balance<CoinType>>(with_defining_ids<CoinType>());
        balance.value()
    }

    public fun get_protocol_fee_rate(port: &Port) : u64 {
        port.protocol_fee_rate
    }

    public fun get_hard_cap(port: &Port) : u128 {
        port.hard_cap
    }
    
    public fun get_port_quote_type(port: &Port) : std::option::Option<TypeName> {
        port.quote_type
    }

    public fun get_port_status_last_aum(port: &Port) : u128 {
        port.status.last_aum
    }

    public fun get_port_status_last_calculate_aum_tx(port: &Port) : vector<u8> {
        port.status.last_calculate_aum_tx
    }
    public fun get_port_status_last_deposit_tx(port: &Port) : vector<u8> {
        port.status.last_deposit_tx
    }

    public fun get_port_status_last_withdraw_tx(port: &Port) : vector<u8> {
        port.status.last_withdraw_tx
    }

    public fun get_port_reward_growth<RewardCoinType>(port: &Port) : u128 {
        let reward_coin_type = with_defining_ids<RewardCoinType>();
        if (port.reward_growth.contains(&reward_coin_type)) {
            *port.reward_growth.get(&reward_coin_type)
        } else {
            0
        }
    }

    public fun get_port_last_update_growth_time_ms<RewardCoinType>(port: &Port) : u64 {
        let reward_coin_type = with_defining_ids<RewardCoinType>();
        if (port.last_update_growth_time_ms.contains(&reward_coin_type)) {
            *port.last_update_growth_time_ms.get(&reward_coin_type)
        } else {
            0
        }
    }

    public fun get_osail_reward_balances_value<OsailCoinType>(port: &Port) : u64 { 
        port.osail_reward_balances.value<OsailCoinType>()
    }

    public fun get_port_osail_growth_global<OsailCoinType>(port: &Port) : u128 {
        let osail_coin_type = with_defining_ids<OsailCoinType>();
        if (port.osail_growth_global.contains(osail_coin_type)) {
            *port.osail_growth_global.borrow(osail_coin_type)
        } else {
            0
        }
    }

    public fun get_port_last_update_osail_growth_time_ms(port: &Port) : u64 {
        port.last_update_osail_growth_time_ms
    }

    public fun get_port_id(port_entry: &PortEntry) : ID {
        port_entry.port_id
    }

    public fun get_volume(port_entry: &PortEntry) : u64 {
        port_entry.volume
    }

    public fun get_entry_reward_growth<RewardCoinType>(port_entry: &PortEntry) : u128 {
        let reward_coin_type = with_defining_ids<RewardCoinType>();
        if (port_entry.entry_reward_growth.contains(&reward_coin_type)) {
            *port_entry.entry_reward_growth.get(&reward_coin_type)
        } else {
            0
        }
    }

    public fun get_repay_type(flash_loan_cert: &FlashLoanCert) : TypeName {
        flash_loan_cert.repay_type
    }

    public fun get_repay_amount(flash_loan_cert: &FlashLoanCert) : u64 {
        flash_loan_cert.repay_amount
    }

    fun update_display(
        publisher: &sui::package::Publisher,
        name: std::string::String,
        link: std::string::String,
        image_url: std::string::String,
        description: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ): sui::display::Display<PortEntry> {
        let mut keys = std::vector::empty<std::string::String>();
        keys.push_back(std::string::utf8(b"name"));
        keys.push_back(std::string::utf8(b"link"));
        keys.push_back(std::string::utf8(b"image_url"));
        keys.push_back(std::string::utf8(b"description"));
        keys.push_back(std::string::utf8(b"project_url"));
        keys.push_back(std::string::utf8(b"creator"));

        let mut values = std::vector::empty<std::string::String>();
        values.push_back(name);
        values.push_back(link);
        values.push_back(image_url);
        values.push_back(description);
        values.push_back(project_url);
        values.push_back(creator);

        let mut display = sui::display::new_with_fields<PortEntry>(publisher, keys, values, ctx);
        sui::display::update_version<PortEntry>(&mut display);

        display
    }

    public fun set_display(
        publisher: &sui::package::Publisher,
        name: std::string::String,
        link: std::string::String,
        image_url: std::string::String,
        description: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(publisher.from_module<PORT>(), vault::error::not_owner());

        let display = update_display(
            publisher,
            name,
            link,
            image_url,
            description,
            project_url,
            creator,
            ctx
        );

        sui::transfer::public_transfer<sui::display::Display<PortEntry>>(display, sui::tx_context::sender(ctx));
    }

    public fun add_manager(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        manager: address, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        global_config.check_pool_manager_role(ctx.sender());
        if (!port.managers.contains(manager)) {
            port.managers.push_back(manager, true);
        };
    }

    public fun remove_manager(
        port: &mut Port, 
        global_config: &vault::vault_config::GlobalConfig, 
        manager: address, 
        ctx: &mut TxContext
    ) {
        global_config.checked_package_version();
        assert!(!port.is_pause, vault::error::port_is_pause());
        global_config.check_pool_manager_role(ctx.sender());
        if (port.managers.contains(manager)) {
            port.managers.remove(manager);
        };
    }

    public fun check_manager(port: &Port, manager: address) : bool {
        port.managers.contains(manager)
    }

    public fun get_managers(port: &Port) : vector<address> {
        let mut managers = std::vector::empty<address>();
        let mut head = port.managers.front();
        while (head.is_some()) {
            let manager = *head.borrow();
            managers.push_back(manager);
            head = port.managers.next(manager);
        };
        managers
    }
}


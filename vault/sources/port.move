module vault::port {

    use std::type_name::TypeName;
    use sui::object::ID;
    use sui::coin::Coin;
    use sui::balance::Balance;
    use sui::linked_table::{Self, LinkedTable};
    use sui::tx_context::TxContext;

    public struct PortRegistry has store, key {
        id: sui::object::UID,
        index: u64,
        ports: sui::table::Table<ID, ID>,
    }
    
    public struct Port<phantom LpCoinType> has key {
        id: sui::object::UID,
        is_pause: bool,
        vault: vault::vault::ClmmVault,
        lp_token_treasury: sui::coin::TreasuryCap<LpCoinType>,
        buffer_assets: vault::balance_bag::BalanceBag,
        protocol_fees: sui::bag::Bag,
        hard_cap: u128,
        quote_type: std::option::Option<TypeName>,
        status: Status,
        protocol_fee_rate: u64,

        reward_growth: sui::vec_map::VecMap<TypeName, u128>, // per lp
        last_update_growth_time_ms: u64, // не можем использовать одно значение под все награды пула

        // osail_type_rewards: vector<TypeName>, // early Osail rewards at the beginning, late at the end
        osail_reward_balances: vault::balance_bag::BalanceBag,
        osail_growth_global: LinkedTable<TypeName, u128>, // TODO складывать сюда рост осейлов, чтобы можно было получать предыдущий рост
        last_update_osail_growth_time_ms: u64,
    }

    public struct PortEntry<phantom LpCoinType> has store, key {
        id: sui::object::UID,
        port_id: ID,
        lp_tokens: Balance<LpCoinType>,
        entry_reward_growth: sui::vec_map::VecMap<TypeName, u128>,
        entry_osail_growth: u128,
    }
    
    public struct Status has store {
        last_aum: u128,
        last_calculate_aum_tx: vector<u8>,
        last_deposit_tx: vector<u8>,
        last_withdraw_tx: vector<u8>,
    }
    
    public struct CreateEvent has copy, drop {
        id: ID,
        pool: ID,
        lower_offset: u32,
        upper_offset: u32,
        rebalance_threshold: u32,
        lp_token_treasury: ID,
        quote_type: std::option::Option<TypeName>,
        hard_cap: u128,
        start_lp_amount: u64,
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
        lp_tokens_amount: u64,
        entry_reward_growth: sui::vec_map::VecMap<TypeName, u128>,
        entry_osail_growth: u128,
    }
    
    public struct IncreaseLiquidityEvent has copy, drop {
        port_id: ID,
        before_aum: u128,
        user_tvl: u128,
        before_supply: u64,
        lp_amount: u64,
        amount_a: u64,
        amount_b: u64,
    }

    public struct PortEntryIncreasedLiquidityEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        lp_tokens_amount: u64,
    }
    
    public struct WithdrawEvent has copy, drop {
        port_id: ID,
        port_entry_id: ID,
        lp_amount: u64,
        liquidity: u128,
        amount_a: u64,
        amount_b: u64,
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
        lp_supply: u64,
        remained_a: u64,
        remained_b: u64,
    }
    
    public struct RebalanceEvent has copy, drop {
        port_id: ID,
        data: vault::vault::MigrateLiquidity,
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
    
    public struct FlashLoanCert {
        port_id: ID,
        repay_type: TypeName,
        repay_amount: u64,
    }

    fun init(ctx: &mut TxContext) {
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

    public fun create_port<CoinTypeA, CoinTypeB, LpCoin>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry,
        pyth_oracle: &vault::pyth_oracle::PythOracle,
        treasury_cap: sui::coin::TreasuryCap<LpCoin>, 
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
        balances.insert(std::type_name::with_defining_ids<CoinTypeA>(), start_balance_a.value());
        balances.insert(std::type_name::with_defining_ids<CoinTypeB>(), start_balance_b.value());

        let quote_type = if (quote_type_a) {
            std::option::some<TypeName>(std::type_name::with_defining_ids<CoinTypeA>())
        } else {
            std::option::some<TypeName>(std::type_name::with_defining_ids<CoinTypeB>())
        };

        let tvl = calculate_tvl_base_on_quote(pyth_oracle, &balances, quote_type, clock);

        create_port_internal<CoinTypeA, CoinTypeB, LpCoin>(
            global_config,
            port_registry,
            treasury_cap,
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
    public fun test_create_port_internal<CoinTypeA, CoinTypeB, LpCoin>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry,
        treasury_cap: sui::coin::TreasuryCap<LpCoin>, 
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
        create_port_internal<CoinTypeA, CoinTypeB, LpCoin>(
            global_config,
            port_registry,
            treasury_cap,
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

    fun create_port_internal<CoinTypeA, CoinTypeB, LpCoin>(
        global_config: &vault::vault_config::GlobalConfig, 
        port_registry: &mut PortRegistry, 
        treasury_cap: sui::coin::TreasuryCap<LpCoin>, 
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
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(sui::coin::total_supply<LpCoin>(&treasury_cap) == 0, vault::error::treasury_cap_illegal());

        let quote_type = if (quote_type_a) {
            std::option::some<TypeName>(std::type_name::with_defining_ids<CoinTypeA>())
        } else {
            std::option::some<TypeName>(std::type_name::with_defining_ids<CoinTypeB>())
        };
        let lp_token_treasury = sui::object::id<sui::coin::TreasuryCap<LpCoin>>(&treasury_cap);
        let mut new_port = Port<LpCoin>{
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
            lp_token_treasury : treasury_cap, 
            buffer_assets     : vault::balance_bag::new_balance_bag(ctx),
            protocol_fees     : sui::bag::new(ctx),
            hard_cap          : hard_cap, 
            quote_type        : quote_type, 
            status            : new_status(), 
            protocol_fee_rate : vault::vault_config::get_protocol_fee_rate(global_config),
            reward_growth     : sui::vec_map::empty<TypeName, u128>(),
            osail_growth_global : linked_table::new<TypeName, u128>(ctx),
            osail_reward_balances : vault::balance_bag::new_balance_bag(ctx),
            last_update_growth_time_ms: clock.timestamp_ms(), 
            last_update_osail_growth_time_ms: clock.timestamp_ms(),
        };
        new_port.buffer_assets.join<CoinTypeA>(sui::balance::zero<CoinTypeA>()); 
        new_port.buffer_assets.join<CoinTypeB>(sui::balance::zero<CoinTypeB>());
        port_registry.ports.add<ID, ID>(
            sui::object::id<Port<LpCoin>>(&new_port), 
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool)
        );

        let lp_amount = get_lp_amount_by_tvl(lp_total_supply<LpCoin>(&new_port), tvl, new_port.status.last_aum);
        let lp_tokens = sui::coin::mint<LpCoin>(
            &mut new_port.lp_token_treasury,
            (lp_amount as u64),
            ctx
        );

        transfer::public_transfer(lp_tokens, sui::tx_context::sender(ctx));
        
        let event = CreateEvent{
            id                  : sui::object::id<Port<LpCoin>>(&new_port), 
            pool                : sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool), 
            lower_offset        : lower_offset, 
            upper_offset        : upper_offset, 
            rebalance_threshold : rebalance_threshold, 
            lp_token_treasury   : lp_token_treasury,
            quote_type          : quote_type, 
            hard_cap            : hard_cap,
            start_lp_amount     : (lp_amount as u64),
        };
        sui::event::emit<CreateEvent>(event);
        sui::transfer::share_object<Port<LpCoin>>(new_port);
    }

    fun new_status() : Status {
        Status{
            last_aum              : 0, 
            last_calculate_aum_tx : std::vector::empty<u8>(), 
            last_deposit_tx       : std::vector::empty<u8>(), 
            last_withdraw_tx      : std::vector::empty<u8>(),
        }
    }
    
    public fun rebalance<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        global_config: &vault::vault_config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_rebalance_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        let (need_rebalance, tick_lower, tick_upper) = check_need_rebalance<CoinTypeA, CoinTypeB, LpCoin>(
            port,
            gauge,
            pool.tick_spacing(), 
            pool.current_tick_index(), 
            port.vault.rebalance_threshold()
        );
        assert!(need_rebalance, vault::error::pool_not_need_rebalance());
        rebalance_internal<CoinTypeA, CoinTypeB, LpCoin>(
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

    fun rebalance_internal<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>,
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
        check_updated_rewards(port,  clock);

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

        let event = RebalanceEvent{
            port_id : sui::object::id<Port<LpCoin>>(port), 
            data    : migrate_liquidity,
        };
        sui::event::emit<RebalanceEvent>(event);

        port.buffer_assets.join<CoinTypeA>(balance_a);
        port.buffer_assets.join<CoinTypeB>(balance_b);
    }
    
    // обновление оффсета тиков
    public fun update_liquidity_offset<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>,
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
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        let (current_lower_offset, current_upper_offset, _) = port.vault.get_liquidity_range();
        assert!(lower_offset != current_lower_offset || upper_offset != current_upper_offset, vault::error::liquidity_range_not_change());
        port.vault.update_liquidity_offset(lower_offset, upper_offset);

        let (need_rebalance, tick_lower, tick_upper) = check_need_rebalance<CoinTypeA, CoinTypeB, LpCoin>(
            port,
            gauge,
            pool.tick_spacing(), 
            pool.current_tick_index(), 
            1
        );
        if (need_rebalance) {
            rebalance_internal<CoinTypeA, CoinTypeB, LpCoin>(
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
            port_id          : sui::object::id<Port<LpCoin>>(port), 
            old_lower_offset : current_lower_offset, 
            old_upper_offset : current_upper_offset, 
            new_lower_offset : lower_offset, 
            new_upper_offset : upper_offset,
        };
        sui::event::emit<UpdateLiquidityOffsetEvent>(event);
    }

    fun check_need_rebalance<CoinTypeA, CoinTypeB, LpCoin>(
        port: &Port<LpCoin>, 
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
        std::debug::print(&std::string::utf8("next_tick_lower:"));
        std::debug::print(&next_tick_lower);
        std::debug::print(&std::string::utf8("current_tick_lower:"));
        std::debug::print(&current_tick_lower);
        std::debug::print(&std::string::utf8("next_tick_upper:"));
        std::debug::print(&next_tick_upper);
        std::debug::print(&std::string::utf8("current_tick_upper:"));
        std::debug::print(&current_tick_upper);
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
    
    public fun update_rebalance_threshold<LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig,
        rebalance_threshold: u32,
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        let (_, _, current_rebalance_threshold) = port.vault.get_liquidity_range();
        port.vault.update_rebalance_threshold(rebalance_threshold);
        let event = UpdateRebalanceThresholdEvent{
            port_id                 : sui::object::id<Port<LpCoin>>(port), 
            old_rebalance_threshold : current_rebalance_threshold, 
            new_rebalance_threshold : rebalance_threshold,
        };
        sui::event::emit<UpdateRebalanceThresholdEvent>(event);
    }
    
    // NO test
    public fun calculate_aum<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig, 
        pyth_oracle: &vault::pyth_oracle::PythOracle,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        check_updated_rewards(port, clock);

        let (amount_a, amount_b) = port.vault.liquidity_value<CoinTypeA, CoinTypeB>(gauge, pool); 
        let mut i = 0;
        let mut balances = sui::vec_map::empty<TypeName, u64>();
        let buffer_balances = *port.buffer_assets.balances(); 
        while (i < buffer_balances.length()) {
            let (type_name_ptr, amount_ptr) = buffer_balances.get_entry_by_idx(i);
            let type_name = *type_name_ptr;
            let amount = *amount_ptr;
            let mut pool_coin_amount = amount;
            if (std::type_name::with_defining_ids<CoinTypeA>() == type_name) {
                pool_coin_amount = amount + amount_a;
            } else {
                if (std::type_name::with_defining_ids<CoinTypeB>() == type_name) {
                    pool_coin_amount = amount + amount_b;
                };
            };
            if (!pyth_oracle.contain_oracle_info(type_name) || pool_coin_amount == 0) {
                i = i + 1;
                continue
            };
            balances.insert(type_name, pool_coin_amount); 
            i = i + 1;
        };
        port.status.last_aum = calculate_tvl_base_on_quote(pyth_oracle, &balances, port.quote_type, clock); 
        let digest = *ctx.digest();
        assert!(digest != port.status.last_calculate_aum_tx, vault::error::operation_not_allowed());
        port.status.last_calculate_aum_tx = digest;
    }

    #[test_only]
    public fun test_calculate_aum<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig, 
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tvl: u128,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        check_updated_rewards(port, clock);

        port.status.last_aum = tvl; 
        let digest = *ctx.digest();
        assert!(digest != port.status.last_calculate_aum_tx, vault::error::operation_not_allowed());
        port.status.last_calculate_aum_tx = digest;
    }
    
    fun calculate_tvl_base_on_quote(
        pyth_oracle: &vault::pyth_oracle::PythOracle, 
        balances: &sui::vec_map::VecMap<TypeName, u64>, 
        quote_type: std::option::Option<TypeName>, 
        clock: &sui::clock::Clock
    ) : u128 {
        let price = if (std::option::is_none<TypeName>(&quote_type)) {
            vault::pyth_oracle::new_price(
                1 * std::u64::pow(10, vault::pyth_oracle::price_multiplier_decimal()), 
                vault::pyth_oracle::price_multiplier_decimal()
            )
        } else {
            vault::pyth_oracle::get_price_by_type(
                pyth_oracle, 
                *std::option::borrow<TypeName>(&quote_type), 
                clock
            )
        };
        let mut tvl = 0;
        let mut i = 0;
        while (i < sui::vec_map::length<TypeName, u64>(balances)) {
            let (type_name, type_balance) = sui::vec_map::get_entry_by_idx<TypeName, u64>(balances, i);
            let price_by_type = vault::pyth_oracle::get_price_by_type(pyth_oracle, *type_name, clock);
            let (price_in_quote, _) = vault::pyth_oracle::calculate_prices(&price_by_type, &price);
            tvl = tvl + integer_mate::full_math_u128::mul_div_floor(
                (price_in_quote as u128), 
                (*type_balance as u128), 
                (std::u64::pow(10, vault::pyth_oracle::price_multiplier_decimal()) as u128)
            );
            i = i + 1;
        };
        tvl
    }
    
    public fun claim_protocol_fee<LpCoin, ProtocolFeeCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &vault::vault_config::GlobalConfig, 
        ctx: &mut TxContext
    ) : Coin<ProtocolFeeCoin> {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_protocol_fee_claim_role(global_config, sui::tx_context::sender(ctx));  
        let protocol_fee = port.take_protocol_asset<LpCoin, ProtocolFeeCoin>();
        let event = ClaimProtocolFeeEvent{
            port_id : sui::object::id<Port<LpCoin>>(port), 
            amount  : sui::balance::value<ProtocolFeeCoin>(&protocol_fee), 
            type_name : std::type_name::with_defining_ids<ProtocolFeeCoin>(),
        };
        sui::event::emit<ClaimProtocolFeeEvent>(event);
        sui::coin::from_balance<ProtocolFeeCoin>(protocol_fee, ctx)
    }

    fun take_protocol_asset<LpCoin, RewardCoinType>(port: &mut Port<LpCoin>) : Balance<RewardCoinType> {
        let (balance, _) = vault::vault_utils::remove_balance_from_bag<RewardCoinType>(&mut port.protocol_fees, 0, true); 
        balance
    }
    
    // первично внести ликвидности и получить нфт PortEntry
    public fun deposit<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        pyth_oracle: &vault::pyth_oracle::PythOracle, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry<LpCoin> {

        let mut balances = sui::vec_map::empty<TypeName, u64>(); 
        balances.insert(std::type_name::with_defining_ids<CoinTypeA>(), sui::coin::value<CoinTypeA>(&coin_a)); 
        balances.insert(std::type_name::with_defining_ids<CoinTypeB>(), sui::coin::value<CoinTypeB>(&coin_b));

        let tvl = calculate_tvl_base_on_quote(pyth_oracle, &balances, port.quote_type, clock);

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
            pyth_oracle.get_price<CoinTypeA>(clock),
            pyth_oracle.get_price<CoinTypeB>(clock),
            clock,
            ctx
        )
    }

    #[test_only]
    public fun test_deposit<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
        tvl: u128,
        price_a: vault::pyth_oracle::Price,
        price_b: vault::pyth_oracle::Price,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry<LpCoin> {

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

    fun deposit_internal<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        clmm_global_config: &clmm_pool::config::GlobalConfig, 
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>,
        tvl: u128,
        price_a: vault::pyth_oracle::Price,
        price_b: vault::pyth_oracle::Price,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : PortEntry<LpCoin> {

        let lp_tokens = before_increase_liquidity(
            port, 
            global_config, 
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
        let current_osail_growth = *port.osail_growth_global.borrow(*last_osail_type);

        let port_entry = PortEntry {
            id: sui::object::new(ctx),
            port_id: sui::object::id<Port<LpCoin>>(port),
            lp_tokens: lp_tokens.into_balance(),
            entry_reward_growth,
            entry_osail_growth: current_osail_growth,
        };

        let event = PortEntryCreatedEvent{
            port_id: sui::object::id<Port<LpCoin>>(port),
            port_entry_id: sui::object::id<PortEntry<LpCoin>>(&port_entry),
            lp_tokens_amount: port_entry.lp_tokens.value(),
            entry_reward_growth,
            entry_osail_growth: current_osail_growth,
        };
        sui::event::emit<PortEntryCreatedEvent>(event);
    
        port.add_liquidity<CoinTypeA, CoinTypeB, LpCoin>(
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

// внести новую ликвидность в port_entry
    public fun increase_liquidity<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &mut vault::vault_config::GlobalConfig, 
        pyth_oracle: &vault::pyth_oracle::PythOracle, 
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        port_entry: &mut PortEntry<LpCoin>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {

        let mut balances = sui::vec_map::empty<TypeName, u64>(); 
        balances.insert(std::type_name::with_defining_ids<CoinTypeA>(), sui::coin::value<CoinTypeA>(&coin_a)); 
        balances.insert(std::type_name::with_defining_ids<CoinTypeB>(), sui::coin::value<CoinTypeB>(&coin_b));

        let tvl = calculate_tvl_base_on_quote(pyth_oracle, &balances, port.quote_type, clock);

        let price_a = pyth_oracle.get_price<CoinTypeA>(clock);
        let price_b = pyth_oracle.get_price<CoinTypeB>(clock);

        let lp_tokens = before_increase_liquidity(
            port, 
            global_config, 
            coin_a,
            coin_b, 
            tvl,
            clock, 
            ctx
        );
        check_claimed_rewards(
            port, 
            std::type_name::with_defining_ids<CoinTypeA>(), 
            std::type_name::with_defining_ids<CoinTypeB>(), 
            port_entry, 
            clock
        );

        port_entry.lp_tokens.join(lp_tokens.into_balance());

        let event = PortEntryIncreasedLiquidityEvent{
            port_id: sui::object::id<Port<LpCoin>>(port),
            port_entry_id: sui::object::id<PortEntry<LpCoin>>(port_entry),
            lp_tokens_amount: port_entry.lp_tokens.value(),
        };
        sui::event::emit<PortEntryIncreasedLiquidityEvent>(event);

        port.add_liquidity<CoinTypeA, CoinTypeB, LpCoin>(
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

    // логика перед внесением ликвы
    fun before_increase_liquidity<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &vault::vault_config::GlobalConfig,  
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        tvl: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : Coin<LpCoin> {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        let amount_a = sui::coin::value<CoinTypeA>(&coin_a);
        let amount_b = sui::coin::value<CoinTypeB>(&coin_b);
        assert!(amount_a > 0 || amount_b > 0, vault::error::token_amount_is_zero());
        let digest = *sui::tx_context::digest(ctx);
        assert!(digest == port.status.last_calculate_aum_tx, vault::error::aum_done_err());
        assert!(digest != port.status.last_deposit_tx, vault::error::operation_not_allowed());
        assert!(digest != port.status.last_withdraw_tx, vault::error::operation_not_allowed()); 

        check_updated_rewards(port, clock);

        port.status.last_deposit_tx = digest;

        let lp_supply = lp_total_supply<LpCoin>(port);
        assert!(port.hard_cap == 0 || (port.status.last_aum + tvl <= port.hard_cap), vault::error::hard_cap_reached());

        let lp_amount = get_lp_amount_by_tvl(lp_supply, tvl, port.status.last_aum);
        assert!(lp_amount > 0, vault::error::token_amount_is_zero()); 
        assert!(lp_amount < vault::vault_utils::uint64_max() - 1 - (lp_supply as u128), vault::error::token_amount_overflow());
        port.buffer_assets.join<CoinTypeA>(coin_a.into_balance());
        port.buffer_assets.join<CoinTypeB>(coin_b.into_balance());

        let event = IncreaseLiquidityEvent{
            port_id       : sui::object::id<Port<LpCoin>>(port), 
            before_aum    : port.status.last_aum, 
            user_tvl      : tvl, 
            before_supply : lp_supply, 
            lp_amount     : (lp_amount as u64), 
            amount_a      : amount_a, 
            amount_b      : amount_b,
        };
        sui::event::emit<IncreaseLiquidityEvent>(event);

        port.status.last_aum = port.status.last_aum + tvl;

        let lp_tokens = sui::coin::mint<LpCoin>(
            &mut port.lp_token_treasury,
            (lp_amount as u64),
            ctx
        );

        lp_tokens
    }

    // занести неиспользуемые средства в позицию
    public fun add_liquidity<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &mut vault::vault_config::GlobalConfig, 
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
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(), vault::error::clmm_pool_not_match());
        let diff_price = integer_mate::full_math_u64::mul_div_floor(
            price_a, 
            std::u64::pow(10, vault::pyth_oracle::price_multiplier_decimal()),
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
                        vault::pyth_oracle::price_multiplier_decimal()
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
            port_id            : sui::object::id<Port<LpCoin>>(port),
            amount_a           : amount_a, 
            amount_b           : amount_b, 
            delta_liquidity    : delta_liquidity, 
            current_sqrt_price : clmm_pool::pool::current_sqrt_price<CoinTypeA, CoinTypeB>(pool), 
            lp_supply          : lp_total_supply<LpCoin>(port),
            remained_a         : port.buffer_assets.value<CoinTypeA>(),
            remained_b         : port.buffer_assets.value<CoinTypeB>(),
        };
        sui::event::emit<AddLiquidityEvent>(event);
    }

    fun get_lp_amount_by_tvl(lp_supply: u64, tvl: u128, last_aum: u128) : u128 {
        if (lp_supply == 0) {
            return tvl
        };
        if (last_aum == 0) {
            abort vault::error::invalid_last_aum()
        };
        integer_mate::full_math_u128::mul_div_round((lp_supply as u128), tvl, last_aum)
    }
    
    // изъять средства для перебалансировки
    public fun flash_loan<CoinTypeOut, CoinTypeIn, LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig,  
        pyth_oracle: &vault::pyth_oracle::PythOracle, 
        loan_amount: u64,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext 
    ) : (Coin<CoinTypeOut>, FlashLoanCert) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_operation_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        port.is_pause = true;
        assert!(loan_amount > 0, vault::error::token_amount_is_zero());
        let price_coin_out = vault::pyth_oracle::get_price<CoinTypeOut>(pyth_oracle, clock); 
        let price_coin_in = vault::pyth_oracle::get_price<CoinTypeIn>(pyth_oracle, clock); 
        let (price_coin_out_in_quote, _) = vault::pyth_oracle::calculate_prices(&price_coin_out, &price_coin_in); 
        let repay_amount = integer_mate::full_math_u64::mul_div_ceil( // TODO проверить расчет
            integer_mate::full_math_u64::mul_div_floor(
                price_coin_out_in_quote, 
                loan_amount, 
                std::u64::pow(10, vault::pyth_oracle::price_multiplier_decimal())
            ),
            10000 - (global_config.get_swap_slippage<CoinTypeOut>() + global_config.get_swap_slippage<CoinTypeIn>()) / 2, 
            10000
        );
        let repay_type = std::type_name::with_defining_ids<CoinTypeIn>();
        let (coin_type_a, coin_type_b) = port.vault.coin_types();
        assert!(repay_type == coin_type_a || repay_type == coin_type_b, vault::error::incorrect_repay());
        let flash_loan_cert = FlashLoanCert{
            port_id      : sui::object::id<Port<LpCoin>>(port),  
            repay_type   : repay_type,  
            repay_amount : repay_amount,
        };
        let flash_loan_event = FlashLoanEvent{
            port_id             : sui::object::id<Port<LpCoin>>(port), 
            loan_type           : std::type_name::with_defining_ids<CoinTypeOut>(), 
            repay_type          : repay_type, 
            loan_amount         : loan_amount, 
            repay_amount        : repay_amount, 
            base_to_quote_price : price_coin_out_in_quote, 
            base_price          : vault::pyth_oracle::price_value(&price_coin_out), 
            quote_price         : vault::pyth_oracle::price_value(&price_coin_in),
        };
        sui::event::emit<FlashLoanEvent>(flash_loan_event);

        (
            sui::coin::from_balance<CoinTypeOut>(
                port.buffer_assets.split<CoinTypeOut>(loan_amount), ctx
            ), 
            flash_loan_cert
        )
    }

    // вернуть средства после ребалансировки
    public fun repay_flash_loan<LpCoin, RepayCoinType>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig,
        flash_loan_cert: FlashLoanCert, 
        coin: Coin<RepayCoinType>, 
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_operation_role(global_config, sui::tx_context::sender(ctx));
        assert!(port.is_pause, vault::error::pool_is_pause());
        port.is_pause = false;

        assert!(std::type_name::with_defining_ids<RepayCoinType>() == flash_loan_cert.repay_type, vault::error::incorrect_repay());
        assert!(sui::coin::value<RepayCoinType>(&coin) >= flash_loan_cert.repay_amount, vault::error::incorrect_repay());
        assert!(sui::object::id<Port<LpCoin>>(port) == flash_loan_cert.port_id, vault::error::incorrect_repay());

        let repay_amount = sui::coin::value<RepayCoinType>(&coin);
        port.buffer_assets.join<RepayCoinType>(sui::coin::into_balance<RepayCoinType>(coin)); 

        let FlashLoanCert {
            port_id      : _,
            repay_type   : _,
            repay_amount : _,
        } = flash_loan_cert;
        
        let event = RepayFlashLoanEvent{
            port_id      : sui::object::id<Port<LpCoin>>(port), 
            repay_type   : std::type_name::with_defining_ids<RepayCoinType>(), 
            repay_amount : repay_amount,
        };
        sui::event::emit<RepayFlashLoanEvent>(event);
    }

    // вывести ликвидность из port_entry, пропорционально lp_token_amount
    public fun withdraw<CoinTypeA, CoinTypeB, LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &vault::vault_config::GlobalConfig,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        clmm_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        port_entry: &mut PortEntry<LpCoin>,
        lp_token_amount: u64,
        clock: &sui::clock::Clock, 
        ctx: &mut TxContext
    ) : (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(),
            vault::error::clmm_pool_not_match()
        );
        assert!(lp_token_amount > 0, vault::error::token_amount_is_zero());
        assert!(lp_token_amount <= port_entry.lp_tokens.value(), vault::error::token_amount_not_enough()); 
        let lp_token = port_entry.lp_tokens.split(lp_token_amount);
        let lp_amount = lp_token.value();
        let digest = *sui::tx_context::digest(ctx);
        assert!(digest != port.status.last_deposit_tx, vault::error::operation_not_allowed()); 
        assert!(digest != port.status.last_withdraw_tx, vault::error::operation_not_allowed()); 
        port.status.last_withdraw_tx = digest;
        check_updated_rewards(port, clock);
        check_claimed_rewards(
            port, 
            std::type_name::with_defining_ids<CoinTypeA>(), 
            std::type_name::with_defining_ids<CoinTypeB>(), 
            port_entry, 
            clock
        );

        let lp_supply = lp_total_supply<LpCoin>(port); 
        let mut balances = *port.buffer_assets.balances();
        let coin_a_type = std::type_name::with_defining_ids<CoinTypeA>(); 
        let (_, coin_a_amount) = balances.remove( &coin_a_type);
        let coin_b_type = std::type_name::with_defining_ids<CoinTypeB>();
        let (_, coin_b_amount) = balances.remove(&coin_b_type);
        let mut coin_a_balance = port.buffer_assets.split<CoinTypeA>(
            (get_user_share_by_lp_amount(lp_supply, lp_amount, (coin_a_amount as u128)) as u64)
        );
        let mut coin_b_balance = port.buffer_assets.split<CoinTypeB>(
            (get_user_share_by_lp_amount(lp_supply, lp_amount, (coin_b_amount as u128)) as u64)
        );
        let liquidity = get_user_share_by_lp_amount(lp_supply, lp_amount, port.vault.get_position_liquidity(gauge));
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

        let event = WithdrawEvent{
            port_id   : sui::object::id<Port<LpCoin>>(port),
            port_entry_id: sui::object::id<PortEntry<LpCoin>>(port_entry),
            lp_amount : lp_amount,
            liquidity : liquidity, 
            amount_a  : coin_a_balance.value(), 
            amount_b  : coin_b_balance.value(),
        };
        sui::event::emit<WithdrawEvent>(event);

        port.lp_token_treasury.burn(lp_token.into_coin(ctx));

        (
            sui::coin::from_balance<CoinTypeA>(coin_a_balance, ctx), 
            sui::coin::from_balance<CoinTypeB>(coin_b_balance, ctx)
        )
    }

    // проверка, что пользователь не получил награды
    fun check_claimed_rewards<LpCoin>(
        port: &Port<LpCoin>,
        coin_a_type: TypeName,
        coin_b_type: TypeName,
        port_entry: &PortEntry<LpCoin>,
        clock: &sui::clock::Clock
    ) {
        assert!(!port.is_pause, vault::error::pool_is_pause());

        check_updated_rewards(port, clock);

        let last_osail_type_opt = port.osail_growth_global.back();
        if (last_osail_type_opt.is_some()) {
            let last_osail_type = last_osail_type_opt.borrow();
            assert!(port_entry.entry_reward_growth.contains(last_osail_type) &&
            *port_entry.entry_reward_growth.get(last_osail_type) == *port.osail_growth_global.borrow(*last_osail_type),
            vault::error::osail_reward_not_claimed());
        };

        let balances = *port.buffer_assets.balances();
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
                *port_entry.entry_reward_growth.get(buffer_coin_type) == *port.reward_growth.get(buffer_coin_type),
            vault::error::reward_growth_not_match());

            i = i + 1;
        }
    }

    // уничтожить port_entry (пользователь склеймил награды и вывел все ликвидность)
    public fun destory_port_entry<LpCoin>(
        port: &mut Port<LpCoin>, 
        global_config: &vault::vault_config::GlobalConfig, 
        port_entry: PortEntry<LpCoin>
    ) {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port<LpCoin>>(port), vault::error::port_entry_port_id_not_match());
        assert!(port_entry.lp_tokens.value() == 0, vault::error::port_entry_lp_tokens_not_empty());
        // check_claimed_rewards

        let PortEntry {
            id              : port_entry_id,
            port_id         : _,
            lp_tokens       : lp_tokens,
            entry_reward_growth : _,
            entry_osail_growth : _,
        } = port_entry;

        lp_tokens.destroy_zero();

        let event = PortEntryDestroyedEvent{
            port_id: sui::object::id<Port<LpCoin>>(port),
            port_entry_id: *sui::object::uid_as_inner(&port_entry_id),
        };
        sui::event::emit<PortEntryDestroyedEvent>(event);

        sui::object::delete(port_entry_id);
    }

    // обновить награды (осейл), которые заработала позиция и сложить их для дальнейшего распределения
    public fun update_position_reward<CoinTypeA, CoinTypeB, LpCoin, SailCoinType, OsailCoinType>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig, 
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(
            sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool) == port.vault.pool_id(),
            vault::error::clmm_pool_not_match()
        );
        let osail_coin_type = std::type_name::with_defining_ids<OsailCoinType>();
        // проверка клейма предыдущего осейла происходит на уровне гейджа
        let mut osail_reward = port.vault.collect_position_reward<CoinTypeA, CoinTypeB, SailCoinType, OsailCoinType>(
            minter,
            distribution_config,
            gauge,
            pool,
            clock,
            ctx
        );
        merge_protocol_asset<LpCoin, OsailCoinType>(port, &mut osail_reward); 
        let amount_osail = sui::balance::value<OsailCoinType>(&osail_reward);

        port.osail_reward_balances.join<OsailCoinType>(osail_reward);

        let lp_supply = lp_total_supply<LpCoin>(port);
        let current_growth = if (port.osail_growth_global.contains(osail_coin_type)) {
            port.osail_growth_global.remove(osail_coin_type)
        } else {
            let last_osail_type_opt = port.osail_growth_global.back();
            if (last_osail_type_opt.is_some()) {
                // берем рост последнего типа
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
                (lp_supply as u128)
            )
        );
        assert!(!overflow, vault::error::growth_overflow());
        port.osail_growth_global.push_back(osail_coin_type, new_growth);
        port.last_update_osail_growth_time_ms = sui::clock::timestamp_ms(clock); 

        let event = OsailRewardUpdatedEvent{
            port_id  : sui::object::id<Port<LpCoin>>(port),
            osail_coin_type: osail_coin_type,
            amount_osail : amount_osail, 
            new_growth : new_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<OsailRewardUpdatedEvent>(event);
    }

    // проверка, что награды были обновлены
    public fun check_updated_rewards<LpCoin>(
        port: &Port<LpCoin>,
        clock: &sui::clock::Clock
    ) {
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(port.last_update_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_growth_time()); 
        assert!(port.last_update_osail_growth_time_ms == clock.timestamp_ms(), vault::error::not_updated_osail_growth_time());
    }

    // клейм наград осейла пользователем в соответствии с его долей и временем владения
    public fun claim_position_reward<CoinTypeA, CoinTypeB, LpCoin, SailCoinType, OsailCoinType>(
        global_config: &vault::vault_config::GlobalConfig,
        port: &mut Port<LpCoin>,
        port_entry: &mut PortEntry<LpCoin>,
        minter: &mut governance::minter::Minter<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) : Coin<OsailCoinType> {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port<LpCoin>>(port), vault::error::port_entry_port_id_not_match());

        if (port.last_update_osail_growth_time_ms != clock.timestamp_ms()) { 
            update_position_reward<CoinTypeA, CoinTypeB, LpCoin, SailCoinType, OsailCoinType>(
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
        assert!(port_entry.lp_tokens.value() != 0, vault::error::port_entry_lp_tokens_empty());

        let osail_coin_type = std::type_name::with_defining_ids<OsailCoinType>();
        assert!(port.osail_growth_global.contains(osail_coin_type), vault::error::osail_growth_not_match());

        let osail_growth = port.osail_growth_global.borrow(osail_coin_type);
        let (_, entry_osail_growth) = port_entry.entry_reward_growth.remove(&osail_coin_type);
        assert!(entry_osail_growth < *osail_growth, vault::error::no_available_osail_reward());

        let prev_osail_growth_opt = port.osail_growth_global.prev(osail_coin_type);
        if (prev_osail_growth_opt.is_some()) {
            let prev_osail_growth = port.osail_growth_global.borrow(*prev_osail_growth_opt.borrow());
            assert!(*prev_osail_growth <= entry_osail_growth, vault::error::not_claimed_previous_osail_reward());
        };

        let accumulated_osail_reward_growth = *osail_growth - entry_osail_growth;
        let (osail_reward_amount , overflow) = integer_mate::math_u64::overflowing_mul(port_entry.lp_tokens.value(), (accumulated_osail_reward_growth as u64));
        assert!(!overflow, vault::error::token_amount_overflow());
        assert!(osail_reward_amount > 0, vault::error::osail_reward_empty());

        assert!(port.osail_reward_balances.value<OsailCoinType>() >= osail_reward_amount, vault::error::osail_reward_not_enough());
        let osail_reward = port.osail_reward_balances.split<OsailCoinType>(osail_reward_amount);

        port_entry.entry_reward_growth.insert(osail_coin_type, *osail_growth);

        let event = OsailRewardClaimedEvent{
            port_id  : sui::object::id<Port<LpCoin>>(port),
            port_entry_id: sui::object::id<PortEntry<LpCoin>>(port_entry),
            osail_coin_type: osail_coin_type,
            amount_osail : osail_reward_amount, 
            new_growth : *osail_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<OsailRewardClaimedEvent>(event);

        sui::coin::from_balance<OsailCoinType>(osail_reward, ctx)
    }

// метод для определения типа осейла который можно клеймить
    // fun get_osail_type_to_claim<LpCoin>(port: &mut Port<LpCoin>) : TypeName {
    //     // let osail_type_rewards = port.osail_type_rewards;
    //     // let osail_reward_balances = port.osail_reward_balances;
    //     // let mut i = 0;
    //     // while (i < osail_type_rewards.length()) {
    //     //     let osail_coin_type = osail_type_rewards.borrow(i);
    //     // }
    // }
    
    // обновление наград с пула для позиции
    public fun update_pool_reward<CoinTypeA, CoinTypeB, LpCoin, RewardCoinType>(
        port: &mut Port<LpCoin>, 
        global_config: &vault::vault_config::GlobalConfig,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault, 
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        clock: &sui::clock::Clock
    ) {
        vault::vault_config::checked_package_version(global_config);  
        assert!(!port.is_pause, vault::error::pool_is_pause());
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
        merge_protocol_asset<LpCoin, RewardCoinType>(port, &mut reward_balance); 
        let amount = sui::balance::value<RewardCoinType>(&reward_balance);
        port.buffer_assets.join<RewardCoinType>(reward_balance);

        let reward_type = std::type_name::with_defining_ids<RewardCoinType>();
        let lp_supply = lp_total_supply<LpCoin>(port);
        
        let (_, current_growth) = port.reward_growth.remove(&reward_type);
        let (new_growth, overflow) = integer_mate::math_u128::overflowing_add(
            current_growth,
            integer_mate::full_math_u128::mul_div_floor(
                (amount as u128), 
                1, 
                (lp_supply as u128)
            )
        );
        assert!(!overflow, vault::error::growth_overflow());
        port.reward_growth.insert(reward_type, new_growth);
    
        port.last_update_growth_time_ms = sui::clock::timestamp_ms(clock); 
    
        let event = UpdatePoolRewardEvent{
            port_id     : sui::object::id<Port<LpCoin>>(port),
            reward_type : std::type_name::with_defining_ids<RewardCoinType>(), 
            amount      : amount, 
            new_growth  : new_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<UpdatePoolRewardEvent>(event);
    }

    // клейм наград пользователем из порта
    public fun claim_pool_reward<CoinTypeA, CoinTypeB, LpCoin, RewardCoinType>(
        global_config: &vault::vault_config::GlobalConfig,
        port: &mut Port<LpCoin>,
        port_entry: &mut PortEntry<LpCoin>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clmm_global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) : Coin<RewardCoinType> {
        vault::vault_config::checked_package_version(global_config);
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(port_entry.port_id == sui::object::id<Port<LpCoin>>(port), vault::error::port_entry_port_id_not_match());

        update_pool_reward<CoinTypeA, CoinTypeB, LpCoin, RewardCoinType>(
            port,
            global_config,
            distribution_config,
            gauge,
            clmm_global_config,
            rewarder_vault,
            pool,
            clock
        );
        assert!(port.last_update_growth_time_ms == clock.timestamp_ms(), vault::error::port_entry_time_not_match());
        assert!(port_entry.lp_tokens.value() == 0, vault::error::port_entry_lp_tokens_not_empty());

        let reward_coin_type = std::type_name::with_defining_ids<RewardCoinType>();
        let balances = *port.buffer_assets.balances();
        assert!(balances.contains(&reward_coin_type), vault::error::buffer_assets_not_empty());
        
        let (_, start_growth) = port_entry.entry_reward_growth.remove(&reward_coin_type);
        let current_growth = port.reward_growth.get(&reward_coin_type);
        let accumulated_growth_reward = *current_growth - start_growth;
        let (reward_amount , overflow) = integer_mate::math_u64::overflowing_mul(port_entry.lp_tokens.value(), (accumulated_growth_reward as u64));
        assert!(!overflow, vault::error::token_amount_overflow());
        assert!(reward_amount > 0, vault::error::reward_empty());
        port_entry.entry_reward_growth.insert(std::type_name::with_defining_ids<RewardCoinType>(), *current_growth);

        let port_entry_id = sui::object::id<PortEntry<LpCoin>>(port_entry);
        let event = PoolRewardClaimedEvent{
            port_id     : sui::object::id<Port<LpCoin>>(port),
            port_entry_id : port_entry_id,
            reward_type : std::type_name::with_defining_ids<RewardCoinType>(),
            amount      : reward_amount, 
            new_growth  : *current_growth,
            update_time : sui::clock::timestamp_ms(clock),
        };
        sui::event::emit<PoolRewardClaimedEvent>(event);

        sui::coin::from_balance<RewardCoinType>(port.buffer_assets.split<RewardCoinType>(reward_amount), ctx)
    }
    
    // собрать комиссию протокола с награды
    fun merge_protocol_asset<LpCoin, RewardCoinType>(port: &mut Port<LpCoin>, reward_balance: &mut Balance<RewardCoinType>) {
        let amount = sui::balance::value<RewardCoinType>(reward_balance);
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
    
    public fun lp_total_supply<LpCoin>(port: &Port<LpCoin>) : u64 {
        sui::coin::total_supply<LpCoin>(&port.lp_token_treasury)
    }
    
    public fun update_hard_cap<LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig, 
        new_hard_cap: u128, 
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        let old_hard_cap = port.hard_cap;
        port.hard_cap = new_hard_cap;
        let event = UpdateHardCapEvent{
            port_id      : sui::object::id<Port<LpCoin>>(port), 
            old_hard_cap : old_hard_cap, 
            new_hard_cap : new_hard_cap,
        };
        sui::event::emit<UpdateHardCapEvent>(event);
    }
    
    public fun update_protocol_fee<LpCoin>(
        port: &mut Port<LpCoin>,
        global_config: &vault::vault_config::GlobalConfig,
        new_protocol_fee_rate: u64,
        ctx: &mut TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(!port.is_pause, vault::error::pool_is_pause());
        assert!(new_protocol_fee_rate <= vault::vault_config::get_max_protocol_fee_rate(), vault::error::invalid_protocol_fee_rate()); 
        let old_protocol_fee_rate = port.protocol_fee_rate;
        port.protocol_fee_rate = new_protocol_fee_rate;
        let event = UpdateProtocolFeeEvent{
            port_id               : sui::object::id<Port<LpCoin>>(port), 
            old_protocol_fee_rate : old_protocol_fee_rate, 
            new_protocol_fee_rate : new_protocol_fee_rate,
        };
        sui::event::emit<UpdateProtocolFeeEvent>(event);
    }

    fun get_user_share_by_lp_amount(lp_supply: u64, lp_amount: u64, total_amount: u128) : u128 {
        integer_mate::full_math_u128::mul_div_round((lp_amount as u128), total_amount, (lp_supply as u128))
    }

    public fun pause<LpCoin>(port: &mut Port<LpCoin>, global_config: &vault::vault_config::GlobalConfig, ctx: &mut TxContext) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        port.is_pause = true;
        let event = PauseEvent{port_id: sui::object::id<Port<LpCoin>>(port)};
        sui::event::emit<PauseEvent>(event);
    }

    public fun unpause<LpCoin>(port: &mut Port<LpCoin>, global_config: &vault::vault_config::GlobalConfig, ctx: &mut TxContext) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        port.is_pause = false;
        let event = UnpauseEvent{port_id: sui::object::id<Port<LpCoin>>(port)};
        sui::event::emit<UnpauseEvent>(event);
    }

    public fun get_position_tick_range<CoinTypeA, CoinTypeB, LpCoin>(
        port: &Port<LpCoin>,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>
    ) : (integer_mate::i32::I32, integer_mate::i32::I32) {
        port.vault.get_position_tick_range<CoinTypeA, CoinTypeB>(gauge)
    }

    public fun rebalance_threshold<LpCoin>(port: &Port<LpCoin>) : u32 {
        port.vault.rebalance_threshold()
    }
}


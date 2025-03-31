module clmm_pool::factory {
    public struct FACTORY has drop {
        dummy_field: bool,
    }

    public struct PoolSimpleInfo has copy, drop, store {
        pool_id: sui::object::ID,
        pool_key: sui::object::ID,
        coin_type_a: std::type_name::TypeName,
        coin_type_b: std::type_name::TypeName,
        tick_spacing: u32,
    }

    public struct Pools has store, key {
        id: sui::object::UID,
        list: move_stl::linked_table::LinkedTable<sui::object::ID, PoolSimpleInfo>,
        index: u64,
    }

    public struct InitFactoryEvent has copy, drop {
        pools_id: sui::object::ID,
    }

    public struct CreatePoolEvent has copy, drop {
        pool_id: sui::object::ID,
        coin_type_a: std::string::String,
        coin_type_b: std::string::String,
        tick_spacing: u32,
    }

    public fun coin_types(pool_info: &PoolSimpleInfo): (std::type_name::TypeName, std::type_name::TypeName) {
        (pool_info.coin_type_a, pool_info.coin_type_b)
    }
    
    public fun create_pool<CoinTypeA, CoinTypeB>(
        pools: &mut Pools,
        global_config: &clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        current_sqrt_price: u128,
        url: std::string::String,
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let pool = create_pool_internal<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            current_sqrt_price,
            url,
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
            clock,
            ctx
        );
        sui::transfer::public_share_object<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
    }

    public fun create_pool_<CoinTypeA, CoinTypeB>(
        pools: &mut Pools,
        global_config: &clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        current_sqrt_price: u128,
        url: std::string::String,
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): clmm_pool::pool::Pool<CoinTypeA, CoinTypeB> {
        clmm_pool::config::checked_package_version(global_config);
        create_pool_internal<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            current_sqrt_price,
            url,
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
            clock,
            ctx
        )
    }

    fun create_pool_internal<CoinTypeA, CoinTypeB>(
        pools: &mut Pools,
        global_config: &clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        current_sqrt_price: u128,
        url: std::string::String,
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): clmm_pool::pool::Pool<CoinTypeA, CoinTypeB> {
        assert!(current_sqrt_price >= clmm_pool::tick_math::min_sqrt_price() && current_sqrt_price <= clmm_pool::tick_math::max_sqrt_price(), 2);
        let coin_type_a = std::type_name::get<CoinTypeA>();
        let coin_type_b = std::type_name::get<CoinTypeB>();
        assert!(coin_type_a != coin_type_b, 3);
        let pool_key = new_pool_key<CoinTypeA, CoinTypeB>(tick_spacing);
        if (move_stl::linked_table::contains<sui::object::ID, PoolSimpleInfo>(&pools.list, pool_key)) {
            abort 1
        };
        let pool_url = if (std::string::length(&url) == 0) {
            std::string::utf8(b"")
        } else {
            url
        };
        let pool = clmm_pool::pool::new<CoinTypeA, CoinTypeB>(
            tick_spacing,
            current_sqrt_price,
            clmm_pool::config::get_fee_rate(tick_spacing, global_config),
            pool_url,
            pools.index,
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
            clock,
            ctx
        );
        pools.index = pools.index + 1;
        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(&pool);
        let pool_info = PoolSimpleInfo {
            pool_id,
            pool_key,
            coin_type_a,
            coin_type_b,
            tick_spacing,
        };
        move_stl::linked_table::push_back<sui::object::ID, PoolSimpleInfo>(&mut pools.list, pool_key, pool_info);
        let event = CreatePoolEvent {
            pool_id,
            coin_type_a: std::string::from_ascii(std::type_name::into_string(coin_type_a)),
            coin_type_b: std::string::from_ascii(std::type_name::into_string(coin_type_b)), 
            tick_spacing,
        };
        sui::event::emit<CreatePoolEvent>(event);
        pool
    }

    public fun create_pool_with_liquidity<CoinTypeA, CoinTypeB>(
        pools: &mut Pools,
        global_config: &clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        tick_lower: u32,
        tick_upper: u32,
        mut coin_a_input: sui::coin::Coin<CoinTypeA>,
        mut coin_b_input: sui::coin::Coin<CoinTypeB>,
        liquidity_amount_a: u64,
        liquidity_amount_b: u64,
        fix_amount_a: bool,
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (clmm_pool::position::Position, sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeB>) {
        clmm_pool::config::checked_package_version(global_config);
        let mut pool = create_pool_internal<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
            clock,
            ctx
        );
        let mut position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            &mut pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let fix_amount = if (fix_amount_a) {
            liquidity_amount_a
        } else {
            liquidity_amount_b
        };
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<CoinTypeA, CoinTypeB>(
            global_config,
            &mut pool,
            &mut position,
            fix_amount,
            fix_amount_a,
            clock
        );
        let (amount_a, amount_b) = clmm_pool::pool::add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        if (fix_amount_a) {
            assert!(amount_b <= liquidity_amount_b, 4);
        } else {
            assert!(amount_a <= liquidity_amount_a, 5);
        };
        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            &mut pool,
            sui::coin::into_balance<CoinTypeA>(sui::coin::split<CoinTypeA>(&mut coin_a_input, amount_a, ctx)),
            sui::coin::into_balance<CoinTypeB>(sui::coin::split<CoinTypeB>(&mut coin_b_input, amount_b, ctx)),
            receipt
        );
        sui::transfer::public_share_object<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        (position, coin_a_input, coin_b_input)
    }
    
    public fun fetch_pools(pools: &Pools, pool_ids: vector<sui::object::ID>, limit: u64): vector<PoolSimpleInfo> {
        let mut result = std::vector::empty<PoolSimpleInfo>();
        let next_id = if (std::vector::is_empty<sui::object::ID>(&pool_ids)) {
            move_stl::linked_table::head<sui::object::ID, PoolSimpleInfo>(&pools.list)
        } else {
            // move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(
            //     move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(
            //         &pools.list,
            //         *std::vector::borrow<sui::object::ID>(&pool_ids, 0)
            //     )
            // )
            std::option::some<sui::object::ID>(*std::vector::borrow<sui::object::ID>(&pool_ids, 0))
        };
        let mut current_id = next_id;
        let mut count = 0;
        while (std::option::is_some<sui::object::ID>(&current_id) && count < limit) {
            let node = move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(
                &pools.list,
                *std::option::borrow<sui::object::ID>(&current_id)
            );
            current_id = move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(node);
            std::vector::push_back<PoolSimpleInfo>(
                &mut result,
                *move_stl::linked_table::borrow_value<sui::object::ID, PoolSimpleInfo>(node)
            );
            count = count + 1;
        };
        result
    }

    public fun index(pools: &Pools): u64 {
        pools.index
    }
    
    fun init(factory: FACTORY, ctx: &mut sui::tx_context::TxContext) {
        let pools = Pools {
            id: sui::object::new(ctx),
            list: move_stl::linked_table::new<sui::object::ID, PoolSimpleInfo>(ctx),
            index: 0,
        };
        let pools_id = sui::object::id<Pools>(&pools);
        sui::transfer::share_object<Pools>(pools);
        let event = InitFactoryEvent { pools_id };
        sui::event::emit<InitFactoryEvent>(event);
        sui::package::claim_and_keep<FACTORY>(factory, ctx);
    }
    
    public fun new_pool_key<CoinTypeA, CoinTypeB>(tick_spacing: u32): sui::object::ID {
        let type_name_a = std::type_name::into_string(std::type_name::get<CoinTypeA>());
        let mut bytes_a = *std::ascii::as_bytes(&type_name_a);
        let type_name_b = std::type_name::into_string(std::type_name::get<CoinTypeB>());
        let bytes_b = std::ascii::as_bytes(&type_name_b);
        let mut index = 0;
        let mut swapped = false;
        while (index < std::vector::length<u8>(bytes_b)) {
            let byte_b = *std::vector::borrow<u8>(bytes_b, index);
            let should_compare = !swapped && index < std::vector::length<u8>(&bytes_a);
            let error_code;
            if (should_compare) {
                let byte_a = *std::vector::borrow<u8>(&bytes_a, index);
                if (byte_a < byte_b) {
                    error_code = 6;
                    abort error_code
                };
                if (byte_a > byte_b) {
                    swapped = true;
                };
            };
            std::vector::push_back<u8>(&mut bytes_a, byte_b);
            index = index + 1;
            continue;
            error_code = 6;
            abort error_code
        };
        if (!swapped) {
            if (std::vector::length<u8>(&bytes_a) < std::vector::length<u8>(bytes_b)) {
                abort 6
            };
        };
        std::vector::append<u8>(&mut bytes_a, sui::bcs::to_bytes<u32>(&tick_spacing));
        sui::object::id_from_bytes(sui::hash::blake2b256(&bytes_a))
    }

    public fun pool_id(pool_info: &PoolSimpleInfo): sui::object::ID {
        pool_info.pool_id
    }

    public fun pool_key(pool_info: &PoolSimpleInfo): sui::object::ID {
        pool_info.pool_key
    }

    public fun pool_simple_info(pools: &Pools, pool_key: sui::object::ID): &PoolSimpleInfo {
        move_stl::linked_table::borrow<sui::object::ID, PoolSimpleInfo>(&pools.list, pool_key)
    }

    public fun tick_spacing(pool_info: &PoolSimpleInfo): u32 {
        pool_info.tick_spacing
    }

    // decompiled from Move bytecode v6
}


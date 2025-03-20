module clmm_pool::factory {
    public struct FACTORY has drop {}

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
    
    public fun coin_types(info: &PoolSimpleInfo) : (std::type_name::TypeName, std::type_name::TypeName) {
        (info.coin_type_a, info.coin_type_b)
    }
    
    public fun create_pool<T0, T1>(
        pools: &mut Pools,
        global_config: &clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        sqrt_price: u128,
        url: std::string::String,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let pool = create_pool_internal<T0, T1>(pools, global_config, tick_spacing, sqrt_price, url, clock, ctx);
        sui::transfer::public_share_object<clmm_pool::pool::Pool<T0, T1>>(pool);
    }
    
    public fun create_pool_<T0, T1>(pools: &mut Pools, global_config: &clmm_pool::config::GlobalConfig, tick_spacing: u32, sqrt_price: u128, url: std::string::String, clock: &sui::clock::Clock, ctx: &mut sui::tx_context::TxContext) : clmm_pool::pool::Pool<T0, T1> {
        clmm_pool::config::checked_package_version(global_config);
        create_pool_internal<T0, T1>(pools, global_config, tick_spacing, sqrt_price, url, clock, ctx)
    }
    
    fun create_pool_internal<T0, T1>(pools: &mut Pools, global_config: &clmm_pool::config::GlobalConfig, tick_spacing: u32, sqrt_price: u128, url: std::string::String, clock: &sui::clock::Clock, ctx: &mut sui::tx_context::TxContext) : clmm_pool::pool::Pool<T0, T1> {
        assert!(sqrt_price >= clmm_pool::tick_math::min_sqrt_price() && sqrt_price <= clmm_pool::tick_math::max_sqrt_price(), 2);
        let type_a = std::type_name::get<T0>();
        let type_b = std::type_name::get<T1>();
        assert!(type_a != type_b, 3);
        let pool_key = new_pool_key<T0, T1>(tick_spacing);
        if (move_stl::linked_table::contains<sui::object::ID, PoolSimpleInfo>(&pools.list, pool_key)) {
            abort 1
        };
        let pool_url = if (std::string::length(&url) == 0) {
            std::string::utf8(b"")
        } else {
            url
        };
        let pool = clmm_pool::pool::new<T0, T1>(tick_spacing, sqrt_price, clmm_pool::config::get_fee_rate(tick_spacing, global_config), pool_url, pools.index, clock, ctx);
        pools.index = pools.index + 1;
        let pool_id = sui::object::id<clmm_pool::pool::Pool<T0, T1>>(&pool);
        let pool_info = PoolSimpleInfo{
            pool_id      : pool_id, 
            pool_key     : pool_key, 
            coin_type_a  : type_a, 
            coin_type_b  : type_b, 
            tick_spacing : tick_spacing,
        };
        move_stl::linked_table::push_back<sui::object::ID, PoolSimpleInfo>(&mut pools.list, pool_key, pool_info);
        let event = CreatePoolEvent{
            pool_id      : pool_id, 
            coin_type_a  : std::string::from_ascii(std::type_name::into_string(type_a)), 
            coin_type_b  : std::string::from_ascii(std::type_name::into_string(type_b)), 
            tick_spacing : tick_spacing,
        };
        sui::event::emit<CreatePoolEvent>(event);
        pool
    }
    
    public fun create_pool_with_liquidity<T0, T1>(pools: &mut Pools, global_config: &clmm_pool::config::GlobalConfig, tick_spacing: u32, sqrt_price: u128, url: std::string::String, tick_lower: u32, tick_upper: u32, mut coin_a: sui::coin::Coin<T0>, mut coin_b: sui::coin::Coin<T1>, amount_a: u64, amount_b: u64, fix_amount_a: bool, clock: &sui::clock::Clock, ctx: &mut sui::tx_context::TxContext) : (clmm_pool::position::Position, sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        clmm_pool::config::checked_package_version(global_config);
        let mut pool = create_pool_internal<T0, T1>(pools, global_config, tick_spacing, sqrt_price, url, clock, ctx);
        let mut position = clmm_pool::pool::open_position<T0, T1>(global_config, &mut pool, tick_lower, tick_upper, ctx);
        let fix_amount = if (fix_amount_a) {
            amount_a
        } else {
            amount_b
        };
        let liquidity_delta = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(global_config, &mut pool, &mut position, fix_amount, fix_amount_a, clock);
        let (pay_amount_a, pay_amount_b) = clmm_pool::pool::add_liquidity_pay_amount<T0, T1>(&liquidity_delta);
        if (fix_amount_a) {
            assert!(pay_amount_b <= amount_b, 4);
        } else {
            assert!(pay_amount_a <= amount_a, 5);
        };
        clmm_pool::pool::repay_add_liquidity<T0, T1>(global_config, &mut pool, sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut coin_a, pay_amount_a, ctx)), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut coin_b, pay_amount_b, ctx)), liquidity_delta);
        sui::transfer::public_share_object<clmm_pool::pool::Pool<T0, T1>>(pool);
        (position, coin_a, coin_b)
    }
    
    public fun fetch_pools(pools: &Pools, pool_ids: vector<sui::object::ID>, limit: u64) : vector<PoolSimpleInfo> {
        let mut result = std::vector::empty<PoolSimpleInfo>();
        let next_node = if (std::vector::is_empty<sui::object::ID>(&pool_ids)) {
            move_stl::linked_table::head<sui::object::ID, PoolSimpleInfo>(&pools.list)
        } else {
            move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(&pools.list, *std::vector::borrow<sui::object::ID>(&pool_ids, 0)))
        };
        let mut current = next_node;
        let mut count = 0;
        while (std::option::is_some<sui::object::ID>(&current) && count < limit) {
            let node = move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(&pools.list, *std::option::borrow<sui::object::ID>(&current));
            current = move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(node);
            std::vector::push_back<PoolSimpleInfo>(&mut result, *move_stl::linked_table::borrow_value<sui::object::ID, PoolSimpleInfo>(node));
            count = count + 1;
        };
        result
    }
    
    public fun index(pools: &Pools) : u64 {
        pools.index
    }
    
    fun init(factory: FACTORY, ctx: &mut sui::tx_context::TxContext) {
        let pools = Pools{
            id    : sui::object::new(ctx), 
            list  : move_stl::linked_table::new<sui::object::ID, PoolSimpleInfo>(ctx), 
            index : 0,
        };
        let pools_id = sui::object::id<Pools>(&pools);
        sui::transfer::share_object<Pools>(pools);
        let event = InitFactoryEvent{pools_id};
        sui::event::emit<InitFactoryEvent>(event);
        sui::package::claim_and_keep<FACTORY>(factory, ctx);
    }
    
    public fun new_pool_key<T0, T1>(tick_spacing: u32) : sui::object::ID {
        let type_a_str = std::type_name::into_string(std::type_name::get<T0>());
        let mut bytes = *std::ascii::as_bytes(&type_a_str);
        let type_b_str = std::type_name::into_string(std::type_name::get<T1>());
        let type_b_bytes = std::ascii::as_bytes(&type_b_str);
        let mut i = 0;
        let mut found = false;
        while (i < std::vector::length<u8>(type_b_bytes)) {
            let byte_b = *std::vector::borrow<u8>(type_b_bytes, i);
            let should_compare = !found && i < std::vector::length<u8>(&bytes);
            let err;
            if (should_compare) {
                let byte_a = *std::vector::borrow<u8>(&bytes, i);
                if (byte_a < byte_b) {
                    err = 6;
                    abort err
                };
                if (byte_a > byte_b) {
                    found = true;
                };
            };
            std::vector::push_back<u8>(&mut bytes, byte_b);
            i = i + 1;
            continue;
            err = 6;
            abort err
        };
        if (!found) {
            if (std::vector::length<u8>(&bytes) < std::vector::length<u8>(type_b_bytes)) {
                abort 6
            };
        };
        std::vector::append<u8>(&mut bytes, sui::bcs::to_bytes<u32>(&tick_spacing));
        sui::object::id_from_bytes(sui::hash::blake2b256(&bytes))
    }
    
    public fun pool_id(info: &PoolSimpleInfo) : sui::object::ID {
        info.pool_id
    }
    
    public fun pool_key(info: &PoolSimpleInfo) : sui::object::ID {
        info.pool_key
    }
    
    public fun pool_simple_info(pools: &Pools, key: sui::object::ID) : &PoolSimpleInfo {
        move_stl::linked_table::borrow<sui::object::ID, PoolSimpleInfo>(&pools.list, key)
    }
    
    public fun tick_spacing(info: &PoolSimpleInfo) : u32 {
        info.tick_spacing
    }

    // decompiled from Move bytecode v6
}


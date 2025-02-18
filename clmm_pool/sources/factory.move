module clmm_pool::factory {
    public struct FACTORY has drop {
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
    
    public fun coin_types(arg0: &PoolSimpleInfo) : (std::type_name::TypeName, std::type_name::TypeName) {
        (arg0.coin_type_a, arg0.coin_type_b)
    }
    
    public fun create_pool<T0, T1>(arg0: &mut Pools, arg1: &clmm_pool::config::GlobalConfig, arg2: u32, arg3: u128, arg4: std::string::String, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        clmm_pool::config::checked_package_version(arg1);
        let pool = create_pool_internal<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
        sui::transfer::public_share_object<clmm_pool::pool::Pool<T0, T1>>(pool);
    }
    
    public fun create_pool_<T0, T1>(arg0: &mut Pools, arg1: &clmm_pool::config::GlobalConfig, arg2: u32, arg3: u128, arg4: std::string::String, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) : clmm_pool::pool::Pool<T0, T1> {
        clmm_pool::config::checked_package_version(arg1);
        create_pool_internal<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
    }
    
    fun create_pool_internal<T0, T1>(arg0: &mut Pools, arg1: &clmm_pool::config::GlobalConfig, arg2: u32, arg3: u128, arg4: std::string::String, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) : clmm_pool::pool::Pool<T0, T1> {
        assert!(arg3 >= clmm_pool::tick_math::min_sqrt_price() && arg3 <= clmm_pool::tick_math::max_sqrt_price(), 2);
        let v0 = std::type_name::get<T0>();
        let v1 = std::type_name::get<T1>();
        assert!(v0 != v1, 3);
        let v2 = new_pool_key<T0, T1>(arg2);
        if (move_stl::linked_table::contains<sui::object::ID, PoolSimpleInfo>(&arg0.list, v2)) {
            abort 1
        };
        let v3 = if (std::string::length(&arg4) == 0) {
            std::string::utf8(b"")
        } else {
            arg4
        };
        let v4 = clmm_pool::pool::new<T0, T1>(arg2, arg3, clmm_pool::config::get_fee_rate(arg2, arg1), v3, arg0.index, arg5, arg6);
        arg0.index = arg0.index + 1;
        let v5 = sui::object::id<clmm_pool::pool::Pool<T0, T1>>(&v4);
        let v6 = PoolSimpleInfo{
            pool_id      : v5, 
            pool_key     : v2, 
            coin_type_a  : v0, 
            coin_type_b  : v1, 
            tick_spacing : arg2,
        };
        move_stl::linked_table::push_back<sui::object::ID, PoolSimpleInfo>(&mut arg0.list, v2, v6);
        let v7 = CreatePoolEvent{
            pool_id      : v5, 
            coin_type_a  : std::string::from_ascii(std::type_name::into_string(v0)), 
            coin_type_b  : std::string::from_ascii(std::type_name::into_string(v1)), 
            tick_spacing : arg2,
        };
        sui::event::emit<CreatePoolEvent>(v7);
        v4
    }
    
    public fun create_pool_with_liquidity<T0, T1>(arg0: &mut Pools, arg1: &clmm_pool::config::GlobalConfig, arg2: u32, arg3: u128, arg4: std::string::String, arg5: u32, arg6: u32, mut arg7: sui::coin::Coin<T0>, mut arg8: sui::coin::Coin<T1>, arg9: u64, arg10: u64, arg11: bool, arg12: &sui::clock::Clock, arg13: &mut sui::tx_context::TxContext) : (clmm_pool::position::Position, sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        clmm_pool::config::checked_package_version(arg1);
        let mut v0 = create_pool_internal<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg12, arg13);
        let mut v1 = clmm_pool::pool::open_position<T0, T1>(arg1, &mut v0, arg5, arg6, arg13);
        let v2 = if (arg11) {
            arg9
        } else {
            arg10
        };
        let v3 = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg1, &mut v0, &mut v1, v2, arg11, arg12);
        let (v4, v5) = clmm_pool::pool::add_liquidity_pay_amount<T0, T1>(&v3);
        if (arg11) {
            assert!(v5 <= arg10, 4);
        } else {
            assert!(v4 <= arg9, 5);
        };
        clmm_pool::pool::repay_add_liquidity<T0, T1>(arg1, &mut v0, sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut arg7, v4, arg13)), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut arg8, v5, arg13)), v3);
        sui::transfer::public_share_object<clmm_pool::pool::Pool<T0, T1>>(v0);
        (v1, arg7, arg8)
    }
    
    public fun fetch_pools(arg0: &Pools, arg1: vector<sui::object::ID>, arg2: u64) : vector<PoolSimpleInfo> {
        let mut v0 = std::vector::empty<PoolSimpleInfo>();
        let v1 = if (std::vector::is_empty<sui::object::ID>(&arg1)) {
            move_stl::linked_table::head<sui::object::ID, PoolSimpleInfo>(&arg0.list)
        } else {
            move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(&arg0.list, *std::vector::borrow<sui::object::ID>(&arg1, 0)))
        };
        let mut v2 = v1;
        let mut v3 = 0;
        while (std::option::is_some<sui::object::ID>(&v2) && v3 < arg2) {
            let v4 = move_stl::linked_table::borrow_node<sui::object::ID, PoolSimpleInfo>(&arg0.list, *std::option::borrow<sui::object::ID>(&v2));
            v2 = move_stl::linked_table::next<sui::object::ID, PoolSimpleInfo>(v4);
            std::vector::push_back<PoolSimpleInfo>(&mut v0, *move_stl::linked_table::borrow_value<sui::object::ID, PoolSimpleInfo>(v4));
            v3 = v3 + 1;
        };
        v0
    }
    
    public fun index(arg0: &Pools) : u64 {
        arg0.index
    }
    
    fun init(arg0: FACTORY, arg1: &mut sui::tx_context::TxContext) {
        let v0 = Pools{
            id    : sui::object::new(arg1), 
            list  : move_stl::linked_table::new<sui::object::ID, PoolSimpleInfo>(arg1), 
            index : 0,
        };
        let pools_id = sui::object::id<Pools>(&v0);
        sui::transfer::share_object<Pools>(v0);
        let v1 = InitFactoryEvent{pools_id};
        sui::event::emit<InitFactoryEvent>(v1);
        sui::package::claim_and_keep<FACTORY>(arg0, arg1);
    }
    
    public fun new_pool_key<T0, T1>(arg0: u32) : sui::object::ID {
        let v0 = std::type_name::into_string(std::type_name::get<T0>());
        let mut v1 = *std::ascii::as_bytes(&v0);
        let v2 = std::type_name::into_string(std::type_name::get<T1>());
        let v3 = std::ascii::as_bytes(&v2);
        let mut v4 = 0;
        let mut v5 = false;
        while (v4 < std::vector::length<u8>(v3)) {
            let v6 = *std::vector::borrow<u8>(v3, v4);
            let v7 = !v5 && v4 < std::vector::length<u8>(&v1);
            let v8;
            if (v7) {
                let v9 = *std::vector::borrow<u8>(&v1, v4);
                if (v9 < v6) {
                    v8 = 6;
                    abort v8
                };
                if (v9 > v6) {
                    v5 = true;
                };
            };
            std::vector::push_back<u8>(&mut v1, v6);
            v4 = v4 + 1;
            continue;
            v8 = 6;
            abort v8
        };
        if (!v5) {
            if (std::vector::length<u8>(&v1) < std::vector::length<u8>(v3)) {
                abort 6
            };
        };
        std::vector::append<u8>(&mut v1, sui::bcs::to_bytes<u32>(&arg0));
        sui::object::id_from_bytes(sui::hash::blake2b256(&v1))
    }
    
    public fun pool_id(arg0: &PoolSimpleInfo) : sui::object::ID {
        arg0.pool_id
    }
    
    public fun pool_key(arg0: &PoolSimpleInfo) : sui::object::ID {
        arg0.pool_key
    }
    
    public fun pool_simple_info(arg0: &Pools, arg1: sui::object::ID) : &PoolSimpleInfo {
        move_stl::linked_table::borrow<sui::object::ID, PoolSimpleInfo>(&arg0.list, arg1)
    }
    
    public fun tick_spacing(arg0: &PoolSimpleInfo) : u32 {
        arg0.tick_spacing
    }
    
    // decompiled from Move bytecode v6
}


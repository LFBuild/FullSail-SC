module integrate::pool_script {
    fun swap<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: vector<sui::coin::Coin<T0>>, arg3: vector<sui::coin::Coin<T1>>, arg4: bool, arg5: bool, arg6: u64, arg7: u64, arg8: u128, arg9: &sui::clock::Clock, arg10: &mut sui::tx_context::TxContext) {
        let v0 = integrate::utils::merge_coins<T1>(arg3, arg10);
        let v1 = integrate::utils::merge_coins<T0>(arg2, arg10);
        let (v2, v3, v4) = clmm_pool::pool::flash_swap<T0, T1>(arg0, arg1, arg4, arg5, arg6, arg8, arg9);
        let v5 = v4;
        let v6 = v3;
        let v7 = v2;
        let v8 = clmm_pool::pool::swap_pay_amount<T0, T1>(&v5);
        let v9 = if (arg4) {
            sui::balance::value<T1>(&v6)
        } else {
            sui::balance::value<T0>(&v7)
        };
        if (arg5) {
            assert!(v8 == arg6, 2);
            assert!(v9 >= arg7, 1);
        } else {
            assert!(v9 == arg6, 2);
            assert!(v8 <= arg7, 0);
        };
        let (v10, v11) = if (arg4) {
            (sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut v1, v8, arg10)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut v0, v8, arg10)))
        };
        sui::coin::join<T1>(&mut v0, sui::coin::from_balance<T1>(v6, arg10));
        sui::coin::join<T0>(&mut v1, sui::coin::from_balance<T0>(v7, arg10));
        clmm_pool::pool::repay_flash_swap<T0, T1>(arg0, arg1, v10, v11, v5);
        integrate::utils::send_coin<T0>(v1, sui::tx_context::sender(arg10));
        integrate::utils::send_coin<T1>(v0, sui::tx_context::sender(arg10));
    }
    
    public entry fun create_pool<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::factory::Pools, arg2: u32, arg3: u128, arg4: std::string::String, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        clmm_pool::factory::create_pool<T0, T1>(arg1, arg0, arg2, arg3, arg4, arg5, arg6);
    }
    
    public entry fun close_position<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: clmm_pool::position::Position, arg3: u64, arg4: u64, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        let v0 = clmm_pool::position::liquidity(&arg2);
        if (v0 > 0) {
            remove_liquidity<T0, T1>(arg0, arg1, &mut arg2, v0, arg3, arg4, arg5, arg6);
        };
        clmm_pool::pool::close_position<T0, T1>(arg0, arg1, arg2);
    }
    
    public entry fun collect_fee<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: &mut sui::tx_context::TxContext) {
        let (v0, v1) = clmm_pool::pool::collect_fee<T0, T1>(arg0, arg1, arg2, true);
        integrate::utils::send_coin<T0>(sui::coin::from_balance<T0>(v0, arg3), sui::tx_context::sender(arg3));
        integrate::utils::send_coin<T1>(sui::coin::from_balance<T1>(v1, arg3), sui::tx_context::sender(arg3));
    }
    
    public entry fun collect_protocol_fee<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut sui::tx_context::TxContext) {
        let (v0, v1) = clmm_pool::pool::collect_protocol_fee<T0, T1>(arg0, arg1, arg2);
        integrate::utils::send_coin<T0>(sui::coin::from_balance<T0>(v0, arg2), sui::tx_context::sender(arg2));
        integrate::utils::send_coin<T1>(sui::coin::from_balance<T1>(v1, arg2), sui::tx_context::sender(arg2));
    }
    
    public entry fun collect_reward<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: &mut clmm_pool::rewarder::RewarderGlobalVault, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        integrate::utils::send_coin<T2>(sui::coin::from_balance<T2>(clmm_pool::pool::collect_reward<T0, T1, T2>(arg0, arg1, arg2, arg3, true, arg4), arg5), sui::tx_context::sender(arg5));
    }
    
    public entry fun initialize_rewarder<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::initialize_rewarder<T0, T1, T2>(arg0, arg1, arg2);
    }
    
    public entry fun open_position<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: u32, arg3: u32, arg4: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer<clmm_pool::position::Position>(clmm_pool::pool::open_position<T0, T1>(arg0, arg1, arg2, arg3, arg4), sui::tx_context::sender(arg4));
    }
    
    public entry fun remove_liquidity<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: u128, arg4: u64, arg5: u64, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        let (v0, v1) = clmm_pool::pool::remove_liquidity<T0, T1>(arg0, arg1, arg2, arg3, arg6);
        let v2 = v1;
        let v3 = v0;
        assert!(sui::balance::value<T0>(&v3) >= arg4, 1);
        assert!(sui::balance::value<T1>(&v2) >= arg5, 1);
        let (v4, v5) = clmm_pool::pool::collect_fee<T0, T1>(arg0, arg1, arg2, false);
        sui::balance::join<T0>(&mut v3, v4);
        sui::balance::join<T1>(&mut v2, v5);
        integrate::utils::send_coin<T0>(sui::coin::from_balance<T0>(v3, arg7), sui::tx_context::sender(arg7));
        integrate::utils::send_coin<T1>(sui::coin::from_balance<T1>(v2, arg7), sui::tx_context::sender(arg7));
    }
    
    fun repay_add_liquidity<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: clmm_pool::pool::AddLiquidityReceipt<T0, T1>, arg3: vector<sui::coin::Coin<T0>>, arg4: vector<sui::coin::Coin<T1>>, arg5: u64, arg6: u64, arg7: &mut sui::tx_context::TxContext) {
        let v0 = integrate::utils::merge_coins<T0>(arg3, arg7);
        let v1 = integrate::utils::merge_coins<T1>(arg4, arg7);
        let (v2, v3) = clmm_pool::pool::add_liquidity_pay_amount<T0, T1>(&arg2);
        assert!(v2 <= arg5, 0);
        assert!(v3 <= arg6, 0);
        clmm_pool::pool::repay_add_liquidity<T0, T1>(arg0, arg1, sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut v0, v2, arg7)), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut v1, v3, arg7)), arg2);
        integrate::utils::send_coin<T0>(v0, sui::tx_context::sender(arg7));
        integrate::utils::send_coin<T1>(v1, sui::tx_context::sender(arg7));
    }
    
    public entry fun set_display<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &sui::package::Publisher, arg2: std::string::String, arg3: std::string::String, arg4: std::string::String, arg5: std::string::String, arg6: std::string::String, arg7: std::string::String, arg8: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::set_display<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
    }
    
    public entry fun update_fee_rate<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::update_fee_rate<T0, T1>(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_position_url<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: std::string::String, arg3: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::update_position_url<T0, T1>(arg0, arg1, arg2, arg3);
    }
    
    public entry fun add_liquidity_fix_coin_only_a<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T0>>, arg4: u64, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, arg2, arg4, true, arg5, arg6), arg3, std::vector::empty<sui::coin::Coin<T1>>(), arg4, 0, arg6);
    }
    
    public entry fun add_liquidity_fix_coin_only_b<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T1>>, arg4: u64, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, arg2, arg4, false, arg5, arg6), std::vector::empty<sui::coin::Coin<T0>>(), arg3, 0, arg4, arg6);
    }
    
    public entry fun add_liquidity_fix_coin_with_all<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T0>>, arg4: vector<sui::coin::Coin<T1>>, arg5: u64, arg6: u64, arg7: bool, arg8: &sui::clock::Clock, arg9: &mut sui::tx_context::TxContext) {
        let v0 = if (arg7) {
            arg5
        } else {
            arg6
        };
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, arg2, v0, arg7, arg8, arg9), arg3, arg4, arg5, arg6, arg9);
    }
    
    public entry fun add_liquidity_only_a<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T0>>, arg4: u64, arg5: u128, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity<T0, T1>(arg0, arg1, arg2, arg5, arg6, arg7), arg3, std::vector::empty<sui::coin::Coin<T1>>(), arg4, 0, arg7);
    }
    
    public entry fun add_liquidity_only_b<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T1>>, arg4: u64, arg5: u128, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity<T0, T1>(arg0, arg1, arg2, arg5, arg6, arg7), std::vector::empty<sui::coin::Coin<T0>>(), arg3, 0, arg4, arg7);
    }
    
    public entry fun add_liquidity_with_all<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: vector<sui::coin::Coin<T0>>, arg4: vector<sui::coin::Coin<T1>>, arg5: u64, arg6: u64, arg7: u128, arg8: &sui::clock::Clock, arg9: &mut sui::tx_context::TxContext) {
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity<T0, T1>(arg0, arg1, arg2, arg7, arg8, arg9), arg3, arg4, arg5, arg6, arg9);
    }
    
    public entry fun create_pool_with_liquidity_only_a<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::factory::Pools, arg2: u32, arg3: u128, arg4: std::string::String, arg5: vector<sui::coin::Coin<T0>>, arg6: u32, arg7: u32, arg8: u64, arg9: &sui::clock::Clock, arg10: &mut sui::tx_context::TxContext) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(arg1, arg0, arg2, arg3, arg4, arg6, arg7, integrate::utils::merge_coins<T0>(arg5, arg10), sui::coin::zero<T1>(arg10), arg8, 0, true, arg9, arg10);
        sui::coin::destroy_zero<T1>(v2);
        integrate::utils::send_coin<T0>(v1, sui::tx_context::sender(arg10));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg10));
    }
    
    public entry fun create_pool_with_liquidity_only_b<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::factory::Pools, arg2: u32, arg3: u128, arg4: std::string::String, arg5: vector<sui::coin::Coin<T1>>, arg6: u32, arg7: u32, arg8: u64, arg9: &sui::clock::Clock, arg10: &mut sui::tx_context::TxContext) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(arg1, arg0, arg2, arg3, arg4, arg6, arg7, sui::coin::zero<T0>(arg10), integrate::utils::merge_coins<T1>(arg5, arg10), 0, arg8, false, arg9, arg10);
        sui::coin::destroy_zero<T0>(v1);
        integrate::utils::send_coin<T1>(v2, sui::tx_context::sender(arg10));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg10));
    }
    
    public entry fun create_pool_with_liquidity_with_all<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::factory::Pools, arg2: u32, arg3: u128, arg4: std::string::String, arg5: vector<sui::coin::Coin<T0>>, arg6: vector<sui::coin::Coin<T1>>, arg7: u32, arg8: u32, arg9: u64, arg10: u64, arg11: bool, arg12: &sui::clock::Clock, arg13: &mut sui::tx_context::TxContext) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(arg1, arg0, arg2, arg3, arg4, arg7, arg8, integrate::utils::merge_coins<T0>(arg5, arg13), integrate::utils::merge_coins<T1>(arg6, arg13), arg9, arg10, arg11, arg12, arg13);
        integrate::utils::send_coin<T0>(v1, sui::tx_context::sender(arg13));
        integrate::utils::send_coin<T1>(v2, sui::tx_context::sender(arg13));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg13));
    }
    
    public entry fun open_position_with_liquidity_only_a<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: u32, arg3: u32, arg4: vector<sui::coin::Coin<T0>>, arg5: u64, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        let v0 = clmm_pool::pool::open_position<T0, T1>(arg0, arg1, arg2, arg3, arg7);
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, &mut v0, arg5, true, arg6, arg7), arg4, std::vector::empty<sui::coin::Coin<T1>>(), arg5, 0, arg7);
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg7));
    }
    
    public entry fun open_position_with_liquidity_only_b<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: u32, arg3: u32, arg4: vector<sui::coin::Coin<T1>>, arg5: u64, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        let v0 = clmm_pool::pool::open_position<T0, T1>(arg0, arg1, arg2, arg3, arg7);
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, &mut v0, arg5, false, arg6, arg7), std::vector::empty<sui::coin::Coin<T0>>(), arg4, 0, arg5, arg7);
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg7));
    }
    
    public entry fun open_position_with_liquidity_with_all<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: u32, arg3: u32, arg4: vector<sui::coin::Coin<T0>>, arg5: vector<sui::coin::Coin<T1>>, arg6: u64, arg7: u64, arg8: bool, arg9: &sui::clock::Clock, arg10: &mut sui::tx_context::TxContext) {
        let v0 = clmm_pool::pool::open_position<T0, T1>(arg0, arg1, arg2, arg3, arg10);
        let v1 = if (arg8) {
            arg6
        } else {
            arg7
        };
        repay_add_liquidity<T0, T1>(arg0, arg1, clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(arg0, arg1, &mut v0, v1, arg8, arg9, arg10), arg4, arg5, arg6, arg7, arg10);
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(arg10));
    }
    
    public entry fun pause_pool<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::pause<T0, T1>(arg0, arg1, arg2);
    }
    
    public entry fun swap_a2b<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: vector<sui::coin::Coin<T0>>, arg3: bool, arg4: u64, arg5: u64, arg6: u128, arg7: &sui::clock::Clock, arg8: &mut sui::tx_context::TxContext) {
        swap<T0, T1>(arg0, arg1, arg2, std::vector::empty<sui::coin::Coin<T1>>(), true, arg3, arg4, arg5, arg6, arg7, arg8);
    }
    
    public entry fun swap_a2b_with_partner<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::partner::Partner, arg3: vector<sui::coin::Coin<T0>>, arg4: bool, arg5: u64, arg6: u64, arg7: u128, arg8: &sui::clock::Clock, arg9: &mut sui::tx_context::TxContext) {
        swap_with_partner<T0, T1>(arg0, arg1, arg2, arg3, std::vector::empty<sui::coin::Coin<T1>>(), true, arg4, arg5, arg6, arg7, arg8, arg9);
    }
    
    public entry fun swap_b2a<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: vector<sui::coin::Coin<T1>>, arg3: bool, arg4: u64, arg5: u64, arg6: u128, arg7: &sui::clock::Clock, arg8: &mut sui::tx_context::TxContext) {
        swap<T0, T1>(arg0, arg1, std::vector::empty<sui::coin::Coin<T0>>(), arg2, false, arg3, arg4, arg5, arg6, arg7, arg8);
    }
    
    public entry fun swap_b2a_with_partner<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::partner::Partner, arg3: vector<sui::coin::Coin<T1>>, arg4: bool, arg5: u64, arg6: u64, arg7: u128, arg8: &sui::clock::Clock, arg9: &mut sui::tx_context::TxContext) {
        swap_with_partner<T0, T1>(arg0, arg1, arg2, std::vector::empty<sui::coin::Coin<T0>>(), arg3, false, arg4, arg5, arg6, arg7, arg8, arg9);
    }
    
    fun swap_with_partner<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::partner::Partner, arg3: vector<sui::coin::Coin<T0>>, arg4: vector<sui::coin::Coin<T1>>, arg5: bool, arg6: bool, arg7: u64, arg8: u64, arg9: u128, arg10: &sui::clock::Clock, arg11: &mut sui::tx_context::TxContext) {
        let v0 = integrate::utils::merge_coins<T0>(arg3, arg11);
        let v1 = integrate::utils::merge_coins<T1>(arg4, arg11);
        let (v2, v3, v4) = clmm_pool::pool::flash_swap_with_partner<T0, T1>(arg0, arg1, arg2, arg5, arg6, arg7, arg9, arg10);
        let v5 = v4;
        let v6 = v3;
        let v7 = v2;
        let v8 = clmm_pool::pool::swap_pay_amount<T0, T1>(&v5);
        let v9 = if (arg5) {
            sui::balance::value<T1>(&v6)
        } else {
            sui::balance::value<T0>(&v7)
        };
        if (arg6) {
            assert!(v8 == arg7, 2);
            assert!(v9 >= arg8, 1);
        } else {
            assert!(v9 == arg7, 2);
            assert!(v8 <= arg8, 0);
        };
        let (v10, v11) = if (arg5) {
            (sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut v0, v8, arg11)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut v1, v8, arg11)))
        };
        sui::coin::join<T0>(&mut v0, sui::coin::from_balance<T0>(v7, arg11));
        sui::coin::join<T1>(&mut v1, sui::coin::from_balance<T1>(v6, arg11));
        clmm_pool::pool::repay_flash_swap_with_partner<T0, T1>(arg0, arg1, arg2, v10, v11, v5);
        integrate::utils::send_coin<T0>(v0, sui::tx_context::sender(arg11));
        integrate::utils::send_coin<T1>(v1, sui::tx_context::sender(arg11));
    }
    
    public entry fun unpause_pool<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::unpause<T0, T1>(arg0, arg1, arg2);
    }
    
    public entry fun update_rewarder_emission<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &clmm_pool::rewarder::RewarderGlobalVault, arg3: u128, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::update_emission<T0, T1, T2>(arg0, arg1, arg2, arg3, arg4, arg5);
    }
    
    // decompiled from Move bytecode v6
}


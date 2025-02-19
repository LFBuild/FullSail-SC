module integrate::pool_creator_v2 {
    fun build_init_position_arg<T0, T1>(arg0: u128, arg1: u32, arg2: u32, arg3: &mut sui::coin::Coin<T0>, arg4: &mut sui::coin::Coin<T1>, arg5: bool, arg6: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        let v0 = sui::coin::value<T0>(arg3);
        let v1 = sui::coin::value<T1>(arg4);
        let v2 = if (arg5) {
            v0
        } else {
            v1
        };
        let (_, v4, v5) = clmm_pool::clmm_math::get_liquidity_by_amount(integer_mate::i32::from_u32(arg1), integer_mate::i32::from_u32(arg2), clmm_pool::tick_math::get_tick_at_sqrt_price(arg0), arg0, v2, arg5);
        assert!(v4 <= v0, 1);
        assert!(v5 <= v1, 1);
        (sui::coin::split<T0>(arg3, v4, arg6), sui::coin::split<T1>(arg4, v5, arg6))
    }
    
    public entry fun create_pool_v2<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::factory::Pools, arg2: u32, arg3: u128, arg4: std::string::String, arg5: u32, arg6: u32, arg7: &mut sui::coin::Coin<T0>, arg8: &mut sui::coin::Coin<T1>, arg9: &sui::coin::CoinMetadata<T0>, arg10: &sui::coin::CoinMetadata<T1>, arg11: bool, arg12: &sui::clock::Clock, arg13: &mut sui::tx_context::TxContext) {
        let (v0, v1) = build_init_position_arg<T0, T1>(arg3, arg5, arg6, arg7, arg8, arg11, arg13);
        let v2 = v1;
        let v3 = v0;
        let liquidity_coin_1 = sui::coin::value<T0>(&v3);
        let liquidity_coin_2 = sui::coin::value<T1>(&v2);
        let (v4, v5, v6) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(arg1, arg0, arg2, arg3, arg4, arg5, arg6, v3, v2, liquidity_coin_1, liquidity_coin_2, arg11, arg12, arg13);
        sui::coin::destroy_zero<T0>(v5);
        sui::coin::destroy_zero<T1>(v6);
        sui::transfer::public_transfer<clmm_pool::position::Position>(v4, sui::tx_context::sender(arg13));
    }
    
    // decompiled from Move bytecode v6
}


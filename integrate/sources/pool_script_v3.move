module integrate::pool_script_v3 {
    public entry fun collect_fee<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: &mut sui::coin::Coin<T0>, arg4: &mut sui::coin::Coin<T1>, arg5: &mut sui::tx_context::TxContext) {
        let (v0, v1) = clmm_pool::pool::collect_fee<T0, T1>(arg0, arg1, arg2, true);
        sui::coin::join<T0>(arg3, sui::coin::from_balance<T0>(v0, arg5));
        sui::coin::join<T1>(arg4, sui::coin::from_balance<T1>(v1, arg5));
    }
    
    public entry fun collect_reward<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::position::Position, arg3: &mut clmm_pool::rewarder::RewarderGlobalVault, arg4: &mut sui::coin::Coin<T2>, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        sui::coin::join<T2>(arg4, sui::coin::from_balance<T2>(clmm_pool::pool::collect_reward<T0, T1, T2>(arg0, arg1, arg2, arg3, true, arg5), arg6));
    }
    
    public entry fun update_rewarder_emission<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &clmm_pool::rewarder::RewarderGlobalVault, arg3: u64, arg4: u64, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        clmm_pool::pool::update_emission<T0, T1, T2>(arg0, arg1, arg2, integer_mate::full_math_u128::mul_div_floor(arg3 as u128, 18446744073709551616, arg4 as u128), arg5, arg6);
    }
    
    // decompiled from Move bytecode v6
}


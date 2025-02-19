module integrate::rewarder_script {
    public entry fun deposit_reward<T0>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::rewarder::RewarderGlobalVault, arg2: vector<sui::coin::Coin<T0>>, arg3: u64, arg4: &mut sui::tx_context::TxContext) {
        let mut v0 = integrate::utils::merge_coins<T0>(arg2, arg4);
        assert!(sui::coin::value<T0>(&v0) >= arg3, 1);
        clmm_pool::rewarder::deposit_reward<T0>(arg0, arg1, sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut v0, arg3, arg4)));
        integrate::utils::send_coin<T0>(v0, sui::tx_context::sender(arg4));
    }
    
    public entry fun emergent_withdraw<T0>(arg0: &clmm_pool::config::AdminCap, arg1: &clmm_pool::config::GlobalConfig, arg2: &mut clmm_pool::rewarder::RewarderGlobalVault, arg3: u64, arg4: address, arg5: &mut sui::tx_context::TxContext) {
        assert!(clmm_pool::rewarder::balance_of<T0>(arg2) >= arg3, 2);
        integrate::utils::send_coin<T0>(sui::coin::from_balance<T0>(clmm_pool::rewarder::emergent_withdraw<T0>(arg0, arg1, arg2, arg3), arg5), arg4);
    }
    
    public entry fun emergent_withdraw_all<T0>(arg0: &clmm_pool::config::AdminCap, arg1: &clmm_pool::config::GlobalConfig, arg2: &mut clmm_pool::rewarder::RewarderGlobalVault, arg3: address, arg4: &mut sui::tx_context::TxContext) {
        let global_vault_balance = clmm_pool::rewarder::balance_of<T0>(arg2);
        integrate::utils::send_coin<T0>(sui::coin::from_balance<T0>(clmm_pool::rewarder::emergent_withdraw<T0>(arg0, arg1, arg2, global_vault_balance), arg4), arg3);
    }
    
    // decompiled from Move bytecode v6
}


module integrate::rewarder_script {
    public entry fun deposit_reward<RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        reward_input_coins: vector<sui::coin::Coin<RewardCoinType>>,
        amount: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut reward_coin = integrate::utils::merge_coins<RewardCoinType>(reward_input_coins, ctx);
        assert!(reward_coin.value<RewardCoinType>() >= amount, 1);
        clmm_pool::rewarder::deposit_reward<RewardCoinType>(
            global_config,
            rewarder_vault,
            sui::coin::into_balance<RewardCoinType>(sui::coin::split<RewardCoinType>(&mut reward_coin, amount, ctx))
        );
        integrate::utils::send_coin<RewardCoinType>(reward_coin, sui::tx_context::sender(ctx));
    }

    public entry fun emergent_withdraw<RewardCoinType>(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        amount: u64,
        recipient: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(clmm_pool::rewarder::balance_of<RewardCoinType>(rewarder_vault) >= amount, 2);
        integrate::utils::send_coin<RewardCoinType>(
            sui::coin::from_balance<RewardCoinType>(clmm_pool::rewarder::emergent_withdraw<RewardCoinType>(
                admin_cap,
                global_config,
                rewarder_vault,
                amount
            ), ctx),
            recipient
        );
    }

    public entry fun emergent_withdraw_all<RewardCoinType>(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &clmm_pool::config::GlobalConfig,
        global_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        recipient: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let global_vault_balance = clmm_pool::rewarder::balance_of<RewardCoinType>(global_vault);
        integrate::utils::send_coin<RewardCoinType>(
            sui::coin::from_balance<RewardCoinType>(
                clmm_pool::rewarder::emergent_withdraw<RewardCoinType>(
                    admin_cap,
                    global_config,
                    global_vault,
                    global_vault_balance
                ),
                ctx
            ),
            recipient
        );
    }

    // decompiled from Move bytecode v6
}


module integrate::rewarder_script {
    // Error constants
    const EInsufficientReward: u64 = 1;
    const EInsufficientVaultBalance: u64 = 2;

    public entry fun deposit_reward<RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        reward_input_coins: vector<sui::coin::Coin<RewardCoinType>>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let mut reward_coin = integrate::utils::merge_coins<RewardCoinType>(reward_input_coins, ctx);
        assert!(reward_coin.value<RewardCoinType>() >= amount, EInsufficientReward);
        clmm_pool::rewarder::deposit_reward<RewardCoinType>(
            global_config,
            rewarder_vault,
            reward_coin.split(amount, ctx).into_balance()
        );
        integrate::utils::send_coin<RewardCoinType>(reward_coin, tx_context::sender(ctx));
    }

    public entry fun emergent_withdraw<RewardCoinType>(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(rewarder_vault.balance_of<RewardCoinType>() >= amount, EInsufficientVaultBalance);
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
        ctx: &mut TxContext
    ) {
        let global_vault_balance = global_vault.balance_of<RewardCoinType>();
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


module integrate::pool_script_v3 {
    public entry fun collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: &mut sui::coin::Coin<CoinTypeA>,
        coin_b_input: &mut sui::coin::Coin<CoinTypeB>,
        ctx: &mut TxContext
    ) {
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            true
        );
        coin_a_input.join<CoinTypeA>(sui::coin::from_balance<CoinTypeA>(collected_fee_a, ctx));
        coin_b_input.join<CoinTypeB>(sui::coin::from_balance<CoinTypeB>(collected_fee_b, ctx));
    }

    public entry fun collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        coin_a_input: &mut sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        coin_a_input.join<RewardCoinType>(sui::coin::from_balance<RewardCoinType>(
            clmm_pool::pool::collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
                global_config,
                pool,
                position,
                rewarder_vault,
                true,
                clock
            ),
            ctx
        ));
    }

    /// Updates the reward emission rate for a pool.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `pool` - The pool to update emission for
    /// * `rewarder_vault` - Global vault for rewards
    /// * `total_reward_amount` - Total amount of reward tokens to distribute
    /// * `distribution_period_seconds` - Time period in seconds over which to distribute the rewards
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `RewardCoinType` - Type of reward token to emit
    /// 
    /// # Formula
    /// emissions_per_second = (total_reward_amount * 2^64) / distribution_period_seconds
    /// This calculates the emission rate in Q64.64 format for the CLMM pool.
    public entry fun update_rewarder_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        total_reward_amount: u64,
        distribution_period_seconds: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        clmm_pool::pool::update_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
            global_config,
            pool,
            rewarder_vault,
            integer_mate::full_math_u128::mul_div_floor((total_reward_amount as u128), 18446744073709551616, (distribution_period_seconds as u128)),
            clock,
            ctx
        );
    }

    // decompiled from Move bytecode v6
}


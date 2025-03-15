module integrate::pool_script_v3 {
    public entry fun collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: &mut sui::coin::Coin<CoinTypeA>,
        coin_b_input: &mut sui::coin::Coin<CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            true
        );
        coin_a_input.join<CoinTypeA>(sui::coin::from_balance<CoinTypeA>(v0, ctx));
        coin_b_input.join<CoinTypeB>(sui::coin::from_balance<CoinTypeB>(v1, ctx));
    }

    public entry fun collect_reward<CoinTypeA, CoinTypeB, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        coin_a_input: &mut sui::coin::Coin<T2>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        coin_a_input.join<T2>(sui::coin::from_balance<T2>(
            clmm_pool::pool::collect_reward<CoinTypeA, CoinTypeB, T2>(
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

    public entry fun update_rewarder_emission<CoinTypeA, CoinTypeB, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        rewarder_vault: &clmm_pool::rewarder::RewarderGlobalVault,
        fee_numerator: u64,
        fee_denominator: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::update_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
            global_config,
            pool,
            rewarder_vault,
            integer_mate::full_math_u128::mul_div_floor((fee_numerator as u128), 18446744073709551616, (fee_denominator as u128)),
            clock,
            ctx
        );
    }

    // decompiled from Move bytecode v6
}


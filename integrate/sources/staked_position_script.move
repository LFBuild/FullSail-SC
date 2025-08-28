module integrate::staked_position_script {
    use integrate::pool_script_v2;

    public fun open_position_and_stake_with_liquidity_by_fix_coin<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        amount_a: u64,
        amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): distribution::gauge::StakedPosition {
        let position = pool_script_v2::open_position_with_liquidity_by_fix_coin_return<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            tick_lower,
            tick_upper,
            coin_a,
            coin_b,
            amount_a,
            amount_b,
            fix_amount_a,
            clock,
            ctx
        );
        
        let staked_position = distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        staked_position
    }


    // all rewards for previous epochs must be claimed
    public fun add_staked_liquidity_by_fix_coin<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        amount_a: u64,
        amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): distribution::gauge::StakedPosition {
       let mut reward_coin = distribution::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            minter,
            distribution_config,
            gauge,
            pool,
            &staked_position,
            clock,
            ctx
        );
        if (reward_coin.value<EpochOSail>() > 0) {
            transfer::public_transfer<sui::coin::Coin<EpochOSail>>(reward_coin, tx_context::sender(ctx));
        } else {
            reward_coin.destroy_zero<EpochOSail>();
        };

        let mut position = distribution::gauge::withdraw_position<CoinTypeA, CoinTypeB>(
            gauge,
            distribution_config,
            pool,
            staked_position,
            clock,
            ctx
        );

        pool_script_v2::add_liquidity_by_fix_coin<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            coin_a,
            coin_b,
            amount_a,
            amount_b,
            fix_amount_a,
            clock,
            ctx
        );
        
        let new_staked_position = distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        new_staked_position
    }

    // all rewards for previous epochs must be claimed
    public fun remove_staked_liquidity_by_fix_coin<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): distribution::gauge::StakedPosition {
       let mut reward_coin = distribution::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            minter,
            distribution_config,
            gauge,
            pool,
            &staked_position,
            clock,
            ctx
        );
        if (reward_coin.value<EpochOSail>() > 0) {
            transfer::public_transfer<sui::coin::Coin<EpochOSail>>(reward_coin, tx_context::sender(ctx));
        } else {
            reward_coin.destroy_zero<EpochOSail>();
        };

        let mut position = distribution::gauge::withdraw_position<CoinTypeA, CoinTypeB>(
            gauge,
            distribution_config,
            pool,
            staked_position,
            clock,
            ctx
        );

        pool_script_v2::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            liquidity,
            min_amount_a,
            min_amount_b,
            clock,
            ctx
        );
        
        let new_staked_position = distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        new_staked_position
    }

    // all rewards for previous epochs must be claimed
    public fun close_staked_position<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
       let mut reward_coin = distribution::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            minter,
            distribution_config,
            gauge,
            pool,
            &staked_position,
            clock,
            ctx
        );
        if (reward_coin.value<EpochOSail>() > 0) {
            transfer::public_transfer<sui::coin::Coin<EpochOSail>>(reward_coin, tx_context::sender(ctx));
        } else {
            reward_coin.destroy_zero<EpochOSail>();
        };

        let mut position = distribution::gauge::withdraw_position<CoinTypeA, CoinTypeB>(
            gauge,
            distribution_config,
            pool,
            staked_position,
            clock,
            ctx
        );

        pool_script_v2::close_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            position,
            min_amount_a,
            min_amount_b,
            clock,
            ctx
        );
    }
}
module integrate::liquidity_soft_lock_v2_script {
    use integrate::pool_script_v2;
    
    // Error constants
    const EFailedLockPosition: u64 = 939267347223;

    public fun open_position_and_stake_and_lock_v2<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        locker: &mut liquidity_soft_locker::liquidity_soft_lock_v2::SoftLocker,
        pool_tranche_manager: &mut liquidity_soft_locker::pool_soft_tranche::PoolSoftTrancheManager,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        amount_a: u64,
        amount_b: u64,
        fix_amount_a: bool,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let position = integrate::pool_script_v2::open_position_with_liquidity_by_fix_coin_return<CoinTypeA, CoinTypeB>(
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

        let mut lock_positions = liquidity_soft_locker::liquidity_soft_lock_v2::lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            distribution_config,
            locker,
            pool_tranche_manager,
            gauge,
            pool,
            staked_position,
            block_period_index,
            clock,
            ctx
        );

        let len = lock_positions.length();
        let mut i = 0;
        while (i < len) {
            transfer::public_transfer<liquidity_soft_locker::liquidity_soft_lock_v2::SoftLockedPosition<CoinTypeA, CoinTypeB>>(
                lock_positions.pop_back(), 
                tx_context::sender(ctx)
            );
            i = i + 1;
        };
        lock_positions.destroy_empty();
    }

    public entry fun lock_position_v2<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut liquidity_soft_locker::liquidity_soft_lock_v2::SoftLocker,
        pool_tranche_manager: &mut liquidity_soft_locker::pool_soft_tranche::PoolSoftTrancheManager,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        
        let mut lock_positions = liquidity_soft_locker::liquidity_soft_lock_v2::lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            distribution_config,
            locker,
            pool_tranche_manager,
            gauge,
            pool,
            staked_position,
            block_period_index,
            clock,
            ctx
        );

        assert!(lock_positions.length() > 0, EFailedLockPosition);

        let len = lock_positions.length();
        let mut i = 0;
        while (i < len) {
            transfer::public_transfer<liquidity_soft_locker::liquidity_soft_lock_v2::SoftLockedPosition<CoinTypeA, CoinTypeB>>(
                lock_positions.pop_back(), 
                tx_context::sender(ctx)
            );
            i = i + 1;
        };
        lock_positions.destroy_empty();
    }
}


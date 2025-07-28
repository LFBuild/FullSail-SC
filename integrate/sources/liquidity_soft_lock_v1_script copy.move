module integrate::liquidity_soft_lock_v1_script {
    use integrate::pool_script_v2;
    
    // Error constants
    const EFailedLockPosition: u64 = 939267347223;

    public entry fun open_position_and_soft_lock_with_liquidity_by_fix_coin<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locker: &mut liquidity_soft_locker::liquidity_soft_lock_v1::SoftLocker,
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
        let mut position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let amount_to_add = if (fix_amount_a) {
            amount_a
        } else {
            amount_b
        };
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            amount_to_add,
            fix_amount_a,
            clock
        );
        pool_script_v2::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            receipt,
            coin_a,
            coin_b,
            amount_a,
            amount_b,
            ctx
        );
        
        let mut soft_lock_positions = liquidity_soft_locker::liquidity_soft_lock_v1::lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            locker,
            pool_tranche_manager,
            pool,
            position,
            block_period_index,
            clock,
            ctx
        );

        let len = soft_lock_positions.length();
        let mut i = 0;
        while (i < len) {
            transfer::public_transfer<liquidity_soft_locker::liquidity_soft_lock_v1::SoftLockedPosition<CoinTypeA, CoinTypeB>>(
                soft_lock_positions.pop_back(), 
                tx_context::sender(ctx)
            );
            i = i + 1;
        };
        soft_lock_positions.destroy_empty();
    }

    public entry fun soft_lock_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locker: &mut liquidity_soft_locker::liquidity_soft_lock_v1::SoftLocker,
        pool_tranche_manager: &mut liquidity_soft_locker::pool_soft_tranche::PoolSoftTrancheManager,
        position: clmm_pool::position::Position,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        
        let mut soft_lock_positions = liquidity_soft_locker::liquidity_soft_lock_v1::lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            locker,
            pool_tranche_manager,
            pool,
            position,
            block_period_index,
            clock,
            ctx
        );

        assert!(soft_lock_positions.length() > 0, EFailedLockPosition);

        let len = soft_lock_positions.length();
        let mut i = 0;
        while (i < len) {
            transfer::public_transfer<liquidity_soft_locker::liquidity_soft_lock_v1::SoftLockedPosition<CoinTypeA, CoinTypeB>>(
                soft_lock_positions.pop_back(), 
                tx_context::sender(ctx)
            );
            i = i + 1;
        };
        soft_lock_positions.destroy_empty();
    }
}


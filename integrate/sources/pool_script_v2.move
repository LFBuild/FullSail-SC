module integrate::pool_script_v2 {

    fun swap<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(global_config, pool, a2b, by_amount_in, amount, sqrt_price_limit, clock);
        let pay_amout = clmm_pool::pool::swap_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        let coin_out_value = if (a2b) {
            sui::balance::value<CoinTypeB>(&coin_b_out)
        } else {
            sui::balance::value<CoinTypeA>(&coin_a_out)
        };
        if (by_amount_in) {
            assert!(pay_amout == amount, 2);
            assert!(coin_out_value >= amount_limit, 1);
        } else {
            assert!(coin_out_value == amount, 2);
            assert!(pay_amout <= amount_limit, 0);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (sui::coin::into_balance<CoinTypeA>(sui::coin::split<CoinTypeA>(&mut coin_a, pay_amout, ctx)), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), sui::coin::into_balance<CoinTypeB>(sui::coin::split<CoinTypeB>(&mut coin_b, pay_amout, ctx)))
        };
        clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            repay_amount_a,
            repay_amount_b,
            receipt
        );
        sui::coin::join<CoinTypeB>(&mut coin_b, sui::coin::from_balance<CoinTypeB>(coin_b_out, ctx));
        sui::coin::join<CoinTypeA>(&mut coin_a, sui::coin::from_balance<CoinTypeA>(coin_a_out, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, sui::tx_context::sender(ctx));
    }
    
    public entry fun create_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        current_sqrt_price: u128,
        url: std::string::String,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::factory::create_pool<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            current_sqrt_price,
            url,
            clock,
            ctx
        );
    }
    
    public entry fun create_pool_with_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_amount_a: u64,
        liquidity_amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (position, remaining_coin_a, remaining_coin_b) = clmm_pool::factory::create_pool_with_liquidity<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            tick_lower,
            tick_upper,
            coin_a,
            coin_b,
            liquidity_amount_a,
            liquidity_amount_b,
            fix_amount_a,
            clock,
            ctx
        );
        integrate::utils::send_coin<CoinTypeA>(remaining_coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(remaining_coin_b, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
    }
    
    public entry fun add_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        max_amount_a: u64,
        max_amount_b: u64,
        delta_liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            delta_liquidity,
            clock
        );
        repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            receipt,
            coin_a,
            coin_b,
            max_amount_a,
            max_amount_b,
            ctx
        );
    }
    
    public entry fun close_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut position: clmm_pool::position::Position,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let v0 = clmm_pool::position::liquidity(&position);
        if (v0 > 0) {
            remove_liquidity<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                &mut position,
                v0,
                min_amount_a,
                min_amount_b,
                clock,
                ctx
            );
        };
        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(global_config, pool, position);
    }
    
    public entry fun collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(global_config, pool, position, true);
        sui::coin::join<CoinTypeA>(&mut coin_a, sui::coin::from_balance<CoinTypeA>(v0, ctx));
        sui::coin::join<CoinTypeB>(&mut coin_b, sui::coin::from_balance<CoinTypeB>(v1, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, sui::tx_context::sender(ctx));
    }
    
    public entry fun collect_protocol_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1) = clmm_pool::pool::collect_protocol_fee<CoinTypeA, CoinTypeB>(global_config, pool, ctx);
        sui::coin::join<CoinTypeA>(&mut coin_a, sui::coin::from_balance<CoinTypeA>(v0, ctx));
        sui::coin::join<CoinTypeB>(&mut coin_b, sui::coin::from_balance<CoinTypeB>(v1, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, sui::tx_context::sender(ctx));
    }
    
    public entry fun collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        rewarder: &mut clmm_pool::rewarder::RewarderGlobalVault,
        mut reward_coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::coin::join<RewardCoinType>(&mut reward_coin, sui::coin::from_balance<RewardCoinType>(clmm_pool::pool::collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(global_config, pool, position, rewarder, true, clock), ctx));
        integrate::utils::send_coin<RewardCoinType>(reward_coin, sui::tx_context::sender(ctx));
    }
    
    public entry fun initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(global_config, pool, ctx);
    }
    
    public entry fun open_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig, 
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_transfer<clmm_pool::position::Position>(
            clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                tick_lower,
                tick_upper,
                ctx
            ),
            sui::tx_context::sender(ctx)
        );
    }
    
    public entry fun remove_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            liquidity,
            clock
        );
        let mut v2 = v1;
        let mut v3 = v0;
        assert!(sui::balance::value<CoinTypeA>(&v3) >= min_amount_a, 1);
        assert!(sui::balance::value<CoinTypeB>(&v2) >= min_amount_b, 1);
        let (v4, v5) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(global_config, pool, position, false);
        sui::balance::join<CoinTypeA>(&mut v3, v4);
        sui::balance::join<CoinTypeB>(&mut v2, v5);
        integrate::utils::send_coin<CoinTypeA>(sui::coin::from_balance<CoinTypeA>(v3, ctx), sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(sui::coin::from_balance<CoinTypeB>(v2, ctx), sui::tx_context::sender(ctx));
    }
    
    fun repay_add_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        receipt: clmm_pool::pool::AddLiquidityReceipt<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        max_amount_a: u64,
        max_amount_b: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (pay_amount_a, pay_amount_b) = clmm_pool::pool::add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        assert!(pay_amount_a <= max_amount_a, 0);
        assert!(pay_amount_b <= max_amount_b, 0);
        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            sui::coin::into_balance<CoinTypeA>(
                sui::coin::split<CoinTypeA>(
                    &mut coin_a,
                    pay_amount_a,
                    ctx
                )
            ),
            sui::coin::into_balance<CoinTypeB>(
                sui::coin::split<CoinTypeB>(
                    &mut coin_b,
                    pay_amount_b,
                    ctx
                )
            ),
            receipt
        );
        integrate::utils::send_coin<CoinTypeA>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, sui::tx_context::sender(ctx));
    }
    
    public entry fun set_display<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        publisher: &sui::package::Publisher, 
        name: std::string::String,
        description: std::string::String,
        image_url: std::string::String,
        link: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::set_display<CoinTypeA, CoinTypeB>(
            global_config,
            publisher,
            name,
            description,
            image_url,
            link,
            project_url,
            creator,
            ctx
        );
    }
    
    public entry fun update_fee_rate<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::update_fee_rate<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            fee_rate,
            ctx
        );
    }
    
    public entry fun update_position_url<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>, 
        url: std::string::String, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::update_position_url<CoinTypeA, CoinTypeB>(global_config, pool, url, ctx);
    }
    
    public entry fun add_liquidity_by_fix_coin<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        amount_a: u64,
        amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let amount_in = if (fix_amount_a) {
            amount_a
        } else {
            amount_b
        };
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            amount_in,
            fix_amount_a,
            clock
        );
        repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            receipt,
            coin_a,
            coin_b,
            amount_a,
            amount_b,
            ctx
        );
    }
    
    public entry fun open_position_with_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        max_amount_a: u64,
        max_amount_b: u64,
        delta_liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let receipt = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &mut position,
            delta_liquidity,
            clock
        );
        repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            receipt,
            coin_a,
            coin_b,
            max_amount_a,
            max_amount_b,
            ctx
        );
        sui::transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
    }
    
    public entry fun open_position_with_liquidity_by_fix_coin<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        amount_a: u64,
        amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(global_config, pool, tick_lower, tick_upper, ctx);
        let v1 = if (fix_amount_a) {
            amount_a
        } else {
            amount_b
        };
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<CoinTypeA, CoinTypeB>(global_config, pool, &mut position, v1, fix_amount_a, clock);
        repay_add_liquidity<CoinTypeA, CoinTypeB>(global_config, pool, receipt, coin_a, coin_b, amount_a, amount_b, ctx);
        sui::transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
    }
    
    public entry fun pause_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::pause<CoinTypeA, CoinTypeB>(global_config, pool, ctx);
    }
    
    public entry fun swap_a2b<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            coin_a,
            coin_b,
            true,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }
    
    public entry fun swap_a2b_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        swap_partner: &mut clmm_pool::partner::Partner,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            swap_partner,
            coin_a,
            coin_b,
            true,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }
    
    public entry fun swap_b2a<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            coin_a,
            coin_b,
            false,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }
    
    public entry fun swap_b2a_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        swap_partner: &mut clmm_pool::partner::Partner,
        coin_a: sui::coin::Coin<CoinTypeA>,
        coin_b: sui::coin::Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            swap_partner,
            coin_a,
            coin_b,
            false,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }
    
    fun swap_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        swap_partner: &mut clmm_pool::partner::Partner,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1, v2) = clmm_pool::pool::flash_swap_with_partner<CoinTypeA, CoinTypeB>(global_config, pool, swap_partner, a2b, by_amount_in, amount, sqrt_price_limit, clock);
        let v3 = v2;
        let v4 = v1;
        let v5 = v0;
        let v6 = clmm_pool::pool::swap_pay_amount<CoinTypeA, CoinTypeB>(&v3);
        let v7 = if (a2b) {
            sui::balance::value<CoinTypeB>(&v4)
        } else {
            sui::balance::value<CoinTypeA>(&v5)
        };
        if (by_amount_in) {
            assert!(v6 == amount, 2);
            assert!(v7 >= amount_limit, 1);
        } else {
            assert!(v7 == amount, 2);
            assert!(v6 <= amount_limit, 0);
        };
        let (v8, v9) = if (a2b) {
            (sui::coin::into_balance<CoinTypeA>(sui::coin::split<CoinTypeA>(&mut coin_a, v6, ctx)), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), sui::coin::into_balance<CoinTypeB>(sui::coin::split<CoinTypeB>(&mut coin_b, v6, ctx)))
        };
        clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(global_config, pool, swap_partner, v8, v9, v3);
        sui::coin::join<CoinTypeB>(&mut coin_b, sui::coin::from_balance<CoinTypeB>(v4, ctx));
        sui::coin::join<CoinTypeA>(&mut coin_a, sui::coin::from_balance<CoinTypeA>(v5, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, sui::tx_context::sender(ctx));
    }
    
    public entry fun unpause_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::unpause<CoinTypeA, CoinTypeB>(global_config, pool, ctx);
    }
    
    public entry fun update_rewarder_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        rewarder_global_vault: &clmm_pool::rewarder::RewarderGlobalVault,
        emissions_per_second: u128, 
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::update_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
            global_config, 
            pool,
            rewarder_global_vault,
            emissions_per_second,
            clock,
            ctx
        );
    }
}


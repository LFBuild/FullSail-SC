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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            stats,
            clock
        );
        let pay_amout = receipt.swap_pay_amount();
        let coin_out_value = if (a2b) {
            coin_b_out.value()
        } else {
            coin_a_out.value()
        };
        if (by_amount_in) {
            assert!(pay_amout == amount, 2);
            assert!(coin_out_value >= amount_limit, 1);
        } else {
            assert!(coin_out_value == amount, 2);
            assert!(pay_amout <= amount_limit, 0);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (coin_a.split(pay_amout, ctx).into_balance(), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), coin_b.split(pay_amout, ctx).into_balance())
        };
        clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            repay_amount_a,
            repay_amount_b,
            receipt
        );
        coin_b.join(sui::coin::from_balance<CoinTypeB>(coin_b_out, ctx));
        coin_a.join(sui::coin::from_balance<CoinTypeA>(coin_a_out, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, tx_context::sender(ctx));
    }

    public entry fun create_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        current_sqrt_price: u128,
        url: std::string::String,
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        pools.create_pool<CoinTypeA, CoinTypeB>(
            global_config,
            tick_spacing,
            current_sqrt_price,
            url,
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
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
        feed_id_coin_a: address,
        feed_id_coin_b: address,
        auto_calculation_volumes: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (position, remaining_coin_a, remaining_coin_b) = pools.create_pool_with_liquidity(
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
            feed_id_coin_a,
            feed_id_coin_b,
            auto_calculation_volumes,
            clock,
            ctx
        );
        integrate::utils::send_coin<CoinTypeA>(remaining_coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(remaining_coin_b, tx_context::sender(ctx));
        transfer::public_transfer<clmm_pool::position::Position>(position, tx_context::sender(ctx));
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
        ctx: &mut TxContext
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
        ctx: &mut TxContext
    ) {
        let liquidity = position.liquidity();
        if (liquidity > 0) {
            remove_liquidity<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                &mut position,
                liquidity,
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
        ctx: &mut TxContext
    ) {
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            true
        );
        coin_a.join(sui::coin::from_balance<CoinTypeA>(collected_fee_a, ctx));
        coin_b.join(sui::coin::from_balance<CoinTypeB>(collected_fee_b, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, tx_context::sender(ctx));
    }

    public entry fun collect_protocol_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        ctx: &mut TxContext
    ) {
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_protocol_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            ctx
        );
        coin_a.join(sui::coin::from_balance<CoinTypeA>(collected_fee_a, ctx));
        coin_b.join(sui::coin::from_balance<CoinTypeB>(collected_fee_b, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, tx_context::sender(ctx));
    }

    public entry fun collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        rewarder: &mut clmm_pool::rewarder::RewarderGlobalVault,
        mut reward_coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_coin.join<RewardCoinType>(sui::coin::from_balance<RewardCoinType>(
            clmm_pool::pool::collect_reward<CoinTypeA, CoinTypeB, RewardCoinType>(
                global_config,
                pool,
                position,
                rewarder,
                true,
                clock
            ),
            ctx
        ));
        integrate::utils::send_coin<RewardCoinType>(reward_coin, tx_context::sender(ctx));
    }

    public entry fun initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut TxContext
    ) {
        clmm_pool::pool::initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(global_config, pool, ctx);
    }

    public entry fun open_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tick_lower: u32,
        tick_upper: u32,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer<clmm_pool::position::Position>(
            clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                tick_lower,
                tick_upper,
                ctx
            ),
            tx_context::sender(ctx)
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
        ctx: &mut TxContext
    ) {
        let (removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            liquidity,
            clock
        );
        let mut mut_removed_b = removed_b;
        let mut mut_removed_a = removed_a;
        assert!(mut_removed_a.value<CoinTypeA>() >= min_amount_a, 1);
        assert!(mut_removed_b.value<CoinTypeB>() >= min_amount_b, 1);
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            false
        );
        mut_removed_a.join<CoinTypeA>(collected_fee_a);
        mut_removed_b.join<CoinTypeB>(collected_fee_b);
        integrate::utils::send_coin<CoinTypeA>(
            sui::coin::from_balance<CoinTypeA>(mut_removed_a, ctx),
            tx_context::sender(ctx)
        );
        integrate::utils::send_coin<CoinTypeB>(
            sui::coin::from_balance<CoinTypeB>(mut_removed_b, ctx),
            tx_context::sender(ctx)
        );
    }

    fun repay_add_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        receipt: clmm_pool::pool::AddLiquidityReceipt<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        max_amount_a: u64,
        max_amount_b: u64,
        ctx: &mut TxContext
    ) {
        let (pay_amount_a, pay_amount_b) = receipt.add_liquidity_pay_amount();
        assert!(pay_amount_a <= max_amount_a, 0);
        assert!(pay_amount_b <= max_amount_b, 0);
        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            coin_a.split<CoinTypeA>(pay_amount_a, ctx).into_balance(),
            coin_b.split<CoinTypeB>(pay_amount_b, ctx).into_balance(),
            receipt
        );
        integrate::utils::send_coin<CoinTypeA>(coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, tx_context::sender(ctx));
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
        ctx: &mut TxContext
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
        ctx: &mut TxContext
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
        ctx: &mut TxContext
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
        ctx: &mut TxContext
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
        ctx: &mut TxContext
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
        transfer::public_transfer<clmm_pool::position::Position>(position, tx_context::sender(ctx));
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
            pool,
            &mut position,
            amount_to_add,
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
        transfer::public_transfer<clmm_pool::position::Position>(position, tx_context::sender(ctx));
    }

    public entry fun pause_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut TxContext
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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
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
            stats,
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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
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
            stats,
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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
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
            stats,
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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
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
            stats,
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
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (coin_a_out, coin_b_out, swap_receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            swap_partner,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            stats,
            clock
        );
        let pay_amount = swap_receipt.swap_pay_amount();
        let coin_out_value = if (a2b) {
            coin_b_out.value()
        } else {
            coin_a_out.value()
        };
        if (by_amount_in) {
            assert!(pay_amount == amount, 2);
            assert!(coin_out_value >= amount_limit, 1);
        } else {
            assert!(coin_out_value == amount, 2);
            assert!(pay_amount <= amount_limit, 0);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (coin_a.split(pay_amount, ctx).into_balance(), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), coin_b.split(pay_amount, ctx).into_balance())
        };
        clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            swap_partner,
            repay_amount_a,
            repay_amount_b,
            swap_receipt
        );
        coin_b.join(sui::coin::from_balance<CoinTypeB>(coin_b_out, ctx));
        coin_a.join(sui::coin::from_balance<CoinTypeA>(coin_a_out, ctx));
        integrate::utils::send_coin<CoinTypeA>(coin_a, tx_context::sender(ctx));
        integrate::utils::send_coin<CoinTypeB>(coin_b, tx_context::sender(ctx));
    }

    public entry fun unpause_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut TxContext
    ) {
        clmm_pool::pool::unpause<CoinTypeA, CoinTypeB>(global_config, pool, ctx);
    }

    public entry fun update_rewarder_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        rewarder_global_vault: &clmm_pool::rewarder::RewarderGlobalVault,
        emissions_per_second: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
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


module integrate::pool_script {

    fun swap<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut coin_a = integrate::utils::merge_coins<T1>(coin_b_input, ctx);
        let mut coin_b = integrate::utils::merge_coins<T0>(coin_a_input, ctx);
        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<T0, T1>(
            global_config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        );
        let pay_amount = clmm_pool::pool::swap_pay_amount<T0, T1>(&receipt);
        let coin_out_value = if (a2b) {
            coin_b_out.value::<T1>()
        } else {
            coin_a_out.value::<T0>()
        };
        if (by_amount_in) {
            assert!(pay_amount == amount, 2);
            assert!(coin_out_value >= amount_limit, 1);
        } else {
            assert!(coin_out_value == amount, 2);
            assert!(pay_amount <= amount_limit, 0);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (sui::coin::into_balance<T0>(coin_b.split::<T0>(pay_amount, ctx)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(coin_a.split::<T1>(pay_amount, ctx)))
        };
        coin_a.join::<T1>(sui::coin::from_balance<T1>(coin_b_out, ctx));
        coin_b.join::<T0>(sui::coin::from_balance<T0>(coin_a_out, ctx));
        clmm_pool::pool::repay_flash_swap<T0, T1>(global_config, pool, repay_amount_a, repay_amount_b, receipt);
        integrate::utils::send_coin<T0>(coin_b, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<T1>(coin_a, sui::tx_context::sender(ctx));
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

    public entry fun close_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut position: clmm_pool::position::Position,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let liquidity = clmm_pool::position::liquidity(&position);
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

    public entry fun collect_fee<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<T0, T1>(
            global_config,
            pool,
            position,
            true
        );
        integrate::utils::send_coin<T0>(
            sui::coin::from_balance<T0>(collected_fee_a, ctx),
            sui::tx_context::sender(ctx)
        );
        integrate::utils::send_coin<T1>(
            sui::coin::from_balance<T1>(collected_fee_b, ctx),
            sui::tx_context::sender(ctx)
        );
    }

    public entry fun collect_protocol_fee<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_protocol_fee<T0, T1>(global_config, pool, ctx);
        integrate::utils::send_coin<T0>(
            sui::coin::from_balance<T0>(collected_fee_a, ctx),
            sui::tx_context::sender(ctx)
        );
        integrate::utils::send_coin<T1>(
            sui::coin::from_balance<T1>(collected_fee_b, ctx),
            sui::tx_context::sender(ctx)
        );
    }

    public entry fun collect_reward<T0, T1, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        rewarder_vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        integrate::utils::send_coin<T2>(
            sui::coin::from_balance<T2>(
                clmm_pool::pool::collect_reward<T0, T1, T2>(
                    global_config,
                    pool,
                    position,
                    rewarder_vault,
                    true,
                    clock
                ),
                ctx
            ),
            sui::tx_context::sender(ctx)
        );
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
        let (removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            liquidity,
            clock
        );
        let mut mut_removed_b = removed_b;
        let mut mut_removed_a = removed_a;
        assert!(mut_removed_a.value::<CoinTypeA>() >= min_amount_a, 1);
        assert!(mut_removed_b.value::<CoinTypeB>() >= min_amount_b, 1);
        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(global_config, pool, position, false);
        mut_removed_a.join::<CoinTypeA>(collected_fee_a);
        mut_removed_b.join::<CoinTypeB>(collected_fee_b);
        integrate::utils::send_coin<CoinTypeA>(
            sui::coin::from_balance<CoinTypeA>(mut_removed_a, ctx),
            sui::tx_context::sender(ctx)
        );
        integrate::utils::send_coin<CoinTypeB>(
            sui::coin::from_balance<CoinTypeB>(mut_removed_b, ctx),
            sui::tx_context::sender(ctx)
        );
    }

    fun repay_add_liquidity<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        receipt: clmm_pool::pool::AddLiquidityReceipt<T0, T1>,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        max_amount_a: u64,
        max_amount_b: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut coin_a = integrate::utils::merge_coins<T0>(coin_a_input, ctx);
        let mut coin_b = integrate::utils::merge_coins<T1>(coin_b_input, ctx);
        let (pay_amount_a, pay_amount_b) = clmm_pool::pool::add_liquidity_pay_amount<T0, T1>(&receipt);
        assert!(pay_amount_a <= max_amount_a, 0);
        assert!(pay_amount_b <= max_amount_b, 0);
        clmm_pool::pool::repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            sui::coin::into_balance<T0>(coin_a.split::<T0>(pay_amount_a, ctx)),
            sui::coin::into_balance<T1>(coin_b.split::<T1>(pay_amount_b, ctx)),
            receipt
        );
        integrate::utils::send_coin<T0>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<T1>(coin_b, sui::tx_context::sender(ctx));
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

    public entry fun add_liquidity_fix_coin_only_a<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        amount_a: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            position,
            amount_a,
            true,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            coin_a_input,
            std::vector::empty<sui::coin::Coin<T1>>(),
            amount_a,
            0,
            ctx
        );
    }

    public entry fun add_liquidity_fix_coin_only_b<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            position,
            amount_b,
            false,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            std::vector::empty<sui::coin::Coin<T0>>(),
            coin_b_input,
            0,
            amount_b,
            ctx
        );
    }

    public entry fun add_liquidity_fix_coin_with_all<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
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
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            position,
            amount_in,
            fix_amount_a,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            coin_a_input,
            coin_b_input,
            amount_a,
            amount_b,
            ctx
        );
    }

    public entry fun add_liquidity_only_a<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        amount_a: u64,
        delta_liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity<T0, T1>(
            global_config,
            pool,
            position,
            delta_liquidity,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            coin_a_input,
            std::vector::empty<sui::coin::Coin<T1>>(),
            amount_a,
            0,
            ctx
        );
    }

    public entry fun add_liquidity_only_b<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        amount_b: u64,
        delta_liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity<T0, T1>(
            global_config,
            pool,
            position,
            delta_liquidity,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            std::vector::empty<sui::coin::Coin<T0>>(),
            coin_b_input,
            0,
            amount_b,
            ctx
        );
    }

    public entry fun add_liquidity_with_all<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        position: &mut clmm_pool::position::Position,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        amount_a: u64,
        amount_b: u64,
        delta_liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let receipt = clmm_pool::pool::add_liquidity<T0, T1>(global_config, pool, position, delta_liquidity, clock);
        repay_add_liquidity<T0, T1>(global_config, pool, receipt, coin_a_input, coin_b_input, amount_a, amount_b, ctx);
    }

    public entry fun create_pool_with_liquidity_only_a<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_amount_a: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            tick_lower,
            tick_upper,
            integrate::utils::merge_coins<T0>(coin_a_input, ctx),
            sui::coin::zero<T1>(ctx),
            liquidity_amount_a,
            0,
            true,
            clock,
            ctx
        );
        sui::coin::destroy_zero<T1>(v2);
        integrate::utils::send_coin<T0>(v1, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(ctx));
    }

    public entry fun create_pool_with_liquidity_only_b<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            tick_lower,
            tick_upper,
            sui::coin::zero<T0>(ctx),
            integrate::utils::merge_coins<T1>(coin_b_input, ctx),
            0,
            liquidity_amount_b,
            false,
            clock,
            ctx
        );
        sui::coin::destroy_zero<T0>(v1);
        integrate::utils::send_coin<T1>(v2, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(ctx));
    }

    public entry fun create_pool_with_liquidity_with_all<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_amount_a: u64,
        liquidity_amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (v0, v1, v2) = clmm_pool::factory::create_pool_with_liquidity<T0, T1>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            tick_lower,
            tick_upper,
            integrate::utils::merge_coins<T0>(coin_a_input, ctx),
            integrate::utils::merge_coins<T1>(coin_b_input, ctx),
            liquidity_amount_a,
            liquidity_amount_b,
            fix_amount_a,
            clock,
            ctx
        );
        integrate::utils::send_coin<T0>(v1, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<T1>(v2, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(ctx));
    }

    public entry fun open_position_with_liquidity_only_a<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        tick_lower: u32,
        tick_upper: u32,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        max_amount_a: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = clmm_pool::pool::open_position<T0, T1>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            &mut v0,
            max_amount_a,
            true,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            coin_a_input,
            std::vector::empty<sui::coin::Coin<T1>>(),
            max_amount_a,
            0,
            ctx
        );
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(ctx));
    }

    public entry fun open_position_with_liquidity_only_b<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        tick_lower: u32,
        tick_upper: u32,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        max_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut position = clmm_pool::pool::open_position<T0, T1>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            &mut position,
            max_amount_b,
            false,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            std::vector::empty<sui::coin::Coin<T0>>(),
            coin_b_input,
            0,
            max_amount_b,
            ctx
        );
        sui::transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
    }

    public entry fun open_position_with_liquidity_with_all<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        tick_lower: u32,
        tick_upper: u32,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        max_amount_a: u64,
        max_amount_b: u64,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = clmm_pool::pool::open_position<T0, T1>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            ctx
        );
        let v1 = if (fix_amount_a) {
            max_amount_a
        } else {
            max_amount_b
        };
        let receipt = clmm_pool::pool::add_liquidity_fix_coin<T0, T1>(
            global_config,
            pool,
            &mut v0,
            v1,
            fix_amount_a,
            clock
        );
        repay_add_liquidity<T0, T1>(
            global_config,
            pool,
            receipt,
            coin_a_input,
            coin_b_input,
            max_amount_a,
            max_amount_b,
            ctx
        );
        sui::transfer::public_transfer<clmm_pool::position::Position>(v0, sui::tx_context::sender(ctx));
    }

    public entry fun pause_pool<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::pool::pause<CoinTypeA, CoinTypeB>(global_config, pool, ctx);
    }

    public entry fun swap_a2b<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        fix_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap<T0, T1>(
            global_config,
            pool,
            coin_a_input,
            std::vector::empty<sui::coin::Coin<T1>>(),
            true,
            fix_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

    public entry fun swap_a2b_with_partner<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        partner: &mut clmm_pool::partner::Partner,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap_with_partner<T0, T1>(
            global_config,
            pool,
            partner,
            coin_a_input,
            std::vector::empty<sui::coin::Coin<T1>>(),
            true,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

    public entry fun swap_b2a<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap<T0, T1>(
            global_config,
            pool,
            std::vector::empty<sui::coin::Coin<T0>>(),
            coin_b_input,
            false,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

    public entry fun swap_b2a_with_partner<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        partner: &mut clmm_pool::partner::Partner,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        swap_with_partner<T0, T1>(
            global_config,
            pool,
            partner,
            std::vector::empty<sui::coin::Coin<T0>>(),
            coin_b_input,
            false,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

    fun swap_with_partner<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        swap_partner: &mut clmm_pool::partner::Partner,
        coin_a_input: vector<sui::coin::Coin<T0>>,
        coin_b_input: vector<sui::coin::Coin<T1>>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut coin_a = integrate::utils::merge_coins<T0>(coin_a_input, ctx);
        let mut coin_b = integrate::utils::merge_coins<T1>(coin_b_input, ctx);
        let (coin_a_out, coin_b_out, swap_receipt) = clmm_pool::pool::flash_swap_with_partner<T0, T1>(
            global_config,
            pool,
            swap_partner,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        );
        let pay_amount = clmm_pool::pool::swap_pay_amount<T0, T1>(&swap_receipt);
        let coin_out_value = if (a2b) {
            coin_b_out.value::<T1>()
        } else {
            coin_a_out.value::<T0>()
        };
        if (by_amount_in) {
            assert!(pay_amount == amount, 2);
            assert!(coin_out_value >= amount_limit, 1);
        } else {
            assert!(coin_out_value == amount, 2);
            assert!(pay_amount <= amount_limit, 0);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (sui::coin::into_balance<T0>(coin_a.split::<T0>(pay_amount, ctx)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(coin_b.split::<T1>(pay_amount, ctx)))
        };
        coin_a.join::<T0>(sui::coin::from_balance<T0>(coin_a_out, ctx));
        coin_b.join::<T1>(sui::coin::from_balance<T1>(coin_b_out, ctx));
        clmm_pool::pool::repay_flash_swap_with_partner<T0, T1>(
            global_config,
            pool,
            swap_partner,
            repay_amount_a,
            repay_amount_b,
            swap_receipt
        );
        integrate::utils::send_coin<T0>(coin_a, sui::tx_context::sender(ctx));
        integrate::utils::send_coin<T1>(coin_b, sui::tx_context::sender(ctx));
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


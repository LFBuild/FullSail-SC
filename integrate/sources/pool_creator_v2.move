module integrate::pool_creator_v2 {

    const EInvalidAmount: u64 = 1;

    fun build_init_position_arg<CoinTypeA, CoinTypeB>(
        initialize_sqrt_price: u128,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: &mut sui::coin::Coin<CoinTypeA>,
        coin_b: &mut sui::coin::Coin<CoinTypeB>,
        fix_amount_a: bool,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeB>) {
        let value_a = coin_a.value::<CoinTypeA>();
        let value_b = coin_b.value::<CoinTypeB>();
        let fixed_amount = if (fix_amount_a) {
            value_a
        } else {
            value_b
        };
        let (_, amount_a, amount_b) = clmm_pool::clmm_math::get_liquidity_by_amount(
            integer_mate::i32::from_u32(tick_lower),
            integer_mate::i32::from_u32(tick_upper),
            clmm_pool::tick_math::get_tick_at_sqrt_price(initialize_sqrt_price),
            initialize_sqrt_price,
            fixed_amount,
            fix_amount_a
        );
        assert!(amount_a <= value_a, EInvalidAmount);
        assert!(amount_b <= value_b, EInvalidAmount);
        (coin_a.split::<CoinTypeA>(amount_a, ctx), coin_b.split::<CoinTypeB>(amount_b, ctx))
    }

    public entry fun create_pool_v2<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pools: &mut clmm_pool::factory::Pools,
        tick_spacing: u32,
        initialize_sqrt_price: u128,
        url: std::string::String,
        tick_lower: u32,
        tick_upper: u32,
        coin_a: &mut sui::coin::Coin<CoinTypeA>,
        coin_b: &mut sui::coin::Coin<CoinTypeB>,
        _metadata_a: &sui::coin::CoinMetadata<CoinTypeA>,
        _metadata_b: &sui::coin::CoinMetadata<CoinTypeB>,
        fix_amount_a: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (coin_a_for_pool, coin_b_for_pool) = build_init_position_arg<CoinTypeA, CoinTypeB>(
            initialize_sqrt_price,
            tick_lower,
            tick_upper,
            coin_a,
            coin_b,
            fix_amount_a,
            ctx
        );
        let liquidity_amount_a = coin_a_for_pool.value::<CoinTypeA>();
        let liquidity_amount_b = coin_b_for_pool.value::<CoinTypeB>();
        let (position, remaining_coin_a, remaining_coin_b) = clmm_pool::factory::create_pool_with_liquidity<CoinTypeA, CoinTypeB>(
            pools,
            global_config,
            tick_spacing,
            initialize_sqrt_price,
            url,
            tick_lower,
            tick_upper,
            coin_a_for_pool,
            coin_b_for_pool,
            liquidity_amount_a,
            liquidity_amount_b,
            fix_amount_a,
            clock,
            ctx
        );
        sui::coin::destroy_zero<CoinTypeA>(remaining_coin_a);
        sui::coin::destroy_zero<CoinTypeB>(remaining_coin_b);
        sui::transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
    }
}


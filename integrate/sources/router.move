module integrate::router {
    // Error constants
    const EAmountMismatch: u64 = 1;
    const EInsufficientFunds: u64 = 4;
    const EUnusedCoinRemaining: u64 = 5;

    public struct CalculatedRouterSwapResult has copy, drop, store {
        amount_in: u64,
        amount_medium: u64,
        amount_out: u64,
        is_exceed: bool,
        current_sqrt_price_ab: u128,
        current_sqrt_price_cd: u128,
        target_sqrt_price_ab: u128,
        target_sqrt_price_cd: u128,
    }

    public struct CalculatedRouterSwapResultEvent has copy, drop, store {
        data: CalculatedRouterSwapResult,
    }

    public fun swap<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        mut amount: u64,
        sqrt_price_limit: u128,
        use_full_input: bool,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeB>) {
        if (by_amount_in && use_full_input) {
            let amount_to_use = if (a2b) {
                coin_a.value<CoinTypeA>()
            } else {
                coin_b.value<CoinTypeB>()
            };
            amount = amount_to_use;
        };
        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            stats,
            price_provider,
            clock
        );
        let pay_amount = clmm_pool::pool::swap_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        let coin_out_value = if (a2b) {
            coin_b_out.value<CoinTypeB>()
        } else {
            coin_a_out.value<CoinTypeA>()
        };
        if (by_amount_in) {
            assert!(pay_amount == amount, EAmountMismatch);
        } else {
            assert!(coin_out_value == amount, EAmountMismatch);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            assert!(coin_a.value<CoinTypeA>() >= pay_amount, EInsufficientFunds);
            (sui::coin::into_balance<CoinTypeA>(coin_a.split<CoinTypeA>(pay_amount, ctx)), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), sui::coin::into_balance<CoinTypeB>(coin_b.split<CoinTypeB>(pay_amount, ctx)))
        };
        coin_a.join<CoinTypeA>(sui::coin::from_balance<CoinTypeA>(coin_a_out, ctx));
        coin_b.join<CoinTypeB>(sui::coin::from_balance<CoinTypeB>(coin_b_out, ctx));
        clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            repay_amount_a,
            repay_amount_b,
            receipt
        );
        (coin_a, coin_b)
    }

    public fun calculate_router_swap_result<CoinTypeA, CoinTypeB, CoinTypeC, CoinTypeD>(
        pool_ab: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        pool_cd: &mut clmm_pool::pool::Pool<CoinTypeC, CoinTypeD>,
        a_to_b: bool,
        c_to_d: bool,
        by_amount_in: bool,
        amount: u64
    ) {
        if (by_amount_in) {
            let first_pool_result = integrate::expect_swap::expect_swap<CoinTypeA, CoinTypeB>(pool_ab, a_to_b, by_amount_in, amount);
            let firt_pool_output = integrate::expect_swap::expect_swap_result_amount_out(&first_pool_result);
            if (integrate::expect_swap::expect_swap_result_is_exceed(&first_pool_result) || firt_pool_output > 18446744073709551615) {
                let failed_result = CalculatedRouterSwapResult {
                    amount_in: 0,
                    amount_medium: 0,
                    amount_out: 0,
                    is_exceed: true,
                    current_sqrt_price_ab: 0,
                    current_sqrt_price_cd: 0,
                    target_sqrt_price_ab: 0,
                    target_sqrt_price_cd: 0,
                };
                let failed_event = CalculatedRouterSwapResultEvent { data: failed_result };
                sui::event::emit<CalculatedRouterSwapResultEvent>(failed_event);
            } else {
                let medium_amount = (firt_pool_output as u64);
                let second_pool_result = integrate::expect_swap::expect_swap<CoinTypeC, CoinTypeD>(
                    pool_cd, c_to_d, by_amount_in, medium_amount);
                let second_pool_output = integrate::expect_swap::expect_swap_result_amount_out(&second_pool_result);
                if (second_pool_output > 18446744073709551615) {
                    let second_fail_result = CalculatedRouterSwapResult {
                        amount_in: 0,
                        amount_medium: 0,
                        amount_out: 0,
                        is_exceed: true,
                        current_sqrt_price_ab: 0,
                        current_sqrt_price_cd: 0,
                        target_sqrt_price_ab: 0,
                        target_sqrt_price_cd: 0,
                    };
                    let second_fail_event = CalculatedRouterSwapResultEvent { data: second_fail_result };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(second_fail_event);
                } else {
                    let is_any_exceed = integrate::expect_swap::expect_swap_result_is_exceed(
                        &first_pool_result
                    ) || integrate::expect_swap::expect_swap_result_is_exceed(&second_pool_result);
                    let success_result = CalculatedRouterSwapResult {
                        amount_in: amount,
                        amount_medium: medium_amount,
                        amount_out: (second_pool_output as u64),
                        is_exceed: is_any_exceed,
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<CoinTypeA, CoinTypeB>(pool_ab),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<CoinTypeC, CoinTypeD>(pool_cd),
                        target_sqrt_price_ab: integrate::expect_swap::expect_swap_result_after_sqrt_price(&first_pool_result
                        ),
                        target_sqrt_price_cd: integrate::expect_swap::expect_swap_result_after_sqrt_price(&second_pool_result
                        ),
                    };
                    let success_event = CalculatedRouterSwapResultEvent { data: success_result };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(success_event);
                };
            };
        } else {
            let reverse_second_result = integrate::expect_swap::expect_swap<CoinTypeC, CoinTypeD>(
                pool_cd, c_to_d, by_amount_in, amount);
            let reverse_second_exceeds = integrate::expect_swap::expect_swap_result_is_exceed(&reverse_second_result);
            let reverse_second_input = integrate::expect_swap::expect_swap_result_amount_in(&reverse_second_result);
            if (reverse_second_exceeds || reverse_second_input > 18446744073709551615) {
                let reverse_fail_result = CalculatedRouterSwapResult {
                    amount_in: 0,
                    amount_medium: 0,
                    amount_out: 0,
                    is_exceed: true,
                    current_sqrt_price_ab: 0,
                    current_sqrt_price_cd: 0,
                    target_sqrt_price_ab: 0,
                    target_sqrt_price_cd: 0,
                };
                let reverse_fail_event = CalculatedRouterSwapResultEvent { data: reverse_fail_result };
                sui::event::emit<CalculatedRouterSwapResultEvent>(reverse_fail_event);
            } else {
                let medium_amount = (reverse_second_input as u64);
                let medium_fee_amount = (integrate::expect_swap::expect_swap_result_fee_amount(&reverse_second_result) as u64);
                let reverse_first_result = integrate::expect_swap::expect_swap<CoinTypeA, CoinTypeB>(pool_ab, a_to_b, by_amount_in, (medium_amount + medium_fee_amount));
                let reverse_first_input = integrate::expect_swap::expect_swap_result_amount_in(&reverse_first_result);
                if (reverse_first_input > 18446744073709551615) {
                    let reverse_first_fail_result = CalculatedRouterSwapResult {
                        amount_in: 0,
                        amount_medium: 0,
                        amount_out: 0,
                        is_exceed: true,
                        current_sqrt_price_ab: 0,
                        current_sqrt_price_cd: 0,
                        target_sqrt_price_ab: 0,
                        target_sqrt_price_cd: 0,
                    };
                    let reverse_first_fail_event = CalculatedRouterSwapResultEvent { data: reverse_first_fail_result };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(reverse_first_fail_event);
                } else {
                    let is_any_reverse_exceed = integrate::expect_swap::expect_swap_result_is_exceed(&reverse_first_result) || reverse_second_exceeds;
                    let reverse_success_result = CalculatedRouterSwapResult {
                        amount_in: (reverse_first_input as u64) + (integrate::expect_swap::expect_swap_result_fee_amount(&reverse_first_result
                        ) as u64),
                        amount_medium: medium_amount + medium_fee_amount,
                        amount_out: amount,
                        is_exceed: is_any_reverse_exceed,
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<CoinTypeA, CoinTypeB>(pool_ab),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<CoinTypeC, CoinTypeD>(pool_cd),
                        target_sqrt_price_ab: integrate::expect_swap::expect_swap_result_after_sqrt_price(&reverse_first_result
                        ),
                        target_sqrt_price_cd: integrate::expect_swap::expect_swap_result_after_sqrt_price(&reverse_second_result
                        ),
                    };
                    let reverse_success_event = CalculatedRouterSwapResultEvent { data: reverse_success_result };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(reverse_success_event);
                };
            };
        };
    }

    public fun check_coin_threshold<CoinTypeA>(coin: &sui::coin::Coin<CoinTypeA>, threshold: u64) {
        assert!(coin.value<CoinTypeA>() >= threshold, EInsufficientFunds);
    }

    public fun swap_ab_bc<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        pool_bc: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeC>,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_bc: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_bc: u128,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_a_out, coin_b_out) = swap<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::zero<CoinTypeB>(ctx),
                true,
                true,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            let coin_b_amount = sui::coin::value<CoinTypeB>(&coin_b_out);
            let (unused_coin_b, coin_c_out) = swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                coin_b_out,
                coin_to,
                true,
                true,
                coin_b_amount,
                sqrt_price_limit_bc,
                false,
                stats,
                price_provider, 
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, EUnusedCoinRemaining);
            sui::coin::destroy_zero<CoinTypeB>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                true,
                false,
                amount_bc,
                sqrt_price_limit_bc,
                stats,
                price_provider,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<CoinTypeB, CoinTypeC>(&receipt),
                sqrt_price_limit_ab,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                sui::coin::into_balance<CoinTypeB>(coin_b_for_repay),
                sui::balance::zero<CoinTypeC>(),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ab_cb<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        pool_cb: &mut clmm_pool::pool::Pool<CoinTypeC, CoinTypeB>,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_cb: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_cb: u128,
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        price_provider: &price_provider::price_provider::PriceProvider,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_a_remaining, coin_b_out) = swap<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::zero<CoinTypeB>(ctx),
                true,
                by_amount_in,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            let coin_b_amount = coin_b_out.value<CoinTypeB>();
            let (coin_c_out, unused_coin_b) = swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                coin_to,
                coin_b_out,
                false,
                true,
                coin_b_amount,
                sqrt_price_limit_cb,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, EUnusedCoinRemaining);
            sui::coin::destroy_zero<CoinTypeB>(unused_coin_b);
            (coin_a_remaining, coin_c_out)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                false,
                false,
                amount_cb,
                sqrt_price_limit_cb,
                stats,
                price_provider,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<CoinTypeC, CoinTypeB>(&receipt),
                sqrt_price_limit_ab,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                sui::balance::zero<CoinTypeC>(),
                sui::coin::into_balance<CoinTypeB>(coin_b_for_repay),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_bc<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeA>,
        pool_bc: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeC>,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_bc: u64,
        sqrt_price_ba: u128,
        sqrt_price_bc: u128,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_b_out, coin_a_out) = swap<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                sui::coin::zero<CoinTypeB>(ctx),
                coin_from,
                false,
                by_amount_in,
                amount_ba,
                sqrt_price_ba,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            let amount = coin_b_out.value<CoinTypeB>();
            let (unused_coin_b, coin_c_out) = swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                coin_b_out,
                coin_to,
                true,
                true,
                amount,
                sqrt_price_bc,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, EUnusedCoinRemaining);
            sui::coin::destroy_zero<CoinTypeB>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                true,
                false,
                amount_bc,
                sqrt_price_bc,
                stats,
                price_provider,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                coin_from,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<CoinTypeB, CoinTypeC>(&receipt),
                sqrt_price_ba,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                sui::coin::into_balance<CoinTypeB>(coin_b_for_repay),
                sui::balance::zero<CoinTypeC>(),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_cb<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeA>,
        pool_cb: &mut clmm_pool::pool::Pool<CoinTypeC, CoinTypeB>,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_cb: u64,
        sqrt_price_limit_ba: u128,
        sqrt_price_limit_cb: u128,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_b_out, coin_a_out) = swap<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                sui::coin::zero<CoinTypeB>(ctx),
                coin_from,
                false,
                true,
                amount_ba,
                sqrt_price_limit_ba,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            let coin_b_amount = coin_b_out.value<CoinTypeB>();
            let (coin_c_out, unused_coin_b) = swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                coin_to,
                coin_b_out,
                false,
                by_amount_in,
                coin_b_amount,
                sqrt_price_limit_cb,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, EUnusedCoinRemaining);
            sui::coin::destroy_zero<CoinTypeB>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                false,
                false,
                amount_cb,
                sqrt_price_limit_cb,
                stats,
                price_provider,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                coin_from,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<CoinTypeC, CoinTypeB>(&receipt),
                sqrt_price_limit_ba,
                false,
                stats,
                price_provider,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                sui::balance::zero<CoinTypeC>(),
                sui::coin::into_balance<CoinTypeB>(coin_b_for_repay),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }
}


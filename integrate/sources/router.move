module integrate::router {
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

    public fun swap<T0, T1>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<T0, T1>,
        mut coin_a: sui::coin::Coin<T0>,
        mut coin_b: sui::coin::Coin<T1>,
        a2b: bool,
        by_amount_in: bool,
        mut amount: u64,
        sqrt_price_limit: u128,
        use_full_input: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        if (by_amount_in && use_full_input) {
            let amount_to_use = if (a2b) {
                coin_a.value<T0>()
            } else {
                coin_b.value<T1>()
            };
            amount = amount_to_use;
        };
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
            coin_b_out.value<T1>()
        } else {
            coin_a_out.value<T0>()
        };
        if (by_amount_in) {
            assert!(pay_amount == amount, 1);
        } else {
            assert!(coin_out_value == amount, 1);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            assert!(coin_a.value<T0>() >= pay_amount, 4);
            (sui::coin::into_balance<T0>(coin_a.split<T0>(pay_amount, ctx)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(coin_b.split<T1>(pay_amount, ctx)))
        };
        coin_a.join<T0>(sui::coin::from_balance<T0>(coin_a_out, ctx));
        coin_b.join<T1>(sui::coin::from_balance<T1>(coin_b_out, ctx));
        clmm_pool::pool::repay_flash_swap<T0, T1>(global_config, pool, repay_amount_a, repay_amount_b, receipt);
        (coin_a, coin_b)
    }

    public fun calculate_router_swap_result<T0, T1, T2, T3>(
        pool_ab: &mut clmm_pool::pool::Pool<T0, T1>,
        pool_bc: &mut clmm_pool::pool::Pool<T2, T3>,
        a_to_b: bool,
        b_to_c: bool,
        by_amount_in: bool,
        amount: u64
    ) {
        if (by_amount_in) {
            let first_pool_result = integrate::expect_swap::expect_swap<T0, T1>(pool_ab, a_to_b, by_amount_in, amount);
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
                let second_pool_result = integrate::expect_swap::expect_swap<T2, T3>(
                    pool_bc, b_to_c, by_amount_in, medium_amount);
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
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<T0, T1>(pool_ab),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<T2, T3>(pool_bc),
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
            let reverse_second_result = integrate::expect_swap::expect_swap<T2, T3>(
                pool_bc, b_to_c, by_amount_in, amount);
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
                let reverse_first_result = integrate::expect_swap::expect_swap<T0, T1>(pool_ab, a_to_b, by_amount_in, (medium_amount + medium_fee_amount));
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
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<T0, T1>(pool_ab),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<T2, T3>(pool_bc),
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

    public fun check_coin_threshold<T0>(coin: &sui::coin::Coin<T0>, threshold: u64) {
        assert!(coin.value<T0>() >= threshold, 4);
    }

    public fun swap_ab_bc<T0, T1, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<T0, T1>,
        pool_bc: &mut clmm_pool::pool::Pool<T1, T2>,
        coin_from: sui::coin::Coin<T0>,
        mut coin_to: sui::coin::Coin<T2>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_bc: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_bc: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (by_amount_in) {
            let (coin_a_out, coin_b_out) = swap<T0, T1>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::zero<T1>(ctx),
                true,
                true,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                clock,
                ctx
            );
            let coin_b_amount = sui::coin::value<T1>(&coin_b_out);
            let (unused_coin_b, coin_c_out) = swap<T1, T2>(
                global_config,
                pool_bc,
                coin_b_out,
                coin_to,
                true,
                true,
                coin_b_amount,
                sqrt_price_limit_bc,
                false,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<T1>() == 0, 5);
            sui::coin::destroy_zero<T1>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap<T1, T2>(
                global_config,
                pool_bc,
                true,
                false,
                amount_bc,
                sqrt_price_limit_bc,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap<T0, T1>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::from_balance<T1>(b_balance, ctx),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<T1, T2>(&receipt),
                sqrt_price_limit_ab,
                false,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<T1, T2>(
                global_config,
                pool_bc,
                sui::coin::into_balance<T1>(coin_b_for_repay),
                sui::balance::zero<T2>(),
                receipt
            );
            coin_to.join<T2>(sui::coin::from_balance<T2>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ab_cb<T0, T1, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<T0, T1>,
        pool_cb: &mut clmm_pool::pool::Pool<T2, T1>,
        coin_from: sui::coin::Coin<T0>,
        mut coin_to: sui::coin::Coin<T2>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_cb: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_cb: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (by_amount_in) {
            let (coin_a_remaining, coin_b_out) = swap<T0, T1>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::zero<T1>(ctx),
                true,
                by_amount_in,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                clock,
                ctx
            );
            let coin_b_amount = coin_b_out.value<T1>();
            let (coin_c_out, unused_coin_b) = swap<T2, T1>(
                global_config,
                pool_cb,
                coin_to,
                coin_b_out,
                false,
                true,
                coin_b_amount,
                sqrt_price_limit_cb,
                false,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<T1>() == 0, 5);
            sui::coin::destroy_zero<T1>(unused_coin_b);
            (coin_a_remaining, coin_c_out)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap<T2, T1>(
                global_config,
                pool_cb,
                false,
                false,
                amount_cb,
                sqrt_price_limit_cb,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap<T0, T1>(
                global_config,
                pool_ab,
                coin_from,
                sui::coin::from_balance<T1>(b_balance, ctx),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<T2, T1>(&receipt),
                sqrt_price_limit_ab,
                false,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<T2, T1>(
                global_config,
                pool_cb,
                sui::balance::zero<T2>(),
                sui::coin::into_balance<T1>(coin_b_for_repay),
                receipt
            );
            coin_to.join<T2>(sui::coin::from_balance<T2>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_bc<T0, T1, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<T1, T0>,
        pool_bc: &mut clmm_pool::pool::Pool<T1, T2>,
        coin_from: sui::coin::Coin<T0>,
        mut coin_to: sui::coin::Coin<T2>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_bc: u64,
        sqrt_price_ba: u128,
        sqrt_price_bc: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (by_amount_in) {
            let (coin_b_out, coin_a_out) = swap<T1, T0>(
                global_config,
                pool_ba,
                sui::coin::zero<T1>(ctx),
                coin_from,
                false,
                by_amount_in,
                amount_ba,
                sqrt_price_ba,
                false,
                clock,
                ctx
            );
            let amount = coin_b_out.value<T1>();
            let (unused_coin_b, coin_c_out) = swap<T1, T2>(
                global_config,
                pool_bc,
                coin_b_out,
                coin_to,
                true,
                true,
                amount,
                sqrt_price_bc,
                false,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<T1>() == 0, 5);
            sui::coin::destroy_zero<T1>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap<T1, T2>(
                global_config,
                pool_bc,
                true,
                false,
                amount_bc,
                sqrt_price_bc,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap<T1, T0>(
                global_config,
                pool_ba,
                sui::coin::from_balance<T1>(b_balance, ctx),
                coin_from,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<T1, T2>(&receipt),
                sqrt_price_ba,
                false,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<T1, T2>(
                global_config,
                pool_bc,
                sui::coin::into_balance<T1>(coin_b_for_repay),
                sui::balance::zero<T2>(),
                receipt
            );
            coin_to.join<T2>(sui::coin::from_balance<T2>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_cb<T0, T1, T2>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<T1, T0>,
        pool_cb: &mut clmm_pool::pool::Pool<T2, T1>,
        coin_from: sui::coin::Coin<T0>,
        mut coin_to: sui::coin::Coin<T2>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_cb: u64,
        sqrt_price_limit_ba: u128,
        sqrt_price_limit_cb: u128,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (by_amount_in) {
            let (coin_b_out, coin_a_out) = swap<T1, T0>(
                global_config,
                pool_ba,
                sui::coin::zero<T1>(ctx),
                coin_from,
                false,
                true,
                amount_ba,
                sqrt_price_limit_ba,
                false,
                clock,
                ctx
            );
            let coin_b_amount = coin_b_out.value<T1>();
            let (coin_c_out, unused_coin_b) = swap<T2, T1>(
                global_config,
                pool_cb,
                coin_to,
                coin_b_out,
                false,
                by_amount_in,
                coin_b_amount,
                sqrt_price_limit_cb,
                false,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<T1>() == 0, 5);
            sui::coin::destroy_zero<T1>(unused_coin_b);
            (coin_a_out, coin_c_out)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap<T2, T1>(
                global_config,
                pool_cb,
                false,
                false,
                amount_cb,
                sqrt_price_limit_cb,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap<T1, T0>(
                global_config,
                pool_ba,
                sui::coin::from_balance<T1>(b_balance, ctx),
                coin_from,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<T2, T1>(&receipt),
                sqrt_price_limit_ba,
                false,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap<T2, T1>(
                global_config,
                pool_cb,
                sui::balance::zero<T2>(),
                sui::coin::into_balance<T1>(coin_b_for_repay),
                receipt
            );
            coin_to.join<T2>(sui::coin::from_balance<T2>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }
}


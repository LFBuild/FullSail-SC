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
    
    public fun swap<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, mut arg2: sui::coin::Coin<T0>, mut arg3: sui::coin::Coin<T1>, arg4: bool, arg5: bool, mut arg6: u64, arg7: u128, arg8: bool, arg9: &sui::clock::Clock, arg10: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        if (arg5 && arg8) {
            let v0 = if (arg4) {
                sui::coin::value<T0>(&arg2)
            } else {
                sui::coin::value<T1>(&arg3)
            };
            arg6 = v0;
        };
        let (v1, v2, v3) = clmm_pool::pool::flash_swap<T0, T1>(arg0, arg1, arg4, arg5, arg6, arg7, arg9);
        let v4 = v3;
        let v5 = v2;
        let v6 = v1;
        let v7 = clmm_pool::pool::swap_pay_amount<T0, T1>(&v4);
        let v8 = if (arg4) {
            sui::balance::value<T1>(&v5)
        } else {
            sui::balance::value<T0>(&v6)
        };
        if (arg5) {
            assert!(v7 == arg6, 1);
        } else {
            assert!(v8 == arg6, 1);
        };
        let (v9, v10) = if (arg4) {
            assert!(sui::coin::value<T0>(&arg2) >= v7, 4);
            (sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut arg2, v7, arg10)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut arg3, v7, arg10)))
        };
        sui::coin::join<T0>(&mut arg2, sui::coin::from_balance<T0>(v6, arg10));
        sui::coin::join<T1>(&mut arg3, sui::coin::from_balance<T1>(v5, arg10));
        clmm_pool::pool::repay_flash_swap<T0, T1>(arg0, arg1, v9, v10, v4);
        (arg2, arg3)
    }

    public fun calculate_router_swap_result<T0, T1, T2, T3>(
        arg0: &mut clmm_pool::pool::Pool<T0, T1>,
        arg1: &mut clmm_pool::pool::Pool<T2, T3>,
        arg2: bool,
        arg3: bool,
        arg4: bool,
        arg5: u64
    ) {
        if (arg4) {
            let v0 = integrate::expect_swap::expect_swap<T0, T1>(arg0, arg2, arg4, arg5);
            let v1 = integrate::expect_swap::expect_swap_result_amount_out(&v0);
            if (integrate::expect_swap::expect_swap_result_is_exceed(&v0) || v1 > 18446744073709551615) {
                let v2 = CalculatedRouterSwapResult {
                    amount_in: 0,
                    amount_medium: 0,
                    amount_out: 0,
                    is_exceed: true,
                    current_sqrt_price_ab: 0,
                    current_sqrt_price_cd: 0,
                    target_sqrt_price_ab: 0,
                    target_sqrt_price_cd: 0,
                };
                let v3 = CalculatedRouterSwapResultEvent { data: v2 };
                sui::event::emit<CalculatedRouterSwapResultEvent>(v3);
            } else {
                let v4 = (v1 as u64);
                let v5 = integrate::expect_swap::expect_swap<T2, T3>(arg1, arg3, arg4, v4);
                let v6 = integrate::expect_swap::expect_swap_result_amount_out(&v5);
                if (v6 > 18446744073709551615) {
                    let v7 = CalculatedRouterSwapResult {
                        amount_in: 0,
                        amount_medium: 0,
                        amount_out: 0,
                        is_exceed: true,
                        current_sqrt_price_ab: 0,
                        current_sqrt_price_cd: 0,
                        target_sqrt_price_ab: 0,
                        target_sqrt_price_cd: 0,
                    };
                    let v8 = CalculatedRouterSwapResultEvent { data: v7 };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(v8);
                } else {
                    let v9 = integrate::expect_swap::expect_swap_result_is_exceed(
                        &v0
                    ) || integrate::expect_swap::expect_swap_result_is_exceed(&v5);
                    let v10 = CalculatedRouterSwapResult {
                        amount_in: arg5,
                        amount_medium: v4,
                        amount_out: (v6 as u64),
                        is_exceed: v9,
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<T0, T1>(arg0),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<T2, T3>(arg1),
                        target_sqrt_price_ab: integrate::expect_swap::expect_swap_result_after_sqrt_price(&v0),
                        target_sqrt_price_cd: integrate::expect_swap::expect_swap_result_after_sqrt_price(&v5),
                    };
                    let v11 = CalculatedRouterSwapResultEvent { data: v10 };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(v11);
                };
            };
        } else {
            let v12 = integrate::expect_swap::expect_swap<T2, T3>(arg1, arg3, arg4, arg5);
            let v13 = integrate::expect_swap::expect_swap_result_is_exceed(&v12);
            let v14 = integrate::expect_swap::expect_swap_result_amount_in(&v12);
            if (v13 || v14 > 18446744073709551615) {
                let v15 = CalculatedRouterSwapResult {
                    amount_in: 0,
                    amount_medium: 0,
                    amount_out: 0,
                    is_exceed: true,
                    current_sqrt_price_ab: 0,
                    current_sqrt_price_cd: 0,
                    target_sqrt_price_ab: 0,
                    target_sqrt_price_cd: 0,
                };
                let v16 = CalculatedRouterSwapResultEvent { data: v15 };
                sui::event::emit<CalculatedRouterSwapResultEvent>(v16);
            } else {
                let v17 = (v14 as u64);
                let v18 = (integrate::expect_swap::expect_swap_result_fee_amount(&v12) as u64);
                let v19 = integrate::expect_swap::expect_swap<T0, T1>(arg0, arg2, arg4, (v17 + v18));
                let v20 = integrate::expect_swap::expect_swap_result_amount_in(&v19);
                if (v20 > 18446744073709551615) {
                    let v21 = CalculatedRouterSwapResult {
                        amount_in: 0,
                        amount_medium: 0,
                        amount_out: 0,
                        is_exceed: true,
                        current_sqrt_price_ab: 0,
                        current_sqrt_price_cd: 0,
                        target_sqrt_price_ab: 0,
                        target_sqrt_price_cd: 0,
                    };
                    let v22 = CalculatedRouterSwapResultEvent { data: v21 };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(v22);
                } else {
                    let v23 = integrate::expect_swap::expect_swap_result_is_exceed(&v19) || v13;
                    let v24 = CalculatedRouterSwapResult {
                        amount_in: (v20 as u64) + (integrate::expect_swap::expect_swap_result_fee_amount(&v19) as u64),
                        amount_medium: v17 + v18,
                        amount_out: arg5,
                        is_exceed: v23,
                        current_sqrt_price_ab: clmm_pool::pool::current_sqrt_price<T0, T1>(arg0),
                        current_sqrt_price_cd: clmm_pool::pool::current_sqrt_price<T2, T3>(arg1),
                        target_sqrt_price_ab: integrate::expect_swap::expect_swap_result_after_sqrt_price(&v19),
                        target_sqrt_price_cd: integrate::expect_swap::expect_swap_result_after_sqrt_price(&v12),
                    };
                    let v25 = CalculatedRouterSwapResultEvent { data: v24 };
                    sui::event::emit<CalculatedRouterSwapResultEvent>(v25);
                };
            };
        };
    }

    public fun check_coin_threshold<T0>(arg0: &sui::coin::Coin<T0>, arg1: u64) {
        assert!(sui::coin::value<T0>(arg0) >= arg1, 4);
    }
    
    public fun swap_ab_bc<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::pool::Pool<T1, T2>, arg3: sui::coin::Coin<T0>, mut arg4: sui::coin::Coin<T2>, arg5: bool, arg6: u64, arg7: u64, arg8: u128, arg9: u128, arg10: &sui::clock::Clock, arg11: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg5) {
            let (v2, v3) = swap<T0, T1>(arg0, arg1, arg3, sui::coin::zero<T1>(arg11), true, true, arg6, arg8, false, arg10, arg11);
            let v4 = v3;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap<T1, T2>(arg0, arg2, v4, arg4, true, true, amount, arg9, false, arg10, arg11);
            let v7 = v5;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v2, v6)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap<T1, T2>(arg0, arg2, true, false, arg7, arg9, arg10);
            let v11 = v10;
            let (v12, v13) = swap<T0, T1>(arg0, arg1, arg3, sui::coin::from_balance<T1>(v8, arg11), true, false, clmm_pool::pool::swap_pay_amount<T1, T2>(&v11), arg8, false, arg10, arg11);
            clmm_pool::pool::repay_flash_swap<T1, T2>(arg0, arg2, sui::coin::into_balance<T1>(v13), sui::balance::zero<T2>(), v11);
            sui::coin::join<T2>(&mut arg4, sui::coin::from_balance<T2>(v9, arg11));
            (v12, arg4)
        }
    }
    
    public fun swap_ab_cb<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut clmm_pool::pool::Pool<T2, T1>, arg3: sui::coin::Coin<T0>, mut arg4: sui::coin::Coin<T2>, arg5: bool, arg6: u64, arg7: u64, arg8: u128, arg9: u128, arg10: &sui::clock::Clock, arg11: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg5) {
            let (v2, v3) = swap<T0, T1>(arg0, arg1, arg3, sui::coin::zero<T1>(arg11), true, arg5, arg6, arg8, false, arg10, arg11);
            let v4 = v3;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap<T2, T1>(arg0, arg2, arg4, v4, false, true, amount, arg9, false, arg10, arg11);
            let v7 = v6;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v2, v5)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap<T2, T1>(arg0, arg2, false, false, arg7, arg9, arg10);
            let v11 = v10;
            let (v12, v13) = swap<T0, T1>(arg0, arg1, arg3, sui::coin::from_balance<T1>(v9, arg11), true, false, clmm_pool::pool::swap_pay_amount<T2, T1>(&v11), arg8, false, arg10, arg11);
            clmm_pool::pool::repay_flash_swap<T2, T1>(arg0, arg2, sui::balance::zero<T2>(), sui::coin::into_balance<T1>(v13), v11);
            sui::coin::join<T2>(&mut arg4, sui::coin::from_balance<T2>(v8, arg11));
            (v12, arg4)
        }
    }
    
    public fun swap_ba_bc<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T1, T0>, arg2: &mut clmm_pool::pool::Pool<T1, T2>, arg3: sui::coin::Coin<T0>, mut arg4: sui::coin::Coin<T2>, arg5: bool, arg6: u64, arg7: u64, arg8: u128, arg9: u128, arg10: &sui::clock::Clock, arg11: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg5) {
            let (v2, v3) = swap<T1, T0>(arg0, arg1, sui::coin::zero<T1>(arg11), arg3, false, arg5, arg6, arg8, false, arg10, arg11);
            let v4 = v2;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap<T1, T2>(arg0, arg2, v4, arg4, true, true, amount, arg9, false, arg10, arg11);
            let v7 = v5;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v3, v6)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap<T1, T2>(arg0, arg2, true, false, arg7, arg9, arg10);
            let v11 = v10;
            let (v12, v13) = swap<T1, T0>(arg0, arg1, sui::coin::from_balance<T1>(v8, arg11), arg3, false, false, clmm_pool::pool::swap_pay_amount<T1, T2>(&v11), arg8, false, arg10, arg11);
            clmm_pool::pool::repay_flash_swap<T1, T2>(arg0, arg2, sui::coin::into_balance<T1>(v12), sui::balance::zero<T2>(), v11);
            sui::coin::join<T2>(&mut arg4, sui::coin::from_balance<T2>(v9, arg11));
            (v13, arg4)
        }
    }
    
    public fun swap_ba_cb<T0, T1, T2>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T1, T0>, arg2: &mut clmm_pool::pool::Pool<T2, T1>, arg3: sui::coin::Coin<T0>, mut arg4: sui::coin::Coin<T2>, arg5: bool, arg6: u64, arg7: u64, arg8: u128, arg9: u128, arg10: &sui::clock::Clock, arg11: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg5) {
            let (v2, v3) = swap<T1, T0>(arg0, arg1, sui::coin::zero<T1>(arg11), arg3, false, true, arg6, arg8, false, arg10, arg11);
            let v4 = v2;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap<T2, T1>(arg0, arg2, arg4, v4, false, arg5, amount, arg9, false, arg10, arg11);
            let v7 = v6;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v3, v5)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap<T2, T1>(arg0, arg2, false, false, arg7, arg9, arg10);
            let v11 = v10;
            let (v12, v13) = swap<T1, T0>(arg0, arg1, sui::coin::from_balance<T1>(v9, arg11), arg3, false, false, clmm_pool::pool::swap_pay_amount<T2, T1>(&v11), arg8, false, arg10, arg11);
            clmm_pool::pool::repay_flash_swap<T2, T1>(arg0, arg2, sui::balance::zero<T2>(), sui::coin::into_balance<T1>(v12), v11);
            sui::coin::join<T2>(&mut arg4, sui::coin::from_balance<T2>(v8, arg11));
            (v13, arg4)
        }
    }

    // decompiled from Move bytecode v6
}


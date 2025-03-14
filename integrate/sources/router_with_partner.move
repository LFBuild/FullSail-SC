module integrate::router_with_partner {
    public fun swap_ab_bc_with_partner<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: &mut clmm_pool::pool::Pool<T1, T2>,
        arg3: &mut clmm_pool::partner::Partner,
        arg4: sui::coin::Coin<T0>,
        mut arg5: sui::coin::Coin<T2>,
        arg6: bool,
        arg7: u64,
        arg8: u64,
        arg9: u128,
        arg10: u128,
        arg11: &sui::clock::Clock,
        arg12: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg6) {
            let (v2, v3) = swap_with_partner<T0, T1>(
                arg0,
                arg1,
                arg3,
                arg4,
                sui::coin::zero<T1>(arg12),
                true,
                true,
                arg7,
                arg9,
                false,
                arg11,
                arg12
            );
            let v4 = v3;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                v4,
                arg5,
                true,
                true,
                amount,
                arg10,
                false,
                arg11,
                arg12
            );
            let v7 = v5;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v2, v6)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                true,
                false,
                arg8,
                arg10,
                arg11
            );
            let v11 = v10;
            let (v12, v13) = swap_with_partner<T0, T1>(
                arg0,
                arg1,
                arg3,
                arg4,
                sui::coin::from_balance<T1>(v8, arg12),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<T1, T2>(&v11),
                arg9,
                false,
                arg11,
                arg12
            );
            clmm_pool::pool::repay_flash_swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                sui::coin::into_balance<T1>(v13),
                sui::balance::zero<T2>(),
                v11
            );
            sui::coin::join<T2>(&mut arg5, sui::coin::from_balance<T2>(v9, arg12));
            (v12, arg5)
        }
    }

    public fun swap_ab_cb_with_partner<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: &mut clmm_pool::pool::Pool<T2, T1>,
        arg3: &mut clmm_pool::partner::Partner,
        arg4: sui::coin::Coin<T0>,
        mut arg5: sui::coin::Coin<T2>,
        arg6: bool,
        arg7: u64,
        arg8: u64,
        arg9: u128,
        arg10: u128,
        arg11: &sui::clock::Clock,
        arg12: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg6) {
            let (v2, v3) = swap_with_partner<T0, T1>(
                arg0,
                arg1,
                arg3,
                arg4,
                sui::coin::zero<T1>(arg12),
                true,
                arg6,
                arg7,
                arg9,
                false,
                arg11,
                arg12
            );
            let v4 = v3;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                arg5,
                v4,
                false,
                true,
                amount,
                arg10,
                false,
                arg11,
                arg12
            );
            let v7 = v6;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v2, v5)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                false,
                false,
                arg8,
                arg10,
                arg11
            );
            let v11 = v10;
            let (v12, v13) = swap_with_partner<T0, T1>(
                arg0,
                arg1,
                arg3,
                arg4,
                sui::coin::from_balance<T1>(v9, arg12),
                true,
                false,
                clmm_pool::pool::swap_pay_amount<T2, T1>(&v11),
                arg9,
                false,
                arg11,
                arg12
            );
            clmm_pool::pool::repay_flash_swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                sui::balance::zero<T2>(),
                sui::coin::into_balance<T1>(v13),
                v11
            );
            sui::coin::join<T2>(&mut arg5, sui::coin::from_balance<T2>(v8, arg12));
            (v12, arg5)
        }
    }

    public fun swap_ba_bc_with_partner<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut clmm_pool::pool::Pool<T1, T0>,
        arg2: &mut clmm_pool::pool::Pool<T1, T2>,
        arg3: &mut clmm_pool::partner::Partner,
        arg4: sui::coin::Coin<T0>,
        mut arg5: sui::coin::Coin<T2>,
        arg6: bool,
        arg7: u64,
        arg8: u64,
        arg9: u128,
        arg10: u128,
        arg11: &sui::clock::Clock,
        arg12: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg6) {
            let (v2, v3) = swap_with_partner<T1, T0>(
                arg0,
                arg1,
                arg3,
                sui::coin::zero<T1>(arg12),
                arg4,
                false,
                arg6,
                arg7,
                arg9,
                false,
                arg11,
                arg12
            );
            let v4 = v2;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                v4,
                arg5,
                true,
                true,
                amount,
                arg10,
                false,
                arg11,
                arg12
            );
            let v7 = v5;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v3, v6)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                true,
                false,
                arg8,
                arg10,
                arg11
            );
            let v11 = v10;
            let (v12, v13) = swap_with_partner<T1, T0>(
                arg0,
                arg1,
                arg3,
                sui::coin::from_balance<T1>(v8, arg12),
                arg4,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<T1, T2>(&v11),
                arg9,
                false,
                arg11,
                arg12
            );
            clmm_pool::pool::repay_flash_swap_with_partner<T1, T2>(
                arg0,
                arg2,
                arg3,
                sui::coin::into_balance<T1>(v12),
                sui::balance::zero<T2>(),
                v11
            );
            sui::coin::join<T2>(&mut arg5, sui::coin::from_balance<T2>(v9, arg12));
            (v13, arg5)
        }
    }

    public fun swap_ba_cb_with_partner<T0, T1, T2>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut clmm_pool::pool::Pool<T1, T0>,
        arg2: &mut clmm_pool::pool::Pool<T2, T1>,
        arg3: &mut clmm_pool::partner::Partner,
        arg4: sui::coin::Coin<T0>,
        mut arg5: sui::coin::Coin<T2>,
        arg6: bool,
        arg7: u64,
        arg8: u64,
        arg9: u128,
        arg10: u128,
        arg11: &sui::clock::Clock,
        arg12: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T2>) {
        if (arg6) {
            let (v2, v3) = swap_with_partner<T1, T0>(
                arg0,
                arg1,
                arg3,
                sui::coin::zero<T1>(arg12),
                arg4,
                false,
                true,
                arg7,
                arg9,
                false,
                arg11,
                arg12
            );
            let v4 = v2;
            let amount = sui::coin::value<T1>(&v4);
            let (v5, v6) = swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                arg5,
                v4,
                false,
                arg6,
                amount,
                arg10,
                false,
                arg11,
                arg12
            );
            let v7 = v6;
            assert!(sui::coin::value<T1>(&v7) == 0, 5);
            sui::coin::destroy_zero<T1>(v7);
            (v3, v5)
        } else {
            let (v8, v9, v10) = clmm_pool::pool::flash_swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                false,
                false,
                arg8,
                arg10,
                arg11
            );
            let v11 = v10;
            let (v12, v13) = swap_with_partner<T1, T0>(
                arg0,
                arg1,
                arg3,
                sui::coin::from_balance<T1>(v9, arg12),
                arg4,
                false,
                false,
                clmm_pool::pool::swap_pay_amount<T2, T1>(&v11),
                arg9,
                false,
                arg11,
                arg12
            );
            clmm_pool::pool::repay_flash_swap_with_partner<T2, T1>(
                arg0,
                arg2,
                arg3,
                sui::balance::zero<T2>(),
                sui::coin::into_balance<T1>(v12),
                v11
            );
            sui::coin::join<T2>(&mut arg5, sui::coin::from_balance<T2>(v8, arg12));
            (v13, arg5)
        }
    }

    public fun swap_with_partner<T0, T1>(
        arg0: &clmm_pool::config::GlobalConfig,
        arg1: &mut clmm_pool::pool::Pool<T0, T1>,
        arg2: &mut clmm_pool::partner::Partner,
        mut arg3: sui::coin::Coin<T0>,
        mut arg4: sui::coin::Coin<T1>,
        arg5: bool,
        arg6: bool,
        mut arg7: u64,
        arg8: u128,
        arg9: bool,
        arg10: &sui::clock::Clock,
        arg11: &mut sui::tx_context::TxContext
    ): (sui::coin::Coin<T0>, sui::coin::Coin<T1>) {
        if (arg6 && arg9) {
            let v0 = if (arg5) {
                sui::coin::value<T0>(&arg3)
            } else {
                sui::coin::value<T1>(&arg4)
            };
            arg7 = v0;
        };
        let (v1, v2, v3) = clmm_pool::pool::flash_swap_with_partner<T0, T1>(
            arg0,
            arg1,
            arg2,
            arg5,
            arg6,
            arg7,
            arg8,
            arg10
        );
        let v4 = v3;
        let v5 = v2;
        let v6 = v1;
        let v7 = clmm_pool::pool::swap_pay_amount<T0, T1>(&v4);
        let v8 = if (arg5) {
            sui::balance::value<T1>(&v5)
        } else {
            sui::balance::value<T0>(&v6)
        };
        if (arg6) {
            assert!(v7 == arg7, 1);
        } else {
            assert!(v8 == arg7, 1);
        };
        let (v9, v10) = if (arg5) {
            assert!(sui::coin::value<T0>(&arg3) >= v7, 4);
            (sui::coin::into_balance<T0>(sui::coin::split<T0>(&mut arg3, v7, arg11)), sui::balance::zero<T1>())
        } else {
            (sui::balance::zero<T0>(), sui::coin::into_balance<T1>(sui::coin::split<T1>(&mut arg4, v7, arg11)))
        };
        sui::coin::join<T0>(&mut arg3, sui::coin::from_balance<T0>(v6, arg11));
        sui::coin::join<T1>(&mut arg4, sui::coin::from_balance<T1>(v5, arg11));
        clmm_pool::pool::repay_flash_swap_with_partner<T0, T1>(arg0, arg1, arg2, v9, v10, v4);
        (arg3, arg4)
    }

    // decompiled from Move bytecode v6
}


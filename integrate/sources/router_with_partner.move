module integrate::router_with_partner {
    public fun swap_ab_bc_with_partner<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        pool_bc: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeC>,
        partner: &mut clmm_pool::partner::Partner,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_bc: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_bc: u128,
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_a_out, intermediate_coin_b) = swap_with_partner<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                partner,
                coin_from,
                sui::coin::zero<CoinTypeB>(ctx),
                true,
                true,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                stats,
                clock,
                ctx
            );
            let intermediate_amount = intermediate_coin_b.value<CoinTypeB>();
            let (unused_coin_b, final_coin_c) = swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                intermediate_coin_b,
                coin_to,
                true,
                true,
                intermediate_amount,
                sqrt_price_limit_bc,
                false,
                stats,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, 5);
            unused_coin_b.destroy_zero();
            (coin_a_out, final_coin_c)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                true,
                false,
                amount_bc,
                sqrt_price_limit_bc,
                stats,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap_with_partner<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                partner,
                coin_from,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                true,
                false,
                receipt.swap_pay_amount(),
                sqrt_price_limit_ab,
                false,
                stats,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                coin_b_for_repay.into_balance(),
                sui::balance::zero<CoinTypeC>(),
                receipt
            );
            coin_to.join(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ab_cb_with_partner<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ab: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        pool_cb: &mut clmm_pool::pool::Pool<CoinTypeC, CoinTypeB>,
        partner: &mut clmm_pool::partner::Partner,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ab: u64,
        amount_cb: u64,
        sqrt_price_limit_ab: u128,
        sqrt_price_limit_cb: u128,
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (coin_a_out, intermediate_coin_b) = swap_with_partner<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                partner,
                coin_from,
                sui::coin::zero<CoinTypeB>(ctx),
                true,
                by_amount_in,
                amount_ab,
                sqrt_price_limit_ab,
                false,
                stats,
                clock,
                ctx
            );
            let intermediate_amount = intermediate_coin_b.value();
            let (final_coin_c, unused_coin_b) = swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                coin_to,
                intermediate_coin_b,
                false,
                true,
                intermediate_amount,
                sqrt_price_limit_cb,
                false,
                stats,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, 5);
            unused_coin_b.destroy_zero();
            (coin_a_out, final_coin_c)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                false,
                false,
                amount_cb,
                sqrt_price_limit_cb,
                stats,
                clock
            );
            let (final_coin_a, coin_b_for_repay) = swap_with_partner<CoinTypeA, CoinTypeB>(
                global_config,
                pool_ab,
                partner,
                coin_from,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                true,
                false,
                receipt.swap_pay_amount(),
                sqrt_price_limit_ab,
                false,
                stats,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                sui::balance::zero<CoinTypeC>(),
                coin_b_for_repay.into_balance(),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_bc_with_partner<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeA>,
        pool_bc: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeC>,
        partner: &mut clmm_pool::partner::Partner,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_bc: u64,
        sqrt_price_limit_ba: u128,
        sqrt_price_limit_bc: u128,
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (intemediate_coin_b, coin_a_out) = swap_with_partner<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                partner,
                sui::coin::zero<CoinTypeB>(ctx),
                coin_from,
                false,
                by_amount_in,
                amount_ba,
                sqrt_price_limit_ba,
                false,
                stats,
                clock,
                ctx
            );
            let intemediate_coin_b = intemediate_coin_b;
            let intemediate_amount = intemediate_coin_b.value<CoinTypeB>();
            let (unused_coin_b, final_coin_c) = swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                intemediate_coin_b,
                coin_to,
                true,
                true,
                intemediate_amount,
                sqrt_price_limit_bc,
                false,
                stats,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, 5);
            unused_coin_b.destroy_zero();
            (coin_a_out, final_coin_c)
        } else {
            let (b_balance, c_balance, receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                true,
                false,
                amount_bc,
                sqrt_price_limit_bc,
                stats,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap_with_partner<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                partner,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                coin_from,
                false,
                false,
                receipt.swap_pay_amount(),
                sqrt_price_limit_ba,
                false,
                stats,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeB, CoinTypeC>(
                global_config,
                pool_bc,
                partner,
                coin_b_for_repay.into_balance(),
                sui::balance::zero<CoinTypeC>(),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_ba_cb_with_partner<CoinTypeA, CoinTypeB, CoinTypeC>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool_ba: &mut clmm_pool::pool::Pool<CoinTypeB, CoinTypeA>,
        pool_cb: &mut clmm_pool::pool::Pool<CoinTypeC, CoinTypeB>,
        partner: &mut clmm_pool::partner::Partner,
        coin_from: sui::coin::Coin<CoinTypeA>,
        mut coin_to: sui::coin::Coin<CoinTypeC>,
        by_amount_in: bool,
        amount_ba: u64,
        amount_bc: u64,
        sqrt_price_limit_ba: u128,
        sqrt_price_limit_bc: u128,
        stats: &mut clmm_pool::stats::Stats,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::coin::Coin<CoinTypeA>, sui::coin::Coin<CoinTypeC>) {
        if (by_amount_in) {
            let (intermediate_coin_b, coin_a_out) = swap_with_partner<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                partner,
                sui::coin::zero<CoinTypeB>(ctx),
                coin_from,
                false,
                true,
                amount_ba,
                sqrt_price_limit_ba,
                false,
                stats,
                clock,
                ctx
            );
            let amount = intermediate_coin_b.value();
            let (final_coin_c, unused_coin_b) = swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                coin_to,
                intermediate_coin_b,
                false,
                by_amount_in,
                amount,
                sqrt_price_limit_bc,
                false,
                stats,
                clock,
                ctx
            );
            assert!(unused_coin_b.value<CoinTypeB>() == 0, 5);
            unused_coin_b.destroy_zero();
            (coin_a_out, final_coin_c)
        } else {
            let (c_balance, b_balance, receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                false,
                false,
                amount_bc,
                sqrt_price_limit_bc,
                stats,
                clock
            );
            let (coin_b_for_repay, final_coin_a) = swap_with_partner<CoinTypeB, CoinTypeA>(
                global_config,
                pool_ba,
                partner,
                sui::coin::from_balance<CoinTypeB>(b_balance, ctx),
                coin_from,
                false,
                false,
                receipt.swap_pay_amount(),
                sqrt_price_limit_ba,
                false,
                stats,
                clock,
                ctx
            );
            clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeC, CoinTypeB>(
                global_config,
                pool_cb,
                partner,
                sui::balance::zero<CoinTypeC>(),
                coin_b_for_repay.into_balance(),
                receipt
            );
            coin_to.join<CoinTypeC>(sui::coin::from_balance<CoinTypeC>(c_balance, ctx));
            (final_coin_a, coin_to)
        }
    }

    public fun swap_with_partner<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        partner: &mut clmm_pool::partner::Partner,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        mut amount: u64,
        sqrt_price_limit: u128,
        use_full_input: bool,
        stats: &mut clmm_pool::stats::Stats,
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
        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            partner,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            stats,
            clock
        );
        let pay_mount = receipt.swap_pay_amount();
        let coin_out_value = if (a2b) {
            coin_b_out.value<CoinTypeB>()
        } else {
            coin_a_out.value<CoinTypeA>()
        };
        if (by_amount_in) {
            assert!(pay_mount == amount, 1);
        } else {
            assert!(coin_out_value == amount, 1);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            assert!(coin_a.value<CoinTypeA>() >= pay_mount, 4);
            (
                coin_a.split<CoinTypeA>(pay_mount, ctx).into_balance(),
                sui::balance::zero<CoinTypeB>()
            )
        } else {
            (
                sui::balance::zero<CoinTypeA>(),
                coin_b.split<CoinTypeB>(pay_mount, ctx).into_balance()
            )
        };
        coin_a.join<CoinTypeA>(sui::coin::from_balance<CoinTypeA>(coin_a_out, ctx));
        coin_b.join<CoinTypeB>(sui::coin::from_balance<CoinTypeB>(coin_b_out, ctx));
        clmm_pool::pool::repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            partner,
            repay_amount_a,
            repay_amount_b,
            receipt
        );
        (coin_a, coin_b)
    }
}


module integrate::expect_swap {
    public struct ExpectSwapResult has copy, drop, store {
        amount_in: u256,
        amount_out: u256,
        fee_amount: u256,
        fee_rate: u64,
        after_sqrt_price: u128,
        is_exceed: bool,
        step_results: vector<SwapStepResult>,
    }

    public struct SwapStepResult has copy, drop, store {
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        current_liquidity: u128,
        amount_in: u256,
        amount_out: u256,
        fee_amount: u256,
        remainder_amount: u64,
    }

    public struct SwapResult has copy, drop {
        amount_in: u256,
        amount_out: u256,
        fee_amount: u256,
        ref_fee_amount: u256,
        steps: u64,
    }

    public struct ExpectSwapResultEvent has copy, drop, store {
        data: ExpectSwapResult,
        current_sqrt_price: u128,
    }

    public fun expect_swap<T0, T1>(
        arg0: &clmm_pool::pool::Pool<T0, T1>,
        arg1: bool,
        arg2: bool,
        arg3: u64
    ): ExpectSwapResult {
        let mut v0 = arg0.current_sqrt_price();
        let mut v1 = arg0.liquidity();
        let mut v2 = default_swap_result();
        let mut v3 = arg3;
        let mut v4 = arg0.tick_manager().first_score_for_swap(arg0.current_tick_index(), arg1);
        let mut v5 = ExpectSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: arg0.fee_rate(),
            after_sqrt_price: arg0.current_sqrt_price(),
            is_exceed: false,
            step_results: std::vector::empty<SwapStepResult>(),
        };
        while (v3 > 0) {
            if (v4.is_none()) {
                v5.is_exceed = true;
                break
            };
            let (v6, v7) = arg0.tick_manager().borrow_tick_for_swap(v4.borrow(), arg1);
            v4 = v7;
            let v8 = v6.sqrt_price();
            let (v9, v10, v11, v12) = compute_swap_step(
                v0,
                v8,
                v1,
                v3,
                arg0.fee_rate(),
                arg1,
                arg2
            );
            if (v9 != 0 || v12 != 0) {
                let v13 = if (arg2) {
                    let v14 = check_remainer_amount_sub(v3, (v9 as u64));
                    check_remainer_amount_sub(v14, (v12 as u64))
                } else {
                    check_remainer_amount_sub(v3, (v10 as u64))
                };
                v3 = v13;
                v2.update_swap_result(v9, v10, v12);
            };
            let v15 = SwapStepResult {
                current_sqrt_price: v0,
                target_sqrt_price: v8,
                current_liquidity: v1,
                amount_in: v9,
                amount_out: v10,
                fee_amount: v12,
                remainder_amount: v3,
            };
            v5.step_results.push_back(v15);
            if (v11 == v8) {
                v0 = v8;
                let v16 = if (arg1) {
                    v6.liquidity_net().neg()
                } else {
                    v6.liquidity_net()
                };
                if (!v16.is_neg()) {
                    let v17 = v16.abs_u128();
                    assert!(integer_mate::math_u128::add_check(v1, v17), 5);
                    v1 = v1 + v17;
                    continue
                };
                let v18 = v16.abs_u128();
                assert!(v1 >= v18, 5);
                v1 = v1 - v18;
                continue
            };
            v0 = v11;
        };
        v5.amount_in = v2.amount_in;
        v5.amount_out = v2.amount_out;
        v5.fee_amount = v2.fee_amount;
        v5.after_sqrt_price = v0;
        v5
    }

    fun check_remainer_amount_sub(arg0: u64, arg1: u64): u64 {
        assert!(arg0 >= arg1, 4);
        arg0 - arg1
    }

    public fun compute_swap_step(
        arg0: u128,
        arg1: u128,
        arg2: u128,
        arg3: u64,
        arg4: u64,
        arg5: bool,
        arg6: bool
    ): (u256, u256, u128, u256) {
        if (arg2 == 0) {
            return (0, 0, arg1, 0)
        };
        if (arg5) {
            assert!(arg0 >= arg1, 3);
        } else {
            assert!(arg0 < arg1, 3);
        };
        let (v0, v1, v2, v3) = if (arg6) {
            let v4 = integer_mate::full_math_u64::mul_div_floor(
                arg3,
                clmm_pool::clmm_math::fee_rate_denominator() - arg4,
                clmm_pool::clmm_math::fee_rate_denominator()
            );
            let v5 = clmm_pool::clmm_math::get_delta_up_from_input(arg0, arg1, arg2, arg5);
            let (v6, v7, v8) = if (v5 > (v4 as u256)) {
                ((v4 as u256), ((arg3 - v4) as u256), clmm_pool::clmm_math::get_next_sqrt_price_from_input(
                    arg0,
                    arg2,
                    v4,
                    arg5
                ))
            } else {
                (v5, (integer_mate::full_math_u64::mul_div_ceil(
                    (v5 as u64),
                    arg4,
                    clmm_pool::clmm_math::fee_rate_denominator() - arg4
                ) as u256), arg1)
            };
            (v6, clmm_pool::clmm_math::get_delta_down_from_output(arg0, v8, arg2, arg5), v7, v8)
        } else {
            let v9 = clmm_pool::clmm_math::get_delta_down_from_output(arg0, arg1, arg2, arg5);
            let (v10, v11) = if (v9 > (arg3 as u256)) {
                ((arg3 as u256), clmm_pool::clmm_math::get_next_sqrt_price_from_output(arg0, arg2, arg3, arg5))
            } else {
                (v9, arg1)
            };
            let v12 = clmm_pool::clmm_math::get_delta_up_from_input(arg0, v11, arg2, arg5);
            (v12, v10, (integer_mate::full_math_u128::mul_div_ceil(
                (v12 as u128),
                (arg4 as u128),
                ((clmm_pool::clmm_math::fee_rate_denominator() - arg4) as u128)
            ) as u256), v11)
        };
        (v0, v1, v3, v2)
    }

    fun default_swap_result(): SwapResult {
        SwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            ref_fee_amount: 0,
            steps: 0,
        }
    }

    public fun expect_swap_result_after_sqrt_price(arg0: &ExpectSwapResult): u128 {
        arg0.after_sqrt_price
    }

    public fun expect_swap_result_amount_in(arg0: &ExpectSwapResult): u256 {
        arg0.amount_in
    }

    public fun expect_swap_result_amount_out(arg0: &ExpectSwapResult): u256 {
        arg0.amount_out
    }

    public fun expect_swap_result_fee_amount(arg0: &ExpectSwapResult): u256 {
        arg0.fee_amount
    }

    public fun expect_swap_result_is_exceed(arg0: &ExpectSwapResult): bool {
        arg0.is_exceed
    }

    public fun expect_swap_result_step_results(arg0: &ExpectSwapResult): &vector<SwapStepResult> {
        &arg0.step_results
    }

    public fun expect_swap_result_step_swap_result(arg0: &ExpectSwapResult, arg1: u64): &SwapStepResult {
        arg0.step_results.borrow(arg1)
    }

    public fun expect_swap_result_steps_length(arg0: &ExpectSwapResult): u64 {
        arg0.step_results.length()
    }

    public entry fun get_expect_swap_result<T0, T1>(
        arg0: &clmm_pool::pool::Pool<T0, T1>,
        arg1: bool,
        arg2: bool,
        arg3: u64
    ) {
        let v0 = ExpectSwapResultEvent {
            data: expect_swap<T0, T1>(arg0, arg1, arg2, arg3),
            current_sqrt_price: arg0.current_sqrt_price(),
        };
        sui::event::emit<ExpectSwapResultEvent>(v0);
    }

    public fun step_swap_result_amount_in(arg0: &SwapStepResult): u256 {
        arg0.amount_in
    }

    public fun step_swap_result_amount_out(arg0: &SwapStepResult): u256 {
        arg0.amount_out
    }

    public fun step_swap_result_current_liquidity(arg0: &SwapStepResult): u128 {
        arg0.current_liquidity
    }

    public fun step_swap_result_current_sqrt_price(arg0: &SwapStepResult): u128 {
        arg0.current_sqrt_price
    }

    public fun step_swap_result_fee_amount(arg0: &SwapStepResult): u256 {
        arg0.fee_amount
    }

    public fun step_swap_result_remainder_amount(arg0: &SwapStepResult): u64 {
        arg0.remainder_amount
    }

    public fun step_swap_result_target_sqrt_price(arg0: &SwapStepResult): u128 {
        arg0.target_sqrt_price
    }

    fun update_swap_result(arg0: &mut SwapResult, arg1: u256, arg2: u256, arg3: u256) {
        assert!(integer_mate::math_u256::add_check(arg0.amount_in, arg1), 0);
        assert!(integer_mate::math_u256::add_check(arg0.amount_out, arg2), 1);
        assert!(integer_mate::math_u256::add_check(arg0.fee_amount, arg3), 2);
        arg0.amount_in = arg0.amount_in + arg1;
        arg0.amount_out = arg0.amount_out + arg2;
        arg0.fee_amount = arg0.fee_amount + arg3;
        arg0.steps = arg0.steps + 1;
    }

    // decompiled from Move bytecode v6
}


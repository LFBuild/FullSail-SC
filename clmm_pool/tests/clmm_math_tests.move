#[test_only]
module clmm_pool::clmm_math_tests {
    use clmm_pool::clmm_math;

    #[test]
    fun test_compute_swap_step_zero_liquidity() {
        let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
            100000, // current_sqrt_price
            90000,  // target_sqrt_price
            0,      // liquidity
            1000,   // amount
            3000,   // fee_rate (0.3%)
            true,   // a2b
            true    // by_amount_in
        );
        assert!(amount_in == 0, 1);
        assert!(amount_out == 0, 2);
        assert!(next_sqrt_price == 90000, 3);
        assert!(fee_amount == 0, 4);
    }

    // #[test]
    // fun test_compute_swap_step_a2b_by_amount_in() {
    //     let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         99900,  // target_sqrt_price (smaller difference)
    //         10000000, // liquidity (increased)
    //         100,    // amount (reduced)
    //         3000,   // fee_rate (0.3%)
    //         true,   // a2b
    //         true    // by_amount_in
    //     );
    //     assert!(amount_in == 99, 1); // 100 - 0.3% fee
    //     assert!(amount_out > 0, 2);
    //     assert!(next_sqrt_price < 100000, 3); // Price should decrease for a2b
    //     assert!(fee_amount == 1, 4); // 0.3% of 100
    // }

    // #[test]
    // fun test_compute_swap_step_b2a_by_amount_in() {
    //     let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         105000, // target_sqrt_price
    //         100,    // liquidity
    //         100,    // amount
    //         3000,   // fee_rate (0.3%)
    //         false,  // b2a
    //         true    // by_amount_in
    //     );
    //     assert!(amount_in == 99, 1); // 100 - 0.3% fee
    //     assert!(amount_out > 0, 2);
    //     assert!(next_sqrt_price > 100000, 3); // Price should increase for b2a
    //     assert!(fee_amount == 1, 4); // 0.3% of 100
    // }

    // #[test]
    // fun test_compute_swap_step_a2b_by_amount_out() {
    //     let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         95000,  // target_sqrt_price
    //         100,    // liquidity
    //         100,    // amount
    //         3000,   // fee_rate (0.3%)
    //         true,   // a2b
    //         false   // by_amount_out
    //     );
    //     assert!(amount_out == 100, 1);
    //     assert!(amount_in > 100, 2); // Should be more due to fee
    //     assert!(next_sqrt_price < 100000, 3);
    //     assert!(fee_amount > 0, 4);
    // }

    // #[test]
    // fun test_compute_swap_step_b2a_by_amount_out() {
    //     let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         105000, // target_sqrt_price
    //         100,    // liquidity
    //         100,    // amount
    //         3000,   // fee_rate (0.3%)
    //         false,  // b2a
    //         false   // by_amount_out
    //     );
    //     assert!(amount_out == 100, 1);
    //     assert!(amount_in > 100, 2); // Should be more due to fee
    //     assert!(next_sqrt_price > 100000, 3);
    //     assert!(fee_amount > 0, 4);
    // }

    // #[test]
    // fun test_compute_swap_step_zero_fee() {
    //     let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         95000,  // target_sqrt_price
    //         100,    // liquidity
    //         100,    // amount
    //         0,      // fee_rate (0%)
    //         true,   // a2b
    //         true    // by_amount_in
    //     );
    //     assert!(amount_in == 100, 1); // No fee deduction
    //     assert!(amount_out > 0, 2);
    //     assert!(next_sqrt_price < 100000, 3);
    //     assert!(fee_amount == 0, 4);
    // }

    // #[test]
    // #[expected_failure(abort_code = 4)]
    // fun test_compute_swap_step_invalid_price_a2b() {
    //     clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         105000, // target_sqrt_price (higher than current for a2b)
    //         100,    // liquidity
    //         100,    // amount
    //         3000,   // fee_rate
    //         true,   // a2b
    //         true    // by_amount_in
    //     );
    // }

    // #[test]
    // #[expected_failure(abort_code = 4)]
    // fun test_compute_swap_step_invalid_price_b2a() {
    //     clmm_math::compute_swap_step(
    //         100000, // current_sqrt_price
    //         95000,  // target_sqrt_price (lower than current for b2a)
    //         100,    // liquidity
    //         100,    // amount
    //         3000,   // fee_rate
    //         false,  // b2a
    //         true    // by_amount_in
    //     );
    // }
}

module clmm_pool::clmm_math {
    public fun compute_swap_step(
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        liquidity: u128,
        amount: u64,
        fee_rate: u64,
        a2b: bool,
        by_amount_in: bool
    ): (u64, u64, u128, u64) {
        if (liquidity == 0) {
            return (0, 0, target_sqrt_price, 0)
        };
        if (a2b) {
            assert!(current_sqrt_price >= target_sqrt_price, 4);
        } else {
            assert!(current_sqrt_price < target_sqrt_price, 4);
        };
        let (fee_amount, next_sqrt_price, amount_in, amount_out) = if (by_amount_in) {
            let amount_after_fee = integer_mate::full_math_u64::mul_div_floor(amount, 1000000 - fee_rate, 1000000);
            let mut adjusted_amount = amount_after_fee;
            if (fee_rate > 0 && amount_after_fee == amount) {
                adjusted_amount = amount_after_fee - 1;
            };
            let delta_up = get_delta_up_from_input(current_sqrt_price, target_sqrt_price, liquidity, a2b);
            let (final_amount_in, final_fee_amount, final_sqrt_price) = if (delta_up > (adjusted_amount as u256)) {
                (adjusted_amount, amount - adjusted_amount, get_next_sqrt_price_from_input(current_sqrt_price, liquidity, adjusted_amount, a2b))
            } else {
                (delta_up as u64, integer_mate::full_math_u64::mul_div_ceil(delta_up as u64, fee_rate, 1000000 - fee_rate), target_sqrt_price)
            };
            (final_fee_amount, final_sqrt_price, final_amount_in, get_delta_down_from_output(current_sqrt_price, final_sqrt_price, liquidity, a2b) as u64)
        } else {
            let delta_down = get_delta_down_from_output(current_sqrt_price, target_sqrt_price, liquidity, a2b);
            let (final_amount_out, final_sqrt_price) = if (delta_down > (amount as u256)) {
                (amount, get_next_sqrt_price_from_output(current_sqrt_price, liquidity, amount, a2b))
            } else {
                (delta_down as u64, target_sqrt_price)
            };
            let amount_in = get_delta_up_from_input(current_sqrt_price, final_sqrt_price, liquidity, a2b) as u64;
            let calculated_fee = integer_mate::full_math_u64::mul_div_ceil(amount_in, fee_rate, 1000000 - fee_rate);
            let mut final_fee = calculated_fee;
            if (fee_rate > 0 && calculated_fee == 0) {
                final_fee = 1;
            };
            (final_fee, final_sqrt_price, amount_in, final_amount_out)
        };
        (amount_in, amount_out, next_sqrt_price, fee_amount)
    }

    public fun fee_rate_denominator(): u64 {
        1000000
    }

    public fun get_amount_by_liquidity(
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32, 
        current_tick: integer_mate::i32::I32,
        current_sqrt_price: u128,
        liquidity: u128,
        round_up: bool
    ): (u64, u64) {
        if (liquidity == 0) {
            return (0, 0)
        };
        if (integer_mate::i32::lt(current_tick, tick_lower)) {
            (get_delta_a(
                clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                liquidity,
                round_up
            ), 0)
        } else {
            let (amount_a, amount_b) = if (integer_mate::i32::lt(current_tick, tick_upper)) {
                (get_delta_a(current_sqrt_price, clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), liquidity, round_up), 
                 get_delta_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    current_sqrt_price,
                    liquidity,
                    round_up
                ))
            } else {
                (0, get_delta_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    liquidity,
                    round_up
                ))
            };
            (amount_a, amount_b)
        }
    }

    public fun get_delta_a(sqrt_price_a: u128, sqrt_price_b: u128, liquidity: u128, round_up: bool): u64 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        let (shifted_product, overflow) = integer_mate::math_u256::checked_shlw(integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff));
        if (overflow) {
            abort 2
        };
        integer_mate::math_u256::div_round(shifted_product, integer_mate::full_math_u128::full_mul(sqrt_price_a, sqrt_price_b), round_up) as u64
    }

    public fun get_delta_b(sqrt_price_a: u128, sqrt_price_b: u128, liquidity: u128, round_up: bool): u64 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        let product = integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff);
        if (round_up && product & 18446744073709551615 > 0) {
            return ((product >> 64) + 1) as u64
        };
        (product >> 64) as u64
    }

    public fun get_delta_down_from_output(sqrt_price_a: u128, sqrt_price_b: u128, liquidity: u128, round_up: bool): u256 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        if (round_up) {
            integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff) >> 64
        } else {
            let (shifted_product, overflow) = integer_mate::math_u256::checked_shlw(integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff));
            if (overflow) {
                abort 2
            };
            integer_mate::math_u256::div_round(shifted_product, integer_mate::full_math_u128::full_mul(sqrt_price_a, sqrt_price_b), false)
        }
    }

    public fun get_delta_up_from_input(sqrt_price_a: u128, sqrt_price_b: u128, liquidity: u128, round_up: bool): u256 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        if (round_up) {
            let (shifted_product, overflow) = integer_mate::math_u256::checked_shlw(integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff));
            if (overflow) {
                abort 2
            };
            integer_mate::math_u256::div_round(shifted_product, integer_mate::full_math_u128::full_mul(sqrt_price_a, sqrt_price_b), true)
        } else {
            let product = integer_mate::full_math_u128::full_mul(liquidity, sqrt_price_diff);
            let result = if (product & 18446744073709551615 > 0) {
                (product >> 64) + 1
            } else {
                product >> 64
            };
            result
        }
    }

    public fun get_liquidity_by_amount(
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        current_tick: integer_mate::i32::I32,
        current_sqrt_price: u128,
        amount_in: u64,
        is_fix_amount_a: bool
    ): (u128, u64, u64) {
        if (is_fix_amount_a) {
            let (liquidity, amount_b) = if (integer_mate::i32::lt(current_tick, tick_lower)) {
                (get_liquidity_from_a(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    amount_in,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::lt(current_tick, tick_upper), 3018);
                let liquidity = get_liquidity_from_a(current_sqrt_price, clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), amount_in, false);
                (liquidity, get_delta_b(current_sqrt_price, clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower), liquidity, true))
            };
            (liquidity, amount_in, amount_b)
        } else {
            let (liquidity, amount_a) = if (integer_mate::i32::gte(current_tick, tick_upper)) {
                (get_liquidity_from_b(
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower),
                    clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper),
                    amount_in,
                    false
                ), 0)
            } else {
                assert!(integer_mate::i32::gte(current_tick, tick_lower), 3018);
                let liquidity = get_liquidity_from_b(clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower), current_sqrt_price, amount_in, false);
                (liquidity, get_delta_a(current_sqrt_price, clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper), liquidity, true))
            };
            (liquidity, amount_a, amount_in)
        }
    }
    
    public fun get_liquidity_from_a(
        sqrt_price_a: u128,
        sqrt_price_b: u128,
        amount: u64,
        round_up: bool
    ): u128 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        integer_mate::math_u256::div_round(
            (integer_mate::full_math_u128::full_mul(sqrt_price_a, sqrt_price_b) >> 64) * (amount as u256),
            sqrt_price_diff as u256,
            round_up
        ) as u128
    }

    public fun get_liquidity_from_b(sqrt_price_a: u128, sqrt_price_b: u128, amount: u64, round_up: bool): u128 {
        let sqrt_price_diff = if (sqrt_price_a > sqrt_price_b) {
            sqrt_price_a - sqrt_price_b
        } else {
            sqrt_price_b - sqrt_price_a
        };
        integer_mate::math_u256::div_round((amount as u256) << 64, sqrt_price_diff as u256, round_up) as u128
    }
    public fun get_next_sqrt_price_a_up(sqrt_price: u128, liquidity: u128, amount: u64, add: bool): u128 {
        if (amount == 0) {
            return sqrt_price
        };
        let (product, overflow) = integer_mate::math_u256::checked_shlw(integer_mate::full_math_u128::full_mul(sqrt_price, liquidity));
        if (overflow) {
            abort 2
        };
        let next_sqrt_price = if (add) {
            integer_mate::math_u256::div_round(
                product,
                ((liquidity as u256) << 64) + integer_mate::full_math_u128::full_mul(sqrt_price, amount as u128),
                true
            ) as u128
        } else {
            integer_mate::math_u256::div_round(
                product,
                ((liquidity as u256) << 64) - integer_mate::full_math_u128::full_mul(sqrt_price, amount as u128),
                true
            ) as u128
        };
        if (next_sqrt_price > clmm_pool::tick_math::max_sqrt_price()) {
            abort 0
        };
        if (next_sqrt_price < clmm_pool::tick_math::min_sqrt_price()) {
            abort 1
        };
        next_sqrt_price
    }
    public fun get_next_sqrt_price_b_down(sqrt_price: u128, liquidity: u128, amount: u64, add: bool): u128 {
        let next_sqrt_price = if (add) {
            sqrt_price + integer_mate::math_u128::checked_div_round((amount as u128) << 64, liquidity, !add)
        } else {
            sqrt_price - integer_mate::math_u128::checked_div_round((amount as u128) << 64, liquidity, !add)
        };
        if (next_sqrt_price > clmm_pool::tick_math::max_sqrt_price()) {
            abort 0
        };
        if (next_sqrt_price < clmm_pool::tick_math::min_sqrt_price()) {
            abort 1
        };
        next_sqrt_price
    }
    public fun get_next_sqrt_price_from_input(sqrt_price: u128, liquidity: u128, amount: u64, is_token_a: bool): u128 {
        if (is_token_a) {
            get_next_sqrt_price_a_up(sqrt_price, liquidity, amount, true)
        } else {
            get_next_sqrt_price_b_down(sqrt_price, liquidity, amount, true)
        }
    }

    public fun get_next_sqrt_price_from_output(sqrt_price: u128, liquidity: u128, amount: u64, is_token_a: bool): u128 {
        if (is_token_a) {
            get_next_sqrt_price_b_down(sqrt_price, liquidity, amount, false)
        } else {
            get_next_sqrt_price_a_up(sqrt_price, liquidity, amount, false)
        }
    }

    // decompiled from Move bytecode v6
}


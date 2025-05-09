module liquidity_locker::locker_utils {

    const EOverflow: u64 = 9877453648562383;
    const EZeroPrice: u64 = 9375892909283584;

    public fun calculate_position_liquidity_in_token_a<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 { // Q64.64
        // Get current price
        let sqrt_price = pool.current_sqrt_price();
        let price = integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price); // Q128.128
        assert!(price > 0, EZeroPrice);

        // Get position balances
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        // Convert balance_b to tokenA equivalent
        let amount_b_in_a = ((((amount_b as u256) << 64) << 64) << 64) / price; // Q64.64

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_a as u128) << 64, amount_b_in_a as u128);
        assert!(!overflow, EOverflow);

        // Total liquidity in tokenA
        result
    }

    public fun calculate_position_liquidity_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 { // Q64.64
        // Get current price
        let sqrt_price = pool.current_sqrt_price();
        let price = integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price); // Q128.128
        assert!(price > 0, EZeroPrice);

        // Get position balances
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        let amount_a_in_b = ((amount_a as u256) * price) >> 64; // Q64.64

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_b as u128) << 64, amount_a_in_b as u128);
        assert!(!overflow, EOverflow);

        // Total liquidity in tokenB
        result
    }

    public fun calculate_token_a_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        amount_a: u64
    ): u64 {
        // Get current price
        let sqrt_price = pool.current_sqrt_price();
        let price = integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price); // Q128.128
        assert!(price > 0, EZeroPrice);

        ((((amount_a as u256) * price) >> 64) >> 64) as u64
    }
}
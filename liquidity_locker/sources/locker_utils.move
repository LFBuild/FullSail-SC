module liquidity_locker::locker_utils {

    const EOverflow: u64 = 98774536485623832;
    const EZeroPrice: u64 = 9375892909283584;

    public fun calculate_position_liquidity_in_token_a<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 {
        // Получаем текущую цену
        let sqrt_price = pool.current_sqrt_price();
        let (price, overflow) = integer_mate::math_u128::overflowing_mul(sqrt_price, sqrt_price);
        assert!(!overflow, EOverflow);
        assert!(price > 0, EZeroPrice);

        // Получаем балансы позиции
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        // Конвертируем balance_b в эквивалент tokenA
        let amount_b_in_a = integer_mate::math_u128::checked_div_round((amount_b as u128) << 64, price, false);

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_a as u128) << 64, amount_b_in_a);
        assert!(!overflow, EOverflow);

        // Общая ликвидность в tokenA
       result
    }

    public fun calculate_position_liquidity_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 {
        // Получаем текущую цену
       let sqrt_price = pool.current_sqrt_price();
        let (price, overflow) = integer_mate::math_u128::overflowing_mul(sqrt_price, sqrt_price);
        assert!(!overflow, EOverflow);
        assert!(price > 0, EZeroPrice);

        // Получаем балансы позиции
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        let (amount_a_in_b, overflow) = integer_mate::math_u128::overflowing_mul((amount_a as u128) << 64, price);
        assert!(!overflow, EOverflow);

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_b as u128) << 64, amount_a_in_b);
        assert!(!overflow, EOverflow);

        // Общая ликвидность в tokenB
       result
    }
}
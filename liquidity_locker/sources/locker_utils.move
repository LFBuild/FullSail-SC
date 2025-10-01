/// Utility Module for Liquidity Locker
/// 
/// This module provides utility functions for calculating liquidity values and token conversions
/// in the liquidity locker system. It handles complex mathematical operations required for
/// position management and liquidity calculations.
/// 
/// Key features:
/// * Calculate total position liquidity in terms of token A
/// * Calculate total position liquidity in terms of token B
/// * Convert token A amounts to token B equivalent values
/// 
/// The module uses fixed-point arithmetic (Q64.64 format) for precise calculations and
/// implements overflow checks to ensure mathematical operations remain safe.
/// 
/// # Security
/// The module implements various safety checks:
/// * Prevents division by zero in price calculations
/// * Guards against arithmetic overflow in liquidity calculations
/// * Validates price values before calculations
module liquidity_locker::locker_utils {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const EOverflow: u64 = 9877453648562383;
    const EZeroPrice: u64 = 9375892909283584;

    /// Calculates the total liquidity of a position in terms of token A.
    /// This function converts both token A and token B balances to their equivalent value in token A.
    /// 
    /// # Arguments
    /// * `pool` - The CLMM pool containing the position
    /// * `position_id` - ID of the position to calculate liquidity for
    /// 
    /// # Returns
    /// Total position liquidity in token A (Q64.64 fixed-point format)
    /// 
    /// # Aborts
    /// * If price is zero
    /// * If addition operation overflows
    public fun calculate_position_liquidity_in_token_a<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 { 
        // Get current price
        let sqrt_price = pool.current_sqrt_price();
        let price = integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price); // Q128.128
        assert!(price > 0, EZeroPrice);

        // Get position balances
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        // Convert balance_b to tokenA equivalent
        let amount_b_in_a = ((amount_b as u256) << 192) / price; // Q64.64

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_a as u128) << 64, amount_b_in_a as u128);
        assert!(!overflow, EOverflow);

        // Total liquidity in tokenA
        result
    }

    /// Calculates the total liquidity of a position in terms of token B.
    /// This function converts both token A and token B balances to their equivalent value in token B.
    /// 
    /// # Arguments
    /// * `pool` - The CLMM pool containing the position
    /// * `position_id` - ID of the position to calculate liquidity for
    /// 
    /// # Returns
    /// Total position liquidity in token B (Q64.64 fixed-point format)
    /// 
    /// # Aborts
    /// * If price is zero
    /// * If addition operation overflows
    public fun calculate_position_liquidity_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 { 
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

    /// Calculates the equivalent amount of token B for a given amount of token A
    /// based on the current pool price.
    /// 
    /// # Arguments
    /// * `pool` - The CLMM pool containing the tokens
    /// * `amount_a` - Amount of token A to convert
    /// 
    /// # Returns
    /// Equivalent amount of token B
    /// 
    /// # Aborts
    /// * If current price is zero
    public fun calculate_token_a_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        amount_a: u64
    ): u64 {
        // Get current price
        let sqrt_price = pool.current_sqrt_price();
        let price = integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price); // Q128.128
        assert!(price > 0, EZeroPrice);

        (((amount_a as u256) * price) >> 128) as u64
    }
}
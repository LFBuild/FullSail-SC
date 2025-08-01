/// Constants Module
/// 
/// This module defines various constants used throughout the liquidity locker system.
/// It provides functions to access important numerical values that define the behavior
/// and limits of the protocol.
/// 
/// Key constants include:
/// * Maximum profitability rate for positions
/// * Denominator values for calculating liquidity shares and profitability rates
/// * Minimum volume thresholds denominator
/// 
/// These constants are used to ensure consistent calculations and enforce protocol limits
/// across different operations in the liquidity locker system.
module liquidity_locker::consts {
    
    /// Returns the maximum allowed profitability rate (50% or 0.5)
    public fun max_profitability_rate(): u64 {
        5000
    }

    /// Returns the denominator used for calculating liquidity shares
    /// 100000 represents 100% or 1.0
    public fun lock_liquidity_share_denom(): u64 {
        100000
    }

    /// Returns the denominator used for calculating profitability rates
    /// 10000 represents 100% or 1.0
    public fun profitability_rate_denom(): u64 {
        10000
    }

    /// Returns the denominator used for calculating minimum remaining volume percentage
    /// 10000 represents 100% or 1.0
    public fun minimum_remaining_volume_percentage_denom(): u64 {
        10000
    }
}
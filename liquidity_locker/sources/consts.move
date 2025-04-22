module liquidity_locker::consts {
    public fun max_profitability_rate(): u64 {
        5000
    }

    public fun lock_liquidity_share_denom(): u64 {
        10000
    }

    public fun profitability_rate_denom(): u64 {
        10000
    }
}
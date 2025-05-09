module liquidity_locker::consts {
    public fun max_profitability_rate(): u64 {
        5000
    }

    // множитель долей, то есть 10000 = 100% или 1
    public fun lock_liquidity_share_denom(): u64 {
        100000
    }

    // множитель долей, то есть 10000 = 100% или 1
    public fun profitability_rate_denom(): u64 {
        10000
    }

    public fun minimum_remaining_volume_denom(): u64 {
        10000
    }
}
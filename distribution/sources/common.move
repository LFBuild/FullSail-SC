module distribution::common {

    const MAX_DISCOUNT: u64 = 100000000;

    const MIN_DISCOUNT: u64 = MAX_DISCOUNT / 2;

    const PERCENT_DECIMALS: u8 = 6;

    const PERCENT_DENOMINATOR: u64 = 100000000;

    /// Returns the current period based on the system time
    public fun current_period(clock: &sui::clock::Clock): u64 {
        to_period(current_timestamp(clock))
    }

    /// Converts the system time from milliseconds to seconds
    public fun current_timestamp(clock: &sui::clock::Clock): u64 {
        clock.timestamp_ms() / 1000
    }

    /// Returns the number of seconds in a day
    public fun day(): u64 {
        86400
    }

    /// Calculates the start timestamp of the next epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    public fun epoch_next(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 604800
    }

    /// Calculates the start timestamp of the current epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    public fun epoch_start(timestamp: u64): u64 {
        timestamp - timestamp % 604800
    }

    /// Calculates the end timestamp of the voting period in the current epoch
    /// Voting ends 1 hour before the end of the epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    public fun epoch_vote_end(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 604800 - 3600
    }

    /// Calculates the start timestamp of the voting period in the current epoch
    /// Voting starts 1 hour after the beginning of the epoch
    public fun epoch_vote_start(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 3600
    }

    /// Returns the time required for transaction finality
    public fun get_time_to_finality(): u64 {
        500
    }

    /// Returns the number of seconds in an hour
    public fun hour(): u64 {
        3600
    }

    /// Returns the maximum allowed lock time for token locking
    public fun max_lock_time(): u64 {
        125798400
    }

    /// Returns the minimum allowed lock time for token locking
    public fun min_lock_time(): u64 {
        604800
    }

    /// Converts a timestamp to its corresponding period by rounding down to the start of the week
    ///
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    public fun to_period(timestamp: u64): u64 {
        timestamp / 604800 * 604800
    }

    /// Returns the number of seconds in a week
    public fun week(): u64 {
        604800
    }

    public fun min_o_sail_discount(): u64 {
        return MIN_DISCOUNT
    }

    /// Maximum discount which OCoin provides
    public fun max_o_sail_discount(): u64 {
        return MAX_DISCOUNT
    }

    /// Decimals 6,  1% = 1_000_000
    public fun percent_decimals(): u8 {
        return PERCENT_DECIMALS
    }

    /// If you want to calculate 1% of X, multiply X by percent value and divide by persent_denominator
    public fun persent_denominator(): u64 {
        return PERCENT_DENOMINATOR
    }
}


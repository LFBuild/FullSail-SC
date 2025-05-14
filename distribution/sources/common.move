module distribution::common {
    // TODO: replace with actual week before deployment
    const WEEK: u64 = 7 * 86400;
    const DAY: u64 = 86400;
    const HOUR: u64 = 3600;

    /// Returns the current period based on the system time
    /// 
    /// # Arguments
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The current period timestamp (rounded down to the start of the week)
    public fun current_period(clock: &sui::clock::Clock): u64 {
        to_period(current_timestamp(clock))
    }

    /// Converts the system time from milliseconds to seconds
    /// 
    /// # Arguments
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The current time in seconds
    public fun current_timestamp(clock: &sui::clock::Clock): u64 {
        clock.timestamp_ms() / 1000
    }

    /// Returns the number of seconds in a day
    /// 
    /// # Returns
    /// The number of seconds in a day (86400)
    public fun day(): u64 {
        DAY
    }

    /// Calculates the start timestamp of the next epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the next epoch
    public fun epoch_next(timestamp: u64): u64 {
        timestamp - timestamp % WEEK + WEEK
    }

    /// Calculates the start timestamp of the current epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the current epoch
    public fun epoch_start(timestamp: u64): u64 {
        timestamp - timestamp % WEEK
    }

    /// Calculates the end timestamp of the voting period in the current epoch
    /// Voting ends 1 hour before the end of the epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp when voting ends in the current epoch
    public fun epoch_vote_end(timestamp: u64): u64 {
        timestamp - timestamp % WEEK + WEEK - HOUR
    }

    /// Calculates the start timestamp of the voting period in the current epoch
    /// Voting starts 1 hour after the beginning of the epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp when voting starts in the current epoch
    public fun epoch_vote_start(timestamp: u64): u64 {
        timestamp - timestamp % WEEK + HOUR
    }

    /// Returns the time required for transaction finality
    /// 
    /// # Returns
    /// The time in seconds required for transaction finality (500)
    public fun get_time_to_finality(): u64 {
        500
    }

    /// Returns the number of seconds in an hour
    /// 
    /// # Returns
    /// The number of seconds in an hour (3600)
    public fun hour(): u64 {
        HOUR
    }

    /// Returns the maximum allowed lock time for token locking
    /// 
    /// # Returns
    /// The maximum lock time in seconds (125798400 - approximately 4 years)
    public fun max_lock_time(): u64 {
        125798400
    }

    /// Returns the minimum allowed lock time for token locking
    /// 
    /// # Returns
    /// The minimum lock time in seconds (604800 - 1 week)
    public fun min_lock_time(): u64 {
        WEEK
    }

    /// Converts a timestamp to its corresponding period by rounding down to the start of the week
    /// 
    /// # Arguments
    /// * `timestamp` - The timestamp in seconds to convert
    /// 
    /// # Returns
    /// The timestamp of the start of the week containing the input timestamp
    public fun to_period(timestamp: u64): u64 {
        timestamp / WEEK * WEEK
    }

    /// Returns the number of seconds in a week
    /// 
    /// # Returns
    /// The number of seconds in a week (604800)
    public fun week(): u64 {
        WEEK
    }
}


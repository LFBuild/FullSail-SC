module liquidity_locker::time_manager {
    const HOUR: u64 = 3600;
    const DAY: u64 = 24 * HOUR;
    const WEEK: u64 = 7 * DAY;
    const EPOCH_DURATION: u64 = DAY / 4;

    /// Returns the current period based on the system time
    /// 
    /// # Arguments
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The current period timestamp (rounded down to the start of the epoch)
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

    /// Calculates the start timestamp of the next epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the next epoch
    public fun epoch_next(timestamp: u64): u64 {
        timestamp - (timestamp % EPOCH_DURATION) + EPOCH_DURATION
    }

    /// Calculates the start timestamp of the previous epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the previous epoch
    public fun epoch_prev(timestamp: u64): u64 {
        timestamp - (timestamp % EPOCH_DURATION) - EPOCH_DURATION
    }
    /// Calculates the start timestamp of the current epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the current epoch
    public fun epoch_start(timestamp: u64): u64 {
        timestamp - (timestamp % EPOCH_DURATION)
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
        timestamp - (timestamp % EPOCH_DURATION) + EPOCH_DURATION - HOUR
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
        timestamp - timestamp % EPOCH_DURATION + HOUR
    }

    /// Returns the time required for transaction finality
    /// 
    /// # Returns
    /// The time in milliseconds required for transaction finality (500)
    public fun get_time_to_finality_ms(): u64 {
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
    /// The minimum lock time in seconds
    public fun min_lock_time(): u64 {
        EPOCH_DURATION
    }

    /// Converts a timestamp to its corresponding period by rounding down to the start of the epoch
    /// 
    /// # Arguments
    /// * `timestamp` - The timestamp in seconds to convert
    /// 
    /// # Returns
    /// The timestamp of the start of the epoch containing the input timestamp
    public fun to_period(timestamp: u64): u64 {
        timestamp / EPOCH_DURATION * EPOCH_DURATION
    }

    /// Returns the number of seconds in a week
    /// 
    /// # Returns
    /// The number of seconds in a week (604800)
    public fun week(): u64 {
        WEEK
    }

    /// Returns the number of seconds in an epoch
    /// 
    /// # Returns
    /// The number of seconds in an epoch
    public fun epoch(): u64 {
        EPOCH_DURATION
    }

    /// Converts an epoch to seconds
    /// 
    /// # Arguments
    /// * `epoch` - The epoch to convert
    /// 
    /// # Returns
    /// The epoch in seconds
    public fun epoch_to_seconds(epoch: u64): u64 {
        epoch * EPOCH_DURATION
    }

    /// Returns the number of complete epochs contained in the timestamp
    /// 
    /// # Arguments
    /// * `timestamp` - The timestamp in seconds
    /// 
    /// # Returns
    /// The number of complete epochs contained in the timestamp
    public fun number_epochs_in_timestamp(timestamp: u64): u64 {
        timestamp / EPOCH_DURATION
    }
}


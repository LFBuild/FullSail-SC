module distribution::common {

    use switchboard::decimal::{Self, Decimal};
    use switchboard::aggregator::{Self, Aggregator};

    const EDecimalToQ64NegativeNotSupported: u64 = 440708559177319000;
    const EGetTimeCheckedPriceOutdated: u64 = 286529906002696900;
    const EGetTimeCheckedPriceNegativePrice: u64 = 986261309772136700;

    const HOUR: u64 = 3600;
    const DAY: u64 = 24 * HOUR;
    const WEEK: u64 = 7 * DAY;

    // OSail params
    const MAX_DISCOUNT: u64 = 100000000;
    const MIN_DISCOUNT: u64 = MAX_DISCOUNT / 2;
    const PERCENT_DENOMINATOR: u64 = 100000000;

    const MAX_PRICE_AGE_MS: u64 = 1 * 60 * 1000; // 1 minute

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
        timestamp - (timestamp % WEEK) + WEEK
    }

    /// Calculates the start timestamp of the previous epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the previous epoch
    public fun epoch_prev(timestamp: u64): u64 {
        timestamp - (timestamp % WEEK) - WEEK
    }
    /// Calculates the start timestamp of the current epoch (week)
    /// 
    /// # Arguments
    /// * `timestamp` - The current timestamp in seconds
    /// 
    /// # Returns
    /// The timestamp of the start of the current epoch
    public fun epoch_start(timestamp: u64): u64 {
        timestamp - (timestamp % WEEK)
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
        epoch_next(timestamp) - HOUR
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
        epoch_start(timestamp) + HOUR
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

    /// The oSAIL option token should be exercisable for this number of seconds
    /// after it is distributed.
    public fun o_sail_duration(): u64 {
        WEEK * 4
    }

    /// Discount that oSAIL grants. Currently it's the only option,
    /// but there is a possibility that different percents will be implemented.
    public fun o_sail_discount(): u64 {
        return MIN_DISCOUNT
    }

    /// If you want to calculate 1% of X, multiply X by percent value and divide by persent_denominator
    public fun persent_denominator(): u64 {
        return PERCENT_DENOMINATOR
    }

    /// Converts an epoch to seconds
    /// 
    /// # Arguments
    /// * `epoch` - The epoch to convert
    /// 
    /// # Returns
    /// The epoch in seconds
    public fun epoch_to_seconds(epoch: u64): u64 {
        epoch * WEEK
    }

    /// Returns the number of complete epochs contained in the timestamp
    /// 
    /// # Arguments
    /// * `timestamp` - The timestamp in seconds
    /// 
    /// # Returns
    /// The number of complete epochs contained in the timestamp
    public fun number_epochs_in_timestamp(timestamp: u64): u64 {
        timestamp / WEEK
    }


    public fun decimal_to_q64(
        decimal: &Decimal,
    ): u128 {
        assert!(!decimal.neg(), EDecimalToQ64NegativeNotSupported);

        let dec = decimal.dec();
        let dec_multiplier = decimal::pow_10(dec);

        integer_mate::full_math_u128::mul_div_floor(
            decimal.value(),
            1 << 64,
            dec_multiplier
        )
    }

    /// Utility function to convert USD amount * 2^64 to asset amount * 2^64
    public fun usd_q64_to_asset_q64(
        usd_amount_q64: u128,
        asset_price_q64: u128,
    ): u128 {
        integer_mate::full_math_u128::mul_div_floor(
            usd_amount_q64,
            1 << 64,
            asset_price_q64
        )
    }

    /// Utility function to get the current price of an asset from a switchboard aggregator
    /// Asserts that the price is not too old and returns the price
    /// 
    /// # Arguments
    /// * `aggregator` - The switchboard aggregator to get the price from
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The price in Q64.64 format, i.e USD/asset * 2^64
    public fun get_time_checked_price_q64(
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
    ): u128 {
        let price_result = aggregator.current_result();
        let current_time = clock.timestamp_ms();
        let price_result_time = price_result.timestamp_ms();

        assert!(price_result_time > current_time - MAX_PRICE_AGE_MS, EGetTimeCheckedPriceOutdated);

        let price_result_price = price_result.result();
        assert!(!price_result_price.neg(), EGetTimeCheckedPriceNegativePrice);

        decimal_to_q64(price_result_price)
    }
}


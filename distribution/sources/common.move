module distribution::common {

    use switchboard::decimal::{Self, Decimal};
    use switchboard::aggregator::{Self, Aggregator};

    const EDecimalToQ64NegativeNotSupported: u64 = 440708559177319000;
    const EGetTimeCheckedPriceOutdated: u64 = 286529906002696900;
    const EGetTimeCheckedPriceNegativePrice: u64 = 986261309772136700;

    const HOUR: u64 = 3600;
    const DAY: u64 = 24 * HOUR;
    const WEEK: u64 = 7 * DAY;
    const EPOCH_DURATION: u64 = DAY / 2;

    // OSail params
    const MAX_DISCOUNT: u64 = 100000000;
    const MIN_DISCOUNT: u64 = MAX_DISCOUNT / 2;
    const PERCENT_DENOMINATOR: u64 = 100000000;

    const MAX_PRICE_AGE_MS: u64 = 1 * 60 * 1000; // 1 minute

    // We use 6 decimals for all tokens participating in distribution calculations.
    const USD_DECIMALS: u8 = 6;
    const SAIL_DECIMALS: u8 = 6;

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

    /// The oSAIL option token should be exercisable for this number of seconds
    /// after it is distributed.
    public fun o_sail_duration(): u64 {
        EPOCH_DURATION * 4
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


    public fun decimal_to_q64(
        decimal: &Decimal,
    ): u128 {
        let dec = decimal.dec();
        let dec_denominator = decimal::pow_10(dec);

        decimal_to_q64_decimals(decimal, dec_denominator)
    }

    public fun decimal_to_q64_decimals(
        decimal: &Decimal,
        dec_denominator: u128,
    ): u128 {
        assert!(!decimal.neg(), EDecimalToQ64NegativeNotSupported);

        integer_mate::full_math_u128::mul_div_floor(
            decimal.value(),
            1 << 64,
            dec_denominator
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

    /// Utility function to convert asset amount * 2^64 to USD amount * 2^64
    public fun asset_q64_to_usd_q64(
        asset_amount_q64: u128,
        asset_price_q64: u128,
        ceil: bool,
    ): u128 {
        if (ceil) {
            integer_mate::full_math_u128::mul_div_ceil(
                asset_amount_q64,
                asset_price_q64,
                1 << 64
            )
        } else {
            integer_mate::full_math_u128::mul_div_floor(
                asset_amount_q64,
                asset_price_q64,
                1 << 64
            )
        }
    }

    /// Utility function to get the current price of an asset from a switchboard aggregator
    /// Asserts that the price is not too old and returns the price.
    /// If asset and USD decimals are different the price is adjusted to reflect equasion asset * price = USD
    /// 
    /// # Arguments
    /// * `aggregator` - The switchboard aggregator to get the price from
    /// * `asset_decimals` - The number of decimals of the asset
    /// * `usd_decimals` - The number of decimals of the USD
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The price in Q64.64 format, i.e USD/asset * 2^64 with respect to decimals.
    public fun get_time_checked_price_q64(
        aggregator: &Aggregator,
        asset_decimals: u8,
        usd_decimals: u8,
        clock: &sui::clock::Clock,
    ): u128 {
        let price_result = aggregator.current_result();
        let current_time = clock.timestamp_ms();
        let price_result_time = price_result.timestamp_ms();

        assert!(price_result_time + MAX_PRICE_AGE_MS > current_time, EGetTimeCheckedPriceOutdated);

        let price_result_price = price_result.result();
        assert!(!price_result_price.neg(), EGetTimeCheckedPriceNegativePrice);

        let mut dec = price_result_price.dec();

        if (asset_decimals > usd_decimals) {
            // asset is bigger than USD
            // asset * price = USD
            // so to compensate we need to decrease price therefore increase denominator
            let decimals_delta = asset_decimals - usd_decimals;
            dec = dec + decimals_delta;
        } else {
            // USD is bigger than asset
            // USD / price = asset
            // so to compensate we need to increase price therefore decrease denominator
            let decimals_delta = usd_decimals - asset_decimals;
            dec = dec - decimals_delta;
        };
        let dec_denominator = decimal::pow_10(dec);

        decimal_to_q64_decimals(price_result_price, dec_denominator)
    }

    public fun sail_decimals(): u8 {
        SAIL_DECIMALS
    }

    public fun usd_decimals(): u8 {
        USD_DECIMALS
    }
}


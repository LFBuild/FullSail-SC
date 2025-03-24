module distribution::common {
    public fun current_period(clock: &sui::clock::Clock): u64 {
        to_period(current_timestamp(clock))
    }

    public fun current_timestamp(clock: &sui::clock::Clock): u64 {
        clock.timestamp_ms() / 1000
    }

    public fun day(): u64 {
        86400
    }

    public fun epoch_next(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 604800
    }

    public fun epoch_start(timestamp: u64): u64 {
        timestamp - timestamp % 604800
    }

    public fun epoch_vote_end(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 604800 - 3600
    }

    public fun epoch_vote_start(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 3600
    }

    public fun get_time_to_finality(): u64 {
        500
    }

    public fun hour(): u64 {
        3600
    }

    public fun max_lock_time(): u64 {
        125798400
    }

    public fun min_lock_time(): u64 {
        604800
    }

    public fun to_period(timestamp: u64): u64 {
        timestamp / 604800 * 604800
    }

    public fun week(): u64 {
        604800
    }
}


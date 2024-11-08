module full_sail::rewards_pool {
    use std::ascii::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::package;
    use sui::dynamic_field;
    use sui::vec_map::{Self, VecMap};

    use full_sail::liquidity_pool;
    use full_sail::epoch;

    // --- addresses ---
    const DEFAULT_ADMIN: address = @0x123;

    // --- errors ---
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_MIN_LOCK_TIME: u64 = 2;
    const E_MAX_LOCK_TIME: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_LOCK_NOT_EXPIRED: u64 = 5;
    const E_INVALID_UPDATE: u64 = 6;
    const E_ZERO_AMOUNT: u64 = 7;
    const E_ZERO_TOTAL_POWER: u64 = 8;
    const E_SAME_TOKEN: u64 = 9;

    // --- structs ---
    // otw
    public struct REWARDS_POOL has drop {}

    public struct EpochRewards<phantom BaseType> has store {
        total_amounts: Table<CoinMetadata<BaseType>, u64>
    }
}
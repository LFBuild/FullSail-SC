module full_sail::rewards_pool_continuous {
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::dynamic_object_field;
    use sui::clock::{Self, Clock};

    use full_sail::fullsail_token::{FULLSAIL_TOKEN};

    // --- errors ---
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_MIN_LOCK_TIME: u64 = 2;
    const E_MAX_LOCK_TIME: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_LOCK_NOT_EXPIRED: u64 = 5;
    const E_INVALID_UPDATE: u64 = 6;
    const E_LOCK_EXTENSION_TOO_SHORT: u64 = 7;
    const E_ZERO_AMOUNT: u64 = 8;
    const E_NO_SNAPSHOT: u64 = 9;
    const E_LOCK_EXPIRED: u64 = 10;
    const E_INVALID_EPOCH: u64 = 11;
    const E_INVALID_SPLIT_AMOUNT: u64 = 12;
    const E_PENDING_REBASE: u64 = 13;
    const E_ZERO_TOTAL_POWER: u64 = 14;
    const E_EPOCH_NOT_ENDED: u64 = 15;
    const E_LOCK_DURATION_TOO_SHORT: u64 = 16;
    const E_LOCK_DURATION_TOO_LONG: u64 = 17;
    const E_INVALID_TOKEN: u64 = 18;
    const E_INVALID_EXTENSION: u64 = 19;
    const E_NO_SNAPSHOT_FOUND: u64 = 20;
    const E_INVALID_SPLIT_AMOUNTS: u64 = 21;
    const E_SMART_TABLE_ENTRY_NOT_FOUND: u64 = 22;
    const ERROR_INVALID_UPDATE: u64 = 23;

    // --- structs ---
    public struct REWARD_POOL_CONTINUOUS has drop {}

    public struct RewardsPool has key {
        id: UID,
        reward_per_token_stored: u128,
        user_reward_per_token_paid: Table<address, u128>,
        last_update_time: u64,
        reward_rate: u128,
        reward_duration: u64,
        reward_period_finish: u64,
        rewards: Table<address, u64>,
        total_stake: u128,
        stakes: Table<address, u64>,
    }

    public fun initialize(_otw: REWARD_POOL_CONTINUOUS, duration: u64, ctx: &mut TxContext) {
        let admin_cap = 
    }

    public fun add_rewards(pool: &mut RewardsPool, coin: &mut Coin<FULLSAIL_TOKEN>, clock: &Clock, ctx: &mut TxContext) {
        // Update the rewards for the pool
        update_reward(@0x0, pool, clock);
        
        // Get the asset amount
        let asset_amount = coin::value(coin);
        let deposit_coin = coin::split(coin, asset_amount, ctx);
        // Deposit the asset into the rewards pool
        transfer::public_transfer(
            deposit_coin,
            tx_context::sender(ctx)
        );
        
        // Get the current time
        let current_time = clock::timestamp_ms(clock);
        
        // Borrow mutable reference to the rewards pool
        let pool_ref = pool;
        
        // Calculate the pending reward
        let pending_reward = if (pool_ref.reward_period_finish > current_time) {
            pool_ref.reward_rate * ((pool_ref.reward_period_finish - current_time) as u128)
        } else {
            0
        };
        
        // Update the reward rate and period finish
        pool_ref.reward_rate = (pending_reward + (asset_amount as u128) * 100000000) / (pool_ref.reward_duration as u128);
        pool_ref.reward_period_finish = current_time + pool_ref.reward_duration;
        pool_ref.last_update_time = current_time;
    }

    // public fun claim_rewards(user_address: address, pool: &mut RewardsPool, clock: &Clock) : Coin<FULLSAIL_TOKEN> {
    //     update_reward(user_address, pool, clock);
    //     let pool_ref = pool;
    //     let default_reward_value = 0;
    //     let user_reward_amount = default_reward_value + *table::borrow(&pool_ref.rewards, user_address);
    //     // assert!(user_reward_amount > 0, E_MAX_LOCK_TIME);
    //     table::add(&mut pool_ref.rewards, user_address, 0);
    //     let user_signer = fullsail::package_manager::get_signer();
    //     dispatchable_fungible_asset::withdraw<RewardsPool>(&user_signer, pool, user_reward_amount)
    // }

    fun claimable_internal(user_address: address, pool_ref: &RewardsPool, clock: &Clock) : u64 {
        let _default_stake_value = 0;
        let _default_reward_value = 0;
        let scale_factor = 100000000;
        assert!(scale_factor != 0, 14);
        let _user_rewards = 0;
        (((((*table::borrow(&pool_ref.stakes, user_address) as u128) as u256) * ((reward_per_token_internal(pool_ref, clock) - *table::borrow(&pool_ref.user_reward_per_token_paid, user_address)) as u256) / (scale_factor as u256)) as u128) as u64) + *table::borrow(&pool_ref.rewards, user_address)
    }

    public fun claimable_rewards(user_address: address, pool: &mut RewardsPool, clock: &Clock) : u64 {
        claimable_internal(user_address, pool, clock)
    }

    public fun reward_per_token(pool: &mut RewardsPool, clock: &Clock) : u128 {
        reward_per_token_internal(pool, clock)
    }

    fun reward_per_token_internal(pool_ref: &RewardsPool, clock: &Clock) : u128 {
        let stored_reward = pool_ref.reward_per_token_stored;
        let mut adjusted_reward = stored_reward;
        let total_stake_amount = pool_ref.total_stake;
        if (total_stake_amount > 0) {
            assert!(total_stake_amount != 0, 14);
            adjusted_reward = stored_reward + (((((std::u64::min(clock::timestamp_ms(clock), pool_ref.reward_period_finish) - pool_ref.last_update_time) as u128) as u256) * (pool_ref.reward_rate as u256) / (total_stake_amount as u256)) as u128);
        };
        adjusted_reward
    }

    public fun update_reward(user_address: address, pool: &mut RewardsPool, clock: &Clock) {
        // Borrow mutable reference to the rewards pool
        let pool_ref = pool;
        
        // Update the reward per token stored
        pool_ref.reward_per_token_stored = reward_per_token_internal(pool_ref,  clock);
        
        // Update the last update time
        pool_ref.last_update_time = std::u64::min(clock::timestamp_ms(clock), pool_ref.reward_period_finish);
        
        // Get the claimable amount for the user
        let claimable_amount = claimable_internal(user_address, pool_ref, clock);
        
        // If there is a claimable amount, update the rewards table
        if (claimable_amount > 0) {
            table::add(&mut pool_ref.rewards, user_address, claimable_amount);
        };
        
        // Update the user reward per token paid
        table::add(&mut pool_ref.user_reward_per_token_paid, user_address, pool_ref.reward_per_token_stored);
    }
}
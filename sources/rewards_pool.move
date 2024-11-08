module full_sail::rewards_pool {
    use std::ascii::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::package;
    use sui::dynamic_field;

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
        reward_tokens: vector<CoinMetadata<BaseType>>,
        reward_tokens_amounts: vector<u64>,
        non_default_reward_tokens_count: u64,
        pool_total_coins: u64,
        pool_total_shares: u128,
        pool_shares: Table<address, u128>,
    }

    public struct RewardStore<phantom BaseType> has store {
        store: Balance<BaseType>,
    }

    public struct RewardsPool<phantom BaseType> has key {
        id: UID,
        epoch_rewards: Table<u64, EpochRewards<BaseType>>,
        reward_tokens: vector<CoinMetadata<BaseType>>,
        reward_stores: vector<RewardStore<BaseType>>,
        default_reward_tokens: vector<CoinMetadata<BaseType>>,
    }

    public fun create<BaseType>(mut reward_tokens_list: vector<CoinMetadata<BaseType>>, ctx: &mut TxContext): ID {
        let mut new_reward_tokens = vector::empty<CoinMetadata<BaseType>>();
        let mut new_reward_stores = vector::empty<RewardStore<BaseType>>();
        let rewards_pool_id = object::new(ctx);

        vector::reverse<CoinMetadata<BaseType>>(&mut reward_tokens_list);
        let mut reward_tokens_length = vector::length<CoinMetadata<BaseType>>(&reward_tokens_list);
        while(reward_tokens_length > 0) {
            let reward_token = vector::pop_back<CoinMetadata<BaseType>>(&mut reward_tokens_list);
            let reward_store = RewardStore<BaseType> {
                store: balance::zero<BaseType>(),
            };
            vector::push_back<CoinMetadata<BaseType>>(&mut new_reward_tokens, reward_token);
            vector::push_back<RewardStore<BaseType>>(&mut new_reward_stores, reward_store);
            reward_tokens_length = reward_tokens_length - 1;
        };
        vector::destroy_empty<CoinMetadata<BaseType>>(reward_tokens_list);
        let rewards_pool = RewardsPool {
            id: rewards_pool_id,
            epoch_rewards: table::new<u64, EpochRewards<BaseType>>(ctx),
            reward_tokens: new_reward_tokens,
            reward_stores: new_reward_stores,
            default_reward_tokens: vector::empty<CoinMetadata<BaseType>>(),
        };

        let pool_id = object::id(&rewards_pool);
        transfer::share_object(rewards_pool);
        pool_id
    }
}
module full_sail::rewards_pool {
    use std::ascii::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::package;
    use sui::clock::Clock;
    use sui::dynamic_field;

    use full_sail::liquidity_pool;
    use full_sail::epoch;

    // --- addresses ---
    const DEFAULT_ADMIN: address = @0x123;

    // --- errors ---
    const E_SHAREHOLDER_NOT_FOUND: u64 = 1;
    const EINSUFFICIENT_SHARES: u64 = 2;
    const E_POOL_TOTAL_COINS_OVERFLOW: u64 = 3;
    const E_POOL_TOTAL_SHARES_OVERFLOW: u64 = 4;
    const E_SHAREHOLDER_SHARES_OVERFLOW: u64 = 5;
    const E_INVALID_EPOCH: u64 = 6;

    const MAX_U64: u64 = 18446744073709551615;
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

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

    public fun default_reward_tokens<BaseType>(rewards_pool: &mut RewardsPool<BaseType>): &vector<CoinMetadata<BaseType>> {
        &rewards_pool.default_reward_tokens
    }

    public fun claimer_shares<BaseType>(user_address: address, rewards_pool: &RewardsPool<BaseType>, epoch_id: u64): (u64, u64) {
        let epoch_reward = table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id);
        (*table::borrow<address, u128>(&epoch_reward.pool_shares, user_address) as u64 , epoch_reward.pool_total_shares as u64)
    }

    public fun total_rewards<BaseType>(rewards_pool: &RewardsPool<BaseType>, epoch_id: u64): (&vector<CoinMetadata<BaseType>>, vector<u64>) {
        // if(!table::contains<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id)) {
        //     // let empty_reward_tokens = vector::empty<CoinMetadata<BaseType>>();
        //     return (&vector::empty<CoinMetadata<BaseType>>(), vector::empty<u64>())
        // };
        // let reward_tokens = table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id).reward_tokens;
        (&table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id).reward_tokens, table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id).reward_tokens_amounts)
    }

    public fun reward_tokens<BaseType>(rewards_pool: &RewardsPool<BaseType>, epoch_id: u64): &vector<CoinMetadata<BaseType>> {
        &table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id).reward_tokens
    }

    public fun decrease_allocation<BaseType>(user_address: address, rewards_pool: &mut RewardsPool<BaseType>, amount: u64, clock: &Clock, ctx: &mut TxContext): u64 {
        let current_epoch = epoch::now(clock);
        if(!table::contains<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, current_epoch)) {
            let new_epoch_reward = EpochRewards {
                reward_tokens: vector::empty<CoinMetadata<BaseType>>(),
                reward_tokens_amounts: vector::empty<u64>(),
                non_default_reward_tokens_count: 0,
                pool_total_coins: 0,
                pool_total_shares: 0,
                pool_shares: table::new<address, u128>(ctx),
            };
            table::add<u64, EpochRewards<BaseType>>(&mut rewards_pool.epoch_rewards, current_epoch, new_epoch_reward);
        };
        let epoch_reward = table::borrow_mut<u64, EpochRewards<BaseType>>(&mut rewards_pool.epoch_rewards, current_epoch);
        assert!(table::contains<address, u128>(&epoch_reward.pool_shares, user_address), E_SHAREHOLDER_NOT_FOUND);
        let shares = table::borrow_mut<address, u128>(&mut epoch_reward.pool_shares, user_address);
        assert!(*shares >= amount as u128, EINSUFFICIENT_SHARES);
        if(amount == 0) return 0;
        let redeemed_coins;
        if(epoch_reward.pool_total_coins == 0 || epoch_reward.pool_total_shares == 0) {
            redeemed_coins = 0;
        } else {
            redeemed_coins = amount * epoch_reward.pool_total_coins / (epoch_reward.pool_total_shares as u64);
        };
        epoch_reward.pool_total_coins = epoch_reward.pool_total_coins - redeemed_coins;
        epoch_reward.pool_total_shares = epoch_reward.pool_total_shares - (amount as u128);
        *shares = *shares - (amount as u128);
        let remaining_shares = *shares;
        if (remaining_shares == 0) {
            table::remove(&mut epoch_reward.pool_shares, user_address);
        };
        redeemed_coins
    }

    public fun increase_allocation<BaseType>(user_address: address, rewards_pool: &mut RewardsPool<BaseType>, amount: u64, clock: &Clock, ctx: &mut TxContext): u64 {
        let current_epoch = epoch::now(clock);
        if(!table::contains<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, current_epoch)) {
            let new_epoch_reward = EpochRewards {
                reward_tokens: vector::empty<CoinMetadata<BaseType>>(),
                reward_tokens_amounts: vector::empty<u64>(),
                non_default_reward_tokens_count: 0,
                pool_total_coins: 0,
                pool_total_shares: 0,
                pool_shares: table::new<address, u128>(ctx),
            };
            table::add<u64, EpochRewards<BaseType>>(&mut rewards_pool.epoch_rewards, current_epoch, new_epoch_reward);
        };
        let epoch_reward = table::borrow_mut<u64, EpochRewards<BaseType>>(&mut rewards_pool.epoch_rewards, current_epoch);
        if(amount == 0) return 0;
        let new_shares;

        if(epoch_reward.pool_total_coins == 0 || epoch_reward.pool_total_shares == 0) {
            new_shares = amount;
        } else {
            new_shares = amount * (epoch_reward.pool_total_shares as u64) / epoch_reward.pool_total_coins;
        };
        assert!(MAX_U64 - epoch_reward.pool_total_coins >= amount, E_POOL_TOTAL_COINS_OVERFLOW);
        assert!(MAX_U128 - epoch_reward.pool_total_shares >= new_shares as u128, E_POOL_TOTAL_SHARES_OVERFLOW);
        epoch_reward.pool_total_coins = epoch_reward.pool_total_coins + amount;
        epoch_reward.pool_total_shares = epoch_reward.pool_total_shares + (new_shares as u128);

        if(table::contains<address, u128>(&epoch_reward.pool_shares, user_address)) {
            let shares = table::borrow_mut<address, u128>(&mut epoch_reward.pool_shares, user_address);
            assert!(MAX_U128 - *shares >= new_shares as u128, E_SHAREHOLDER_SHARES_OVERFLOW);
            *shares = *shares + (new_shares as u128);
        } else if(new_shares > 0) {
            table::add(&mut epoch_reward.pool_shares, user_address, new_shares as u128);
        };
        new_shares
    }

    public fun claimable_rewards<BaseType>(user_address: address, rewards_pool: &RewardsPool<BaseType>, epoch_id: u64, clock: &Clock): (&vector<CoinMetadata<BaseType>>, vector<u64>) {
        assert!(epoch_id <= epoch::now(clock), E_INVALID_EPOCH);
        let epoch_reward = table::borrow<u64, EpochRewards<BaseType>>(&rewards_pool.epoch_rewards, epoch_id);
        let mut claimable_rewards_amounts = vector::empty<u64>();
        let index = 0;
        let shares = table::borrow<address, u128>(&epoch_reward.pool_shares, user_address);
        while(index < vector::length<u64>(&epoch_reward.reward_tokens_amounts)) {
            let rewards = *vector::borrow<u64>(&epoch_reward.reward_tokens_amounts, index) * (*shares as u64) / (epoch_reward.pool_total_shares as u64);
            vector::push_back<u64>(&mut claimable_rewards_amounts, rewards);
        };
        (reward_tokens(rewards_pool, epoch_id), claimable_rewards_amounts)
    }
}
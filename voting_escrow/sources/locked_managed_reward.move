/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::locked_managed_reward {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    public struct LockedManagedReward has store, key {
        id: UID,
        voter: ID,
        ve: ID,
        reward: voting_escrow::reward::Reward,
        reward_cap: voting_escrow::reward_cap::RewardCap,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public(package) fun create(
        voter: ID,
        ve: ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut TxContext
    ): LockedManagedReward {
        let mut coin_types_vec = std::vector::empty<std::type_name::TypeName>();
        coin_types_vec.push_back(reward_coin_type);
        let id = object::new(ctx);
        let inner_id = id.uid_to_inner();
        let (reward, reward_cap) = voting_escrow::reward::create(
                inner_id,
                coin_types_vec,
                false,
                ctx
            );
        LockedManagedReward {
            id,
            voter,
            ve,
            reward,
            reward_cap,
            bag: sui::bag::new(ctx),
        }
    }

    public(package) fun deposit(
        reward: &mut LockedManagedReward,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(&reward.reward_cap, amount, lock_id, clock, ctx);
    }

    public fun earned<RewardCoinType>(
        reward: &LockedManagedReward,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.earned<RewardCoinType>(lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &LockedManagedReward, lock_id: ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock_id, time)
    }

    public fun get_prior_supply_index(reward: &LockedManagedReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    public fun rewards_list_length(reward: &LockedManagedReward): u64 {
        reward.reward.rewards_list_length()
    }

    public(package) fun withdraw(
        reward: &mut LockedManagedReward,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(&reward.reward_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &LockedManagedReward): &voting_escrow::reward::Reward {
        &reward.reward
    }

    public(package) fun get_reward<RewardCoinType>(
        reward: &mut LockedManagedReward,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::balance::Balance<RewardCoinType> {
        let vote_escrow_id = reward.ve();
        let mut reward_balance_option = reward.reward.get_reward_internal<RewardCoinType>(
            &reward.reward_cap,
            object::id_to_address(&vote_escrow_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (reward_balance_option.is_some()) {
            reward_balance_option.extract()
        } else {
            sui::balance::zero<RewardCoinType>()
        };
        reward_balance_option.destroy_none();
        reward_balance
    }

    public(package) fun notify_reward_amount<RewardCoinType>(
        reward: &mut LockedManagedReward,
        coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.notify_reward_amount_internal(&reward.reward_cap, coin.into_balance(), clock, ctx);
    }

    public fun voter(reward: &LockedManagedReward): ID {
        reward.voter
    }

    public fun ve(reward: &LockedManagedReward): ID {
        reward.ve
    }
}


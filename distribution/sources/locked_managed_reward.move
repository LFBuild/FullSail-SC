module distribution::locked_managed_reward {
    public struct LockedManagedReward has store, key {
        id: UID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        voter: ID,
        ve: ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut TxContext
    ): LockedManagedReward {
        let mut coin_types_vec = std::vector::empty<std::type_name::TypeName>();
        coin_types_vec.push_back(reward_coin_type);
        LockedManagedReward {
            id: object::new(ctx),
            reward: distribution::reward::create(
                voter,
                option::some(ve),
                ve,
                coin_types_vec,
                false,
                ctx
            ),
        }
    }

    public fun deposit(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(reward_authorized_cap, amount, lock_id, clock, ctx);
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

    public fun withdraw(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &LockedManagedReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_reward<RewardCoinType>(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::balance::Balance<RewardCoinType> {
        reward_authorized_cap.validate(reward.reward.ve());
        let vote_escrow_id = reward.reward.ve();
        let mut reward_balance_option = reward.reward.get_reward_internal<RewardCoinType>(
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

    public fun notify_reward_amount<RewardCoinType>(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.reward.ve());
        reward.reward.notify_reward_amount_internal(coin.into_balance(), clock, ctx);
    }
}


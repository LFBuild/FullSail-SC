module distribution::locked_managed_reward {
    public struct LockedManagedReward has store, key {
        id: sui::object::UID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        voter: sui::object::ID,
        ve: sui::object::ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut sui::tx_context::TxContext
    ): LockedManagedReward {
        let mut coin_types_vec = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut coin_types_vec, reward_coin_type);
        LockedManagedReward {
            id: sui::object::new(ctx),
            reward: distribution::reward::create(voter, ve, ve, coin_types_vec, ctx),
        }
    }

    public fun deposit(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::deposit(&mut reward.reward, reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun earned<RewardCoinType>(
        reward: &LockedManagedReward,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u64 {
        distribution::reward::earned<RewardCoinType>(&reward.reward, lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &LockedManagedReward, lock_id: sui::object::ID, time: u64): u64 {
        distribution::reward::get_prior_balance_index(&reward.reward, lock_id, time)
    }

    public fun get_prior_supply_index(reward: &LockedManagedReward, time: u64): u64 {
        distribution::reward::get_prior_supply_index(&reward.reward, time)
    }

    public fun rewards_list_length(reward: &LockedManagedReward): u64 {
        distribution::reward::rewards_list_length(&reward.reward)
    }

    public fun withdraw(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::withdraw(&mut reward.reward, reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &LockedManagedReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_reward<RewardCoinType>(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<RewardCoinType> {
        distribution::reward_authorized_cap::validate(reward_authorized_cap, distribution::reward::ve(&reward.reward));
        let vote_escrow_id = distribution::reward::ve(&reward.reward);
        let mut reward_balance_option = distribution::reward::get_reward_internal<RewardCoinType>(
            &mut reward.reward,
            sui::object::id_to_address(&vote_escrow_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (std::option::is_some<sui::balance::Balance<RewardCoinType>>(&reward_balance_option)) {
            std::option::extract<sui::balance::Balance<RewardCoinType>>(&mut reward_balance_option)
        } else {
            sui::balance::zero<RewardCoinType>()
        };
        std::option::destroy_none<sui::balance::Balance<RewardCoinType>>(reward_balance_option);
        reward_balance
    }

    public fun notify_reward_amount<RewardCoinType>(
        reward: &mut LockedManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(reward_authorized_cap, distribution::reward::ve(&reward.reward));
        distribution::reward::notify_reward_amount_internal<RewardCoinType>(
            &mut reward.reward,
            sui::coin::into_balance<RewardCoinType>(coin),
            clock,
            ctx
        );
    }
}


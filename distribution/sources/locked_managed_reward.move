module distribution::locked_managed_reward {
    public struct LockedManagedReward has store, key {
        id: sui::object::UID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        arg0: sui::object::ID,
        arg1: sui::object::ID,
        arg2: std::type_name::TypeName,
        arg3: &mut sui::tx_context::TxContext
    ): LockedManagedReward {
        let mut v0 = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut v0, arg2);
        LockedManagedReward {
            id: sui::object::new(arg3),
            reward: distribution::reward::create(arg0, arg1, arg1, v0, arg3),
        }
    }

    public fun deposit(
        arg0: &mut LockedManagedReward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: u64,
        arg3: sui::object::ID,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::deposit(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }

    public fun earned<T0>(arg0: &LockedManagedReward, arg1: sui::object::ID, arg2: &sui::clock::Clock): u64 {
        distribution::reward::earned<T0>(&arg0.reward, arg1, arg2)
    }

    public fun get_prior_balance_index(arg0: &LockedManagedReward, arg1: sui::object::ID, arg2: u64): u64 {
        distribution::reward::get_prior_balance_index(&arg0.reward, arg1, arg2)
    }

    public fun get_prior_supply_index(arg0: &LockedManagedReward, arg1: u64): u64 {
        distribution::reward::get_prior_supply_index(&arg0.reward, arg1)
    }

    public fun rewards_list_length(arg0: &LockedManagedReward): u64 {
        distribution::reward::rewards_list_length(&arg0.reward)
    }

    public fun withdraw(
        arg0: &mut LockedManagedReward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: u64,
        arg3: sui::object::ID,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::withdraw(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }

    public fun borrow_reward(arg0: &LockedManagedReward): &distribution::reward::Reward {
        &arg0.reward
    }

    public fun get_reward<T0>(
        arg0: &mut LockedManagedReward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<T0> {
        distribution::reward_authorized_cap::validate(arg1, distribution::reward::ve(&arg0.reward));
        let v0 = distribution::reward::ve(&arg0.reward);
        let mut v1 = distribution::reward::get_reward_internal<T0>(
            &mut arg0.reward,
            sui::object::id_to_address(&v0),
            arg2,
            arg3,
            arg4
        );
        let v2 = if (std::option::is_some<sui::balance::Balance<T0>>(&v1)) {
            std::option::extract<sui::balance::Balance<T0>>(&mut v1)
        } else {
            sui::balance::zero<T0>()
        };
        std::option::destroy_none<sui::balance::Balance<T0>>(v1);
        v2
    }

    public fun notify_reward_amount<T0>(
        arg0: &mut LockedManagedReward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: sui::coin::Coin<T0>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(arg1, distribution::reward::ve(&arg0.reward));
        distribution::reward::notify_reward_amount_internal<T0>(
            &mut arg0.reward,
            sui::coin::into_balance<T0>(arg2),
            arg3,
            arg4
        );
    }

    // decompiled from Move bytecode v6
}


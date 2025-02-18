module distribution::free_managed_reward {
    public struct FreeManagedReward has store, key {
        id: sui::object::UID,
        reward: distribution::reward::Reward,
    }
    
    public(package) fun create(arg0: sui::object::ID, arg1: sui::object::ID, arg2: std::type_name::TypeName, arg3: &mut sui::tx_context::TxContext) : FreeManagedReward {
        let mut v0 = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut v0, arg2);
        FreeManagedReward{
            id     : sui::object::new(arg3), 
            reward : distribution::reward::create(arg0, arg1, arg1, v0, arg3),
        }
    }
    
    public fun deposit(arg0: &mut FreeManagedReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: sui::object::ID, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        distribution::reward::deposit(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun earned<T0>(arg0: &FreeManagedReward, arg1: sui::object::ID, arg2: &sui::clock::Clock) : u64 {
        distribution::reward::earned<T0>(&arg0.reward, arg1, arg2)
    }
    
    public fun get_prior_balance_index(arg0: &FreeManagedReward, arg1: sui::object::ID, arg2: u64) : u64 {
        distribution::reward::get_prior_balance_index(&arg0.reward, arg1, arg2)
    }
    
    public fun rewards_list(arg0: &FreeManagedReward) : vector<std::type_name::TypeName> {
        distribution::reward::rewards_list(&arg0.reward)
    }
    
    public fun rewards_list_length(arg0: &FreeManagedReward) : u64 {
        distribution::reward::rewards_list_length(&arg0.reward)
    }
    
    public fun withdraw(arg0: &mut FreeManagedReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: sui::object::ID, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        distribution::reward::withdraw(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun borrow_reward(arg0: &FreeManagedReward) : &distribution::reward::Reward {
        &arg0.reward
    }
    
    public fun get_prior_supply_index(arg0: &FreeManagedReward, arg1: u64) : u64 {
        get_prior_supply_index(arg0, arg1)
    }
    
    public fun get_reward<T0>(arg0: &mut FreeManagedReward, arg1: distribution::lock_owner::OwnerProof, arg2: &sui::clock::Clock, arg3: &mut sui::tx_context::TxContext) {
        let (v0, v1, v2) = distribution::lock_owner::consume(arg1);
        assert!(distribution::reward::ve(&arg0.reward) == v0, 9223372337502486527);
        let mut v3 = distribution::reward::get_reward_internal<T0>(&mut arg0.reward, sui::tx_context::sender(arg3), v1, arg2, arg3);
        if (std::option::is_some<sui::balance::Balance<T0>>(&v3)) {
            sui::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::from_balance<T0>(std::option::extract<sui::balance::Balance<T0>>(&mut v3), arg3), v2);
        };
        std::option::destroy_none<sui::balance::Balance<T0>>(v3);
    }
    
    public fun notify_reward_amount<T0>(arg0: &mut FreeManagedReward, mut arg1: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>, arg2: sui::coin::Coin<T0>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = std::type_name::get<T0>();
        if (!distribution::reward::rewards_contains(&arg0.reward, v0)) {
            assert!(std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&arg1), 9223372389042094079);
            distribution::whitelisted_tokens::validate<T0>(std::option::extract<distribution::whitelisted_tokens::WhitelistedToken>(&mut arg1), distribution::reward::voter(&arg0.reward));
            distribution::reward::add_reward_token(&mut arg0.reward, v0);
        };
        std::option::destroy_none<distribution::whitelisted_tokens::WhitelistedToken>(arg1);
        distribution::reward::notify_reward_amount_internal<T0>(&mut arg0.reward, sui::coin::into_balance<T0>(arg2), arg3, arg4);
    }
    
    // decompiled from Move bytecode v6
}


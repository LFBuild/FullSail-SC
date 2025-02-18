module distribution::bribe_voting_reward {
    public struct BribeVotingReward has store, key {
        id: sui::object::UID,
        gauge: sui::object::ID,
        reward: distribution::reward::Reward,
    }
    
    public(package) fun create(arg0: sui::object::ID, arg1: sui::object::ID, arg2: sui::object::ID, arg3: vector<std::type_name::TypeName>, arg4: &mut sui::tx_context::TxContext) : BribeVotingReward {
        BribeVotingReward{
            id     : sui::object::new(arg4), 
            gauge  : arg2, 
            reward : distribution::reward::create(arg0, arg1, arg0, arg3, arg4),
        }
    }
    
    public fun deposit(arg0: &mut BribeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: sui::object::ID, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        distribution::reward::deposit(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun earned<T0>(arg0: &BribeVotingReward, arg1: sui::object::ID, arg2: &sui::clock::Clock) : u64 {
        distribution::reward::earned<T0>(&arg0.reward, arg1, arg2)
    }
    
    public fun get_prior_balance_index(arg0: &BribeVotingReward, arg1: sui::object::ID, arg2: u64) : u64 {
        distribution::reward::get_prior_balance_index(&arg0.reward, arg1, arg2)
    }
    
    public fun get_prior_supply_index(arg0: &BribeVotingReward, arg1: u64) : u64 {
        distribution::reward::get_prior_supply_index(&arg0.reward, arg1)
    }
    
    public fun rewards_list_length(arg0: &BribeVotingReward) : u64 {
        distribution::reward::rewards_list_length(&arg0.reward)
    }
    
    public fun withdraw(arg0: &mut BribeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: sui::object::ID, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        distribution::reward::withdraw(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun borrow_reward(arg0: &BribeVotingReward) : &distribution::reward::Reward {
        &arg0.reward
    }
    
    public fun get_reward<T0, T1>(arg0: &mut BribeVotingReward, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = sui::object::id<distribution::voting_escrow::Lock>(arg2);
        let v1 = distribution::voting_escrow::owner_of<T0>(arg1, v0);
        let mut v2 = distribution::reward::get_reward_internal<T1>(&mut arg0.reward, v1, v0, arg3, arg4);
        if (std::option::is_some<sui::balance::Balance<T1>>(&v2)) {
            sui::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::from_balance<T1>(std::option::extract<sui::balance::Balance<T1>>(&mut v2), arg4), v1);
        };
        std::option::destroy_none<sui::balance::Balance<T1>>(v2);
    }
    
    public fun notify_reward_amount<T0>(arg0: &mut BribeVotingReward, mut arg1: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>, arg2: sui::coin::Coin<T0>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = std::type_name::get<T0>();
        if (!distribution::reward::rewards_contains(&arg0.reward, v0)) {
            assert!(std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&arg1), 9223372410516930559);
            distribution::whitelisted_tokens::validate<T0>(std::option::extract<distribution::whitelisted_tokens::WhitelistedToken>(&mut arg1), distribution::reward::voter(&arg0.reward));
            distribution::reward::add_reward_token(&mut arg0.reward, v0);
        };
        if (std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&arg1)) {
            distribution::whitelisted_tokens::validate<T0>(std::option::destroy_some<distribution::whitelisted_tokens::WhitelistedToken>(arg1), distribution::reward::voter(&arg0.reward));
        } else {
            std::option::destroy_none<distribution::whitelisted_tokens::WhitelistedToken>(arg1);
        };
        distribution::reward::notify_reward_amount_internal<T0>(&mut arg0.reward, sui::coin::into_balance<T0>(arg2), arg3, arg4);
    }
    
    public fun voter_get_reward<T0, T1>(arg0: &mut BribeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: &distribution::voting_escrow::VotingEscrow<T0>, arg3: sui::object::ID, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) : sui::balance::Balance<T1> {
        distribution::reward_authorized_cap::validate(arg1, distribution::reward::authorized(&arg0.reward));
        let mut v0 = distribution::reward::get_reward_internal<T1>(&mut arg0.reward, distribution::voting_escrow::owner_of<T0>(arg2, arg3), arg3, arg4, arg5);
        let v1 = if (std::option::is_some<sui::balance::Balance<T1>>(&v0)) {
            std::option::extract<sui::balance::Balance<T1>>(&mut v0)
        } else {
            sui::balance::zero<T1>()
        };
        std::option::destroy_none<sui::balance::Balance<T1>>(v0);
        v1
    }
    
    // decompiled from Move bytecode v6
}


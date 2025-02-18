module distribution::fee_voting_reward {
    struct FeeVotingReward has store, key {
        id: 0x2::object::UID,
        gauge: 0x2::object::ID,
        reward: distribution::reward::Reward,
    }
    
    public fun balance<T0>(arg0: &FeeVotingReward) : u64 {
        distribution::reward::balance<T0>(&arg0.reward)
    }
    
    public(friend) fun create(arg0: 0x2::object::ID, arg1: 0x2::object::ID, arg2: 0x2::object::ID, arg3: vector<std::type_name::TypeName>, arg4: &mut 0x2::tx_context::TxContext) : FeeVotingReward {
        FeeVotingReward{
            id     : 0x2::object::new(arg4), 
            gauge  : arg2, 
            reward : distribution::reward::create(arg0, arg1, arg0, arg3, arg4),
        }
    }
    
    public fun deposit(arg0: &mut FeeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: 0x2::object::ID, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        distribution::reward::deposit(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun earned<T0>(arg0: &FeeVotingReward, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock) : u64 {
        distribution::reward::earned<T0>(&arg0.reward, arg1, arg2)
    }
    
    public fun get_prior_balance_index(arg0: &FeeVotingReward, arg1: 0x2::object::ID, arg2: u64) : u64 {
        distribution::reward::get_prior_balance_index(&arg0.reward, arg1, arg2)
    }
    
    public fun get_prior_supply_index(arg0: &FeeVotingReward, arg1: u64) : u64 {
        distribution::reward::get_prior_supply_index(&arg0.reward, arg1)
    }
    
    public fun rewards_list_length(arg0: &FeeVotingReward) : u64 {
        distribution::reward::rewards_list_length(&arg0.reward)
    }
    
    public fun withdraw(arg0: &mut FeeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: u64, arg3: 0x2::object::ID, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        distribution::reward::withdraw(&mut arg0.reward, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun borrow_reward(arg0: &FeeVotingReward) : &distribution::reward::Reward {
        &arg0.reward
    }
    
    public fun get_reward<T0, T1>(arg0: &mut FeeVotingReward, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<distribution::voting_escrow::Lock>(arg2);
        let v1 = distribution::voting_escrow::owner_of<T0>(arg1, v0);
        let v2 = distribution::reward::get_reward_internal<T1>(&mut arg0.reward, v1, v0, arg3, arg4);
        if (std::option::is_some<0x2::balance::Balance<T1>>(&v2)) {
            0x2::transfer::public_transfer<0x2::coin::Coin<T1>>(0x2::coin::from_balance<T1>(std::option::extract<0x2::balance::Balance<T1>>(&mut v2), arg4), v1);
        };
        std::option::destroy_none<0x2::balance::Balance<T1>>(v2);
    }
    
    public fun notify_reward_amount<T0>(arg0: &mut FeeVotingReward, arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap, arg2: 0x2::coin::Coin<T0>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        distribution::reward_authorized_cap::validate(arg1, distribution::reward::authorized(&arg0.reward));
        assert!(distribution::reward::rewards_contains(&arg0.reward, std::type_name::get<T0>()), 9223372427696799743);
        distribution::reward::notify_reward_amount_internal<T0>(&mut arg0.reward, 0x2::coin::into_balance<T0>(arg2), arg3, arg4);
    }
    
    public fun voter_get_reward<T0, T1>(arg0: &mut FeeVotingReward, arg1: &distribution::voter_cap::VoterCap, arg2: &distribution::voting_escrow::VotingEscrow<T0>, arg3: 0x2::object::ID, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T1> {
        assert!(distribution::voter_cap::get_voter_id(arg1) == distribution::reward::voter(&arg0.reward), 9223372358977323007);
        let v0 = distribution::reward::get_reward_internal<T1>(&mut arg0.reward, distribution::voting_escrow::owner_of<T0>(arg2, arg3), arg3, arg4, arg5);
        let v1 = if (std::option::is_some<0x2::balance::Balance<T1>>(&v0)) {
            std::option::extract<0x2::balance::Balance<T1>>(&mut v0)
        } else {
            0x2::balance::zero<T1>()
        };
        std::option::destroy_none<0x2::balance::Balance<T1>>(v0);
        v1
    }
    
    // decompiled from Move bytecode v6
}


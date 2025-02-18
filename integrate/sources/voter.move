module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::voter {
    struct EventDistributeReward has copy, drop, store {
        sender: address,
        gauge: 0x2::object::ID,
        amount: u64,
    }
    
    struct EventRewardTokens has copy, drop, store {
        list: 0x2::vec_map::VecMap<0x2::object::ID, vector<0x1::type_name::TypeName>>,
    }
    
    struct ClaimableVotingBribes has copy, drop, store {
        data: 0x2::vec_map::VecMap<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>,
    }
    
    struct PoolWeight has copy, drop, store {
        id: 0x2::object::ID,
        weight: u64,
    }
    
    struct PoolsTally has copy, drop, store {
        list: vector<PoolWeight>,
    }
    
    public entry fun create<T0>(arg0: &0x2::package::Publisher, arg1: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x1::vector::empty<0x1::type_name::TypeName>();
        0x1::vector::push_back<0x1::type_name::TypeName>(&mut v0, 0x1::type_name::get<T0>());
        let (v1, v2) = distribution::voter::create<T0>(arg0, v0, arg1);
        0x2::transfer::public_share_object<distribution::voter::Voter<T0>>(v1);
        0x2::transfer::public_transfer<distribution::notify_reward_cap::NotifyRewardCap>(v2, 0x2::tx_context::sender(arg1));
    }
    
    public entry fun create_gauge<T0, T1, T2>(arg0: &mut distribution::voter::Voter<T2>, arg1: &0x5640f87c73cced090abe3c3e4738b8f0044a070be17c39ad202224298cf3784::gauge_cap::CreateCap, arg2: &distribution::voter_cap::GovernorCap, arg3: &distribution::voting_escrow::VotingEscrow<T2>, arg4: &mut clmm_pool::pool::Pool<T0, T1>, arg5: &0x2::clock::Clock, arg6: &mut 0x2::tx_context::TxContext) {
        0x2::transfer::public_share_object<distribution::gauge::Gauge<T0, T1, T2>>(distribution::voter::create_gauge<T0, T1, T2>(arg0, arg1, arg2, arg3, arg4, arg5, arg6));
    }
    
    public entry fun poke<T0>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        distribution::voter::poke<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public entry fun vote<T0>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: vector<0x2::object::ID>, arg4: vector<u64>, arg5: &0x2::clock::Clock, arg6: &mut 0x2::tx_context::TxContext) {
        distribution::voter::vote<T0>(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
    }
    
    public fun claim_voting_bribes<T0, T1>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: vector<distribution::voting_escrow::Lock>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0;
        while (v0 < 0x1::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            distribution::voter::claim_voting_bribe<T0, T1>(arg0, arg1, 0x1::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0), arg3, arg4);
            v0 = v0 + 1;
        };
        while (0x1::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(0x1::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2), arg1, 0x2::tx_context::sender(arg4), arg3, arg4);
        };
        0x1::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }
    
    public fun claim_voting_bribes_2<T0, T1, T2>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: vector<distribution::voting_escrow::Lock>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0;
        while (v0 < 0x1::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = 0x1::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_bribe<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T2>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (0x1::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(0x1::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2), arg1, 0x2::tx_context::sender(arg4), arg3, arg4);
        };
        0x1::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }
    
    public fun claim_voting_bribes_3<T0, T1, T2, T3>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: vector<distribution::voting_escrow::Lock>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0;
        while (v0 < 0x1::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = 0x1::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_bribe<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T2>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T3>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (0x1::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(0x1::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2), arg1, 0x2::tx_context::sender(arg4), arg3, arg4);
        };
        0x1::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }
    
    public fun claim_voting_fee_rewards<T0, T1, T2>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: vector<distribution::voting_escrow::Lock>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0;
        while (v0 < 0x1::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = 0x1::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_fee_reward<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_fee_reward<T0, T2>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (0x1::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(0x1::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2), arg1, 0x2::tx_context::sender(arg4), arg3, arg4);
        };
        0x1::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }
    
    public fun claim_voting_fee_rewards_single<T0, T1, T2>(arg0: &mut distribution::voter::Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        distribution::voter::claim_voting_fee_reward<T0, T1>(arg0, arg1, arg2, arg3, arg4);
        distribution::voter::claim_voting_fee_reward<T0, T2>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public fun claimable_voting_bribes<T0, T1>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock) {
        let v0 = 0x2::vec_map::empty<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>();
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T1>(), claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2));
        let v1 = ClaimableVotingBribes{data: v0};
        0x2::event::emit<ClaimableVotingBribes>(v1);
    }
    
    public fun claimable_voting_bribes_2<T0, T1, T2>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock) {
        let v0 = 0x2::vec_map::empty<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>();
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T1>(), claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2));
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T2>(), claimable_voting_bribes_internal<T0, T2>(arg0, arg1, arg2));
        let v1 = ClaimableVotingBribes{data: v0};
        0x2::event::emit<ClaimableVotingBribes>(v1);
    }
    
    public fun claimable_voting_bribes_3<T0, T1, T2, T3>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock) {
        let v0 = 0x2::vec_map::empty<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>();
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T1>(), claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2));
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T2>(), claimable_voting_bribes_internal<T0, T2>(arg0, arg1, arg2));
        0x2::vec_map::insert<0x1::type_name::TypeName, 0x2::vec_map::VecMap<0x2::object::ID, u64>>(&mut v0, 0x1::type_name::get<T3>(), claimable_voting_bribes_internal<T0, T3>(arg0, arg1, arg2));
        let v1 = ClaimableVotingBribes{data: v0};
        0x2::event::emit<ClaimableVotingBribes>(v1);
    }
    
    fun claimable_voting_bribes_internal<T0, T1>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock) : 0x2::vec_map::VecMap<0x2::object::ID, u64> {
        let v0 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let v1 = 0;
        let v2 = 0x2::vec_map::empty<0x2::object::ID, u64>();
        while (v1 < 0x1::vector::length<0x2::object::ID>(&v0)) {
            let v3 = *0x1::vector::borrow<0x2::object::ID>(&v0, v1);
            0x2::vec_map::insert<0x2::object::ID, u64>(&mut v2, v3, distribution::bribe_voting_reward::earned<T1>(distribution::voter::borrow_bribe_voting_reward<T0>(arg0, distribution::voter::pool_to_gauge<T0>(arg0, v3)), arg1, arg2));
            v1 = v1 + 1;
        };
        v2
    }
    
    public entry fun distribute<T0, T1, T2>(arg0: &mut distribution::minter::Minter<T2>, arg1: &mut distribution::voter::Voter<T2>, arg2: &mut distribution::voting_escrow::VotingEscrow<T2>, arg3: &mut distribution::reward_distributor::RewardDistributor<T2>, arg4: &mut distribution::gauge::Gauge<T0, T1, T2>, arg5: &mut clmm_pool::pool::Pool<T0, T1>, arg6: &0x2::clock::Clock, arg7: &mut 0x2::tx_context::TxContext) {
        if (distribution::minter::active_period<T2>(arg0) + 604800 < distribution::common::current_timestamp(arg6)) {
            distribution::minter::update_period<T2>(arg0, arg1, arg2, arg3, arg6, arg7);
        };
        assert!(distribution::gauge::pool_id<T0, T1, T2>(arg4) == 0x2::object::id<clmm_pool::pool::Pool<T0, T1>>(arg5), 9223373041877123071);
        let v0 = EventDistributeReward{
            sender : 0x2::tx_context::sender(arg7), 
            gauge  : 0x2::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg4), 
            amount : distribution::voter::distribute_gauge<T0, T1, T2>(arg1, arg4, arg5, arg6, arg7),
        };
        0x2::event::emit<EventDistributeReward>(v0);
    }
    
    public entry fun get_voting_bribe_reward_tokens<T0>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID) {
        let v0 = 0x2::vec_map::empty<0x2::object::ID, vector<0x1::type_name::TypeName>>();
        let v1 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let v2 = 0;
        while (v2 < 0x1::vector::length<0x2::object::ID>(&v1)) {
            0x2::vec_map::insert<0x2::object::ID, vector<0x1::type_name::TypeName>>(&mut v0, *0x1::vector::borrow<0x2::object::ID>(&v1, v2), distribution::reward::rewards_list(distribution::bribe_voting_reward::borrow_reward(distribution::voter::borrow_bribe_voting_reward<T0>(arg0, distribution::voter::pool_to_gauge<T0>(arg0, *0x1::vector::borrow<0x2::object::ID>(&v1, v2))))));
            v2 = v2 + 1;
        };
        let v3 = EventRewardTokens{list: v0};
        0x2::event::emit<EventRewardTokens>(v3);
    }
    
    public entry fun get_voting_bribe_reward_tokens_by_pool<T0>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID) {
        let v0 = 0x2::vec_map::empty<0x2::object::ID, vector<0x1::type_name::TypeName>>();
        0x2::vec_map::insert<0x2::object::ID, vector<0x1::type_name::TypeName>>(&mut v0, arg1, distribution::reward::rewards_list(distribution::bribe_voting_reward::borrow_reward(distribution::voter::borrow_bribe_voting_reward<T0>(arg0, distribution::voter::pool_to_gauge<T0>(arg0, arg1)))));
        let v1 = EventRewardTokens{list: v0};
        0x2::event::emit<EventRewardTokens>(v1);
    }
    
    public entry fun get_voting_fee_reward_tokens<T0>(arg0: &distribution::voter::Voter<T0>, arg1: 0x2::object::ID) {
        let v0 = 0x2::vec_map::empty<0x2::object::ID, vector<0x1::type_name::TypeName>>();
        let v1 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let v2 = 0;
        while (v2 < 0x1::vector::length<0x2::object::ID>(&v1)) {
            0x2::vec_map::insert<0x2::object::ID, vector<0x1::type_name::TypeName>>(&mut v0, *0x1::vector::borrow<0x2::object::ID>(&v1, v2), distribution::reward::rewards_list(distribution::fee_voting_reward::borrow_reward(distribution::voter::borrow_fee_voting_reward<T0>(arg0, distribution::voter::pool_to_gauge<T0>(arg0, *0x1::vector::borrow<0x2::object::ID>(&v1, v2))))));
            v2 = v2 + 1;
        };
        let v3 = EventRewardTokens{list: v0};
        0x2::event::emit<EventRewardTokens>(v3);
    }
    
    public entry fun notify_bribe_reward<T0, T1>(arg0: &mut distribution::voter::Voter<T0>, arg1: 0x2::object::ID, arg2: 0x2::coin::Coin<T1>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        distribution::bribe_voting_reward::notify_reward_amount<T1>(distribution::voter::borrow_bribe_voting_reward_mut<T0>(arg0, distribution::voter::pool_to_gauge<T0>(arg0, arg1)), 0x1::option::none<distribution::whitelisted_tokens::WhitelistedToken>(), arg2, arg3, arg4);
    }
    
    public entry fun pools_tally<T0>(arg0: &distribution::voter::Voter<T0>, arg1: vector<0x2::object::ID>) {
        let v0 = 0x1::vector::empty<PoolWeight>();
        let v1 = 0;
        while (v1 < 0x1::vector::length<0x2::object::ID>(&arg1)) {
            let v2 = PoolWeight{
                id     : *0x1::vector::borrow<0x2::object::ID>(&arg1, v1), 
                weight : distribution::voter::get_pool_weight<T0>(arg0, *0x1::vector::borrow<0x2::object::ID>(&arg1, v1)),
            };
            0x1::vector::push_back<PoolWeight>(&mut v0, v2);
            v1 = v1 + 1;
        };
        let v3 = PoolsTally{list: v0};
        0x2::event::emit<PoolsTally>(v3);
    }
    
    // decompiled from Move bytecode v6
}


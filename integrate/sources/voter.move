module integrate::voter {
    public struct EventDistributeReward has copy, drop, store {
        sender: address,
        gauge: sui::object::ID,
        amount: u64,
    }

    public struct EventRewardTokens has copy, drop, store {
        list: sui::vec_map::VecMap<sui::object::ID, vector<std::type_name::TypeName>>,
    }

    public struct ClaimableVotingBribes has copy, drop, store {
        data: sui::vec_map::VecMap<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>,
    }

    public struct PoolWeight has copy, drop, store {
        id: sui::object::ID,
        weight: u64,
    }

    public struct PoolsTally has copy, drop, store {
        list: vector<PoolWeight>,
    }

    public entry fun create<T0>(arg0: &sui::package::Publisher, arg1: &mut sui::tx_context::TxContext) {
        let mut v0 = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut v0, std::type_name::get<T0>());
        let (v1, v2) = distribution::voter::create<T0>(arg0, v0, arg1);
        sui::transfer::public_share_object<distribution::voter::Voter<T0>>(v1);
        sui::transfer::public_transfer<distribution::notify_reward_cap::NotifyRewardCap>(
            v2,
            sui::tx_context::sender(arg1)
        );
    }

    public entry fun create_gauge<T0, T1, T2>(
        arg0: &mut distribution::voter::Voter<T2>,
        arg1: &gauge_cap::gauge_cap::CreateCap,
        arg2: &distribution::voter_cap::GovernorCap,
        arg3: &distribution::voting_escrow::VotingEscrow<T2>,
        arg4: &mut clmm_pool::pool::Pool<T0, T1>,
        arg5: &sui::clock::Clock,
        arg6: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_share_object<distribution::gauge::Gauge<T0, T1, T2>>(
            distribution::voter::create_gauge<T0, T1, T2>(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
        );
    }

    public entry fun poke<T0>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &distribution::voting_escrow::Lock,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        distribution::voter::poke<T0>(arg0, arg1, arg2, arg3, arg4);
    }

    public entry fun vote<T0>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &distribution::voting_escrow::Lock,
        arg3: vector<sui::object::ID>,
        arg4: vector<u64>,
        arg5: &sui::clock::Clock,
        arg6: &mut sui::tx_context::TxContext
    ) {
        distribution::voter::vote<T0>(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
    }

    public fun claim_voting_bribes<T0, T1>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        mut arg2: vector<distribution::voting_escrow::Lock>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = 0;
        while (v0 < std::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            distribution::voter::claim_voting_bribe<T0, T1>(
                arg0,
                arg1,
                std::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0),
                arg3,
                arg4
            );
            v0 = v0 + 1;
        };
        while (std::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(
                std::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2),
                arg1,
                sui::tx_context::sender(arg4),
                arg3,
                arg4
            );
        };
        std::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }

    public fun claim_voting_bribes_2<T0, T1, T2>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        mut arg2: vector<distribution::voting_escrow::Lock>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = 0;
        while (v0 < std::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = std::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_bribe<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T2>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (std::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(
                std::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2),
                arg1,
                sui::tx_context::sender(arg4),
                arg3,
                arg4
            );
        };
        std::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }

    public fun claim_voting_bribes_3<T0, T1, T2, T3>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        mut arg2: vector<distribution::voting_escrow::Lock>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = 0;
        while (v0 < std::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = std::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_bribe<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T2>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_bribe<T0, T3>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (std::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(
                std::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2),
                arg1,
                sui::tx_context::sender(arg4),
                arg3,
                arg4
            );
        };
        std::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }

    public fun claim_voting_fee_rewards<T0, T1, T2>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        mut arg2: vector<distribution::voting_escrow::Lock>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = 0;
        while (v0 < std::vector::length<distribution::voting_escrow::Lock>(&arg2)) {
            let v1 = std::vector::borrow<distribution::voting_escrow::Lock>(&arg2, v0);
            distribution::voter::claim_voting_fee_reward<T0, T1>(arg0, arg1, v1, arg3, arg4);
            distribution::voter::claim_voting_fee_reward<T0, T2>(arg0, arg1, v1, arg3, arg4);
            v0 = v0 + 1;
        };
        while (std::vector::length<distribution::voting_escrow::Lock>(&arg2) > 0) {
            distribution::voting_escrow::transfer<T0>(
                std::vector::pop_back<distribution::voting_escrow::Lock>(&mut arg2),
                arg1,
                sui::tx_context::sender(arg4),
                arg3,
                arg4
            );
        };
        std::vector::destroy_empty<distribution::voting_escrow::Lock>(arg2);
    }

    public fun claim_voting_fee_rewards_single<T0, T1, T2>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: &mut distribution::voting_escrow::VotingEscrow<T0>,
        arg2: &distribution::voting_escrow::Lock,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        distribution::voter::claim_voting_fee_reward<T0, T1>(arg0, arg1, arg2, arg3, arg4);
        distribution::voter::claim_voting_fee_reward<T0, T2>(arg0, arg1, arg2, arg3, arg4);
    }

    public fun claimable_voting_bribes<T0, T1>(
        arg0: &distribution::voter::Voter<T0>,
        arg1: sui::object::ID,
        arg2: &sui::clock::Clock
    ) {
        let mut v0 = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T1>(),
            claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2)
        );
        let v1 = ClaimableVotingBribes { data: v0 };
        sui::event::emit<ClaimableVotingBribes>(v1);
    }

    public fun claimable_voting_bribes_2<T0, T1, T2>(
        arg0: &distribution::voter::Voter<T0>,
        arg1: sui::object::ID,
        arg2: &sui::clock::Clock
    ) {
        let mut v0 = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T1>(),
            claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2)
        );
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T2>(),
            claimable_voting_bribes_internal<T0, T2>(arg0, arg1, arg2)
        );
        let v1 = ClaimableVotingBribes { data: v0 };
        sui::event::emit<ClaimableVotingBribes>(v1);
    }

    public fun claimable_voting_bribes_3<T0, T1, T2, T3>(
        arg0: &distribution::voter::Voter<T0>,
        arg1: sui::object::ID,
        arg2: &sui::clock::Clock
    ) {
        let mut v0 = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T1>(),
            claimable_voting_bribes_internal<T0, T1>(arg0, arg1, arg2)
        );
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T2>(),
            claimable_voting_bribes_internal<T0, T2>(arg0, arg1, arg2)
        );
        sui::vec_map::insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            &mut v0,
            std::type_name::get<T3>(),
            claimable_voting_bribes_internal<T0, T3>(arg0, arg1, arg2)
        );
        let v1 = ClaimableVotingBribes { data: v0 };
        sui::event::emit<ClaimableVotingBribes>(v1);
    }

    fun claimable_voting_bribes_internal<T0, T1>(
        arg0: &distribution::voter::Voter<T0>,
        arg1: sui::object::ID,
        arg2: &sui::clock::Clock
    ): sui::vec_map::VecMap<sui::object::ID, u64> {
        let v0 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let mut v1 = 0;
        let mut v2 = sui::vec_map::empty<sui::object::ID, u64>();
        while (v1 < std::vector::length<sui::object::ID>(&v0)) {
            let v3 = *std::vector::borrow<sui::object::ID>(&v0, v1);
            sui::vec_map::insert<sui::object::ID, u64>(
                &mut v2,
                v3,
                distribution::bribe_voting_reward::earned<T1>(
                    distribution::voter::borrow_bribe_voting_reward<T0>(
                        arg0,
                        distribution::voter::pool_to_gauge<T0>(arg0, v3)
                    ),
                    arg1,
                    arg2
                )
            );
            v1 = v1 + 1;
        };
        v2
    }

    public entry fun distribute<T0, T1, T2>(
        arg0: &mut distribution::minter::Minter<T2>,
        arg1: &mut distribution::voter::Voter<T2>,
        arg2: &mut distribution::voting_escrow::VotingEscrow<T2>,
        arg3: &mut distribution::reward_distributor::RewardDistributor<T2>,
        arg4: &mut distribution::gauge::Gauge<T0, T1, T2>,
        arg5: &mut clmm_pool::pool::Pool<T0, T1>,
        arg6: &sui::clock::Clock,
        arg7: &mut sui::tx_context::TxContext
    ) {
        if (distribution::minter::active_period<T2>(arg0) + 604800 < distribution::common::current_timestamp(arg6)) {
            distribution::minter::update_period<T2>(arg0, arg1, arg2, arg3, arg6, arg7);
        };
        assert!(
            distribution::gauge::pool_id<T0, T1, T2>(arg4) == sui::object::id<clmm_pool::pool::Pool<T0, T1>>(arg5),
            9223373041877123071
        );
        let v0 = EventDistributeReward {
            sender: sui::tx_context::sender(arg7),
            gauge: sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg4),
            amount: distribution::voter::distribute_gauge<T0, T1, T2>(arg1, arg4, arg5, arg6, arg7),
        };
        sui::event::emit<EventDistributeReward>(v0);
    }

    public entry fun get_voting_bribe_reward_tokens<T0>(arg0: &distribution::voter::Voter<T0>, arg1: sui::object::ID) {
        let mut v0 = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        let v1 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let mut v2 = 0;
        while (v2 < std::vector::length<sui::object::ID>(&v1)) {
            sui::vec_map::insert<sui::object::ID, vector<std::type_name::TypeName>>(
                &mut v0,
                *std::vector::borrow<sui::object::ID>(&v1, v2),
                distribution::reward::rewards_list(
                    distribution::bribe_voting_reward::borrow_reward(
                        distribution::voter::borrow_bribe_voting_reward<T0>(
                            arg0,
                            distribution::voter::pool_to_gauge<T0>(arg0, *std::vector::borrow<sui::object::ID>(&v1, v2))
                        )
                    )
                )
            );
            v2 = v2 + 1;
        };
        let v3 = EventRewardTokens { list: v0 };
        sui::event::emit<EventRewardTokens>(v3);
    }

    public entry fun get_voting_bribe_reward_tokens_by_pool<T0>(
        arg0: &distribution::voter::Voter<T0>,
        arg1: sui::object::ID
    ) {
        let mut v0 = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        sui::vec_map::insert<sui::object::ID, vector<std::type_name::TypeName>>(
            &mut v0,
            arg1,
            distribution::reward::rewards_list(
                distribution::bribe_voting_reward::borrow_reward(
                    distribution::voter::borrow_bribe_voting_reward<T0>(
                        arg0,
                        distribution::voter::pool_to_gauge<T0>(arg0, arg1)
                    )
                )
            )
        );
        let v1 = EventRewardTokens { list: v0 };
        sui::event::emit<EventRewardTokens>(v1);
    }

    public entry fun get_voting_fee_reward_tokens<T0>(arg0: &distribution::voter::Voter<T0>, arg1: sui::object::ID) {
        let mut v0 = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        let v1 = distribution::voter::voted_pools<T0>(arg0, arg1);
        let mut v2 = 0;
        while (v2 < std::vector::length<sui::object::ID>(&v1)) {
            sui::vec_map::insert<sui::object::ID, vector<std::type_name::TypeName>>(
                &mut v0,
                *std::vector::borrow<sui::object::ID>(&v1, v2),
                distribution::reward::rewards_list(
                    distribution::fee_voting_reward::borrow_reward(
                        distribution::voter::borrow_fee_voting_reward<T0>(
                            arg0,
                            distribution::voter::pool_to_gauge<T0>(arg0, *std::vector::borrow<sui::object::ID>(&v1, v2))
                        )
                    )
                )
            );
            v2 = v2 + 1;
        };
        let v3 = EventRewardTokens { list: v0 };
        sui::event::emit<EventRewardTokens>(v3);
    }

    public entry fun notify_bribe_reward<T0, T1>(
        arg0: &mut distribution::voter::Voter<T0>,
        arg1: sui::object::ID,
        arg2: sui::coin::Coin<T1>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let gauge = distribution::voter::pool_to_gauge<T0>(arg0, arg1);
        distribution::bribe_voting_reward::notify_reward_amount<T1>(
            distribution::voter::borrow_bribe_voting_reward_mut<T0>(arg0, gauge),
            std::option::none<distribution::whitelisted_tokens::WhitelistedToken>(),
            arg2,
            arg3,
            arg4
        );
    }

    public entry fun pools_tally<T0>(arg0: &distribution::voter::Voter<T0>, arg1: vector<sui::object::ID>) {
        let mut v0 = std::vector::empty<PoolWeight>();
        let mut v1 = 0;
        while (v1 < std::vector::length<sui::object::ID>(&arg1)) {
            let v2 = PoolWeight {
                id: *std::vector::borrow<sui::object::ID>(&arg1, v1),
                weight: distribution::voter::get_pool_weight<T0>(
                    arg0,
                    *std::vector::borrow<sui::object::ID>(&arg1, v1)
                ),
            };
            std::vector::push_back<PoolWeight>(&mut v0, v2);
            v1 = v1 + 1;
        };
        let v3 = PoolsTally { list: v0 };
        sui::event::emit<PoolsTally>(v3);
    }

    // decompiled from Move bytecode v6
}


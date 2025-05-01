module integrate::voter {
    use sui::transfer::public_transfer;

    const EDistributeInccorectGaugePool: u64 = 9223373041877123071;

    public struct EventDistributeReward has copy, drop, store {
        sender: address,
        gauge: ID,
        amount: u64,
    }

    public struct EventRewardTokens has copy, drop, store {
        list: sui::vec_map::VecMap<ID, vector<std::type_name::TypeName>>,
    }

    public struct ClaimableVotingBribes has copy, drop, store {
        data: sui::vec_map::VecMap<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>,
    }

    public struct ClaimableVotingFees has copy, drop, store {
        data: sui::vec_map::VecMap<std::type_name::TypeName, u64>,
    }

    public struct PoolWeight has copy, drop, store {
        id: ID,
        weight: u64,
    }

    public struct PoolsTally has copy, drop, store {
        list: vector<PoolWeight>,
    }

    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        global_config: ID,
        distribution_config: ID,
        ctx: &mut TxContext
    ) {
        let (voter, notify_reward_cap) = distribution::voter::create(
            publisher,
            global_config,
            distribution_config,
            ctx
        );
        transfer::public_share_object<distribution::voter::Voter>(voter);
        transfer::public_transfer<distribution::notify_reward_cap::NotifyRewardCap>(
            notify_reward_cap,
            tx_context::sender(ctx)
        );
    }

    public entry fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut distribution::voter::Voter,
        distribtuion_config: &mut distribution::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        governor_cap: &distribution::voter_cap::GovernorCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        transfer::public_share_object<distribution::gauge::Gauge<CoinTypeA, CoinTypeB>>(
            voter.create_gauge(distribtuion_config, create_cap, governor_cap, voting_escrow, pool, clock, ctx)
        );
    }

    public entry fun poke<SailCoinType>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.poke(voting_escrow, distribtuion_config, lock, clock, ctx);
    }

    public entry fun vote<SailCoinType>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        pools: vector<ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.vote(voting_escrow, distribtuion_config, lock, pools, weights, clock, ctx);
    }

    public fun batch_vote<SailCoinType> (
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        mut locks: vector<distribution::voting_escrow::Lock>,
        pools: vector<ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        let mut i = 0;
        let len = locks.length();
        while (i < len) {
            let lock = locks.pop_back();
            voter.vote(voting_escrow, distribtuion_config, &lock, pools, weights, clock, ctx);
            i = i + 1;
            public_transfer(lock, ctx.sender());
        };
        locks.destroy_empty()
    }

    public fun claim_voting_bribes<SailCoinType, BribeCoinType>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            voter.claim_voting_bribe<SailCoinType, BribeCoinType>(voting_escrow, locks.borrow(i), clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_bribes_2<SailCoinType, BribeCoinType1, BribeCoinType2>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType1>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType2>(voting_escrow, lock, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_bribes_3<SailCoinType, BribeCoinType1, BribeCoinType2, BribeCoinType3>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut lock: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < lock.length()) {
            let lock = lock.borrow(i);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType1>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType2>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType3>(voting_escrow, lock, clock, ctx);
            i = i + 1;
        };
        while (lock.length() > 0) {
            lock.pop_back().transfer(voting_escrow, tx_context::sender(ctx), clock, ctx);
        };
        lock.destroy_empty();
    }

    public fun claim_voting_fee_rewards<SailCoinType, RewardCoinType1, RewardCoinType2>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_fee_reward<SailCoinType, RewardCoinType1>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_fee_reward<SailCoinType, RewardCoinType2>(voting_escrow, lock, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_fee_rewards_single<SailCoinType, RewardCoinType1, RewardCoinType2>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.claim_voting_fee_reward<SailCoinType, RewardCoinType1>(voting_escrow, lock, clock, ctx);
        voter.claim_voting_fee_reward<SailCoinType, RewardCoinType2>(voting_escrow, lock, clock, ctx);
    }

    public fun claimable_voting_bribes<SailCoinType, BribeCoinType>(
        voter: &distribution::voter::Voter,
        lock_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    public fun claimable_voting_bribes_2<SailCoinType, BribeCoinType1, BribeCoinType2>(
        voter: &distribution::voter::Voter,
        lock_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType1>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType1>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType2>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType2>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    public fun claimable_voting_bribes_3<SailCoinType, BribeCoinType1, BribeCoinType2, BribeCoinType3>(
        voter: &distribution::voter::Voter,
        lock_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType1>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType1>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType2>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType2>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<ID, u64>>(
            std::type_name::get<BribeCoinType3>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType3>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    fun claimable_voting_bribes_internal<SailCoinType, BribeCoinType>(
        voter: &distribution::voter::Voter,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): sui::vec_map::VecMap<ID, u64> {
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        let mut reward_by_pool = sui::vec_map::empty<ID, u64>();
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            reward_by_pool.insert<ID, u64>(
                pool_id,
                voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).earned<BribeCoinType>(lock_id, clock)
            );
            i = i + 1;
        };
        reward_by_pool
    }

    public entry fun distribute<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (minter.active_period() + distribution::common::week() < distribution::common::current_timestamp(clock)) {
            minter.update_period(voter, voting_escrow, reward_distributor, clock, ctx);
        };
        assert!(
            gauge.pool_id() == object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            EDistributeInccorectGaugePool
        );
        let event_distribute_reward = EventDistributeReward {
            sender: tx_context::sender(ctx),
            gauge: object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge),
            amount: voter.distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType>(distribtuion_config, gauge, pool, clock, ctx),
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

    public entry fun get_voting_bribe_reward_tokens<SailCoinType>(
        voter: &distribution::voter::Voter,
        lock_id: ID
    ) {
        let mut bribe_tokens_by_pool = sui::vec_map::empty<ID, vector<std::type_name::TypeName>>();
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            bribe_tokens_by_pool.insert<ID, vector<std::type_name::TypeName>>(
                pool_id,
                voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
            );
            i = i + 1;
        };
        let reward_tokens_event = EventRewardTokens { list: bribe_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    public entry fun get_voting_bribe_reward_tokens_by_pool<SailCoinType>(
        voter: &distribution::voter::Voter,
        pool_id: ID
    ) {
        let mut bribe_tokens_by_pool = sui::vec_map::empty<ID, vector<std::type_name::TypeName>>();
        bribe_tokens_by_pool.insert<ID, vector<std::type_name::TypeName>>(pool_id,
            voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
        );
        let reward_tokens_event = EventRewardTokens { list: bribe_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    public entry fun get_voting_fee_reward_tokens<SailCoinType>(voter: &distribution::voter::Voter, lock_id: ID) {
        let mut reward_tokens_by_pool = sui::vec_map::empty<ID, vector<std::type_name::TypeName>>();
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            reward_tokens_by_pool.insert<ID, vector<std::type_name::TypeName>>(
                pool_id,
                voter.borrow_fee_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
            );
            i = i + 1;
        };
        let reward_tokens_event = EventRewardTokens { list: reward_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    fun claimable_voting_fees_internal<SailCoinType, FeeCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter
            .borrow_fee_voting_reward(voter.pool_to_gauge(pool_id))
            .earned<FeeCoinType>(lock_id, clock)
    }

    public fun claimable_voting_fees_1<SailCoinType, FeeCoinType1>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_fees = sui::vec_map::empty<std::type_name::TypeName, u64>();
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType1>(),
            claimable_voting_fees_internal<SailCoinType, FeeCoinType1>(voter, lock_id, pool_id, clock)
        );
        let claimable_fees_event = ClaimableVotingFees { data: claimable_fees };
        sui::event::emit<ClaimableVotingFees>(claimable_fees_event);
    }

    public fun claimable_voting_fees_2<SailCoinType, FeeCoinType1, FeeCoinType2>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_fees = sui::vec_map::empty<std::type_name::TypeName, u64>();
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType1>(),
            claimable_voting_fees_internal<SailCoinType, FeeCoinType1>(voter, lock_id, pool_id, clock)
        );
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType2>(),
            claimable_voting_fees_internal<SailCoinType, FeeCoinType2>(voter, lock_id, pool_id, clock)
        );
        let claimable_fees_event = ClaimableVotingFees { data: claimable_fees };
        sui::event::emit<ClaimableVotingFees>(claimable_fees_event);
    }
    
    public entry fun notify_bribe_reward<SailCoinType, BribeCoinType>(
        voter: &mut distribution::voter::Voter,
        pool_id: ID,
        reward_coin: sui::coin::Coin<BribeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let gauge = voter.pool_to_gauge(pool_id);
        voter.borrow_bribe_voting_reward_mut(gauge).notify_reward_amount(
            option::none<distribution::whitelisted_tokens::WhitelistedToken>(),
            reward_coin,
            clock,
            ctx
        );
    }

    public entry fun pools_tally<SailCoinType>(voter: &distribution::voter::Voter, pool_ids: vector<ID>) {
        let mut pool_weights = std::vector::empty<PoolWeight>();
        let mut i = 0;
        while (i < pool_ids.length()) {
            let v2 = PoolWeight {
                id: pool_ids[i],
                weight: voter.get_pool_weight(pool_ids[i]),
            };
            pool_weights.push_back(v2);
            i = i + 1;
        };
        let pools_tally = PoolsTally { list: pool_weights };
        sui::event::emit<PoolsTally>(pools_tally);
    }
}


module integrate::voter {

    const EDistributeInccorectGaugePool: u64 = 9223373041877123071;

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

    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        global_config: sui::object::ID,
        distribution_config: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut supported_coins = std::vector::empty<std::type_name::TypeName>();
        supported_coins.push_back(std::type_name::get<SailCoinType>());
        let (voter, notify_reward_cap) = distribution::voter::create<SailCoinType>(
            publisher,
            global_config,
            distribution_config,
            supported_coins,
            ctx
        );
        sui::transfer::public_share_object<distribution::voter::Voter<SailCoinType>>(voter);
        sui::transfer::public_transfer<distribution::notify_reward_cap::NotifyRewardCap>(
            notify_reward_cap,
            sui::tx_context::sender(ctx)
        );
    }

    public entry fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        distribtuion_config: &mut distribution::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        governor_cap: &distribution::voter_cap::GovernorCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_share_object<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(
            voter.create_gauge(distribtuion_config, create_cap, governor_cap, voting_escrow, pool, clock, ctx)
        );
    }

    public entry fun poke<SailCoinType>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        voter.poke(voting_escrow, distribtuion_config, lock, clock, ctx);
    }

    public entry fun vote<SailCoinType>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &distribution::voting_escrow::Lock,
        pools: vector<sui::object::ID>,
        weights: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        voter.vote(voting_escrow, distribtuion_config, lock, pools, weights, clock, ctx);
    }

    public fun claim_voting_bribes<SailCoinType, BribeCoinType>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            voter.claim_voting_bribe<SailCoinType, BribeCoinType>(voting_escrow, locks.borrow(i), clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, sui::tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_bribes_2<SailCoinType, BribeCoinType1, BribeCoinType2>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType1>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_bribe<SailCoinType, BribeCoinType2>(voting_escrow, lock, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, sui::tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_bribes_3<SailCoinType, BribeCoinType1, BribeCoinType2, BribeCoinType3>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut lock: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
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
            lock.pop_back().transfer(voting_escrow, sui::tx_context::sender(ctx), clock, ctx);
        };
        lock.destroy_empty();
    }

    public fun claim_voting_fee_rewards<SailCoinType, RewardCoinType1, RewardCoinType2>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<distribution::voting_escrow::Lock>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_fee_reward<SailCoinType, RewardCoinType1>(voting_escrow, lock, clock, ctx);
            voter.claim_voting_fee_reward<SailCoinType, RewardCoinType2>(voting_escrow, lock, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, sui::tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_fee_rewards_single<SailCoinType, RewardCoinType1, RewardCoinType2>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        voter.claim_voting_fee_reward<SailCoinType, RewardCoinType1>(voting_escrow, lock, clock, ctx);
        voter.claim_voting_fee_reward<SailCoinType, RewardCoinType2>(voting_escrow, lock, clock, ctx);
    }

    public fun claimable_voting_bribes<SailCoinType, BribeCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    public fun claimable_voting_bribes_2<SailCoinType, BribeCoinType1, BribeCoinType2>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType1>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType1>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType2>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType2>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    public fun claimable_voting_bribes_3<SailCoinType, BribeCoinType1, BribeCoinType2, BribeCoinType3>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_bribes = sui::vec_map::empty<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>();
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType1>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType1>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType2>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType2>(voter, lock_id, clock)
        );
        claimable_bribes.insert<std::type_name::TypeName, sui::vec_map::VecMap<sui::object::ID, u64>>(
            std::type_name::get<BribeCoinType3>(),
            claimable_voting_bribes_internal<SailCoinType, BribeCoinType3>(voter, lock_id, clock)
        );
        let claimable_bribes_event = ClaimableVotingBribes { data: claimable_bribes };
        sui::event::emit<ClaimableVotingBribes>(claimable_bribes_event);
    }

    fun claimable_voting_bribes_internal<SailCoinType, BribeCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): sui::vec_map::VecMap<sui::object::ID, u64> {
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        let mut reward_by_pool = sui::vec_map::empty<sui::object::ID, u64>();
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            reward_by_pool.insert<sui::object::ID, u64>(
                pool_id,
                voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).earned<BribeCoinType>(lock_id, clock)
            );
            i = i + 1;
        };
        reward_by_pool
    }

    public entry fun distribute<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        if (minter.active_period() + 604800 < distribution::common::current_timestamp(clock)) {
            minter.update_period(voter, voting_escrow, reward_distributor, clock, ctx);
        };
        assert!(
            gauge.pool_id() == sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            EDistributeInccorectGaugePool
        );
        let event_distribute_reward = EventDistributeReward {
            sender: sui::tx_context::sender(ctx),
            gauge: sui::object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            amount: voter.distribute_gauge(distribtuion_config, gauge, pool, clock, ctx),
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

    public entry fun get_voting_bribe_reward_tokens<SailCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        lock_id: sui::object::ID
    ) {
        let mut bribe_tokens_by_pool = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            bribe_tokens_by_pool.insert<sui::object::ID, vector<std::type_name::TypeName>>(
                pool_id,
                voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
            );
            i = i + 1;
        };
        let reward_tokens_event = EventRewardTokens { list: bribe_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    public entry fun get_voting_bribe_reward_tokens_by_pool<SailCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        pool_id: sui::object::ID
    ) {
        let mut bribe_tokens_by_pool = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        bribe_tokens_by_pool.insert<sui::object::ID, vector<std::type_name::TypeName>>(pool_id,
            voter.borrow_bribe_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
        );
        let reward_tokens_event = EventRewardTokens { list: bribe_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    public entry fun get_voting_fee_reward_tokens<SailCoinType>(voter: &distribution::voter::Voter<SailCoinType>, lock_id: sui::object::ID) {
        let mut reward_tokens_by_pool = sui::vec_map::empty<sui::object::ID, vector<std::type_name::TypeName>>();
        let voted_pools_ids = voter.voted_pools(lock_id);
        let mut i = 0;
        while (i < voted_pools_ids.length()) {
            let pool_id = voted_pools_ids[i];
            reward_tokens_by_pool.insert<sui::object::ID, vector<std::type_name::TypeName>>(
                pool_id,
                voter.borrow_fee_voting_reward(voter.pool_to_gauge(pool_id)).borrow_reward().rewards_list()
            );
            i = i + 1;
        };
        let reward_tokens_event = EventRewardTokens { list: reward_tokens_by_pool };
        sui::event::emit<EventRewardTokens>(reward_tokens_event);
    }

    public entry fun notify_bribe_reward<SailCoinType, BribeCoinType>(
        voter: &mut distribution::voter::Voter<SailCoinType>,
        pool_id: sui::object::ID,
        reward_coin: sui::coin::Coin<BribeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let gauge = voter.pool_to_gauge(pool_id);
        voter.borrow_bribe_voting_reward_mut(gauge).notify_reward_amount(
            std::option::none<distribution::whitelisted_tokens::WhitelistedToken>(),
            reward_coin,
            clock,
            ctx
        );
    }

    public entry fun pools_tally<SailCoinType>(voter: &distribution::voter::Voter<SailCoinType>, pool_ids: vector<sui::object::ID>) {
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


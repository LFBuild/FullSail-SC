module integrate::voter {
    use sui::transfer::public_transfer;

    const EDistributeInccorectGaugePool: u64 = 9223373041877123071;
    const EDistributeInvalidPeriod: u64 = 93972037923406333;

    public struct EventDistributeReward has copy, drop, store {
        sender: address,
        gauge: ID,
        amount: u64,
    }

    public struct EventRewardTokens has copy, drop, store {
        list: sui::vec_map::VecMap<ID, vector<std::type_name::TypeName>>,
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

    public entry fun create(
        publisher: &sui::package::Publisher,
        global_config: ID,
        distribution_config: ID,
        ctx: &mut TxContext
    ) {
        let (voter, distribution_cap) = governance::voter::create(
            publisher,
            global_config,
            distribution_config,
            ctx
        );
        transfer::public_share_object<governance::voter::Voter>(voter);
        transfer::public_transfer<governance::distribute_cap::DistributeCap>(
            distribution_cap,
            tx_context::sender(ctx)
        );
    }

    public entry fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut governance::minter::Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribtuion_config: &mut governance::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        admin_cap: &governance::minter::AdminCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        transfer::public_share_object<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(
            minter.create_gauge(
                voter,
                distribtuion_config, 
                create_cap, 
                admin_cap, 
                voting_escrow,
                pool, 
                gauge_base_emissions,
                clock, 
                ctx
            )
        );
    }

    public entry fun poke<SailCoinType>(
        voter: &mut governance::voter::Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &governance::distribution_config::DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.poke(voting_escrow, distribtuion_config, object::id(lock), clock, ctx);
    }

    public entry fun vote<SailCoinType>(
        voter: &mut governance::voter::Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &governance::distribution_config::DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        pools: vector<ID>,
        weights: vector<u64>,
        volumes: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.vote(
            voting_escrow, 
            distribtuion_config, 
            lock, 
            pools, 
            weights, 
            volumes,
            clock, 
            ctx
        );
    }

    public fun batch_vote<SailCoinType> (
        voter: &mut governance::voter::Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &governance::distribution_config::DistributionConfig,
        mut locks: vector<voting_escrow::voting_escrow::Lock>,
        pools: vector<ID>,
        weights: vector<u64>,
        volumes: vector<u64>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        let mut i = 0;
        let len = locks.length();
        while (i < len) {
            let lock = locks.pop_back();
            voter.vote(voting_escrow, distribtuion_config, &lock, pools, weights, volumes, clock, ctx);
            transfer::public_transfer<voting_escrow::voting_escrow::Lock>(lock, ctx.sender());
            i = i + 1;
        };
        locks.destroy_empty()
    }

    public fun claim_voting_fee_rewards<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &mut governance::voter::Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        mut locks: vector<voting_escrow::voting_escrow::Lock>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_fee_by_pool<CoinTypeA, CoinTypeB, SailCoinType>(voting_escrow, distribution_config, lock, pool, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            transfer::public_transfer<voting_escrow::voting_escrow::Lock>(locks.pop_back(), tx_context::sender(ctx));
        };
        locks.destroy_empty();
    }

    public fun claim_voting_fee_rewards_single<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &mut governance::voter::Voter,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        lock: &voting_escrow::voting_escrow::Lock,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.claim_voting_fee_by_pool<CoinTypeA, CoinTypeB, SailCoinType>(voting_escrow, distribution_config, lock, pool, clock, ctx);
    }


    public entry fun distribute<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType, EpochOSail>(
        minter: &mut governance::minter::Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribute_governor_cap: &governance::minter::DistributeGovernorCap,
        distribtuion_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        next_epoch_emissions_usd: u64,
        price_monitor: &mut price_monitor::price_monitor::PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (minter.active_period() + voting_escrow::common::epoch() < voting_escrow::common::current_timestamp(clock)) {
            abort EDistributeInvalidPeriod;
        };
        assert!(
            gauge.pool_id() == object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            EDistributeInccorectGaugePool
        );
        minter.distribute_gauge<
            CoinTypeA,
            CoinTypeB,
            SailPoolCoinTypeA,
            SailPoolCoinTypeB,
            SailCoinType,
            EpochOSail
        >(
            voter,
            distribute_governor_cap,
            distribtuion_config,
            gauge,
            pool,
            next_epoch_emissions_usd,
            price_monitor,
            sail_stablecoin_pool,
            aggregator,
            clock,
            ctx
        );
        let event_distribute_reward = EventDistributeReward {
            sender: tx_context::sender(ctx),
            gauge: object::id<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge),
            amount: next_epoch_emissions_usd,
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

public entry fun distribute_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        minter: &mut governance::minter::Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribute_governor_cap: &governance::minter::DistributeGovernorCap,
        distribtuion_config: &governance::distribution_config::DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        next_epoch_emissions_usd: u64,
        price_monitor: &mut price_monitor::price_monitor::PriceMonitor,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (minter.active_period() + voting_escrow::common::epoch() < voting_escrow::common::current_timestamp(clock)) {
            abort EDistributeInvalidPeriod
        };
        assert!(
            gauge.pool_id() == object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(sail_pool),
            EDistributeInccorectGaugePool
        );
        minter.distribute_gauge_for_sail_pool<
            CoinTypeA,
            CoinTypeB,
            SailCoinType,
            EpochOSail
        >(
            voter,
            distribute_governor_cap,
            distribtuion_config,
            gauge,
            sail_pool,
            next_epoch_emissions_usd,
            price_monitor,
            aggregator,
            clock,
            ctx
        );
        let event_distribute_reward = EventDistributeReward {
            sender: tx_context::sender(ctx),
            gauge: object::id<governance::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge),
            amount: next_epoch_emissions_usd,
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

    public entry fun get_voting_fee_reward_tokens(voter: &governance::voter::Voter, lock_id: ID) {
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

    fun claimable_voting_fees_internal<FeeCoinType>(
        voter: &governance::voter::Voter,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter
            .borrow_fee_voting_reward(voter.pool_to_gauge(pool_id))
            .earned<FeeCoinType>(lock_id, clock)
    }

    public fun claimable_voting_fees_1<FeeCoinType1>(
        voter: &governance::voter::Voter,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_fees = sui::vec_map::empty<std::type_name::TypeName, u64>();
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType1>(),
            claimable_voting_fees_internal<FeeCoinType1>(voter, lock_id, pool_id, clock)
        );
        let claimable_fees_event = ClaimableVotingFees { data: claimable_fees };
        sui::event::emit<ClaimableVotingFees>(claimable_fees_event);
    }

    public fun claimable_voting_fees_2<FeeCoinType1, FeeCoinType2>(
        voter: &governance::voter::Voter,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ) {
        let mut claimable_fees = sui::vec_map::empty<std::type_name::TypeName, u64>();
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType1>(),
            claimable_voting_fees_internal<FeeCoinType1>(voter, lock_id, pool_id, clock)
        );
        claimable_fees.insert<std::type_name::TypeName, u64>(
            std::type_name::get<FeeCoinType2>(),
            claimable_voting_fees_internal<FeeCoinType2>(voter, lock_id, pool_id, clock)
        );
        let claimable_fees_event = ClaimableVotingFees { data: claimable_fees };
        sui::event::emit<ClaimableVotingFees>(claimable_fees_event);
    }

    public entry fun pools_tally(voter: &governance::voter::Voter, pool_ids: vector<ID>) {
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


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
        let (voter, distribution_cap) = distribution::voter::create(
            publisher,
            global_config,
            distribution_config,
            ctx
        );
        transfer::public_share_object<distribution::voter::Voter>(voter);
        transfer::public_transfer<distribution::distribute_cap::DistributeCap>(
            distribution_cap,
            tx_context::sender(ctx)
        );
    }

    public entry fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribtuion_config: &mut distribution::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        admin_cap: &distribution::minter::AdminCap,
        voting_escrow: &ve::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        transfer::public_share_object<distribution::gauge::Gauge<CoinTypeA, CoinTypeB>>(
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
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &ve::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.poke(voting_escrow, distribtuion_config, object::id(lock), clock, ctx);
    }

    public entry fun vote<SailCoinType>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        lock: &ve::voting_escrow::Lock,
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
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        mut locks: vector<ve::voting_escrow::Lock>,
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
            lock.transfer(voting_escrow, ctx.sender(), clock, ctx);
            i = i + 1;
        };
        locks.destroy_empty()
    }

    public fun claim_voting_fee_rewards<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        mut locks: vector<ve::voting_escrow::Lock>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < locks.length()) {
            let lock = locks.borrow(i);
            voter.claim_voting_fee_by_pool<CoinTypeA, CoinTypeB, SailCoinType>(voting_escrow, lock, pool, clock, ctx);
            i = i + 1;
        };
        while (locks.length() > 0) {
            locks.pop_back().transfer(voting_escrow, tx_context::sender(ctx), clock, ctx);
        };
        locks.destroy_empty();
    }

    public fun claim_voting_fee_rewards_single<SailCoinType, CoinTypeA, CoinTypeB>(
        voter: &mut distribution::voter::Voter,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &ve::voting_escrow::Lock,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voter.claim_voting_fee_by_pool<CoinTypeA, CoinTypeB, SailCoinType>(voting_escrow, lock, pool, clock, ctx);
    }


    public entry fun distribute<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType, EpochOSail>(
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribute_governor_cap: &distribution::minter::DistributeGovernorCap,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        prev_epoch_pool_emissions_usd: u64,
        prev_epoch_pool_fees_usd: u64,
        epoch_pool_emissions_usd: u64,
        epoch_pool_fees_usd: u64,
        epoch_pool_volume_usd: u64,
        epoch_pool_predicted_volume_usd: u64,
        price_monitor: &mut price_monitor::price_monitor::PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (minter.active_period() + ve::common::epoch() < ve::common::current_timestamp(clock)) {
            abort EDistributeInvalidPeriod
        };
        assert!(
            gauge.pool_id() == object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool),
            EDistributeInccorectGaugePool
        );
        let event_distribute_reward = EventDistributeReward {
            sender: tx_context::sender(ctx),
            gauge: object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge),
            amount: minter.distribute_gauge<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType, EpochOSail>(
                voter,
                distribute_governor_cap,
                distribtuion_config,
                gauge,
                pool,
                prev_epoch_pool_emissions_usd,
                prev_epoch_pool_fees_usd,
                epoch_pool_emissions_usd,
                epoch_pool_fees_usd,
                epoch_pool_volume_usd,
                epoch_pool_predicted_volume_usd,
                price_monitor,
                sail_stablecoin_pool,
                aggregator,
                clock,
                ctx
            ),
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

public entry fun distribute_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribute_governor_cap: &distribution::minter::DistributeGovernorCap,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        prev_epoch_pool_emissions_usd: u64,
        prev_epoch_pool_fees_usd: u64,
        epoch_pool_emissions_usd: u64,
        epoch_pool_fees_usd: u64,
        epoch_pool_volume_usd: u64,
        epoch_pool_predicted_volume_usd: u64,
        price_monitor: &mut price_monitor::price_monitor::PriceMonitor,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (minter.active_period() + ve::common::epoch() < ve::common::current_timestamp(clock)) {
            abort EDistributeInvalidPeriod
        };
        assert!(
            gauge.pool_id() == object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(sail_pool),
            EDistributeInccorectGaugePool
        );
        let event_distribute_reward = EventDistributeReward {
            sender: tx_context::sender(ctx),
            gauge: object::id<distribution::gauge::Gauge<CoinTypeA, CoinTypeB>>(gauge),
            amount: minter.distribute_gauge_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
                voter,
                distribute_governor_cap,
                distribtuion_config,
                gauge,
                sail_pool,
                prev_epoch_pool_emissions_usd,
                prev_epoch_pool_fees_usd,
                epoch_pool_emissions_usd,
                epoch_pool_fees_usd,
                epoch_pool_volume_usd,
                epoch_pool_predicted_volume_usd,
                price_monitor,
                aggregator,
                clock,
                ctx
            ),
        };
        sui::event::emit<EventDistributeReward>(event_distribute_reward);
    }

    public entry fun get_voting_fee_reward_tokens(voter: &distribution::voter::Voter, lock_id: ID) {
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
        voter: &distribution::voter::Voter,
        lock_id: ID,
        pool_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        voter
            .borrow_fee_voting_reward(voter.pool_to_gauge(pool_id))
            .earned<FeeCoinType>(lock_id, clock)
    }

    public fun claimable_voting_fees_1<FeeCoinType1>(
        voter: &distribution::voter::Voter,
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
        voter: &distribution::voter::Voter,
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

    public entry fun pools_tally(voter: &distribution::voter::Voter, pool_ids: vector<ID>) {
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


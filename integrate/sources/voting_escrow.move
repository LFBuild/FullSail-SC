module integrate::voting_escrow {
    public struct Summary has copy, drop, store {
        total_locked: u64,
        total_voting_power: u64,
        rebase_apr: u64,
        current_epoch_end: u64,
        current_epoch_vote_end: u64,
        team_emission_rate: u64,
    }

    public struct LockSummary has copy, drop, store {
        voting_power: u64,
        reward_distributor_claimable: u64,
        fee_incentive_total: u64,
        voted_pools: vector<ID>,
    }

    public fun transfer<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: voting_escrow::voting_escrow::Lock,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer<voting_escrow::voting_escrow::Lock>(lock, recipient);
    }

    public fun max_bps(): u64 {
        100000000
    }

    public fun create_lock<SailCoinType>(
        arg0: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        coins: vector<sui::coin::Coin<SailCoinType>>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        arg0.create_lock(
            integrate::utils::merge_coins<SailCoinType>(coins, ctx),
            lock_duration_days,
            permanent,
            clock,
            ctx
        );
    }

    public fun increase_amount<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        coins: vector<sui::coin::Coin<SailCoinType>>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.increase_amount(lock, integrate::utils::merge_coins<SailCoinType>(coins, ctx), clock, ctx);
    }

    public fun increase_unlock_time<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        new_lock_duration_days: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.increase_unlock_time(lock, new_lock_duration_days, clock, ctx);
    }

    public fun lock_permanent<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.lock_permanent(lock, clock, ctx);
    }

    public fun unlock_permanent<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.unlock_permanent(lock, clock, ctx);
    }

    public fun create_lock_single_coin<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        coin: sui::coin::Coin<SailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut v0 = std::vector::empty<sui::coin::Coin<SailCoinType>>();
        v0.push_back(coin);
        create_lock<SailCoinType>(voting_escrow, v0, lock_duration_days, permanent, clock, ctx);
    }

    public fun increase_amount_single_coin<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut voting_escrow::voting_escrow::Lock,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.increase_amount(lock, coin, clock, ctx);
    }

    public fun lock_summary<SailCoinType>(
        voter: &governance::voter::Voter,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        rebase_distributor: &governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock
    ) {
        sui::event::emit<LockSummary>(lock_summary_internal<SailCoinType>(
            voter,
            voting_escrow,
            rebase_distributor,
            lock_id,
            clock
        ));
    }

    fun lock_summary_internal<SailCoinType>(
        voter: &governance::voter::Voter,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        rebase_distributor: &governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): LockSummary {
        let mut total_incentives = 0;
        let voted_pools = voter.voted_pools(lock_id);
        let mut pool_index = 0;
        while (pool_index < voted_pools.length()) {
            let gauge_id = voter.pool_to_gauge(voted_pools[pool_index]);
            total_incentives = total_incentives + voter.borrow_fee_voting_reward(gauge_id).earned<SailCoinType>(
                lock_id,
                clock
            );
            pool_index = pool_index + 1;
        };
        LockSummary {
            voting_power: voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms() / 1000),
            reward_distributor_claimable: rebase_distributor.claimable(voting_escrow, lock_id),
            fee_incentive_total: total_incentives,
            voted_pools,
        }
    }

    public fun merge_locks<SailCoinType>(
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock_a: &mut voting_escrow::voting_escrow::Lock,
        lock_b: &mut voting_escrow::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.merge(lock_a, lock_b, clock, ctx);
    }

    public fun summary<SailCoinType>(
        minter: &governance::minter::Minter<SailCoinType>,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &governance::distribution_config::DistributionConfig,
        clock: &sui::clock::Clock
    ) {
        let current_timestamp = voting_escrow::common::current_timestamp(clock);
        let total_locked = voting_escrow.total_locked();
        let epoch_emissions = minter.o_sail_epoch_emissions(distribution_config);
        let rebase_growth = governance::minter::calculate_rebase_growth(
            epoch_emissions,
            minter.sail_total_supply(),
            total_locked
        );
        let summary_event = Summary {
            total_locked,
            total_voting_power: voting_escrow.total_supply_at(voting_escrow::common::current_timestamp(clock)),
            rebase_apr: integer_mate::full_math_u64::mul_div_floor(
                rebase_growth,
                max_bps(),
                integer_mate::full_math_u64::mul_div_floor(
                    epoch_emissions + rebase_growth,
                    governance::minter::rate_denom(),
                    governance::minter::rate_denom() - minter.team_emission_rate()
                )
            ),
            current_epoch_end: voting_escrow::common::epoch_next(current_timestamp),
            current_epoch_vote_end: voting_escrow::common::epoch_vote_end(current_timestamp),
            team_emission_rate: minter.team_emission_rate(),
        };
        sui::event::emit<Summary>(summary_event);
    }
}


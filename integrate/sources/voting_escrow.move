module integrate::voting_escrow {
    public struct Summary has copy, drop, store {
        total_locked: u64,
        total_voting_power: u64,
        total_voted_power: u64,
        rebase_apr: u64,
        current_epoch_end: u64,
        current_epoch_vote_end: u64,
        team_emission_rate: u64,
    }

    public struct LockSummary has copy, drop, store {
        voting_power: u64,
        reward_distributor_claimable: u64,
        fee_incentive_total: u64,
    }

    public entry fun transfer<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: distribution::voting_escrow::Lock,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::transfer<SailCoinType>(
            lock,
            voting_escrow,
            recipient,
            clock,
            ctx
        );
    }

    public fun max_bps(): u64 {
        100000000
    }

    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        voter_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_share_object<distribution::voting_escrow::VotingEscrow<SailCoinType>>(
            distribution::voting_escrow::create<SailCoinType>(
                publisher,
                voter_id,
                clock,
                ctx
            )
        );
    }

    public entry fun create_lock<SailCoinType>(
        arg0: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        coins: vector<sui::coin::Coin<SailCoinType>>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::create_lock<SailCoinType>(
            arg0,
            integrate::utils::merge_coins<SailCoinType>(coins, ctx),
            lock_duration_days,
            permanent,
            clock,
            ctx
        );
    }

    public entry fun increase_amount<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        coins: vector<sui::coin::Coin<SailCoinType>>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::increase_amount<SailCoinType>(
            voting_escrow,
            lock,
            integrate::utils::merge_coins<SailCoinType>(coins, ctx),
            clock,
            ctx
        );
    }

    public entry fun increase_unlock_time<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        new_lock_duration_days: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::increase_unlock_time<SailCoinType>(
            voting_escrow,
            lock,
            new_lock_duration_days,
            clock,
            ctx
        );
    }

    public entry fun lock_permanent<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::lock_permanent<SailCoinType>(voting_escrow, lock, clock, ctx);
    }

    public entry fun unlock_permanent<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::unlock_permanent<SailCoinType>(voting_escrow, lock, clock, ctx);
    }

    public entry fun create_lock_single_coin<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        coin: sui::coin::Coin<SailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = std::vector::empty<sui::coin::Coin<SailCoinType>>();
        std::vector::push_back<sui::coin::Coin<SailCoinType>>(&mut v0, coin);
        create_lock<SailCoinType>(voting_escrow, v0, lock_duration_days, permanent, clock, ctx);
    }

    public entry fun increase_amount_single_coin<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::increase_amount<SailCoinType>(
            voting_escrow,
            lock,
            coin,
            clock,
            ctx
        );
    }

    public entry fun lock_summary<SailCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &distribution::reward_distributor::RewardDistributor<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ) {
        sui::event::emit<LockSummary>(lock_summary_internal<SailCoinType>(
            voter,
            voting_escrow,
            reward_distributor,
            lock_id,
            clock
        ));
    }

    fun lock_summary_internal<SailCoinType>(
        voter: &distribution::voter::Voter<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &distribution::reward_distributor::RewardDistributor<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): LockSummary {
        let mut total_incentives = 0;
        let voted_pools = distribution::voter::voted_pools<SailCoinType>(voter, lock_id);
        let mut pool_index = 0;
        while (pool_index < std::vector::length<sui::object::ID>(&voted_pools)) {
            let gauge_id = distribution::voter::pool_to_gauge<SailCoinType>(voter, voted_pools[pool_index]);
            let updated_incentives = total_incentives + distribution::fee_voting_reward::earned<SailCoinType>(
                distribution::voter::borrow_fee_voting_reward<SailCoinType>(voter, gauge_id),
                lock_id,
                clock
            );
            total_incentives = updated_incentives + distribution::bribe_voting_reward::earned<SailCoinType>(
                distribution::voter::borrow_bribe_voting_reward<SailCoinType>(voter, gauge_id),
                lock_id,
                clock
            );
            pool_index = pool_index + 1;
        };
        LockSummary {
            voting_power: distribution::voting_escrow::balance_of_nft_at<SailCoinType>(
                voting_escrow,
                lock_id,
                sui::clock::timestamp_ms(clock) / 1000
            ),
            reward_distributor_claimable: distribution::reward_distributor::claimable<SailCoinType>(
                reward_distributor, voting_escrow, lock_id),
            fee_incentive_total: total_incentives,
        }
    }

    public entry fun merge_locks<SailCoinType>(
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_a: distribution::voting_escrow::Lock,
        lock_b: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::voting_escrow::merge<SailCoinType>(voting_escrow, lock_a, lock_b, clock, ctx);
    }

    public entry fun summary<SailCoinType>(
        minter: &distribution::minter::Minter<SailCoinType>,
        voter: &distribution::voter::Voter<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        clock: &sui::clock::Clock
    ) {
        let current_timestamp = distribution::common::current_timestamp(clock);
        let total_locked = distribution::voting_escrow::total_locked<SailCoinType>(voting_escrow);
        let epoch_emissions = distribution::minter::epoch_emissions<SailCoinType>(minter);
        let rebase_growth = distribution::minter::calculate_rebase_growth(
            epoch_emissions, distribution::minter::total_supply<SailCoinType>(minter),
            total_locked
        );
        let summary_event = Summary {
            total_locked,
            total_voting_power: distribution::voting_escrow::total_supply_at<SailCoinType>(
                voting_escrow,
                distribution::common::current_timestamp(clock)
            ),
            total_voted_power: distribution::voter::total_weight<SailCoinType>(voter),
            rebase_apr: integer_mate::full_math_u64::mul_div_floor(
                rebase_growth,
                max_bps(),
                integer_mate::full_math_u64::mul_div_floor(
                    epoch_emissions + rebase_growth,
                    distribution::minter::max_bps(),
                    distribution::minter::max_bps() - distribution::minter::team_emission_rate<SailCoinType>(minter)
                )
            ),
            current_epoch_end: distribution::common::epoch_next(current_timestamp),
            current_epoch_vote_end: distribution::common::epoch_vote_end(current_timestamp),
            team_emission_rate: distribution::minter::team_emission_rate<SailCoinType>(minter),
        };
        sui::event::emit<Summary>(summary_event);
    }
}


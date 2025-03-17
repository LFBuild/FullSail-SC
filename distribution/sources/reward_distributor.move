module distribution::reward_distributor {
    public struct REWARD_DISTRIBUTOR has drop {}

    public struct EventStart has copy, drop, store {
        dummy_field: bool,
    }

    public struct EventCheckpointToken has copy, drop, store {
        to_distribute: u64,
    }

    public struct EventClaimed has copy, drop, store {
        id: sui::object::ID,
        epoch_start: u64,
        epoch_end: u64,
        amount: u64,
    }

    public struct RewardDistributor<phantom T0> has store, key {
        id: sui::object::UID,
        start_time: u64,
        time_cursor_of: sui::table::Table<sui::object::ID, u64>,
        last_token_time: u64,
        tokens_per_period: sui::table::Table<u64, u64>,
        token_last_balance: u64,
        balance: sui::balance::Balance<T0>,
        minter_active_period: u64,
    }

    public fun create<T0>(
        _publisher: &sui::package::Publisher,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (RewardDistributor<T0>, distribution::reward_distributor_cap::RewardDistributorCap) {
        let id = sui::object::new(ctx);
        let reward_distributor = RewardDistributor<T0> {
            id,
            start_time: distribution::common::current_timestamp(clock),
            time_cursor_of: sui::table::new<sui::object::ID, u64>(ctx),
            last_token_time: distribution::common::current_timestamp(clock),
            tokens_per_period: sui::table::new<u64, u64>(ctx),
            token_last_balance: 0,
            balance: sui::balance::zero<T0>(),
            minter_active_period: 0,
        };
        let id = *sui::object::uid_as_inner(&reward_distributor.id);
        (reward_distributor, distribution::reward_distributor_cap::create(id, ctx))
    }

    public fun checkpoint_token<T0>(
        arg0: &mut RewardDistributor<T0>,
        arg1: &distribution::reward_distributor_cap::RewardDistributorCap,
        arg2: sui::coin::Coin<T0>,
        arg3: &sui::clock::Clock
    ) {
        distribution::reward_distributor_cap::validate(arg1, sui::object::id<RewardDistributor<T0>>(arg0));
        sui::balance::join<T0>(&mut arg0.balance, sui::coin::into_balance<T0>(arg2));
        checkpoint_token_internal<T0>(arg0, distribution::common::current_timestamp(arg3));
    }

    fun checkpoint_token_internal<T0>(arg0: &mut RewardDistributor<T0>, arg1: u64) {
        let v0 = sui::balance::value<T0>(&arg0.balance);
        let v1 = v0 - arg0.token_last_balance;
        arg0.token_last_balance = v0;
        let v2 = arg0.last_token_time;
        let mut v3 = v2;
        let v4 = arg1 - v2;
        arg0.last_token_time = arg1;
        let mut v5 = distribution::common::to_period(v2);
        let mut v6 = 0;
        while (v6 < 20) {
            let v7 = if (!sui::table::contains<u64, u64>(&arg0.tokens_per_period, v5)) {
                0
            } else {
                sui::table::remove<u64, u64>(&mut arg0.tokens_per_period, v5)
            };
            let v8 = v5 + distribution::common::week();
            if (arg1 < v8) {
                if (v4 == 0 && arg1 == v3) {
                    sui::table::add<u64, u64>(&mut arg0.tokens_per_period, v5, v7 + v1);
                    break
                };
                sui::table::add<u64, u64>(&mut arg0.tokens_per_period, v5, v7 + v1 * (arg1 - v3) / v4);
                break
            };
            if (v4 == 0 && v8 == v3) {
                sui::table::add<u64, u64>(&mut arg0.tokens_per_period, v5, v7 + v1);
            } else {
                let v9 = v8 - v3;
                sui::table::add<u64, u64>(&mut arg0.tokens_per_period, v5, v7 + v1 * v9 / v4);
            };
            v3 = v8;
            v5 = v8;
            v6 = v6 + 1;
        };
        let v10 = EventCheckpointToken { to_distribute: v1 };
        sui::event::emit<EventCheckpointToken>(v10);
    }

    public fun claim<T0>(
        reward_distributor: &mut RewardDistributor<T0>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<T0>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let v0 = sui::object::id<distribution::voting_escrow::Lock>(lock);
        assert!(
            reward_distributor.minter_active_period >= distribution::common::current_period(clock), 9223372904438169601);
        assert!(
            distribution::voting_escrow::is_locked(distribution::voting_escrow::escrow_type<T0>(voting_escrow, v0)) == false,
            9223372908733267971
        );
        let period = distribution::common::to_period(reward_distributor.last_token_time);
        let v1 = claim_internal<T0>(reward_distributor, voting_escrow, v0, period);
        if (v1 > 0) {
            let (v2, _) = distribution::voting_escrow::locked<T0>(voting_escrow, v0);
            let v4 = v2;
            if (distribution::common::current_timestamp(clock) >= distribution::voting_escrow::end(
                &v4
            ) && !distribution::voting_escrow::is_permanent(&v4)) {
                sui::transfer::public_transfer<sui::coin::Coin<T0>>(
                    sui::coin::from_balance<T0>(sui::balance::split<T0>(&mut reward_distributor.balance, v1), ctx),
                    distribution::voting_escrow::owner_of<T0>(voting_escrow, v0)
                );
            } else {
                distribution::voting_escrow::deposit_for<T0>(
                    voting_escrow,
                    std::option::none<distribution::voting_escrow::DistributorCap>(),
                    lock,
                    sui::coin::from_balance<T0>(sui::balance::split<T0>(&mut reward_distributor.balance, v1), ctx),
                    clock,
                    ctx
                );
            };
            reward_distributor.token_last_balance = reward_distributor.token_last_balance - v1;
        };
        v1
    }

    fun claim_internal<T0>(
        arg0: &mut RewardDistributor<T0>,
        arg1: &distribution::voting_escrow::VotingEscrow<T0>,
        arg2: sui::object::ID,
        arg3: u64
    ): u64 {
        let (v0, v1, v2) = claimable_internal<T0>(arg0, arg1, arg2, arg3);
        if (sui::table::contains<sui::object::ID, u64>(&arg0.time_cursor_of, arg2)) {
            sui::table::remove<sui::object::ID, u64>(&mut arg0.time_cursor_of, arg2);
        };
        sui::table::add<sui::object::ID, u64>(&mut arg0.time_cursor_of, arg2, v2);
        if (v0 == 0) {
            return 0
        };
        let v3 = EventClaimed {
            id: arg2,
            epoch_start: v1,
            epoch_end: v2,
            amount: v0,
        };
        sui::event::emit<EventClaimed>(v3);
        v0
    }

    public fun claimable<SailCoinType>(
        reward_distributor: &RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID
    ): u64 {
        let (v0, _, _) = claimable_internal<SailCoinType>(
            reward_distributor,
            voting_escrow,
            lock_id,
            distribution::common::to_period(reward_distributor.last_token_time)
        );
        v0
    }

    /**
    * Calculates amount that can be claimed in [oldest_unclaimed_epoch, max_period)
    */
    fun claimable_internal<SailCoinType>(
        reward_distributor: &RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID,
        max_period: u64
    ): (u64, u64, u64) {
        let last_checkpoint_time = if (sui::table::contains<sui::object::ID, u64>(&reward_distributor.time_cursor_of, lock_id)) {
            *sui::table::borrow<sui::object::ID, u64>(&reward_distributor.time_cursor_of, lock_id)
        } else {
            0
        };
        let mut epoch_end = last_checkpoint_time;
        let mut epoch_start = last_checkpoint_time;
        let mut total_reward = 0;
        if (distribution::voting_escrow::user_point_epoch<SailCoinType>(voting_escrow, lock_id) == 0) {
            return (0, last_checkpoint_time, last_checkpoint_time)
        };
        if (last_checkpoint_time == 0) {
            let user_point = distribution::voting_escrow::user_point_history<SailCoinType>(voting_escrow, lock_id, 1);
            let initial_period = distribution::common::to_period(distribution::voting_escrow::user_point_ts(&user_point));
            epoch_end = initial_period;
            epoch_start = initial_period;
        };
        if (epoch_end >= max_period) {
            return (0, epoch_start, epoch_end)
        };
        if (epoch_end < reward_distributor.start_time) {
            epoch_end = reward_distributor.start_time;
        };
        let mut i = 0;
        while (i < 50) {
            if (epoch_end >= max_period) {
                break
            };
            let user_balance = distribution::voting_escrow::balance_of_nft_at<SailCoinType>(
                voting_escrow,
                lock_id,
                epoch_end + distribution::common::week() - 1
            );
            let total_supply = distribution::voting_escrow::total_supply_at<SailCoinType>(
                voting_escrow, epoch_end + distribution::common::week() - 1);
            let non_zero_total_supply = if (total_supply == 0) {
                1
            } else {
                total_supply
            };
            let period_reward_tokens = if (sui::table::contains<u64, u64>(&reward_distributor.tokens_per_period,
                epoch_end
            )) {
                let period_reward_tokens_ref = sui::table::borrow<u64, u64>(&reward_distributor.tokens_per_period,
                    epoch_end
                );
                *period_reward_tokens_ref
            } else {
                0
            };
            total_reward = total_reward + user_balance * period_reward_tokens / non_zero_total_supply;
            epoch_end = epoch_end + distribution::common::week();
            i = i + 1;
        };
        // TODO: in original smart contracts version it was (total_reward, epoch_end, epoch_start)
        // but it seemed to be an error, so i changed it.
        // We should revisit it when we have gathered more context
        (total_reward, epoch_start, epoch_end)
    }

    fun init(otw: REWARD_DISTRIBUTOR, ctx: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<REWARD_DISTRIBUTOR>(otw, ctx);
    }

    public fun start<T0>(
        arg0: &mut RewardDistributor<T0>,
        arg1: &distribution::reward_distributor_cap::RewardDistributorCap,
        arg2: u64,
        arg3: &sui::clock::Clock
    ) {
        distribution::reward_distributor_cap::validate(arg1, sui::object::id<RewardDistributor<T0>>(arg0));
        let v0 = distribution::common::current_timestamp(arg3);
        arg0.start_time = v0;
        arg0.last_token_time = v0;
        arg0.minter_active_period = arg2;
        let v1 = EventStart { dummy_field: false };
        sui::event::emit<EventStart>(v1);
    }

    public(package) fun update_active_period<T0>(
        arg0: &mut RewardDistributor<T0>,
        arg1: &distribution::reward_distributor_cap::RewardDistributorCap,
        arg2: u64
    ) {
        distribution::reward_distributor_cap::validate(arg1, sui::object::id<RewardDistributor<T0>>(arg0));
        arg0.minter_active_period = arg2;
    }

    // decompiled from Move bytecode v6
}


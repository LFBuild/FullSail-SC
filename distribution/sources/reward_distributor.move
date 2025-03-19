module distribution::reward_distributor {

    const EMinterNotActive: u64 = 9223372904438169601;
    const EOnlyLockedVotingEscrowCanClaim: u64 = 9223372908733267971;

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

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (RewardDistributor<SailCoinType>, distribution::reward_distributor_cap::RewardDistributorCap) {
        let uid = sui::object::new(ctx);
        let reward_distributor = RewardDistributor<SailCoinType> {
            id: uid,
            start_time: distribution::common::current_timestamp(clock),
            time_cursor_of: sui::table::new<sui::object::ID, u64>(ctx),
            last_token_time: distribution::common::current_timestamp(clock),
            tokens_per_period: sui::table::new<u64, u64>(ctx),
            token_last_balance: 0,
            balance: sui::balance::zero<SailCoinType>(),
            minter_active_period: 0,
        };
        let id = *sui::object::uid_as_inner(&reward_distributor.id);
        (reward_distributor, distribution::reward_distributor_cap::create(id, ctx))
    }

    public fun checkpoint_token<SailCoinType>(
        arg0: &mut RewardDistributor<SailCoinType>,
        arg1: &distribution::reward_distributor_cap::RewardDistributorCap,
        arg2: sui::coin::Coin<SailCoinType>,
        arg3: &sui::clock::Clock
    ) {
        distribution::reward_distributor_cap::validate(arg1, sui::object::id<RewardDistributor<SailCoinType>>(arg0));
        sui::balance::join<SailCoinType>(&mut arg0.balance, sui::coin::into_balance<SailCoinType>(arg2));
        checkpoint_token_internal<SailCoinType>(arg0, distribution::common::current_timestamp(arg3));
    }

    fun checkpoint_token_internal<SailCoinType>(arg0: &mut RewardDistributor<SailCoinType>, arg1: u64) {
        let v0 = sui::balance::value<SailCoinType>(&arg0.balance);
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

    public fun claim<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let lock_id = sui::object::id<distribution::voting_escrow::Lock>(lock);
        assert!(
            reward_distributor.minter_active_period >= distribution::common::current_period(clock), EMinterNotActive);
        assert!(
            distribution::voting_escrow::is_locked(distribution::voting_escrow::escrow_type<SailCoinType>(voting_escrow, lock_id)) == false,
            EOnlyLockedVotingEscrowCanClaim
        );
        let period = distribution::common::to_period(reward_distributor.last_token_time);
        let reward = claim_internal<SailCoinType>(reward_distributor, voting_escrow, lock_id, period);
        if (reward > 0) {
            let (locked_balance, _) = distribution::voting_escrow::locked<SailCoinType>(voting_escrow, lock_id);
            if (distribution::common::current_timestamp(clock) >= distribution::voting_escrow::end(
                &locked_balance
            ) && !distribution::voting_escrow::is_permanent(&locked_balance)) {
                sui::transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                    sui::coin::from_balance<SailCoinType>(reward_distributor.balance.split<SailCoinType>(reward), ctx),
                    distribution::voting_escrow::owner_of<SailCoinType>(voting_escrow, lock_id)
                );
            } else {
                distribution::voting_escrow::deposit_for<SailCoinType>(
                    voting_escrow,
                    std::option::none<distribution::voting_escrow::DistributorCap>(),
                    lock,
                    sui::coin::from_balance<SailCoinType>(reward_distributor.balance.split<SailCoinType>(reward), ctx),
                    clock,
                    ctx
                );
            };
            reward_distributor.token_last_balance = reward_distributor.token_last_balance - reward;
        };
        reward
    }

    fun claim_internal<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID,
        max_period: u64
    ): u64 {
        let (reward, epoch_start, epoch_end) = claimable_internal<SailCoinType>(
            reward_distributor,
            voting_escrow,
            lock_id,
            max_period
        );
        if (sui::table::contains<sui::object::ID, u64>(&reward_distributor.time_cursor_of, lock_id)) {
            sui::table::remove<sui::object::ID, u64>(&mut reward_distributor.time_cursor_of, lock_id);
        };
        sui::table::add<sui::object::ID, u64>(&mut reward_distributor.time_cursor_of, lock_id, epoch_end);
        if (reward == 0) {
            return 0
        };
        let claimed_event = EventClaimed {
            id: lock_id,
            epoch_start,
            epoch_end,
            amount: reward,
        };
        sui::event::emit<EventClaimed>(claimed_event);
        reward
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

    /**
    * Starts the distribution
    */
    public fun start<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        reward_distributor_cap: &distribution::reward_distributor_cap::RewardDistributorCap,
        minter_active_period: u64, // a period until which minting is available, in weeks
        clock: &sui::clock::Clock
    ) {
        distribution::reward_distributor_cap::validate(
            reward_distributor_cap, sui::object::id<RewardDistributor<SailCoinType>>(reward_distributor));
        let current_time = distribution::common::current_timestamp(clock);
        reward_distributor.start_time = current_time;
        reward_distributor.last_token_time = current_time;
        reward_distributor.minter_active_period = minter_active_period;
        let start_event = EventStart { dummy_field: false };
        sui::event::emit<EventStart>(start_event);
    }

    public(package) fun update_active_period<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        reward_distributor_cap: &distribution::reward_distributor_cap::RewardDistributorCap,
        new_active_period: u64
    ) {
        distribution::reward_distributor_cap::validate(
            reward_distributor_cap,
            sui::object::id<RewardDistributor<SailCoinType>>(reward_distributor)
        );
        reward_distributor.minter_active_period = new_active_period;
    }
}


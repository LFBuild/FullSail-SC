module distribution::reward_distributor {

    const ECreateRewardDistributorInvalidPublisher: u64 = 297048250711179300;

    const EMinterNotActive: u64 = 9223372904438169601;
    const EOnlyLockedVotingEscrowCanClaim: u64 = 9223372908733267971;

    /// Witness used for one-time witness pattern
    public struct REWARD_DISTRIBUTOR has drop {}

    public struct EventStart has copy, drop, store {
        dummy_field: bool,
    }

    public struct EventCheckpointToken has copy, drop, store {
        to_distribute: u64,
    }

    public struct EventClaimed has copy, drop, store {
        id: ID,
        epoch_start: u64,
        epoch_end: u64,
        amount: u64,
    }

    /// The RewardDistributor manages the distribution of rewards to users based on their voting power.
    /// It tracks token distribution across time periods and handles the claiming process.
    public struct RewardDistributor<phantom SailCoinType> has store, key {
        id: UID,
        /// The timestamp when reward distribution was started
        start_time: u64,
        /// Maps lock IDs to their last checkpoint time
        time_cursor_of: sui::table::Table<ID, u64>,
        /// The timestamp of the last token checkpoint
        last_token_time: u64,
        /// Maps periods to the amount of tokens to distribute in that period
        tokens_per_period: sui::table::Table<u64, u64>,
        /// The balance of tokens at the last checkpoint
        token_last_balance: u64,
        /// The current balance of reward tokens
        balance: sui::balance::Balance<SailCoinType>,
        /// The period until which reward minting is active
        minter_active_period: u64,
    }

    /// Returns the current balance of reward tokens in the distributor.
    /// 
    /// # Arguments
    /// * `reward` - The reward distributor to check
    /// 
    /// # Returns
    /// The current balance of reward tokens
    public fun balance<SailCoinType>(reward: &RewardDistributor<SailCoinType>): u64 {
        reward.balance.value<SailCoinType>()
    }

    /// Creates a new reward distributor and its associated capability.
    /// 
    /// # Arguments
    /// * `publisher` - The publisher reference
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A tuple containing the new reward distributor and its capability
    public fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (RewardDistributor<SailCoinType>, distribution::reward_distributor_cap::RewardDistributorCap) {
        assert!(publisher.from_module<REWARD_DISTRIBUTOR>(), ECreateRewardDistributorInvalidPublisher);
        let uid = object::new(ctx);
        let reward_distributor = RewardDistributor<SailCoinType> {
            id: uid,
            start_time: distribution::common::current_timestamp(clock),
            time_cursor_of: sui::table::new<ID, u64>(ctx),
            last_token_time: distribution::common::current_timestamp(clock),
            tokens_per_period: sui::table::new<u64, u64>(ctx),
            token_last_balance: 0,
            balance: sui::balance::zero<SailCoinType>(),
            minter_active_period: 0,
        };
        let id = *object::uid_as_inner(&reward_distributor.id);
        (reward_distributor, distribution::reward_distributor_cap::create(id, ctx))
    }

    /// Checkpoints tokens by adding new tokens to the distributor and updating distribution data.
    /// This function is called when new rewards are added to the system.
    /// 
    /// # Arguments
    /// * `reward_distributon` - The reward distributor to checkpoint
    /// * `reward_distributor_cap` - Capability proving authorization to checkpoint
    /// * `coin` - The coin to add to the distributor
    /// * `clock` - The system clock
    public fun checkpoint_token<SailCoinType>(
        reward_distributon: &mut RewardDistributor<SailCoinType>,
        reward_distributor_cap: &distribution::reward_distributor_cap::RewardDistributorCap,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock
    ) {
        reward_distributor_cap.validate(object::id<RewardDistributor<SailCoinType>>(reward_distributon));
        reward_distributon.balance.join(coin.into_balance());
        reward_distributon.checkpoint_token_internal(distribution::common::current_timestamp(clock));
    }

    /// Internal function that handles token checkpointing logic.
    /// Distributes new tokens across time periods based on the amount and timing.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to update
    /// * `time` - The current timestamp
    fun checkpoint_token_internal<SailCoinType>(reward_distributor: &mut RewardDistributor<SailCoinType>, time: u64) {
        let current_balance = reward_distributor.balance.value();
        let balance_delta = current_balance - reward_distributor.token_last_balance;
        let mut last_token_time = reward_distributor.last_token_time;
        let token_time_delta = time - last_token_time;
        let mut last_token_period = distribution::common::to_period(last_token_time);
        let mut i = 0;
        while (i < 20) {
            let last_period_tokens = if (!reward_distributor.tokens_per_period.contains(last_token_period)) {
                0
            } else {
                reward_distributor.tokens_per_period.remove(last_token_period)
            };
            let next_token_period = last_token_period + distribution::common::week();
            if (time < next_token_period) {
                if (token_time_delta == 0 && time == last_token_time) {
                    reward_distributor.tokens_per_period.add(
                        last_token_period,
                        last_period_tokens + balance_delta
                    );
                    break
                };
                reward_distributor.tokens_per_period.add(
                    last_token_period,
                    last_period_tokens + integer_mate::full_math_u64::mul_div_floor(
                        balance_delta, time - last_token_time, token_time_delta)
                );
                break
            };
            if (token_time_delta == 0 && next_token_period == last_token_time) {
                reward_distributor.tokens_per_period.add(
                    last_token_period,
                    last_period_tokens + balance_delta
                );
            } else {
                let v9 = next_token_period - last_token_time;
                reward_distributor.tokens_per_period.add(
                    last_token_period,
                    last_period_tokens + integer_mate::full_math_u64::mul_div_floor(
                        balance_delta,
                        v9,
                        token_time_delta
                    )
                );
            };
            last_token_time = next_token_period;
            last_token_period = next_token_period;
            i = i + 1;
        };
        reward_distributor.token_last_balance = current_balance;
        reward_distributor.last_token_time = time;
        let checkpoint_token_event = EventCheckpointToken { to_distribute: balance_delta };
        sui::event::emit<EventCheckpointToken>(checkpoint_token_event);
    }

    /// Claims rewards for a locked voting escrow.
    /// This function calculates, processes, and distributes rewards to a lock based on its voting power.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to claim from
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// The amount of rewards claimed
    /// 
    /// # Aborts
    /// * If the minter is not active for the current period
    /// * If the voting escrow is not locked
    public fun claim<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<distribution::voting_escrow::Lock>(lock);
        assert!(
            reward_distributor.minter_active_period >= distribution::common::current_period(clock), EMinterNotActive);
        assert!(
            voting_escrow.escrow_type(lock_id).is_locked() == false,
            EOnlyLockedVotingEscrowCanClaim
        );
        let period = distribution::common::to_period(reward_distributor.last_token_time);
        let reward = reward_distributor.claim_internal(voting_escrow, lock_id, period);
        if (reward > 0) {
            let (locked_balance, _) = voting_escrow.locked(lock_id);
            if (distribution::common::current_timestamp(clock) >= locked_balance.end() && !locked_balance.is_permanent(
            )) {
                transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                    sui::coin::from_balance<SailCoinType>(reward_distributor.balance.split<SailCoinType>(reward), ctx),
                    voting_escrow.owner_of(lock_id)
                );
            } else {
                voting_escrow.deposit_for(
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

    /// Internal function to process a reward claim.
    /// Updates the time cursor for the lock and emits a claim event.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock claiming rewards
    /// * `max_period` - The maximum period to consider for the claim
    /// 
    /// # Returns
    /// The amount of rewards claimed
    fun claim_internal<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        max_period: u64
    ): u64 {
        let (reward, epoch_start, epoch_end) = reward_distributor.claimable_internal(
            voting_escrow,
            lock_id,
            max_period
        );
        if (reward_distributor.time_cursor_of.contains(lock_id)) {
            reward_distributor.time_cursor_of.remove(lock_id);
        };
        reward_distributor.time_cursor_of.add(lock_id, epoch_end);
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

    /// Returns the amount of rewards that can be claimed by a lock.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to check
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to check
    /// 
    /// # Returns
    /// The amount of rewards claimable
    public fun claimable<SailCoinType>(
        reward_distributor: &RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID
    ): u64 {
        let (claimable_amount, _, _) = reward_distributor.claimable_internal(
            voting_escrow,
            lock_id,
            distribution::common::to_period(reward_distributor.last_token_time)
        );
        claimable_amount
    }

    /// Internal function that calculates the amount of rewards claimable by a lock.
    /// The calculation is based on the lock's voting power relative to the total supply
    /// of voting power over time.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to calculate rewards for
    /// * `max_period` - The maximum period to consider for the calculation
    /// 
    /// # Returns
    /// A tuple containing the claimable amount, epoch start, and epoch end
    fun claimable_internal<SailCoinType>(
        reward_distributor: &RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        max_period: u64
    ): (u64, u64, u64) {
        let last_checkpoint_time = if (reward_distributor.time_cursor_of.contains(lock_id)) {
            *reward_distributor.time_cursor_of.borrow(lock_id)
        } else {
            0
        };
        let mut epoch_end = last_checkpoint_time;
        let mut epoch_start = last_checkpoint_time;
        let mut total_reward = 0;
        if (voting_escrow.user_point_epoch(lock_id) == 0) {
            return (0, last_checkpoint_time, last_checkpoint_time)
        };
        if (last_checkpoint_time == 0) {
            let user_point = voting_escrow.user_point_history(lock_id, 1);
            let initial_period = distribution::common::to_period(
                user_point.user_point_ts()
            );
            epoch_end = initial_period;
            epoch_start = initial_period;
        };
        if (epoch_end >= max_period) {
            return (0, epoch_start, epoch_end)
        };
        if (epoch_end < reward_distributor.start_time) {
            epoch_end = distribution::common::to_period(reward_distributor.start_time);
        };
        let mut i = 0;
        while (i < 50) {
            if (epoch_end >= max_period) {
                break
            };
            let user_balance = voting_escrow.balance_of_nft_at(lock_id, epoch_end + distribution::common::week() - 1);
            let total_supply = voting_escrow.total_supply_at(epoch_end + distribution::common::week() - 1);
            let non_zero_total_supply = if (total_supply == 0) {
                1
            } else {
                total_supply
            };
            let period_reward_tokens = if (reward_distributor.tokens_per_period.contains(epoch_end)) {
                let period_reward_tokens_ref = reward_distributor.tokens_per_period.borrow(epoch_end);
                *period_reward_tokens_ref
            } else {
                0
            };
            total_reward = total_reward + integer_mate::full_math_u64::mul_div_floor(
                user_balance,
                period_reward_tokens,
                non_zero_total_supply
            );
            epoch_end = epoch_end + distribution::common::week();
            i = i + 1;
        };
        // TODO: in original smart contracts version it was (total_reward, epoch_end, epoch_start)
        // but it seemed to be an error, so i changed it.
        // We should revisit it when we have gathered more context
        (total_reward, epoch_start, epoch_end)
    }

    /// Module initializer, used for the one-time witness pattern.
    /// 
    /// # Arguments
    /// * `otw` - The one-time witness
    /// * `ctx` - The transaction context
    fun init(otw: REWARD_DISTRIBUTOR, ctx: &mut TxContext) {
        sui::package::claim_and_keep<REWARD_DISTRIBUTOR>(otw, ctx);
    }

    /// Returns the timestamp of the last token checkpoint.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to check
    /// 
    /// # Returns
    /// The timestamp of the last token checkpoint
    public fun last_token_time<SailCoinType>(reward_distributor: &RewardDistributor<SailCoinType>): u64 {
        reward_distributor.last_token_time
    }

    /// Returns the period until which reward minting is active.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to check
    /// 
    /// # Returns
    /// The period until which reward minting is active
    public fun minter_active_period<SailCoinType>(reward_distributor: &RewardDistributor<SailCoinType>): u64 {
        reward_distributor.minter_active_period
    }

    /// Starts the reward distribution process.
    /// This function sets the start time, last token time, and minter active period.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to start
    /// * `reward_distributor_cap` - Capability proving authorization to start
    /// * `minter_active_period` - The period until which reward minting will be active
    /// * `clock` - The system clock
    public fun start<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        reward_distributor_cap: &distribution::reward_distributor_cap::RewardDistributorCap,
        minter_active_period: u64, // a period until which minting is available, in weeks
        clock: &sui::clock::Clock
    ) {
        reward_distributor_cap.validate(object::id<RewardDistributor<SailCoinType>>(reward_distributor));
        let current_time = distribution::common::current_timestamp(clock);
        reward_distributor.start_time = current_time;
        reward_distributor.last_token_time = current_time;
        reward_distributor.minter_active_period = minter_active_period;
        let start_event = EventStart { dummy_field: false };
        sui::event::emit<EventStart>(start_event);
    }

    /// Returns the amount of tokens to distribute in a specific period.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to check
    /// * `period_start_time` - The start time of the period to check
    /// 
    /// # Returns
    /// The amount of tokens to distribute in the specified period
    public fun tokens_per_period<SailCoinType>(
        reward_distributor: &RewardDistributor<SailCoinType>,
        period_start_time: u64
    ): u64 {
        *reward_distributor.tokens_per_period.borrow(period_start_time)
    }

    /// Updates the active period for reward minting.
    /// This function can only be called by the holder of the reward distributor capability.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to update
    /// * `reward_distributor_cap` - Capability proving authorization to update
    /// * `new_active_period` - The new period until which reward minting will be active
    public(package) fun update_active_period<SailCoinType>(
        reward_distributor: &mut RewardDistributor<SailCoinType>,
        reward_distributor_cap: &distribution::reward_distributor_cap::RewardDistributorCap,
        new_active_period: u64
    ) {
        reward_distributor_cap.validate(object::id<RewardDistributor<SailCoinType>>(reward_distributor));
        reward_distributor.minter_active_period = new_active_period;
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
        sui::package::claim<REWARD_DISTRIBUTOR>(REWARD_DISTRIBUTOR {}, ctx)
    }
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::reward_distributor {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ETokensAlreadyCheckpointed: u64 = 83171767535347600;

    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use std::type_name::{Self, TypeName};
    /// Witness used for one-time witness pattern
    public struct REWARD_DISTRIBUTOR has drop {}

    public struct EventStart has copy, drop, store {
    }

    public struct EventCheckpointToken has copy, drop, store {
        wrapper_distributor_id: ID,
        to_distribute: u64,
        timestamp: u64,
        token_type: TypeName,
    }

    public struct EventClaimed has copy, drop, store {
        wrapper_distributor_id: ID,
        id: ID,
        epoch_start: u64,
        epoch_end: u64,
        amount: u64,
        token_type: TypeName,
    }

    /// The RewardDistributor manages the distribution of rewards to users based on their voting power.
    /// It tracks token distribution across time periods and handles the claiming process.
    public struct RewardDistributor<phantom RewardCoinType> has store, key {
        id: UID,
        /// ExerciseFeeDistributor or RebaseDistributor id
        wrapper_distributor_id: ID,
        /// The timestamp when reward distribution was started
        start_time: u64,
        /// Maps lock IDs to their last checkpoint time
        time_cursor_of: Table<ID, u64>,
        /// The timestamp of the last token checkpoint
        last_token_time: u64,
        /// Maps periods to the amount of tokens to distribute in that period
        tokens_per_period: Table<u64, u64>,
        /// deprecated. Not used anymore
        token_last_balance: u64,
        /// The current balance of reward tokens
        balance: Balance<RewardCoinType>,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    /// Returns the current balance of reward tokens in the distributor.
    /// 
    /// # Arguments
    /// * `reward` - The reward distributor to check
    /// 
    /// # Returns
    /// The current balance of reward tokens
    public fun balance<RewardCoinType>(reward: &RewardDistributor<RewardCoinType>): u64 {
        reward.balance.value<RewardCoinType>()
    }

    /// Creates a new reward distributor and its associated capability.
    /// 
    /// # Arguments
    /// * `wrapper_distributor_id` - The ID of the wrapper distributor
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A tuple containing the new reward distributor and its capability
    public fun create<RewardCoinType>(
        wrapper_distributor_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (RewardDistributor<RewardCoinType>, voting_escrow::reward_distributor_cap::RewardDistributorCap) {
        let uid = object::new(ctx);
        let reward_distributor = RewardDistributor<RewardCoinType> {
            id: uid,
            wrapper_distributor_id,
            start_time: voting_escrow::common::current_timestamp(clock),
            time_cursor_of: table::new<ID, u64>(ctx),
            last_token_time: voting_escrow::common::current_timestamp(clock),
            tokens_per_period: table::new<u64, u64>(ctx),
            token_last_balance: 0,
            balance: balance::zero<RewardCoinType>(),
            // bag to be preapred for future updates
            bag: sui::bag::new(ctx),
        };
        let id = *object::uid_as_inner(&reward_distributor.id);
        (reward_distributor, voting_escrow::reward_distributor_cap::create(id, ctx))
    }

    /// Checkpoints tokens by adding new tokens to the distributor and updating distribution data.
    /// This function is called when new rewards are added to the system.
    /// 
    /// # Arguments
    /// * `reward_distributon` - The reward distributor to checkpoint
    /// * `reward_distributor_cap` - Capability proving authorization to checkpoint
    /// * `coin` - The coin to add to the distributor
    /// * `clock` - The system clock
    public fun checkpoint_token<RewardCoinType>(
        reward_distributon: &mut RewardDistributor<RewardCoinType>,
        reward_distributor_cap: &voting_escrow::reward_distributor_cap::RewardDistributorCap,
        coin: Coin<RewardCoinType>,
        clock: &sui::clock::Clock
    ) {
        reward_distributor_cap.validate(object::id<RewardDistributor<RewardCoinType>>(reward_distributon));
        let added_tokens = coin.value();
        reward_distributon.balance.join(coin.into_balance());
        reward_distributon.checkpoint_token_internal(added_tokens, voting_escrow::common::current_timestamp(clock));
    }

    /// Internal function that handles token checkpointing logic.
    /// Distributes new tokens across time periods based on the amount and timing.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to update
    /// * `added_tokens` - The amount of tokens being added
    /// * `time` - The current timestamp
    fun checkpoint_token_internal<RewardCoinType>(reward_distributor: &mut RewardDistributor<RewardCoinType>, added_tokens: u64, time: u64) {
        let current_balance = reward_distributor.balance.value();
        let balance_delta = added_tokens;
        let mut last_token_time = reward_distributor.last_token_time;
        let token_time_delta = time - last_token_time;
        let mut last_token_period = voting_escrow::common::to_period(last_token_time);
        let mut i = 0;
        while (i < 20) {
            let last_period_tokens = if (!reward_distributor.tokens_per_period.contains(last_token_period)) {
                0
            } else {
                reward_distributor.tokens_per_period.remove(last_token_period)
            };
            let next_token_period = last_token_period + voting_escrow::common::epoch();
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
                        balance_delta,
                         time - last_token_time,
                         token_time_delta
                        )
                );
                break
            };
            if (token_time_delta == 0 && next_token_period == last_token_time) {
                reward_distributor.tokens_per_period.add(
                    last_token_period,
                    last_period_tokens + balance_delta
                );
            } else {
                let time_until_next_period = next_token_period - last_token_time;
                reward_distributor.tokens_per_period.add(
                    last_token_period,
                    last_period_tokens + integer_mate::full_math_u64::mul_div_floor(
                        balance_delta,
                        time_until_next_period,
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
        let checkpoint_token_event = EventCheckpointToken {
            wrapper_distributor_id: reward_distributor.wrapper_distributor_id,
            to_distribute: balance_delta,
            timestamp: time,
            token_type: type_name::get<RewardCoinType>(),
        };
        sui::event::emit<EventCheckpointToken>(checkpoint_token_event);
    }

    /// Claims rewards for a locked voting escrow.
    /// This function calculates, processes, and distributes rewards to a lock based on its voting power.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to claim from
    /// * `reward_distributor_cap` - Capability proving authorization to claim
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The lock ID to claim rewards for
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// The amount of rewards claimed
    /// 
    /// # Aborts
    /// * If the minter is not active for the current period
    /// * If the voting escrow is of type locked
    public fun claim<SailCoinType, RewardCoinType>(
        reward_distributor: &mut RewardDistributor<RewardCoinType>,
        reward_distributor_cap: &voting_escrow::reward_distributor_cap::RewardDistributorCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        ctx: &mut TxContext
    ): Coin<RewardCoinType> {
        reward_distributor_cap.validate(object::id<RewardDistributor<RewardCoinType>>(reward_distributor));
        let period = voting_escrow::common::to_period(reward_distributor.last_token_time);
        let reward = reward_distributor.claim_internal(voting_escrow, lock_id, period);

        coin::from_balance<RewardCoinType>(reward_distributor.balance.split<RewardCoinType>(reward), ctx)
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
    fun claim_internal<SailCoinType, RewardCoinType>(
        reward_distributor: &mut RewardDistributor<RewardCoinType>,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
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
            wrapper_distributor_id: reward_distributor.wrapper_distributor_id,
            id: lock_id,
            epoch_start,
            epoch_end,
            amount: reward,
            token_type: type_name::get<RewardCoinType>(),
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
    public fun claimable<SailCoinType, RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID
    ): u64 {
        let (claimable_amount, _, _) = reward_distributor.claimable_internal(
            voting_escrow,
            lock_id,
            voting_escrow::common::to_period(reward_distributor.last_token_time)
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
    fun claimable_internal<SailCoinType, RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
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
            let initial_period = voting_escrow::common::to_period(
                user_point.user_point_ts()
            );
            epoch_end = initial_period;
            epoch_start = initial_period;
        };
        if (epoch_end >= max_period) {
            return (0, epoch_start, epoch_end)
        };
        if (epoch_end < reward_distributor.start_time) {
            epoch_end = voting_escrow::common::to_period(reward_distributor.start_time);
        };
        let mut i = 0;
        while (i < 50) {
            if (epoch_end >= max_period) {
                break
            };
            let user_balance = voting_escrow.balance_of_nft_at(lock_id, epoch_end + voting_escrow::common::epoch() - 1);
            let total_supply = voting_escrow.total_supply_at(epoch_end + voting_escrow::common::epoch() - 1);
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
            epoch_end = epoch_end + voting_escrow::common::epoch();
            i = i + 1;
        };
        (total_reward, epoch_start, epoch_end)
    }

    /// Returns the timestamp of the last token checkpoint.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to check
    /// 
    /// # Returns
    /// The timestamp of the last token checkpoint
    public fun last_token_time<RewardCoinType>(reward_distributor: &RewardDistributor<RewardCoinType>): u64 {
        reward_distributor.last_token_time
    }
    /// Starts the reward distribution process.
    /// This function sets the start time, last token time, and minter active period.
    /// 
    /// # Arguments
    /// * `reward_distributor` - The reward distributor to start
    /// * `reward_distributor_cap` - Capability proving authorization to start
    /// * `clock` - The system clock
    public fun start<RewardCoinType>(
        reward_distributor: &mut RewardDistributor<RewardCoinType>,
        reward_distributor_cap: &voting_escrow::reward_distributor_cap::RewardDistributorCap,
        clock: &sui::clock::Clock
    ) {
        reward_distributor_cap.validate(object::id<RewardDistributor<RewardCoinType>>(reward_distributor));
        assert!(reward_distributor.tokens_per_period.is_empty(), ETokensAlreadyCheckpointed);
        let current_time = voting_escrow::common::current_timestamp(clock);
        reward_distributor.start_time = current_time;
        reward_distributor.last_token_time = current_time;
        let start_event = EventStart { };
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
    public fun tokens_per_period<RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>,
        period_start_time: u64
    ): u64 {
        if (reward_distributor.tokens_per_period.contains(period_start_time)) {
            *reward_distributor.tokens_per_period.borrow(period_start_time)
        } else {
            0
        }
    }

    public fun start_time<RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>
    ): u64 {
        reward_distributor.start_time
    }

    #[test_only]
    public fun test_time_cursor_of<RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>,
        lock_id: ID
    ): u64 {
        if (reward_distributor.time_cursor_of.contains(lock_id)) {
            *reward_distributor.time_cursor_of.borrow(lock_id)
        } else {
            0
        }
    }

    #[test_only]
    public fun test_create_reward_distributor_cap<RewardCoinType>(
        self: &RewardDistributor<RewardCoinType>,
        ctx: &mut TxContext
    ): voting_escrow::reward_distributor_cap::RewardDistributorCap {
        let reward_distributor_id = object::id(self);
        voting_escrow::reward_distributor_cap::create(reward_distributor_id, ctx)
    }

    #[test_only]
    public fun total_length<RewardCoinType>(
        reward_distributor: &RewardDistributor<RewardCoinType>
    ): u64 {
        reward_distributor.time_cursor_of.length() +
        reward_distributor.tokens_per_period.length() +
        reward_distributor.bag.length()
    }

}


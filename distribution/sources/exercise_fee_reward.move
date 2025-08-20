module distribution::exercise_fee_reward {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    public struct ExerciseFeeReward has store, key {
        id: UID,
        reward: distribution::reward::Reward,
    }

    public struct EventExerciseFeeRewardCreated has copy, drop, store {
        id: ID,
    }

    /// Creates a new ExerciseFeeReward instance. Supposed to be stored inside Voter,
    /// so it is not linked to VotingEscrow.
    ///
    /// # Arguments
    /// * `voter` - The ID of the voter
    /// * `gauge_id` - The ID of the authorized gauge
    /// * `reward_coin_types` - Vector of coin types that can be used as rewards
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A new ExerciseFeeReward instance
    public(package) fun create(
        voter: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): ExerciseFeeReward {
        let id = object::new(ctx);
        let inner_id = id.uid_to_inner();
        let bribe_voting_reward_created_event = EventExerciseFeeRewardCreated {
            id: inner_id,
        };
        sui::event::emit<EventExerciseFeeRewardCreated>(bribe_voting_reward_created_event);
        ExerciseFeeReward {
            id,
            reward: distribution::reward::create(
                inner_id,
                voter,
                option::none(),
                voter,
                reward_coin_types,
                true,
                ctx
            ),
        }
    }

    /// Deposits rewards into the ExerciseFeeReward.
    /// Actually we are not depositing locks inside smart contracts right now cos
    /// we are calling update
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to deposit into
    /// * `authorized_cap` - Capability proving authorization to deposit
    /// * `amount` - The amount to deposit
    /// * `lock_id` - The ID of the lock receiving the reward
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun deposit(
        reward: &mut ExerciseFeeReward,
        authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(authorized_cap, amount, lock_id, clock, ctx);
    }

    /// Calculates the amount of rewards earned for a specific coin type and lock.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to check
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// The amount of rewards earned for the specified coin type and lock
    public fun earned<SailCoinType>(
        reward: &ExerciseFeeReward,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.earned<SailCoinType>(lock_id, clock)
    }

    /// Gets the prior balance index for a lock at a specific time.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to check
    /// * `lock` - The ID of the lock
    /// * `time` - The timestamp to check
    ///
    /// # Returns
    /// The balance index at the specified time
    public fun get_prior_balance_index(reward: &ExerciseFeeReward, lock: ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock, time)
    }

    /// Gets the prior supply index at a specific time.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to check
    /// * `time` - The timestamp to check
    ///
    /// # Returns
    /// The supply index at the specified time
    public fun get_prior_supply_index(reward: &ExerciseFeeReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    /// Gets the number of reward tokens in the rewards list.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to check
    ///
    /// # Returns
    /// The length of the rewards list
    public fun rewards_list_length(reward: &ExerciseFeeReward): u64 {
        reward.reward.rewards_list_length()
    }

    /// Withdraws rewards from the ExerciseFeeReward.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to withdraw from
    /// * `reward_authorized_cap` - Capability proving authorization to withdraw
    /// * `amount` - The amount to withdraw
    /// * `lock_id` - The ID of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun withdraw(
        reward: &mut ExerciseFeeReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    /// Borrows the reward field from the ExerciseFeeReward.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to borrow from
    ///
    /// # Returns
    /// A reference to the underlying Reward
    public fun borrow_reward(reward: &ExerciseFeeReward): &distribution::reward::Reward {
        &reward.reward
    }

    /// Claims rewards for a specific lock and sends them to the lock owner.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to claim from
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The amount of rewards claimed
    public fun get_reward<SailCoinType, CoinType>(
        reward: &mut ExerciseFeeReward,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = voting_escrow.owner_of(lock_id);
        let mut reward_balance_opt = reward.reward.get_reward_internal<CoinType>(lock_owner, lock_id, clock, ctx);
        let reward_amount = if (reward_balance_opt.is_some()) {
            let reward_balance = reward_balance_opt.extract();
            let amount = reward_balance.value();
            transfer::public_transfer<sui::coin::Coin<CoinType>>(
                sui::coin::from_balance<CoinType>(
                    reward_balance,
                    ctx
                ),
                lock_owner
            );
            amount
        } else {
            0
        };
        reward_balance_opt.destroy_none();
        reward_amount
    }

    /// Adds new reward tokens to the reward pool and updates the reward rate.
    /// Is supposed to be called by Minter when oSAIL is exercised.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward reward instance
    /// * `reward_authorized_cap` - The authorization capability for rewards
    /// * `coin` - The coin to add as rewards
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun notify_reward_amount<CoinType>(
        reward: &mut ExerciseFeeReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        coin: sui::coin::Coin<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.reward.authorized());
        let coin_type = std::type_name::get<CoinType>();
        // whitelist check is performend on the Minter level
        if (!reward.reward.rewards_contains(coin_type)) {
            reward.reward.add_reward_token(coin_type);
        };
        reward.reward.notify_reward_amount_internal(coin.into_balance(), clock, ctx);
    }

    /// Allows a voter to claim rewards for a specific lock
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward instance
    /// * `voter_cap` - The voter capability proving authority
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A balance containing the claimed rewards
    ///
    /// # Aborts
    /// * If the voter is not authorized to claim the rewards
    public fun voter_get_reward<SailCoinType, FeeCoinType>(
        reward: &mut ExerciseFeeReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::balance::Balance<FeeCoinType> {
        reward_authorized_cap.validate(reward.reward.authorized());
        let mut reward_balance_option = reward.reward.get_reward_internal<FeeCoinType>(
            voting_escrow.owner_of(lock_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (reward_balance_option.is_some()) {
            reward_balance_option.extract()
        } else {
            sui::balance::zero<FeeCoinType>()
        };
        reward_balance_option.destroy_none();
        reward_balance
    }


    /// Updates the balances of voting rewards for specific locks for a given epoch.
    /// This function is typically called by an authorized process to null balances
    /// of locks that have not voted during the epoch.
    ///
    /// # Arguments
    /// * `reward` - The `ExerciseFeeReward` instance to update.
    /// * `reward_authorized_cap` - Capability proving authorization to update balances.
    /// * `balances` - A vector of balance amounts corresponding to each `lock_id`.
    /// * `lock_ids` - A vector of `ID`s for the locks whose balances are being updated.
    /// * `for_epoch_start` - The timestamp marking the beginning of the epoch for which balances are being set.
    /// * `final` - true if thats the last update for the epoch
    /// * `ctx` - The transaction context.
    public fun update_balances(
        reward: &mut ExerciseFeeReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        balances: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        final: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.update_balances(
            reward_authorized_cap,
            balances,
            lock_ids,
            for_epoch_start,
            final,
            clock,
            ctx
        );
    }

    public fun rewards_at_epoch<FeeCoinType>(
        reward: &ExerciseFeeReward,
        epoch_start: u64
    ): u64 {
        reward.reward.rewards_at_epoch<FeeCoinType>(epoch_start)
    }

    public fun rewards_this_epoch<FeeCoinType>(
        reward: &ExerciseFeeReward,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.rewards_this_epoch<FeeCoinType>(clock)
    }

    public fun total_supply_at(reward: &ExerciseFeeReward, epoch_start: u64): u64 {
        reward.reward.total_supply_at(epoch_start)
    }

    public fun total_supply(reward: &ExerciseFeeReward, clock: &sui::clock::Clock): u64 {
        reward.reward.total_supply(clock)
    }
}

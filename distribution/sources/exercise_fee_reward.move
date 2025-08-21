module distribution::exercise_fee_reward {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    const EValidateVoterCapInvalid: u64 = 667556652936764400;

    public struct ExerciseFeeReward has store, key {
        id: UID,
        voter: ID,
        reward: ve::reward::Reward,
        reward_cap: ve::reward_cap::RewardCap,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public struct EventExerciseFeeRewardCreated has copy, drop, store {
        voter: ID,
        id: ID,
    }

    /// Creates a new ExerciseFeeReward instance. Supposed to be stored inside Voter,
    /// so it is not linked to VotingEscrow.
    ///
    /// # Arguments
    /// * `voter` - The ID of the voter
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
        let event = EventExerciseFeeRewardCreated {
            voter,
            id: inner_id,
        };
        sui::event::emit<EventExerciseFeeRewardCreated>(event);
        let (reward, reward_cap) = ve::reward::create(inner_id, reward_coin_types, true, ctx);
        ExerciseFeeReward {
            id,
            voter,
            reward,
            reward_cap,
            bag: sui::bag::new(ctx),
        }
    }

    /// Validates that the `VoterCap` corresponds to the voter of the `ExerciseFeeReward`.
    ///
    /// # Arguments
    /// * `reward` - The `ExerciseFeeReward` instance.
    /// * `voter_cap` - The `VoterCap` to validate.
    ///
    /// # Aborts
    /// * If the voter ID from `voter_cap` does not match `reward.voter`.
    public fun validate_voter_cap(reward: &ExerciseFeeReward, voter_cap: &distribution::voter_cap::VoterCap) {
        assert!(voter_cap.get_voter_id() == reward.voter, EValidateVoterCapInvalid);
    }

    /// Deposits rewards into the ExerciseFeeReward.
    /// Actually we are not depositing locks inside smart contracts right now cos
    /// we are calling update
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to deposit into
    /// * `voter_cap` - Capability proving authorization to deposit
    /// * `amount` - The amount to deposit
    /// * `lock_id` - The ID of the lock receiving the reward
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun deposit(
        reward: &mut ExerciseFeeReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.validate_voter_cap(voter_cap);
        reward.reward.deposit(&reward.reward_cap, amount, lock_id, clock, ctx);
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
    /// * `voter_cap` - Capability proving authorization to withdraw
    /// * `amount` - The amount to withdraw
    /// * `lock_id` - The ID of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun withdraw(
        reward: &mut ExerciseFeeReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.validate_voter_cap(voter_cap);
        reward.reward.withdraw(&reward.reward_cap, amount, lock_id, clock, ctx);
    }

    /// Borrows the reward field from the ExerciseFeeReward.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to borrow from
    ///
    /// # Returns
    /// A reference to the underlying Reward
    public fun borrow_reward(reward: &ExerciseFeeReward): &ve::reward::Reward {
        &reward.reward
    }

    /// Claims rewards for a specific lock and sends them to the lock owner.
    ///
    /// # Arguments
    /// * `reward` - The ExerciseFeeReward to claim from
    /// * `voter_cap` - The voter capability
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The amount of rewards claimed
    public fun get_reward<SailCoinType, CoinType>(
        reward: &mut ExerciseFeeReward,
        // voter emits events so we require voter cap to be passed in
        voter_cap: &distribution::voter_cap::VoterCap,
        voting_escrow: &ve::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &ve::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        reward.validate_voter_cap(voter_cap);
        let lock_id = object::id<ve::voting_escrow::Lock>(lock);
        let lock_owner = voting_escrow.owner_of(lock_id);
        let mut reward_balance_opt = reward.reward.get_reward_internal<CoinType>(
            &reward.reward_cap,
            lock_owner,
            lock_id,
            clock,
            ctx,
        );
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
    /// * `voter_cap` - The authorization capability for rewards
    /// * `coin` - The coin to add as rewards
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun notify_reward_amount<CoinType>(
        reward: &mut ExerciseFeeReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        coin: sui::coin::Coin<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.validate_voter_cap(voter_cap);
        let coin_type = std::type_name::get<CoinType>();
        // whitelist check is performend on the Minter level
        if (!reward.reward.rewards_contains(coin_type)) {
            reward.reward.add_reward_token(&reward.reward_cap, coin_type);
        };
        reward.reward.notify_reward_amount_internal(
            &reward.reward_cap,
            coin.into_balance(),
            clock,
            ctx
        );
    }


    /// Updates the balances of voting rewards for specific locks for a given epoch.
    /// This function is typically called by an authorized process to null balances
    /// of locks that have not voted during the epoch.
    ///
    /// # Arguments
    /// * `reward` - The `ExerciseFeeReward` instance to update.
    /// * `voter_cap` - Capability proving authorization to update balances.
    /// * `balances` - A vector of balance amounts corresponding to each `lock_id`.
    /// * `lock_ids` - A vector of `ID`s for the locks whose balances are being updated.
    /// * `for_epoch_start` - The timestamp marking the beginning of the epoch for which balances are being set.
    /// * `final` - true if thats the last update for the epoch
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context.
    public fun update_balances(
        reward: &mut ExerciseFeeReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        balances: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        final: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.validate_voter_cap(voter_cap);
        reward.reward.update_balances(
            &reward.reward_cap,
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

    public fun voter(reward: &ExerciseFeeReward): ID {
        reward.voter
    }
}

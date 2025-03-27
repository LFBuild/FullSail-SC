module distribution::bribe_voting_reward {
    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372410516930559;

    public struct BribeVotingReward has store, key {
        id: UID,
        gauge: ID,
        reward: distribution::reward::Reward,
    }

    /// Creates a new BribeVotingReward instance.
    /// 
    /// # Arguments
    /// * `voter` - The ID of the voter
    /// * `ve` - The ID of the voting escrow
    /// * `authorized` - The ID of the authorized gauge
    /// * `reward_coin_types` - Vector of coin types that can be used as rewards
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A new BribeVotingReward instance
    public(package) fun create(
        voter: ID,
        ve: ID,
        authorized: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): BribeVotingReward {
        BribeVotingReward {
            id: object::new(ctx),
            gauge: authorized,
            reward: distribution::reward::create(voter, ve, voter, reward_coin_types, ctx),
        }
    }

    /// Deposits rewards into the BribeVotingReward.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to deposit into
    /// * `authorized_cap` - Capability proving authorization to deposit
    /// * `amount` - The amount to deposit
    /// * `lock_id` - The ID of the lock receiving the reward
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun deposit(
        reward: &mut BribeVotingReward,
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
    /// * `reward` - The BribeVotingReward to check
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The amount of rewards earned for the specified coin type and lock
    public fun earned<SailCoinType>(
        reward: &BribeVotingReward,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.earned<SailCoinType>(lock_id, clock)
    }

    /// Gets the prior balance index for a lock at a specific time.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to check
    /// * `lock` - The ID of the lock
    /// * `time` - The timestamp to check
    /// 
    /// # Returns
    /// The balance index at the specified time
    public fun get_prior_balance_index(reward: &BribeVotingReward, lock: ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock, time)
    }

    /// Gets the prior supply index at a specific time.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to check
    /// * `time` - The timestamp to check
    /// 
    /// # Returns
    /// The supply index at the specified time
    public fun get_prior_supply_index(reward: &BribeVotingReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    /// Gets the number of reward tokens in the rewards list.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to check
    /// 
    /// # Returns
    /// The length of the rewards list
    public fun rewards_list_length(reward: &BribeVotingReward): u64 {
        reward.reward.rewards_list_length()
    }

    /// Withdraws rewards from the BribeVotingReward.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to withdraw from
    /// * `reward_authorized_cap` - Capability proving authorization to withdraw
    /// * `amount` - The amount to withdraw
    /// * `lock_id` - The ID of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun withdraw(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    /// Borrows the reward field from the BribeVotingReward.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to borrow from
    /// 
    /// # Returns
    /// A reference to the underlying Reward
    public fun borrow_reward(reward: &BribeVotingReward): &distribution::reward::Reward {
        &reward.reward
    }

    /// Claims rewards for a specific lock and sends them to the lock owner.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to claim from
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// The amount of rewards claimed
    public fun get_reward<SailCoinType, BribeCoinType>(
        reward: &mut BribeVotingReward,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = voting_escrow.owner_of(lock_id);
        let mut reward_balance_opt = reward.reward.get_reward_internal<BribeCoinType>(lock_owner, lock_id, clock, ctx);
        let reward_amount = if (reward_balance_opt.is_some()) {
            let reward_balance = reward_balance_opt.extract();
            let amount = reward_balance.value();
            transfer::public_transfer<sui::coin::Coin<BribeCoinType>>(
                sui::coin::from_balance<BribeCoinType>(
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

    /// Adds a new reward token or refreshes the reward amount for an existing token.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to update
    /// * `witelisted_token` - Optional whitelisted token capability
    /// * `arg2` - The coin to use as rewards
    /// * `arg3` - The system clock
    /// * `arg4` - The transaction context
    /// 
    /// # Aborts
    /// * If the token is not in the rewards list and not whitelisted
    public fun notify_reward_amount<CoinType>(
        reward: &mut BribeVotingReward,
        mut witelisted_token: Option<distribution::whitelisted_tokens::WhitelistedToken>,
        arg2: sui::coin::Coin<CoinType>,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.reward.rewards_contains(coin_type_name)) {
            assert!(
                witelisted_token.is_some(),
                ENotifyRewardAmountTokenNotWhitelisted
            );
            witelisted_token.extract().validate<CoinType>(reward.reward.voter());
            reward.reward.add_reward_token(coin_type_name);
        };
        if (witelisted_token.is_some()) {
            witelisted_token.destroy_some().validate<CoinType>(reward.reward.voter());
        } else {
            witelisted_token.destroy_none();
        };
        reward.reward.notify_reward_amount_internal(arg2.into_balance(), arg3, arg4);
    }

    /// Allows a voter to claim rewards for a specific lock, returning the balance instead
    /// of automatically transferring it.
    /// 
    /// # Arguments
    /// * `reward` - The BribeVotingReward to claim from
    /// * `reward_authorized_cap` - Capability proving authorization to claim
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// The balance of rewards claimed
    public fun voter_get_reward<SailCoinType, BribeCoinType>(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::balance::Balance<BribeCoinType> {
        reward_authorized_cap.validate(reward.reward.authorized());
        let mut reward_balance_option = reward.reward.get_reward_internal<BribeCoinType>(
            voting_escrow.owner_of(lock_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (reward_balance_option.is_some()) {
            reward_balance_option.extract()
        } else {
            sui::balance::zero<BribeCoinType>()
        };
        reward_balance_option.destroy_none();
        reward_balance
    }
}


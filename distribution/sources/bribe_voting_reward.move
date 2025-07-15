module distribution::bribe_voting_reward {
    /// The BribeVotingReward module implements a key mechanism in the platform's governance system
    /// designed to incentivize specific voting behaviors. In decentralized finance (DeFi), bribes 
    /// are a legitimate and common mechanism where external parties offer rewards (bribes) to token 
    /// holders to encourage them to vote in a particular way, typically to direct protocol resources 
    /// or emissions to specific liquidity pools.
    /// 
    /// This module:
    /// - Allows protocol participants to offer tokens as rewards to voters who support specific pools
    /// - Creates a transparent economic incentive system for governance participation
    /// - Manages the calculation and distribution of rewards based on voting power and participation
    /// - Connects the platform's liquidity gauges (which measure pool importance) with voting incentives
    /// - Enables a market-driven approach to gauge weight determination
    /// 
    /// The BribeVotingReward system works alongside the fee distribution system, where:
    /// - Fee rewards are protocol-generated incentives from trading activities
    /// - Bribe rewards are externally provided incentives to influence voting
    /// 
    /// This dual reward system creates a comprehensive economic model that aligns
    /// stakeholder interests and promotes active participation in the protocol's governance.
    ///
    /// Each BribeVotingReward instance is associated with a specific gauge and manages
    /// the rewards offered to voters supporting that gauge's associated liquidity pool.

    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372410516930559;

    public struct BribeVotingReward has store, key {
        id: UID,
        gauge: ID,
        reward: distribution::reward::Reward,
    }

    public struct EventBribeVotingRewardCreated has copy, drop, store {
        id: ID,
        gauge_id: ID,
    }

    /// Creates a new BribeVotingReward instance.
    /// 
    /// # Arguments
    /// * `voter` - The ID of the voter
    /// * `ve` - The ID of the voting escrow
    /// * `gauge_id` - The ID of the authorized gauge
    /// * `reward_coin_types` - Vector of coin types that can be used as rewards
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A new BribeVotingReward instance
    public(package) fun create(
        voter: ID,
        ve: ID,
        gauge_id: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): BribeVotingReward {
        let id = object::new(ctx);
        let bribe_voting_reward_created_event = EventBribeVotingRewardCreated {
            id: object::uid_to_inner(&id),
            gauge_id,
        };
        sui::event::emit<EventBribeVotingRewardCreated>(bribe_voting_reward_created_event);
        BribeVotingReward {
            id,
            gauge: gauge_id,
            reward: distribution::reward::create(
                voter,
                option::some(ve),
                voter,
                reward_coin_types,
                true,
                ctx
            ),
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

    /// Updates the balances of bribe rewards for specific locks for a given epoch.
    /// This function is typically called by an authorized process to retroactively record
    /// voting power that determine rewards distribution. It is required due to voting power
    /// calculation being too expensive to be done on-chain.
    ///
    /// # Arguments
    /// * `reward` - The `BribeVotingReward` instance to update.
    /// * `reward_authorized_cap` - Capability proving authorization to update balances.
    /// * `balances` - A vector of balance amounts corresponding to each `lock_id`.
    /// * `lock_ids` - A vector of `ID`s for the locks whose balances are being updated.
    /// * `for_epoch_start` - The timestamp marking the beginning of the epoch for which balances are being set.
    /// * `final` - true if thats the last update for the epoch
    /// * `ctx` - The transaction context.
    public fun update_balances(
        reward: &mut BribeVotingReward,
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
    /// * `whitelisted_token` - Optional whitelisted token capability
    /// * `reward_coin` - The coin to use as rewards
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the token is not in the rewards list and not whitelisted
    public fun notify_reward_amount<CoinType>(
        reward: &mut BribeVotingReward,
        mut whitelisted_token: Option<distribution::whitelisted_tokens::WhitelistedToken>,
        reward_coin: sui::coin::Coin<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.reward.rewards_contains(coin_type_name)) {
            assert!(
                whitelisted_token.is_some(),
                ENotifyRewardAmountTokenNotWhitelisted
            );
            whitelisted_token.extract().validate<CoinType>(reward.reward.voter());
            reward.reward.add_reward_token(coin_type_name);
        };
        if (whitelisted_token.is_some()) {
            whitelisted_token.destroy_some().validate<CoinType>(reward.reward.voter());
        } else {
            whitelisted_token.destroy_none();
        };
        reward.reward.notify_reward_amount_internal(reward_coin.into_balance(), clock, ctx);
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


    public fun rewards_at_epoch<FeeCoinType>(
        reward: &BribeVotingReward,
        epoch_start: u64
    ): u64 {
        reward.reward.rewards_at_epoch<FeeCoinType>(epoch_start)
    }

    public fun rewards_this_epoch<FeeCoinType>(
        reward: &BribeVotingReward,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.rewards_this_epoch<FeeCoinType>(clock)
    }

    public fun total_supply_at(reward: &BribeVotingReward, epoch_start: u64): u64 {
        reward.reward.total_supply_at(epoch_start)
    }

    public fun total_supply(reward: &BribeVotingReward, clock: &sui::clock::Clock): u64 {
        reward.reward.total_supply(clock)
    }
}


/// This module implements the fee voting reward distribution mechanism for the platform.
///
/// # Overview
/// The `fee_voting_reward` module is a critical component of the platform's tokenomics and governance system.
/// It manages the distribution of trading fee rewards to users who participate in the governance process
/// through voting. This creates an incentive mechanism where users who help direct liquidity (via voting)
/// receive a share of the generated trading fees.
///
/// # Mechanism
/// 1. Trading fees are collected from liquidity pools by gauges
/// 2. These fees are transferred to the FeeVotingReward system
/// 3. Voters can claim their proportional share of fees based on their voting power
/// 4. Rewards are tracked per epoch and per lock (voting position)
///
/// This module works alongside other components such as `voting_escrow`, `voter`, and `gauge` to create
/// a complete fee-sharing governance system that incentivizes participation in platform governance.
module distribution::fee_voting_reward {
    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372427696799743;
    const EVoterGetRewardInvalidVoter: u64 = 9223372358977323007;

    public struct FeeVotingReward has store, key {
        id: UID,
        gauge: ID,
        reward: distribution::reward::Reward,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    /// Returns the balance of a specific fee coin type in the reward
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    ///
    /// # Returns
    /// The balance amount of the specified coin type
    public fun balance<FeeCoinType>(reward: &FeeVotingReward): u64 {
        reward.reward.balance<FeeCoinType>()
    }

    /// Creates a new FeeVotingReward instance
    ///
    /// # Arguments
    /// * `voter` - The ID of the voter
    /// * `ve` - The ID of the voting escrow
    /// * `authorized` - The ID of the authorized entity
    /// * `reward_coin_types` - Vector of coin types that are allowed as rewards
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A new FeeVotingReward instance
    public(package) fun create(
        voter: ID,
        ve: ID,
        authorized: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): FeeVotingReward {
        let id = object::new(ctx);
        let inner_id = id.uid_to_inner();
        FeeVotingReward {
            id,
            gauge: authorized,
            reward: distribution::reward::create(
                inner_id,
                voter,
                option::some(ve),
                voter,
                reward_coin_types,
                true,
                ctx
            ),
            bag: sui::bag::new(ctx),
        }
    }

    /// Deposits reward tokens into the fee voting reward system
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `reward_authorized_cap` - The authorization capability for rewards
    /// * `amount` - The amount of tokens to deposit
    /// * `lock_id` - The ID of the lock to deposit rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun deposit(
        reward: &mut FeeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    /// Calculates the rewards earned for a specific lock
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `lock_id` - The ID of the lock to check rewards for
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// The amount of rewards earned for the specified lock
    public fun earned<FeeCoinType>(reward: &FeeVotingReward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        reward.reward.earned<FeeCoinType>(lock_id, clock)
    }

    /// Gets the index of the prior balance record for a specific lock at a given time
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `lock_id` - The ID of the lock
    /// * `time` - The timestamp to check
    ///
    /// # Returns
    /// The index of the prior balance record
    public fun get_prior_balance_index(reward: &FeeVotingReward, lock_id: ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock_id, time)
    }

    /// Gets the index of the prior supply record at a given time
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `time` - The timestamp to check
    ///
    /// # Returns
    /// The index of the prior supply record
    public fun get_prior_supply_index(reward: &FeeVotingReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    /// Returns the length of the rewards list
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    ///
    /// # Returns
    /// The number of reward types in the rewards list
    public fun rewards_list_length(reward: &FeeVotingReward): u64 {
        reward.reward.rewards_list_length()
    }

    /// Withdraws rewards from the fee voting reward system
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `reward_authorized_cap` - The authorization capability for rewards
    /// * `amount` - The amount of tokens to withdraw
    /// * `lock_id` - The ID of the lock to withdraw rewards from
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun withdraw(
        reward: &mut FeeVotingReward,
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
        reward: &mut FeeVotingReward,
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

    /// Returns a reference to the underlying reward
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    ///
    /// # Returns
    /// A reference to the internal reward object
    public fun borrow_reward(reward: &FeeVotingReward): &distribution::reward::Reward {
        &reward.reward
    }

    /// Claims rewards for a lock owner and transfers them directly to the owner
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The amount of rewards claimed
    ///
    /// # Aborts
    /// * If the lock owner cannot be determined
    public fun get_reward<SailCoinType, FeeCoinType>(
        reward: &mut FeeVotingReward,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = voting_escrow.owner_of(lock_id);
        let mut reward_balance_opt = reward.reward.get_reward_internal<FeeCoinType>(lock_owner, lock_id, clock, ctx);
        let reward_amount = if (reward_balance_opt.is_some()) {
            let reward_balance = reward_balance_opt.extract();
            let amount = reward_balance.value();
            transfer::public_transfer<sui::coin::Coin<FeeCoinType>>(
                sui::coin::from_balance<FeeCoinType>(
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

    /// Adds new reward tokens to the reward pool and updates the reward rate
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
    /// * `reward_authorized_cap` - The authorization capability for rewards
    /// * `coin` - The coin to add as rewards
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the token type is not in the whitelist of accepted reward tokens
    public fun notify_reward_amount<FeeCoinType>(
        reward: &mut FeeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        coin: sui::coin::Coin<FeeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.reward.authorized());
        assert!(
            reward.reward.rewards_contains(std::type_name::get<FeeCoinType>()),
            ENotifyRewardAmountTokenNotWhitelisted
        );
        reward.reward.notify_reward_amount_internal(coin.into_balance(), clock, ctx);
    }

    /// Allows a voter to claim rewards for a specific lock
    ///
    /// # Arguments
    /// * `reward` - The fee voting reward instance
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
        reward: &mut FeeVotingReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::balance::Balance<FeeCoinType> {
        assert!(
            voter_cap.get_voter_id() == reward.reward.voter(),
            EVoterGetRewardInvalidVoter
        );
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

    public fun rewards_at_epoch<FeeCoinType>(
        reward: &FeeVotingReward,
        epoch_start: u64
    ): u64 {
        reward.reward.rewards_at_epoch<FeeCoinType>(epoch_start)
    }

    public fun rewards_this_epoch<FeeCoinType>(
        reward: &FeeVotingReward,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.rewards_this_epoch<FeeCoinType>(clock)
    }

    public fun total_supply_at(reward: &FeeVotingReward, epoch_start: u64): u64 {
        reward.reward.total_supply_at(epoch_start)
    }

    public fun total_supply(reward: &FeeVotingReward, clock: &sui::clock::Clock): u64 {
        reward.reward.total_supply(clock)
    }
}


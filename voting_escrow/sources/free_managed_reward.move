/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
/// 
/// A module that provides a wrapper around the base reward system for freely distributable rewards.
/// This specialized wrapper enables token distribution to participants without requiring tokens to be locked.
/// 
/// The FreeManagedReward serves as a key component in the reward distribution system, allowing:
/// - Distribution of rewards to users who hold specific assets (identified by lock_id)
/// - Support for multiple token types as rewards
/// - Time-weighted reward distribution based on the voting escrow system
/// - Permissioned deposit and withdrawal of rewards through an authorization system
///
/// The key difference between this and other reward types (like locked_managed_reward) is that
/// rewards can be freely claimed without additional restrictions beyond ownership proof.
///
/// This module integrates with other distribution components:
/// - voting_escrow: For time-weighted balances
/// - reward: For core reward distribution logic
/// - whitelisted_tokens: For token validation
module voting_escrow::free_managed_reward {

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ENotifyRewardAmountTokenNotAllowed: u64 = 9223372389042094079;

    public struct FreeManagedReward has store, key {
        id: UID,
        voter: ID,
        ve: ID,
        reward: voting_escrow::reward::Reward,
        reward_cap: voting_escrow::reward_cap::RewardCap,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    /// Creates a new FreeManagedReward instance.
    /// 
    /// # Arguments
    /// * `voter` - The ID of the voter module
    /// * `ve` - The ID of the voting escrow module
    /// * `reward_coin_type` - The type name of the coin to be used as the initial reward
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// A new FreeManagedReward object with initialized reward data
    public(package) fun create(
        voter: ID,
        ve: ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut TxContext
    ): FreeManagedReward {
        let mut type_name_vec = std::vector::empty<std::type_name::TypeName>();
        type_name_vec.push_back(reward_coin_type);
        let id = object::new(ctx);
        let inner_id = id.uid_to_inner();
        let (reward, reward_cap) = voting_escrow::reward::create(
                inner_id,
                type_name_vec,
                false,
                ctx
        );
        FreeManagedReward {
            id,
            voter,
            ve,
            reward,
            reward_cap,
            bag: sui::bag::new(ctx),
        }
    }

    /// Deposits an amount of tokens into the reward system for a specific lock.
    /// 
    /// # Arguments
    /// * `reward` - The FreeManagedReward object to deposit into
    /// * `amount` - The amount of tokens to deposit
    /// * `lock_id` - The ID of the lock to deposit for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public(package) fun deposit(
        reward: &mut FreeManagedReward,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(&reward.reward_cap, amount, lock_id, clock, ctx);
    }

    /// Calculates how much of a specific reward token type a lock has earned.
    /// 
    /// # Arguments
    /// * `reward` - The FreeManagedReward object
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - Clock object for timestamp
    /// 
    /// # Returns
    /// The amount of reward tokens earned
    public fun earned<RewardCoinType>(
        reward: &FreeManagedReward,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.earned<RewardCoinType>(lock_id, clock)
    }

    public fun get_prior_balance_index(
        reward: &FreeManagedReward,
        lock_id: ID,
        time: u64
    ): u64 {
        reward.reward.get_prior_balance_index(lock_id, time)
    }

    public fun rewards_list(reward: &FreeManagedReward): vector<std::type_name::TypeName> {
        reward.reward.rewards_list()
    }

    public fun rewards_list_length(reward: &FreeManagedReward): u64 {
        reward.reward.rewards_list_length()
    }

    public(package) fun withdraw(
        reward: &mut FreeManagedReward,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(&reward.reward_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &FreeManagedReward): &voting_escrow::reward::Reward {
        &reward.reward
    }

    public fun get_prior_supply_index(reward: &FreeManagedReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    /// Claims rewards for a specific token type.
    /// Transfers the earned rewards to the owner of the lock.
    /// 
    /// # Arguments
    /// * `reward` - The FreeManagedReward object
    /// * `owner` - The address of the owner of the lock
    /// * `lock_id` - The ID of the lock to claim rewards for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    public(package) fun get_reward<RewardCoinType>(
        reward: &mut FreeManagedReward,
        owner: address,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut reward_coin = reward.reward.get_reward_internal<RewardCoinType>(
            &reward.reward_cap,
            owner,
            lock_id,
            clock,
            ctx
        );
        if (reward_coin.is_some()) {
            transfer::public_transfer<sui::coin::Coin<RewardCoinType>>(
                sui::coin::from_balance<RewardCoinType>(
                    reward_coin.extract(),
                    ctx
                ),
                owner
            );
        };
        reward_coin.destroy_none();
    }

    /// Notifies the reward contract about new rewards being added.
    /// Updates internal accounting and distributes rewards according to participant shares.
    /// 
    /// # Arguments
    /// * `reward` - The FreeManagedReward object
    /// * `whitelisted_token` - Optional whitelist validation for the token type
    /// * `coin` - The coin to add as a reward
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the token is not in the rewards list and no whitelisted token is provided
    /// * If the whitelisted token validation fails
    public fun notify_reward_amount<RewardCoinType>(
        reward: &mut FreeManagedReward,
        mut whitelisted_token: Option<voting_escrow::whitelisted_tokens::WhitelistedToken>,
        coin: sui::coin::Coin<RewardCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let coin_type_name = std::type_name::get<RewardCoinType>();
        if (!reward.reward.rewards_contains(coin_type_name)) {
            assert!(
                whitelisted_token.is_some(),
                ENotifyRewardAmountTokenNotAllowed
            );
            whitelisted_token.extract().validate<RewardCoinType>(reward.voter());
            reward.reward.add_reward_token(&reward.reward_cap, coin_type_name);
        };
        if (whitelisted_token.is_some()) {
            whitelisted_token.extract().validate<RewardCoinType>(reward.voter());
        };
        whitelisted_token.destroy_none();
        reward.reward.notify_reward_amount_internal(&reward.reward_cap, coin.into_balance(), clock, ctx);
    }

    public fun voter(reward: &FreeManagedReward): ID {
        reward.voter
    }

    public fun ve(reward: &FreeManagedReward): ID {
        reward.ve
    }
}


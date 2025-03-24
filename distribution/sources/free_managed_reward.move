module distribution::free_managed_reward {

    const EGetRewardInvalidProver: u64 = 9223372337502486527;

    const ENotifyRewardAmountTokenNotAllowed: u64 = 9223372389042094079;

    public struct FreeManagedReward has store, key {
        id: UID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        voter: ID,
        ve: ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut TxContext
    ): FreeManagedReward {
        let mut type_name_vec = std::vector::empty<std::type_name::TypeName>();
        type_name_vec.push_back(reward_coin_type);
        FreeManagedReward {
            id: object::new(ctx),
            reward: distribution::reward::create(voter, ve, ve, type_name_vec, ctx),
        }
    }

    public fun deposit(
        reward: &mut FreeManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.deposit(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

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

    public fun withdraw(
        reward: &mut FreeManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward.reward.withdraw(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &FreeManagedReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_prior_supply_index(reward: &FreeManagedReward, time: u64): u64 {
        reward.get_prior_supply_index(time)
    }

    public fun get_reward<RewardCoinType>(
        reward: &mut FreeManagedReward,
        owner_proff: distribution::lock_owner::OwnerProof,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (prover, lock, owner) = owner_proff.consume();
        assert!(reward.reward.ve() == prover, EGetRewardInvalidProver);
        let mut reward_coin = reward.reward.get_reward_internal<RewardCoinType>(
            tx_context::sender(ctx),
            lock,
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

    public fun notify_reward_amount<RewardCoinType>(
        reward: &mut FreeManagedReward,
        mut whitelisted_token: Option<distribution::whitelisted_tokens::WhitelistedToken>,
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
            whitelisted_token.extract().validate<RewardCoinType>(reward.reward.voter());
            reward.reward.add_reward_token(coin_type_name);
        };
        if (whitelisted_token.is_some()) {
            whitelisted_token.extract().validate<RewardCoinType>(reward.reward.voter());
        };
        whitelisted_token.destroy_none();
        reward.reward.notify_reward_amount_internal(coin.into_balance(), clock, ctx);
    }
}


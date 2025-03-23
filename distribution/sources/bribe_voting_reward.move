module distribution::bribe_voting_reward {
    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372410516930559;

    public struct BribeVotingReward has store, key {
        id: sui::object::UID,
        gauge: sui::object::ID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        voter: sui::object::ID,
        ve: sui::object::ID,
        authorized: sui::object::ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut sui::tx_context::TxContext
    ): BribeVotingReward {
        BribeVotingReward {
            id: sui::object::new(ctx),
            gauge: authorized,
            reward: distribution::reward::create(voter, ve, voter, reward_coin_types, ctx),
        }
    }

    public fun deposit(
        reward: &mut BribeVotingReward,
        authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        reward.reward.deposit(authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun earned<SailCoinType>(
        reward: &BribeVotingReward,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u64 {
        reward.reward.earned<SailCoinType>(lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &BribeVotingReward, lock: sui::object::ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock, time)
    }

    public fun get_prior_supply_index(reward: &BribeVotingReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    public fun rewards_list_length(reward: &BribeVotingReward): u64 {
        reward.reward.rewards_list_length()
    }

    public fun withdraw(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        reward.reward.withdraw(reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &BribeVotingReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_reward<SailCoinType, BribeCoinType>(
        reward: &mut BribeVotingReward,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let lock_id = sui::object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = voting_escrow.owner_of(lock_id);
        let mut reward_balance_opt = reward.reward.get_reward_internal<BribeCoinType>(lock_owner, lock_id, clock, ctx);
        let reward_amount = if (reward_balance_opt.is_some()) {
            let reward_balance = reward_balance_opt.extract();
            let amount = reward_balance.value();
            sui::transfer::public_transfer<sui::coin::Coin<BribeCoinType>>(
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

    public fun notify_reward_amount<CoinType>(
        reward: &mut BribeVotingReward,
        mut witelisted_token: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>,
        arg2: sui::coin::Coin<CoinType>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
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

    public fun voter_get_reward<SailCoinType, BribeCoinType>(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
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


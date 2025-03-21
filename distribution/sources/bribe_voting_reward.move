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
        distribution::reward::deposit(&mut reward.reward, authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun earned<SailCoinType>(reward: &BribeVotingReward, lock_id: sui::object::ID, clock: &sui::clock::Clock): u64 {
        distribution::reward::earned<SailCoinType>(&reward.reward, lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &BribeVotingReward, lock: sui::object::ID, time: u64): u64 {
        distribution::reward::get_prior_balance_index(&reward.reward, lock, time)
    }

    public fun get_prior_supply_index(reward: &BribeVotingReward, time: u64): u64 {
        distribution::reward::get_prior_supply_index(&reward.reward, time)
    }

    public fun rewards_list_length(reward: &BribeVotingReward): u64 {
        distribution::reward::rewards_list_length(&reward.reward)
    }

    public fun withdraw(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::withdraw(&mut reward.reward, reward_authorized_cap, amount, lock_id, clock, ctx);
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
    ) {
        let lock_id = sui::object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = distribution::voting_escrow::owner_of<SailCoinType>(voting_escrow, lock_id);
        let mut reward_balance = distribution::reward::get_reward_internal<BribeCoinType>(
            &mut reward.reward,
            lock_owner,
            lock_id,
            clock,
            ctx
        );
        if (std::option::is_some<sui::balance::Balance<BribeCoinType>>(&reward_balance)) {
            sui::transfer::public_transfer<sui::coin::Coin<BribeCoinType>>(
                sui::coin::from_balance<BribeCoinType>(
                    std::option::extract<sui::balance::Balance<BribeCoinType>>(&mut reward_balance),
                    ctx
                ),
                lock_owner
            );
        };
        std::option::destroy_none<sui::balance::Balance<BribeCoinType>>(reward_balance);
    }

    public fun notify_reward_amount<CoinType>(
        reward: &mut BribeVotingReward,
        mut witelisted_token: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>,
        arg2: sui::coin::Coin<CoinType>,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!distribution::reward::rewards_contains(&reward.reward, coin_type_name)) {
            assert!(
                std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&witelisted_token),
                ENotifyRewardAmountTokenNotWhitelisted
            );
            distribution::whitelisted_tokens::validate<CoinType>(
                std::option::extract<distribution::whitelisted_tokens::WhitelistedToken>(&mut witelisted_token),
                distribution::reward::voter(&reward.reward)
            );
            distribution::reward::add_reward_token(&mut reward.reward, coin_type_name);
        };
        if (std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&witelisted_token)) {
            distribution::whitelisted_tokens::validate<CoinType>(
                std::option::destroy_some<distribution::whitelisted_tokens::WhitelistedToken>(witelisted_token),
                distribution::reward::voter(&reward.reward)
            );
        } else {
            std::option::destroy_none<distribution::whitelisted_tokens::WhitelistedToken>(witelisted_token);
        };
        distribution::reward::notify_reward_amount_internal<CoinType>(
            &mut reward.reward,
            sui::coin::into_balance<CoinType>(arg2),
            arg3,
            arg4
        );
    }

    public fun voter_get_reward<SailCoinType, BribeCoinType>(
        reward: &mut BribeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<BribeCoinType> {
        distribution::reward_authorized_cap::validate(
            reward_authorized_cap,
            distribution::reward::authorized(&reward.reward)
        );
        let mut reward_balance_option = distribution::reward::get_reward_internal<BribeCoinType>(
            &mut reward.reward,
            distribution::voting_escrow::owner_of<SailCoinType>(voting_escrow, lock_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (std::option::is_some<sui::balance::Balance<BribeCoinType>>(&reward_balance_option)) {
            std::option::extract<sui::balance::Balance<BribeCoinType>>(&mut reward_balance_option)
        } else {
            sui::balance::zero<BribeCoinType>()
        };
        std::option::destroy_none<sui::balance::Balance<BribeCoinType>>(reward_balance_option);
        reward_balance
    }
}


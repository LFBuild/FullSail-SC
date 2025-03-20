module distribution::free_managed_reward {

    const EGetRewardInvalidProver: u64 = 9223372337502486527;

    const ENotifyRewardAmountTokenNotAllowed: u64 = 9223372389042094079;

    public struct FreeManagedReward has store, key {
        id: sui::object::UID,
        reward: distribution::reward::Reward,
    }

    public(package) fun create(
        voter: sui::object::ID,
        ve: sui::object::ID,
        reward_coin_type: std::type_name::TypeName,
        ctx: &mut sui::tx_context::TxContext
    ): FreeManagedReward {
        let mut type_name_vec = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut type_name_vec, reward_coin_type);
        FreeManagedReward {
            id: sui::object::new(ctx),
            reward: distribution::reward::create(voter, ve, ve, type_name_vec, ctx),
        }
    }

    public fun deposit(
        reward: &mut FreeManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::deposit(
            &mut reward.reward,
            reward_authorized_cap,
            amount,
            lock_id,
            clock,
            ctx
        );
    }

    public fun earned<CoinType>(
        reward: &FreeManagedReward,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u64 {
        distribution::reward::earned<CoinType>(&reward.reward, lock_id, clock)
    }

    public fun get_prior_balance_index(
        reward: &FreeManagedReward,
        lock_id: sui::object::ID,
        time: u64
    ): u64 {
        distribution::reward::get_prior_balance_index(&reward.reward, lock_id, time)
    }

    public fun rewards_list(reward: &FreeManagedReward): vector<std::type_name::TypeName> {
        distribution::reward::rewards_list(&reward.reward)
    }

    public fun rewards_list_length(reward: &FreeManagedReward): u64 {
        distribution::reward::rewards_list_length(&reward.reward)
    }

    public fun withdraw(
        reward: &mut FreeManagedReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::withdraw(
            &mut reward.reward,
            reward_authorized_cap,
            amount,
            lock_id,
            clock,
            ctx
        );
    }

    public fun borrow_reward(reward: &FreeManagedReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_prior_supply_index(reward: &FreeManagedReward, time: u64): u64 {
        get_prior_supply_index(reward, time)
    }

    public fun get_reward<CoinType>(
        reward: &mut FreeManagedReward,
        owner_proff: distribution::lock_owner::OwnerProof,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (prover, lock, owner) = distribution::lock_owner::consume(owner_proff);
        assert!(distribution::reward::ve(&reward.reward) == prover, EGetRewardInvalidProver);
        let mut reward_coin = distribution::reward::get_reward_internal<CoinType>(
            &mut reward.reward,
            sui::tx_context::sender(ctx),
            lock,
            clock,
            ctx
        );
        if (std::option::is_some<sui::balance::Balance<CoinType>>(&reward_coin)) {
            sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
                sui::coin::from_balance<CoinType>(
                    std::option::extract<sui::balance::Balance<CoinType>>(&mut reward_coin),
                    ctx
                ),
                owner
            );
        };
        std::option::destroy_none<sui::balance::Balance<CoinType>>(reward_coin);
    }

    public fun notify_reward_amount<CoinType>(
        reward: &mut FreeManagedReward,
        mut whitelisted_token: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>,
        coin: sui::coin::Coin<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!distribution::reward::rewards_contains(&reward.reward, coin_type_name)) {
            assert!(
                std::option::is_some<distribution::whitelisted_tokens::WhitelistedToken>(&whitelisted_token),
                ENotifyRewardAmountTokenNotAllowed
            );
            distribution::whitelisted_tokens::validate<CoinType>(
                std::option::extract<distribution::whitelisted_tokens::WhitelistedToken>(&mut whitelisted_token),
                distribution::reward::voter(&reward.reward)
            );
            distribution::reward::add_reward_token(&mut reward.reward, coin_type_name);
        };
        std::option::destroy_none<distribution::whitelisted_tokens::WhitelistedToken>(whitelisted_token);
        distribution::reward::notify_reward_amount_internal<CoinType>(
            &mut reward.reward,
            sui::coin::into_balance<CoinType>(coin),
            clock,
            ctx
        );
    }
}


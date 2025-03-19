module distribution::fee_voting_reward {
    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372427696799743;
    const EVoterGetRewardInvalidVoter: u64 = 9223372358977323007;

    public struct FeeVotingReward has store, key {
        id: sui::object::UID,
        gauge: sui::object::ID,
        reward: distribution::reward::Reward,
    }

    public fun balance<FeeCoinType>(arg0: &FeeVotingReward): u64 {
        distribution::reward::balance<FeeCoinType>(&arg0.reward)
    }

    public(package) fun create(
        voter: sui::object::ID,
        ve: sui::object::ID,
        authorized: sui::object::ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut sui::tx_context::TxContext
    ): FeeVotingReward {
        FeeVotingReward {
            id: sui::object::new(ctx),
            gauge: authorized,
            reward: distribution::reward::create(voter, ve, voter, reward_coin_types, ctx),
        }
    }

    public fun deposit(
        reward: &mut FeeVotingReward,
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

    public fun earned<FeeCoinType>(reward: &FeeVotingReward, lock_id: sui::object::ID, clock: &sui::clock::Clock): u64 {
        distribution::reward::earned<FeeCoinType>(&reward.reward, lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &FeeVotingReward, lock_id: sui::object::ID, time: u64): u64 {
        distribution::reward::get_prior_balance_index(&reward.reward, lock_id, time)
    }

    public fun get_prior_supply_index(reward: &FeeVotingReward, time: u64): u64 {
        distribution::reward::get_prior_supply_index(&reward.reward, time)
    }

    public fun rewards_list_length(reward: &FeeVotingReward): u64 {
        distribution::reward::rewards_list_length(&reward.reward)
    }

    public fun withdraw(
        reward: &mut FeeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward::withdraw(&mut reward.reward, reward_authorized_cap, amount, lock_id, clock, ctx);
    }

    public fun borrow_reward(reward: &FeeVotingReward): &distribution::reward::Reward {
        &reward.reward
    }

    public fun get_reward<SailCoinType, FeeCoinType>(
        reward: &mut FeeVotingReward,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let lock_id = sui::object::id<distribution::voting_escrow::Lock>(lock);
        let lock_owner = distribution::voting_escrow::owner_of<SailCoinType>(voting_escrow, lock_id);
        let mut reward_balance = distribution::reward::get_reward_internal<FeeCoinType>(&mut reward.reward, lock_owner, lock_id, clock, ctx);
        if (std::option::is_some<sui::balance::Balance<FeeCoinType>>(&reward_balance)) {
            sui::transfer::public_transfer<sui::coin::Coin<FeeCoinType>>(
                sui::coin::from_balance<FeeCoinType>(std::option::extract<sui::balance::Balance<FeeCoinType>>(&mut reward_balance), ctx),
                lock_owner
            );
        };
        std::option::destroy_none<sui::balance::Balance<FeeCoinType>>(reward_balance);
    }

    public fun notify_reward_amount<FeeCoinType>(
        reward: &mut FeeVotingReward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        coin: sui::coin::Coin<FeeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(
            reward_authorized_cap,
            distribution::reward::authorized(&reward.reward)
        );
        assert!(distribution::reward::rewards_contains(&reward.reward, std::type_name::get<FeeCoinType>()), ENotifyRewardAmountTokenNotWhitelisted);
        distribution::reward::notify_reward_amount_internal<FeeCoinType>(
            &mut reward.reward,
            sui::coin::into_balance<FeeCoinType>(coin),
            clock,
            ctx
        );
    }

    public fun voter_get_reward<SailCoinType, FeeCoinType>(
        reward: &mut FeeVotingReward,
        voter_cap: &distribution::voter_cap::VoterCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<FeeCoinType> {
        assert!(
            distribution::voter_cap::get_voter_id(voter_cap) == distribution::reward::voter(&reward.reward),
            EVoterGetRewardInvalidVoter
        );
        let mut reward_balance_option = distribution::reward::get_reward_internal<FeeCoinType>(
            &mut reward.reward,
            distribution::voting_escrow::owner_of<SailCoinType>(voting_escrow, lock_id),
            lock_id,
            clock,
            ctx
        );
        let reward_balance = if (std::option::is_some<sui::balance::Balance<FeeCoinType>>(&reward_balance_option)) {
            std::option::extract<sui::balance::Balance<FeeCoinType>>(&mut reward_balance_option)
        } else {
            sui::balance::zero<FeeCoinType>()
        };
        std::option::destroy_none<sui::balance::Balance<FeeCoinType>>(reward_balance_option);
        reward_balance
    }
}


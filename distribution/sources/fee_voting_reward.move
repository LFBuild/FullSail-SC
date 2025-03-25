module distribution::fee_voting_reward {
    const ENotifyRewardAmountTokenNotWhitelisted: u64 = 9223372427696799743;
    const EVoterGetRewardInvalidVoter: u64 = 9223372358977323007;

    public struct FeeVotingReward has store, key {
        id: UID,
        gauge: ID,
        reward: distribution::reward::Reward,
    }

    public fun balance<FeeCoinType>(reward: &FeeVotingReward): u64 {
        reward.reward.balance<FeeCoinType>()
    }

    public(package) fun create(
        voter: ID,
        ve: ID,
        authorized: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): FeeVotingReward {
        FeeVotingReward {
            id: object::new(ctx),
            gauge: authorized,
            reward: distribution::reward::create(voter, ve, voter, reward_coin_types, ctx),
        }
    }

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

    public fun earned<FeeCoinType>(reward: &FeeVotingReward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        reward.reward.earned<FeeCoinType>(lock_id, clock)
    }

    public fun get_prior_balance_index(reward: &FeeVotingReward, lock_id: ID, time: u64): u64 {
        reward.reward.get_prior_balance_index(lock_id, time)
    }

    public fun get_prior_supply_index(reward: &FeeVotingReward, time: u64): u64 {
        reward.reward.get_prior_supply_index(time)
    }

    public fun rewards_list_length(reward: &FeeVotingReward): u64 {
        reward.reward.rewards_list_length()
    }

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

    public fun borrow_reward(reward: &FeeVotingReward): &distribution::reward::Reward {
        &reward.reward
    }

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
}


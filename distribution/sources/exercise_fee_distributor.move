module distribution::exercise_fee_distributor;

use sui::clock::Clock;
use sui::coin::{Coin};
use distribution::reward_distributor::{Self, RewardDistributor};
use distribution::reward_distributor_cap::RewardDistributorCap;
use distribution::voting_escrow;


public struct ExerciseFeeDistributor<phantom RewardCoinType> has key, store {
    id: UID,
    reward_distributor: RewardDistributor<RewardCoinType>,
    // bag to be prepared for future updates
    bag: sui::bag::Bag,
}

public(package) fun create<RewardCoinType>(
    clock: &Clock,
    ctx: &mut TxContext
): (ExerciseFeeDistributor<RewardCoinType>, RewardDistributorCap) {
    let (reward_distributor, cap) = reward_distributor::create<RewardCoinType>(clock, ctx);

    (
        ExerciseFeeDistributor {
            id: object::new(ctx),
            reward_distributor,
            bag: sui::bag::new(ctx),
        },
        cap
    )
}

public fun claim<SailCoinType, RewardCoinType>(
    self: &mut ExerciseFeeDistributor<RewardCoinType>,
    voting_escrow: &voting_escrow::VotingEscrow<SailCoinType>,
    lock: &voting_escrow::Lock,
    ctx: &mut TxContext
): Coin<RewardCoinType> {
    reward_distributor::claim(
        &mut self.reward_distributor,
        voting_escrow,
        lock,
        ctx
    )
}

public fun balance<RewardCoinType>(self: &ExerciseFeeDistributor<RewardCoinType>): u64 {
    reward_distributor::balance(&self.reward_distributor)
}

public fun checkpoint_token<RewardCoinType>(
    self: &mut ExerciseFeeDistributor<RewardCoinType>,
    reward_distributor_cap: &RewardDistributorCap,
    coin: Coin<RewardCoinType>,
    clock: &Clock
) {
    reward_distributor::checkpoint_token(
        &mut self.reward_distributor,
        reward_distributor_cap,
        coin,
        clock,
    );
}

public fun claimable<SailCoinType, RewardCoinType>(
    self: &ExerciseFeeDistributor<RewardCoinType>,
    voting_escrow: &voting_escrow::VotingEscrow<SailCoinType>,
    lock_id: ID
): u64 {
    reward_distributor::claimable(&self.reward_distributor, voting_escrow, lock_id)
}

public fun last_token_time<RewardCoinType>(self: &ExerciseFeeDistributor<RewardCoinType>): u64 {
    reward_distributor::last_token_time(&self.reward_distributor)
}

public fun start<RewardCoinType>(
    self: &mut ExerciseFeeDistributor<RewardCoinType>,
    reward_distributor_cap: &RewardDistributorCap,
    clock: &Clock
) {
    reward_distributor::start(&mut self.reward_distributor, reward_distributor_cap, clock);
}

public fun tokens_per_period<RewardCoinType>(
    self: &ExerciseFeeDistributor<RewardCoinType>,
    period_start_time: u64
): u64 {
    reward_distributor::tokens_per_period(&self.reward_distributor, period_start_time)
}

#[test_only]
public fun test_borrow_reward_distributor<RewardCoinType>(
    self: &ExerciseFeeDistributor<RewardCoinType>,
): &RewardDistributor<RewardCoinType> {
    &self.reward_distributor
}

/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module governance::passive_fee_distributor;

use sui::clock::Clock;
use sui::coin::Coin;
use voting_escrow::reward_distributor::{Self, RewardDistributor};
use voting_escrow::voting_escrow;
use voting_escrow::reward_distributor_cap::RewardDistributorCap;
use sui::coin;
use governance::distribution_config::{DistributionConfig};

const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

const ELockedVotingEscrowCannotClaim: u64 = 54894326219497416;

public struct PassiveFeeDistributor<phantom FeeCoinType> has key, store {
    id: UID,
    reward_distributor: RewardDistributor<FeeCoinType>,
    reward_distributor_cap: RewardDistributorCap,
    // bag to be prepared for future updates
    bag: sui::bag::Bag,
}

public fun notices(): (vector<u8>, vector<u8>) {
    (COPYRIGHT_NOTICE, PATENT_NOTICE)
}

public(package) fun create<FeeCoinType>(
    clock: &Clock,
    ctx: &mut TxContext
): PassiveFeeDistributor<FeeCoinType> {
    let id = object::new(ctx);
    let inner_id = id.uid_to_inner();
    let (reward_distributor, reward_distributor_cap) =
        reward_distributor::create<FeeCoinType>(inner_id, clock, ctx);

    PassiveFeeDistributor {
        id,
        reward_distributor,
        reward_distributor_cap,
        bag: sui::bag::new(ctx),
    }
}

public fun claim<SailCoinType, FeeCoinType>(
    self: &mut PassiveFeeDistributor<FeeCoinType>,
    voting_escrow: &mut voting_escrow::VotingEscrow<SailCoinType>,
    distribution_config: &DistributionConfig,
    lock: &mut voting_escrow::Lock,
    ctx: &mut TxContext
): Coin<FeeCoinType> {
    distribution_config.checked_package_version();
    let lock_id = object::id(lock);
    assert!(
        voting_escrow.escrow_type(lock_id).is_locked() == false,
        ELockedVotingEscrowCannotClaim
    );

    let reward_coin = reward_distributor::claim(
        &mut self.reward_distributor,
        &self.reward_distributor_cap,
        voting_escrow,
        lock_id,
        ctx,
    );

    reward_coin
}

public fun balance<FeeCoinType>(self: &PassiveFeeDistributor<FeeCoinType>): u64 {
    reward_distributor::balance(&self.reward_distributor)
}

public(package) fun checkpoint_token<FeeCoinType>(
    self: &mut PassiveFeeDistributor<FeeCoinType>,
    coin: Coin<FeeCoinType>,
    clock: &Clock
) {
    reward_distributor::checkpoint_token(&mut self.reward_distributor, &self.reward_distributor_cap, coin, clock);
}

public fun claimable<SailCoinType, FeeCoinType>(
    self: &PassiveFeeDistributor<FeeCoinType>,
    voting_escrow: &voting_escrow::VotingEscrow<SailCoinType>,
    lock_id: ID
): u64 {
    reward_distributor::claimable(&self.reward_distributor, voting_escrow, lock_id)
}

public fun last_token_time<FeeCoinType>(self: &PassiveFeeDistributor<FeeCoinType>): u64 {
    reward_distributor::last_token_time(&self.reward_distributor)
}

public(package) fun start<FeeCoinType>(
    self: &mut PassiveFeeDistributor<FeeCoinType>,
    clock: &Clock
) {
    reward_distributor::start(&mut self.reward_distributor, &self.reward_distributor_cap, clock);
}

public fun tokens_per_period<FeeCoinType>(
    self: &PassiveFeeDistributor<FeeCoinType>,
    period_start_time: u64
): u64 {
    reward_distributor::tokens_per_period(&self.reward_distributor, period_start_time)
}

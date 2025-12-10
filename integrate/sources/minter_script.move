module integrate::minter_script;
use governance::minter::{Self, Minter};
use voting_escrow::voting_escrow::{Self, Lock, VotingEscrow};
use sui::coin::{Self, Coin};
use governance::distribution_config::{Self, DistributionConfig};

public fun deposit_o_sail_into_lock<SailCoinType, OSailCoinType>(
    minter: &mut Minter<SailCoinType>,
    voting_escrow: &mut VotingEscrow<SailCoinType>,
    distribution_config: &DistributionConfig,
    lock: &mut Lock,
    o_sail: Coin<OSailCoinType>,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext,
) {
    if (o_sail.value() > 0) {
        minter.deposit_o_sail_into_lock(voting_escrow, distribution_config, lock, o_sail, clock, ctx);
    } else {
        o_sail.destroy_zero();
    }
}

public fun create_lock_from_o_sail<SailCoinType, OSailCoinType>(
    minter: &mut Minter<SailCoinType>,
    voting_escrow: &mut VotingEscrow<SailCoinType>,
    distribution_config: &DistributionConfig,
    o_sail: Coin<OSailCoinType>,
    lock_duration_days: u64,
    permanent: bool,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    if (o_sail.value() > 0) {
        minter.create_lock_from_o_sail(voting_escrow, distribution_config, o_sail, lock_duration_days, permanent, clock, ctx);
    } else {
        o_sail.destroy_zero();
    }
}
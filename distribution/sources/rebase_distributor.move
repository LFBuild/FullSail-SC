/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module distribution::rebase_distributor;

use sui::clock::Clock;
use sui::coin::Coin;
use distribution::common;
use distribution::reward_distributor::{Self, RewardDistributor};
use distribution::voting_escrow;
use distribution::reward_distributor_cap::RewardDistributorCap;
use sui::coin;

#[allow(unused_const)]
const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

const EMinterNotActive: u64 = 326677348800338700;
const ELockedVotingEscrowCannotClaim: u64 = 27562280597090540;
const ECreateRebaseDistributorInvalidPublisher: u64 = 208084867296439940;

public struct REBASE_DISTRIBUTOR has drop {
}

public struct EventStart has copy, drop, store {
    minter_active_period: u64,
}

public struct EventUpdateActivePeriod has copy, drop, store {
    minter_active_period: u64,
}

public struct RebaseDistributor<phantom SailCoinType> has key, store {
    id: UID,
    reward_distributor: RewardDistributor<SailCoinType>,
    minter_active_period: u64,
    // bag to be prepared for future updates
    bag: sui::bag::Bag,
}

fun init(otw: REBASE_DISTRIBUTOR, ctx: &mut TxContext) {
    sui::package::claim_and_keep<REBASE_DISTRIBUTOR>(otw, ctx);
}

#[test_only]
public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
    sui::package::claim<REBASE_DISTRIBUTOR>(REBASE_DISTRIBUTOR {}, ctx)
}

public fun create<SailCoinType>(
    publisher: &sui::package::Publisher,
    clock: &Clock,
    ctx: &mut TxContext
): (RebaseDistributor<SailCoinType>, RewardDistributorCap) {
    assert!(publisher.from_module<REBASE_DISTRIBUTOR>(), ECreateRebaseDistributorInvalidPublisher);

    let id = object::new(ctx);
    let inner_id = id.uid_to_inner();
    let (reward_distributor, cap) = reward_distributor::create<SailCoinType>(inner_id, clock, ctx);

    (
        RebaseDistributor {
            id,
            reward_distributor,
            minter_active_period: 0,
            bag: sui::bag::new(ctx),
        },
        cap,
    )
}

public fun claim<SailCoinType>(
    self: &mut RebaseDistributor<SailCoinType>,
    voting_escrow: &mut voting_escrow::VotingEscrow<SailCoinType>,
    lock: &mut voting_escrow::Lock,
    clock: &Clock,
    ctx: &mut TxContext
): u64 {
    let lock_id = object::id<voting_escrow::Lock>(lock);
    assert!(
        self.minter_active_period() >= common::current_period(clock),
        EMinterNotActive
    );
    assert!(
        voting_escrow.escrow_type(lock_id).is_locked() == false,
        ELockedVotingEscrowCannotClaim
    );

    let reward_coin = reward_distributor::claim(
        &mut self.reward_distributor,
        voting_escrow,
        lock,
        ctx,
    );

    let reward = coin::value(&reward_coin);

    if (reward > 0) {
        let (locked_balance, _) = voting_escrow.locked(lock_id);
        if (
            common::current_timestamp(clock) >= locked_balance.end()
            && !locked_balance.is_permanent()
        ) {
            transfer::public_transfer(
                reward_coin,
                voting_escrow.owner_of(lock_id),
            );
        } else {
            voting_escrow.deposit_for(
                lock,
                reward_coin,
                clock,
                ctx,
            );
        };
    } else {
        coin::destroy_zero(reward_coin);
    };

    reward
}

public fun balance<SailCoinType>(self: &RebaseDistributor<SailCoinType>): u64 {
    reward_distributor::balance(&self.reward_distributor)
}

public fun checkpoint_token<SailCoinType>(
    self: &mut RebaseDistributor<SailCoinType>,
    reward_distributor_cap: &RewardDistributorCap,
    coin: Coin<SailCoinType>,
    clock: &Clock
) {
    reward_distributor::checkpoint_token(
        &mut self.reward_distributor,
        reward_distributor_cap,
        coin,
        clock,
    );
}

public fun claimable<SailCoinType>(
    self: &RebaseDistributor<SailCoinType>,
    voting_escrow: &voting_escrow::VotingEscrow<SailCoinType>,
    lock_id: ID
): u64 {
    reward_distributor::claimable(&self.reward_distributor, voting_escrow, lock_id)
}

public fun last_token_time<SailCoinType>(self: &RebaseDistributor<SailCoinType>): u64 {
    reward_distributor::last_token_time(&self.reward_distributor)
}

public fun minter_active_period<SailCoinType>(self: &RebaseDistributor<SailCoinType>): u64 {
    self.minter_active_period
}

public fun start<SailCoinType>(
    self: &mut RebaseDistributor<SailCoinType>,
    reward_distributor_cap: &RewardDistributorCap,
    minter_active_period: u64,
    clock: &Clock
) {
    reward_distributor::start(&mut self.reward_distributor, reward_distributor_cap, clock);
    self.minter_active_period = minter_active_period;
    let event = EventStart { minter_active_period };
    sui::event::emit(event);
}

public fun tokens_per_period<SailCoinType>(
    self: &RebaseDistributor<SailCoinType>,
    period_start_time: u64
): u64 {
    reward_distributor::tokens_per_period(&self.reward_distributor, period_start_time)
}

public(package) fun update_active_period<SailCoinType>(
    self: &mut RebaseDistributor<SailCoinType>,
    reward_distributor_cap: &RewardDistributorCap,
    new_active_period: u64
) {
    reward_distributor_cap.validate(object::id(&self.reward_distributor));
    self.minter_active_period = new_active_period;
    let event = EventUpdateActivePeriod { minter_active_period: new_active_period };
    sui::event::emit(event);
}
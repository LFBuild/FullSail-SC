/// Meant to provide a functionality to exchange preSAIL for auto max-locked veSAIL.
module airdrop::exchange_airdrop;

use ve::voting_escrow::{VotingEscrow};
use sui::balance::{Self, Balance};
use sui::coin::{Coin};
use sui::clock::{Clock};

const EWrongWithdrawCap: u64 = 377557558106448800;
const ENotEnoughCollected: u64 = 771533567291238000;
const EGetAirdropNotStarted: u64 = 830914020413490200;
const ENotEnoughReserves: u64 = 653209817586432800;

/// Main object for the exchange airdrop.
/// Allows exchanging `CoinIn` for max-locked `SailCoinType` veNFTs.
public struct ExchangeAirdrop<phantom CoinIn, phantom SailCoinType> has key, store {
    id: UID,
    /// Collected `CoinIn` from users.
    collected: Balance<CoinIn>,
    /// `SailCoinType` reserves to be distributed.
    reserves: Balance<SailCoinType>,
    /// Amount of `SailCoinType` distributed.
    distributed: u64,
    /// The start timestamp of the airdrop in milliseconds.
    start: u64,
}

/// Capability to withdraw collected `CoinIn` from the airdrop.
public struct WithdrawCap has key, store {
    id: UID,
    /// ID of the `ExchangeAirdrop` object.
    airdrop_id: ID,
}

/// Event emitted when a new `ExchangeAirdrop` is created.
public struct EventCreateExchangeAirdrop has copy, drop, store {
    airdrop_id: ID,
    reserves: u64,
    start: u64,
}

/// Event emitted when a user claims their airdrop.
public struct EventAirdropClaimed has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
    user: address,
}

/// Event emitted when collected coins are withdrawn.
public struct EventWithdrawCollected has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

public struct EventWithdrawUnclaimed has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

/// Event emitted when reserves are deposited into the airdrop.
public struct EventDepositToDistribute has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

/*
 * @notice Creates a new exchange airdrop.
 *
 * @param initial_reserves The initial amount of `SailCoinType` to be distributed.
 * @param start The start timestamp of the airdrop in milliseconds.
 * @return (ExchangeAirdrop<CoinIn, SailCoinType>, WithdrawCap) The newly created airdrop object and the withdrawal capability.
 */
public fun new<CoinIn, SailCoinType>(
    initial_reserves: Coin<SailCoinType>,
    start: u64,
    ctx: &mut TxContext,
): (ExchangeAirdrop<CoinIn, SailCoinType>, WithdrawCap) {
    let id = object::new(ctx);
    let inner_id = id.to_inner();
    let reserves_amount = initial_reserves.value();
    let exchange_airdrop = ExchangeAirdrop<CoinIn, SailCoinType> {
        id,
        collected: balance::zero<CoinIn>(),
        reserves: initial_reserves.into_balance(),
        distributed: 0,
        start,
    };
    let withdraw_cap = WithdrawCap {
        id: object::new(ctx),
        airdrop_id: inner_id,
    };

    let event = EventCreateExchangeAirdrop {
        airdrop_id: inner_id,
        reserves: reserves_amount,
        start,
    };
    sui::event::emit(event);

    (exchange_airdrop, withdraw_cap)
}

/*
 * @notice Withdraws collected `CoinIn` from the airdrop.
 *
 * @param self The `ExchangeAirdrop` object.
 * @param cap The `WithdrawCap` for this airdrop.
 * @param amount The amount of `CoinIn` to withdraw.
 * @return Coin<CoinIn> The withdrawn coin.
 *
 * aborts-if:
 * - The `cap` is for a different airdrop.
 * - The `amount` to withdraw is greater than the collected amount.
 */
public fun withdraw_collected<CoinIn, SailCoinType>(
    self: &mut ExchangeAirdrop<CoinIn, SailCoinType>,
    cap: &WithdrawCap,
    amount: u64,
    ctx: &mut TxContext
): Coin<CoinIn> {
    assert!(cap.airdrop_id == object::id(self), EWrongWithdrawCap);
    assert!(self.collected.value() >= amount, ENotEnoughCollected);

    let collected_balance = self.collected.split(amount);
    let event = EventWithdrawCollected {
        airdrop_id: object::id(self),
        amount,
    };
    sui::event::emit(event);
    collected_balance.into_coin(ctx)
}

/*
 * @notice Withdraws unclaimed `SailCoinType` from the airdrop.
 *
 * @param self The `ExchangeAirdrop` object.
 * @param cap The `WithdrawCap` for this airdrop.
 * @param amount The amount of `SailCoinType` to withdraw.
 * @return Coin<SailCoinType> The withdrawn coin.
 *
 * aborts-if:
 * - The `cap` is for a different airdrop.
 * - The `amount` to withdraw is greater than the collected amount.
 */
public fun withdraw_unclaimed<CoinIn, SailCoinType>(
    self: &mut ExchangeAirdrop<CoinIn, SailCoinType>,
    cap: &WithdrawCap,
    amount: u64,
    ctx: &mut TxContext
): Coin<SailCoinType> {
    assert!(cap.airdrop_id == object::id(self), EWrongWithdrawCap);
    assert!(self.reserves.value() >= amount, ENotEnoughReserves);
    let to_withdraw = self.reserves.split(amount);
    let event = EventWithdrawUnclaimed {
        airdrop_id: object::id(self),
        amount,
    };
    sui::event::emit(event);
    to_withdraw.into_coin(ctx)
}

/*
 * @notice Deposits more `SailCoinType` to the reserves.
 *
 * @param self The `ExchangeAirdrop` object.
 * @param reserves The `SailCoinType` coin to deposit.
 */
public fun deposit_reserves<CoinIn, SailCoinType>(
    self: &mut ExchangeAirdrop<CoinIn, SailCoinType>,
    reserves: Coin<SailCoinType>,
) {
    let event = EventDepositToDistribute {
        airdrop_id: object::id(self),
        amount: reserves.value(),
    };
    sui::event::emit(event);
    self.reserves.join(reserves.into_balance());
}

/// @notice Returns the amount of `CoinIn` collected.
public fun collected<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.collected.value()
}

/// @notice Returns the amount of `SailCoinType` in reserves.
public fun reserves<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.reserves.value()
}

/// @notice Returns the amount of `SailCoinType` distributed.
public fun distributed<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.distributed
}

/*
 * @notice Claims airdropped SAIL and locks it into auto max-locked veSAIL.
 *
 * @param self The `ExchangeAirdrop` object.
 * @param voting_escrow The `VotingEscrow` object to create locks.
 * @param coin_in The `CoinIn` to exchange for `SailCoinType`. The amount exchanged is 1:1.
 * @param clock The `sui::clock::Clock` shared object.
 *
 * aborts-if:
 * - The airdrop has not started yet.
 * - There are not enough reserves to cover the exchange.
 */
public fun get_airdrop<CoinIn, SailCoinType>(
    self: &mut ExchangeAirdrop<CoinIn, SailCoinType>,
    voting_escrow: &mut VotingEscrow<SailCoinType>,
    coin_in: Coin<CoinIn>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(self.start <= clock.timestamp_ms(), EGetAirdropNotStarted);
    assert!(self.reserves.value() >= coin_in.value(), ENotEnoughReserves);
    let amount = coin_in.value();
    self.collected.join(coin_in.into_balance());
    let sail = self.reserves.split(amount);
    self.distributed = self.distributed + amount;
    let event = EventAirdropClaimed {
        airdrop_id: object::id(self),
        amount,
        user: ctx.sender(),
    };
    sui::event::emit(event);
    voting_escrow.create_lock(sail.into_coin(ctx), 52 * 7 * 4, true, clock, ctx);
}
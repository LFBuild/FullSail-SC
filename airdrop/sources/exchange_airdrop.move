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

public struct ExchangeAirdrop<phantom CoinIn, phantom SailCoinType> has key, store {
    id: UID,
    collected: Balance<CoinIn>,
    reserves: Balance<SailCoinType>,
    distributed: u64,
    start: u64,
}

public struct WithdrawCap has key, store {
    id: UID,
    airdrop_id: ID,
}

public struct EventCreateExchangeAirdrop has copy, drop, store {
    airdrop_id: ID,
    reserves: u64,
    start: u64,
}

public struct EventAirdropClaimed has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
    user: address,
}

public struct EventWithdrawCollected has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

public struct EventDepositToDistribute has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

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

public fun withdraw_collected<CoinIn, SailCoinType>(
    cap: &WithdrawCap,
    self: &mut ExchangeAirdrop<CoinIn, SailCoinType>,
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

public fun collected<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.collected.value()
}

public fun reserves<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.reserves.value()
}

public fun distributed<CoinIn, SailCoinType>(self: &ExchangeAirdrop<CoinIn, SailCoinType>): u64 {
    self.distributed
}

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
    voting_escrow.create_lock(sail.into_coin(ctx), 365 * 4, true, clock, ctx);
}
/// Module: airdrop
module airdrop::ve_airdrop;

use suitears::airdrop::{Self, Airdrop};
use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use ve::voting_escrow::{Self, Lock, VotingEscrow};

public struct EventVeAirdropCreated has copy, drop, store {
    amount: u64,
    root: vector<u8>,
    start: u64,
}

public struct VeAirdrop<phantom SailCoinType> has key, store {
    id: UID,
    airdrop: Airdrop<SailCoinType>,
}

/*
 * @notice Creates an airdrop.
 *
 * @param airdrop_coin The coin that will be distributed in the airdrop.
 * @param root The Merkle tree root that keeps track of all the airdrops.
 * @param start The start timestamp of the airdrop in milliseconds.
 * @param c The `sui::clock::Clock` shared object.
 * @return Airdrop<SailCoinType>
 *
 * aborts-if:
 * - The `root` is empty.
 * - The `start` is in the past.
 */
public fun new<SailCoinType>(
    airdrop_coin: Coin<SailCoinType>,
    root: vector<u8>,
    start: u64,
    c: &Clock,
    ctx: &mut TxContext,
): VeAirdrop<SailCoinType> {
    let event = EventVeAirdropCreated {
        amount: airdrop_coin.value(),
        root,
        start,
    };
    sui::event::emit(event);
    VeAirdrop {
        id: object::new(ctx),
        airdrop: airdrop::new(airdrop_coin, root, start, c, ctx),
    }
}

public fun balance<SailCoinType>(self: &VeAirdrop<SailCoinType>): u64 {
    self.airdrop.balance()
}

/*
 * @notice Returns the root of the Merkle tree for the airdrop `self`.
 *
 * @param self The shared {Airdrop<SailCoinType>} object.
 * @return vector<u8>.
 */
public fun root<SailCoinType>(self: &VeAirdrop<SailCoinType>): vector<u8> {
    self.airdrop.root()
}

/*
 * @notice Returns the start timestamp of the airdrop. Users can claim after this date.
 *
 * @param self The shared {Airdrop<SailCoinType>} object.
 * @return u64.
 */
public fun start<SailCoinType>(self: &VeAirdrop<SailCoinType>): u64 {
    self.airdrop.start()
}

/*
 * @notice Returns a {Bitmap} that keeps track of the claimed airdrops.
 *
 * @param self The shared {Airdrop<SailCoinType>} object.
 * @return &Bitmap.
 */
public fun borrow_map<SailCoinType>(self: &VeAirdrop<SailCoinType>): &suitears::bitmap::Bitmap {
    self.airdrop.borrow_map()
}

/*
 * @notice Checks if a user has already claimed his airdrop.
 *
 * @param self The shared {Airdrop<SailCoinType>} object.
 * @param proof The proof that the sender can redeem the `amount` from the airdrop.
 * @param amount Number of coins the sender can redeem.
 * @param address A user address.
 * @return bool. True if he has claimed the airdrop already.
 *
 * aborts-if:
 * - If the `proof` is not valid.
 */
public fun has_account_claimed<SailCoinType>(
    self: &VeAirdrop<SailCoinType>,
    proof: vector<vector<u8>>,
    amount: u64,
    user: address,
): bool {
    self.airdrop.has_account_claimed(proof, amount, user)
}

// === Public Mutative Functions ===

/*
 * @notice Claims airdropped SAIL and locks it into auto max-locked veSAIL.
 *
 * @param self The shared {VeAirdrop<SailCoinType>} object.
 * @param voting_escrow The shared {ve::voting_escrow::VotingEscrow<SailCoinType>} object to create locks.
 * @param proof The proof that the sender can redeem the `amount` from the airdrop.
 * @param amount Number of coins the sender can redeem.
 * @param clock The `sui::clock::Clock` shared object.
 *
 * aborts-if:
 * - The `proof` is not valid.
 * - The airdrop has not started yet.
 * - The user already claimed it
 */
public fun get_airdrop<SailCoinType>(
    self: &mut VeAirdrop<SailCoinType>,
    voting_escrow: &mut VotingEscrow<SailCoinType>,
    proof: vector<vector<u8>>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sail = self.airdrop.get_airdrop(proof, clock, amount, ctx);

    voting_escrow.create_lock(sail, 365 * 4, true, clock, ctx)
}


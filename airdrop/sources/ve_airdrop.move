/// Meant to wrap classic merkle airdrop to wrap SAIL into auto max-locked veSAIL.
/// Also introduces some events to track the airdrop.
module airdrop::ve_airdrop;

use airdrop::airdrop::{Self, Airdrop};
use sui::coin::{Coin};
use sui::clock::{Clock};
use ve::voting_escrow::{VotingEscrow};

// === Errors ===

const EWrongWithdrawCap: u64 = 486723797964389060;

// === Events ===

public struct EventVeAirdropCreated has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
    root: vector<u8>,
    start: u64,
}

public struct EventVeAirdropClaimed has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
    user: address,
}

public struct EventVeAirdropWithdrawn has copy, drop, store {
    airdrop_id: ID,
    amount: u64,
}

public struct VeAirdrop<phantom SailCoinType> has key, store {
    id: UID,
    airdrop: Airdrop<SailCoinType>,
}

public struct WithdrawCap has key, store {
    id: UID,
    airdrop_id: ID,
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
): (VeAirdrop<SailCoinType>, WithdrawCap) {
    let id = object::new(ctx);
    let inner_id = id.to_inner();
    let event = EventVeAirdropCreated {
        airdrop_id: inner_id,
        amount: airdrop_coin.value(),
        root,
        start,
    };
    sui::event::emit(event);
    let ve_airdrop = VeAirdrop {
        id,
        airdrop: airdrop::new(airdrop_coin, root, start, c, ctx),
    };
    let withdraw_cap = WithdrawCap {
        id: object::new(ctx),
        airdrop_id: inner_id,
    };
    (ve_airdrop, withdraw_cap)
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

    let event = EventVeAirdropClaimed {
        airdrop_id: object::id(self),
        amount,
        user: ctx.sender(),
    };
    sui::event::emit(event);
    // Creates an auto max-locked veSAIL.
    voting_escrow.create_lock(sail, 52 * 7 * 4, true, clock, ctx)
}

public fun withdraw_and_destroy<SailCoinType>(
    self: VeAirdrop<SailCoinType>,
    cap: &WithdrawCap,
    ctx: &mut TxContext,
): Coin<SailCoinType> {
    let inner_id = object::id(&self);
    assert!(cap.airdrop_id == object::id(&self), EWrongWithdrawCap);
    let VeAirdrop { id, airdrop } = self;
    id.delete();
    let remaining = airdrop.destroy(ctx);
    let event = EventVeAirdropWithdrawn {
        airdrop_id: inner_id,
        amount: remaining.value(),
    };
    sui::event::emit(event);
    
    remaining
}


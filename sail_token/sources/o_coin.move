module sail_token::o_coin;
// Option Coin implementation.
// Behaves like a Coin with expiry date.

use std::ascii;
use std::string;
use sui::balance::{Self, Balance, Supply};
use sui::url::{Self, Url};

/// Trying to join two option coins with different expiry dates
const EExpirationDateNotMatch: u64 = 9327664466072205000;

/// Passed 0 as `n`
const ECannotDivideIntoZeroCoins: u64 = 5174626250516141000;

/// Not enough balance to perform an operation
const ENotEnoughBalance: u64 = 8197057641849652000;

/// A type passed to create_supply is not a one-time witness.
const EBadWitness: u64 = 2560837944997814000;

/// A option coin of type `T` worth `value` and with additional info about expiration date.
/// Transferable and storable
public struct OCoin<phantom T> has key, store {
    /// regular coin fields
    id: UID,
    /// Balance. When option token is exercised exact same amount of liquid tokens should be granted.
    balance: Balance<T>,
    /// expiration date of the option token
    expiry_date_ms: u64,
}

/// Each Coin type T created through `create_currency` function will have a
/// unique instance of CoinMetadata<T> that stores the metadata for this coin type.
public struct OCoinMetadata<phantom T> has key, store {
    id: UID,
    /// Number of decimal places the coin uses.
    /// A coin with `value ` N and `decimals` D should be shown as N / 10^D
    /// E.g., a coin with `value` 7002 and decimals 3 should be displayed as 7.002
    /// This is metadata for display usage only.
    decimals: u8,
    /// Name for the token
    name: string::String,
    /// Symbol for the token
    symbol: ascii::String,
    /// Description of the token
    description: string::String,
    /// URL for the token logo
    icon_url: Option<Url>,
}


/// Capability allowing the bearer to mint and burn
/// coins of type `T`. Transferable
public struct OTreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: Supply<T>
}

/// Return the total number of `T`'s in circulation.
/// Does not consider expiration date.
public fun total_supply<T>(cap: &OTreasuryCap<T>): u64 {
    balance::supply_value(&cap.total_supply)
}

/// Public getter for the option coin's value
public fun value<T>(self: &OCoin<T>): u64 {
    self.balance.value()
}

/// Public getter for option coin's expiry date
public fun expiry_date_ms<T>(self: &OCoin<T>): u64 {
    self.expiry_date_ms
}

/// Get immutable reference to the balance of a coin.
/// There is no mutable access to the balance itself
/// to prevent joining of balances that have different expiry dates.
public fun balance<T>(coin: &OCoin<T>): &Balance<T> {
    &coin.balance
}

/// Take a `OCoin` worth of `value` from `Balance`.
/// Aborts if `value > balance.value`
public fun take<T>(self: &mut OCoin<T>, value: u64, ctx: &mut TxContext): OCoin<T> {
    OCoin {
        id: object::new(ctx),
        balance: self.balance.split(value),
        expiry_date_ms: self.expiry_date_ms,
    }
}

/// Consume the option coin `c` and add its value to `self`.
/// Aborts if `c.value + self.value > U64_MAX`.
/// Abouts if coin `c` and coin `self` have different expiry dates.
public entry fun join<T>(self: &mut OCoin<T>, c: OCoin<T>) {
    assert!(self.expiry_date_ms == c.expiry_date_ms, EExpirationDateNotMatch);

    let OCoin { id, balance, expiry_date_ms: _ } = c;
    id.delete();
    self.balance.join(balance);
}

/// Split option coin `self` to two coins, one with balance `split_amount`,
/// and the remaining balance is left is `self`. Both of new
/// coins have the same expiry date.
public fun split<T>(self: &mut OCoin<T>, split_amount: u64, ctx: &mut TxContext): OCoin<T> {
    self.take(split_amount, ctx)
}


/// Split option coin `self` into `n - 1` coins with equal balances. The remainder is left in
/// `self`. Return newly created option coins with the same expiry_date_ms as original coin.
public fun divide_into_n<T>(self: &mut OCoin<T>, n: u64, ctx: &mut TxContext): vector<OCoin<T>> {
    assert!(n > 0, ECannotDivideIntoZeroCoins);
    assert!(n <= self.value(), ENotEnoughBalance);

    let mut vec = vector[];
    let mut i = 0;
    let split_amount = self.value() / n;
    while (i < n - 1) {
        vec.push_back(self.split(split_amount, ctx));
        i = i + 1;
    };
    vec
}


/// Make any OCoin with any expiration date with a zero value.
/// Useful for placeholding bids/payments or preemptively making empty balances.
public fun zero<T>(expiry_date_ms: u64, ctx: &mut TxContext): OCoin<T> {
    OCoin { id: object::new(ctx), balance: balance::zero(), expiry_date_ms, }
}


/// Destroy a coin with value zero
public fun destroy_zero<T>(c: OCoin<T>) {
    let OCoin { id, balance, expiry_date_ms: _, } = c;
    id.delete();
    balance.destroy_zero()
}


/// Create a new currency type `T` as and return the `TreasuryCap` for
/// `T` to the caller. Can only be called with a `one-time-witness`
/// type, ensuring that there's only one `TreasuryCap` per `T`.
public fun create_currency<T: drop>(
    witness: T,
    decimals: u8,
    symbol: vector<u8>,
    name: vector<u8>,
    description: vector<u8>,
    icon_url: Option<Url>,
    ctx: &mut TxContext,
): (OTreasuryCap<T>, OCoinMetadata<T>) {
    // Make sure there's only one instance of the type T
    assert!(sui::types::is_one_time_witness(&witness), EBadWitness);

    (
        OTreasuryCap {
            id: object::new(ctx),
            total_supply: balance::create_supply(witness)
        },
        OCoinMetadata {
            id: object::new(ctx),
            decimals,
            name: string::utf8(name),
            symbol: ascii::string(symbol),
            description: string::utf8(description),
            icon_url,
        },
    )
}

/// TreasuryCap methods

/// Create a coin worth `value` and increase the total supply
/// in `cap` accordingly.
public fun mint<T>(
    cap: &mut OTreasuryCap<T>,
    value: u64,
    expiry_date_ms: u64,
    ctx: &mut TxContext
): OCoin<T> {
    OCoin {
        id: object::new(ctx),
        balance: cap.total_supply.increase_supply(value),
        expiry_date_ms,
    }
}


/// Destroy the option coin `c` and decrease the total supply in `cap`
/// accordingly.
public entry fun burn<T>(cap: &mut OTreasuryCap<T>, c: OCoin<T>): u64 {
    let OCoin { id, balance, expiry_date_ms: _, } = c;
    id.delete();
    cap.total_supply.decrease_supply(balance)
}


/// Updates the expiry_date
public fun set_expiry_date<T>(_cap: &mut OTreasuryCap<T>, c: &mut OCoin<T>, expiry_date_ms: u64) {
    c.expiry_date_ms = expiry_date_ms;
}

/// Mint `amount` of `Coin` and send it to `recipient`. Invokes `mint()`.
public entry fun mint_and_transfer<T>(
    c: &mut OTreasuryCap<T>,
    amount: u64,
    expiry_date_ms: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(c.mint(amount, expiry_date_ms, ctx), recipient)
}

/// Update name of the coin in `CoinMetadata`
public entry fun update_name<T>(
    _treasury: &OTreasuryCap<T>,
    metadata: &mut OCoinMetadata<T>,
    name: string::String,
) {
    metadata.name = name;
}

/// Update the symbol of the coin in `CoinMetadata`
public entry fun update_symbol<T>(
    _treasury: &OTreasuryCap<T>,
    metadata: &mut OCoinMetadata<T>,
    symbol: ascii::String,
) {
    metadata.symbol = symbol;
}

/// Update the description of the coin in `CoinMetadata`
public entry fun update_description<T>(
    _treasury: &OTreasuryCap<T>,
    metadata: &mut OCoinMetadata<T>,
    description: string::String,
) {
    metadata.description = description;
}

/// Update the url of the coin in `CoinMetadata`
public entry fun update_icon_url<T>(
    _treasury: &OTreasuryCap<T>,
    metadata: &mut OCoinMetadata<T>,
    url: ascii::String,
) {
    metadata.icon_url = option::some(url::new_unsafe(url));
}

// === Get coin metadata fields for on-chain consumption ===

public fun get_decimals<T>(metadata: &OCoinMetadata<T>): u8 {
    metadata.decimals
}

public fun get_name<T>(metadata: &OCoinMetadata<T>): string::String {
    metadata.name
}

public fun get_symbol<T>(metadata: &OCoinMetadata<T>): ascii::String {
    metadata.symbol
}

public fun get_description<T>(metadata: &OCoinMetadata<T>): string::String {
    metadata.description
}

public fun get_icon_url<T>(metadata: &OCoinMetadata<T>): Option<Url> {
    metadata.icon_url
}

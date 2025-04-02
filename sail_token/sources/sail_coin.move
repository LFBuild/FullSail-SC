module sail_token::sail_coin;
public struct SAIL_COIN has drop {}

use sail_token::o_coin;

public struct MinterCap<phantom SailCoinType> has store, key {
    id: UID,
    cap: sui::coin::TreasuryCap<SailCoinType>,
}

public struct OMinterCap<phantom SailCoinType> has store, key {
    id: UID,
    cap: o_coin::OTreasuryCap<SailCoinType>
}

public fun burn<SailCoinType>(
    minter_cap: &mut MinterCap<SailCoinType>,
    coin_to_burn: sui::coin::Coin<SailCoinType>
) {
    minter_cap.cap.burn(coin_to_burn);
}

public fun burn_o<SailCoinType>(
    o_minter_cap: &mut OMinterCap<SailCoinType>,
    coin_to_burn: o_coin::OCoin<SailCoinType>,
) {
    o_minter_cap.cap.burn(coin_to_burn);
}

public fun mint<SailCoinType>(
    minter_cap: &mut MinterCap<SailCoinType>,
    amount: u64,
    ctx: &mut TxContext
): sui::coin::Coin<SailCoinType> {
    minter_cap.cap.mint(amount, ctx)
}

public fun mint_o<SailCoinType>(
    o_minter_cap: &mut OMinterCap<SailCoinType>,
    amount: u64,
    expiry_date_ms: u64,
    ctx: &mut TxContext
): o_coin::OCoin<SailCoinType> {
    o_minter_cap.cap.mint(amount, expiry_date_ms, ctx)
}

public fun total_supply<SailCoinType>(minter_cap: &MinterCap<SailCoinType>): u64 {
    minter_cap.cap.total_supply()
}

fun init_sail(otw: SAIL_COIN, ctx: &mut TxContext) {
    // TODO: add logo url
    // let logoUrl = sui::url::new_unsafe_from_bytes(b"https://link.to.logo");
    let (treasury_cap, metadata) = sui::coin::create_currency<SAIL_COIN>(
        otw,
        6,
        b"SAIL",
        b"FullSail",
        b"FullSail Governance Token with ve(4,4) capabilities",
        option::none<sui::url::Url>(),
        ctx
    );
    let minter_cap = MinterCap<SAIL_COIN> {
        id: object::new(ctx),
        cap: treasury_cap,
    };
    transfer::transfer<MinterCap<SAIL_COIN>>(minter_cap, tx_context::sender(ctx));
    transfer::public_freeze_object<sui::coin::CoinMetadata<SAIL_COIN>>(metadata);
}

fun init_o_sail(otw: SAIL_COIN, ctx: &mut TxContext) {
    let logoUrl = sui::url::new_unsafe_from_bytes(b"https://link.to.logo");
    let (treasury_cap, metadata) = o_coin::create_currency<SAIL_COIN>(
        otw,
        6,
        b"oSAIL",
        b"FullSail Option Token",
        b"FullSail Option Token granting the right to purchase SAIL at a discounted price.",
        option::none<sui::url::Url>(),
        ctx
    );
    let o_minter_cap = OMinterCap<SAIL_COIN> {
        id: object::new(ctx),
        cap: treasury_cap,
    };
    transfer::transfer<OMinterCap<SAIL_COIN>>(o_minter_cap, tx_context::sender(ctx));
    transfer::public_freeze_object<o_coin::OCoinMetadata<SAIL_COIN>>(metadata);
}

fun init(otw: SAIL_COIN, ctx: &mut TxContext) {
    init_sail(otw, ctx)
}


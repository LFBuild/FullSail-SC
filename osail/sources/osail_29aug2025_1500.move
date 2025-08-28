module osail::osail_29aug2025_1500 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_29AUG2025_1500 has drop {}

    fun init(otw: OSAIL_29AUG2025_1500, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail1_test_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_29AUG2025_1500>(
            otw,
            6,
            b"oSAIL-29Aug2025-1500",
            b"oSAIL-29Aug2025-1500",
            b"Full Sail option token, expiration 29 Aug 2025 15:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
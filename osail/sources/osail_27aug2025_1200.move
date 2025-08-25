module osail::osail_27aug2025_1200 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_27AUG2025_1200 has drop {}

    fun init(otw: OSAIL_27AUG2025_1200, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail6_test_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_27AUG2025_1200>(
            otw,
            6,
            b"oSAIL-27Aug2025-1200",
            b"oSAIL-27Aug2025-1200",
            b"Full Sail option token, expiration 27 Aug 2025 12:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
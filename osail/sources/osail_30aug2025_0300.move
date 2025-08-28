module osail::osail_30aug2025_0300 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_30AUG2025_0300 has drop {}

    fun init(otw: OSAIL_30AUG2025_0300, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail5_test_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_30AUG2025_0300>(
            otw,
            6,
            b"oSAIL-30Aug2025-0300",
            b"oSAIL-30Aug2025-0300",
            b"Full Sail option token, expiration 30 Aug 2025 03:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
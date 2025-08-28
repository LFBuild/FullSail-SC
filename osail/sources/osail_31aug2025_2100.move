module osail::osail_31aug2025_2100 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_31AUG2025_2100 has drop {}

    fun init(otw: OSAIL_31AUG2025_2100, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail19_test_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_31AUG2025_2100>(
            otw,
            6,
            b"oSAIL-31Aug2025-2100",
            b"oSAIL-31Aug2025-2100",
            b"Full Sail option token, expiration 31 Aug 2025 21:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
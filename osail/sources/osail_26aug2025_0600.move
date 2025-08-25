module osail::osail_26aug2025_0600 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_26AUG2025_0600 has drop {}

    fun init(otw: OSAIL_26AUG2025_0600, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail1_test_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_26AUG2025_0600>(
            otw,
            6,
            b"oSAIL-26Aug2025-0600",
            b"oSAIL-26Aug2025-0600",
            b"Full Sail option token, expiration 26 Aug 2025 06:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
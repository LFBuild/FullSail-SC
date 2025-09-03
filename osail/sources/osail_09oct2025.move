module osail::osail_09oct2025 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_09OCT2025 has drop {}

    fun init(otw: OSAIL_09OCT2025, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_09OCT2025>(
            otw,
            6,
            b"oSAIL-09Oct2025",
            b"oSAIL-09Oct2025",
            b"Full Sail option token, expiration 09 Oct 2025 00:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
module osail::osail_05sep2025_0900 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_05SEP2025_0900 has drop {}

    fun init(otw: OSAIL_05SEP2025_0900, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_05SEP2025_0900>(
            otw,
            6,
            b"oSAIL-05Sep2025-0900",
            b"oSAIL-05Sep2025-0900",
            b"Full Sail option token, expiration 05 Sep 2025 09:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
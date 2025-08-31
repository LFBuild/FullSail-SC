module osail::osail_02sep2025_0600 {
    use sui::coin;
    use sui::url;
    use std::ascii;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};

    public struct OSAIL_02SEP2025_0600 has drop {}

    fun init(otw: OSAIL_02SEP2025_0600, ctx: &mut TxContext) {
        let url = url::new_unsafe(ascii::string(b"https://app.fullsail.finance/static_files/o_sail_coin.png"));
        let (treasury_cap, metadata) = coin::create_currency<OSAIL_02SEP2025_0600>(
            otw,
            6,
            b"oSAIL-02Sep2025-0600",
            b"oSAIL-02Sep2025-0600",
            b"Full Sail option token, expiration 02 Sep 2025 06:00:00 UTC",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
    }
}
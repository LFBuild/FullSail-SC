module sail_token::sail_token {
    public struct SAIL_TOKEN has drop {}

    fun init(otw: SAIL_TOKEN, ctx: &mut TxContext) {
        let url_bytes = b"https://app.fullsail.finance/static_files/sail_coin.png";
        let url = sui::url::new_unsafe_from_bytes(url_bytes);
        let (treasury_cap, metadata) = sui::coin::create_currency<SAIL_TOKEN>(
            otw,
            6,
            b"SAIL",
            b"SAIL",
            b"Full Sail Governance Token",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<SAIL_TOKEN>>(metadata);
    }
}


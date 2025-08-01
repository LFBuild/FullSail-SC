module pre_sail::pre_sail {
    public struct PRE_SAIL has drop {}

    fun init(otw: PRE_SAIL, ctx: &mut TxContext) {
        let url_bytes = b"https://app.fullsail.finance/static_files/pre_sail_coin.png";
        let url = sui::url::new_unsafe_from_bytes(url_bytes);
        let (treasury_cap, metadata) = sui::coin::create_currency<PRE_SAIL>(
            otw,
            6,
            b"preSAIL",
            b"preSAIL",
            b"Full Sail Governance Token Preview",
            option::some(url),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<PRE_SAIL>>(metadata);
    }
}


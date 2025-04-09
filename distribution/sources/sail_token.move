module distribution::sail_token {
    public struct SAIL_TOKEN has drop {}

    fun init(otw: SAIL_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = sui::coin::create_currency<SAIL_TOKEN>(
            otw,
            6,
            b"SAIL",
            b"FullSail",
            b"FullSail Governance Token with ve(4,4) capabilities",
            option::none<sui::url::Url>(),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<SAIL_TOKEN>>(metadata);
    }
}


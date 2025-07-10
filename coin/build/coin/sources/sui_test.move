module coin::sui_test {
    public struct SUI_TEST has drop {}

    fun init(otw: SUI_TEST, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = sui::coin::create_currency<SUI_TEST>(
            otw,
            6,
            b"SUI-TEST",
            b"Sui Test",
            b"Sui Test Token",
            option::none<sui::url::Url>(),
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<SUI_TEST>>(metadata);
    }
}


module osail::osail16 {
    public struct OSAIL16 has drop {}

    fun init(otw: OSAIL16, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail16_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL16>(
            otw,
            6,
            b"oSAIL-16",
            b"oSAIL-16",
            b"Option Coin Full Sail Epoch 16",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL16>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL16>>(metadata);
    }
} 
module osail::osail8 {
    public struct OSAIL8 has drop {}

    fun init(otw: OSAIL8, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail8_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL8>(
            otw,
            6,
            b"oSAIL-8",
            b"oSAIL-8",
            b"Option Coin Full Sail Epoch 8",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL8>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL8>>(metadata);
    }
} 
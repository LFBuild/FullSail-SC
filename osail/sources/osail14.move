module osail::osail14 {
    public struct OSAIL14 has drop {}

    fun init(otw: OSAIL14, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail14_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL14>(
            otw,
            6,
            b"oSAIL-14",
            b"oSAIL-14",
            b"Option Coin Full Sail Epoch 14",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL14>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL14>>(metadata);
    }
} 
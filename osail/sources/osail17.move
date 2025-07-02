module osail::osail17 {
    public struct OSAIL17 has drop {}

    fun init(otw: OSAIL17, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail17_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL17>(
            otw,
            6,
            b"oSAIL-17",
            b"oSAIL-17",
            b"Option Coin Full Sail Epoch 17",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL17>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL17>>(metadata);
    }
} 
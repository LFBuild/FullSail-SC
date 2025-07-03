module osail::osail13 {
    public struct OSAIL13 has drop {}

    fun init(otw: OSAIL13, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail13_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL13>(
            otw,
            6,
            b"oSAIL-13",
            b"oSAIL-13",
            b"Option Coin Full Sail Epoch 13",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL13>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL13>>(metadata);
    }
} 
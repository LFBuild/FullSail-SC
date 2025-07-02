module osail::osail11 {
    public struct OSAIL11 has drop {}

    fun init(otw: OSAIL11, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail11_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL11>(
            otw,
            6,
            b"oSAIL-11",
            b"oSAIL-11",
            b"Option Coin Full Sail Epoch 11",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL11>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL11>>(metadata);
    }
} 
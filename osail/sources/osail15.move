module osail::osail15 {
    public struct OSAIL15 has drop {}

    fun init(otw: OSAIL15, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail15_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL15>(
            otw,
            6,
            b"oSAIL-15",
            b"oSAIL-15",
            b"Option Coin Full Sail Epoch 15",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL15>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL15>>(metadata);
    }
} 
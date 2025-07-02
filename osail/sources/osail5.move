module osail::osail5 {
    public struct OSAIL5 has drop {}

    fun init(otw: OSAIL5, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail5_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL5>(
            otw,
            6,
            b"oSAIL-5",
            b"oSAIL-5",
            b"Option Coin Full Sail Epoch 5",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL5>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL5>>(metadata);
    }
} 
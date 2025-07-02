module osail::osail19 {
    public struct OSAIL19 has drop {}

    fun init(otw: OSAIL19, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail19_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL19>(
            otw,
            6,
            b"oSAIL-19",
            b"oSAIL-19",
            b"Option Coin Full Sail Epoch 19",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL19>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL19>>(metadata);
    }
} 
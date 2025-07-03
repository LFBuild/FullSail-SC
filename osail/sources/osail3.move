module osail::osail3 {
    public struct OSAIL3 has drop {}

    fun init(otw: OSAIL3, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail3_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL3>(
            otw,
            6,
            b"oSAIL-3",
            b"oSAIL-3",
            b"Option Coin Full Sail Epoch 3",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL3>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL3>>(metadata);
    }
} 
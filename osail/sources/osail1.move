module osail::osail1 {
    public struct OSAIL1 has drop {}

    fun init(otw: OSAIL1, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail1_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL1>(
            otw,
            6,
            b"oSAIL-1",
            b"oSAIL-1",
            b"Option Coin Full Sail Epoch 1",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL1>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL1>>(metadata);
    }
}


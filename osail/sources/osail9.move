module osail::osail9 {
    public struct OSAIL9 has drop {}

    fun init(otw: OSAIL9, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail9_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL9>(
            otw,
            6,
            b"oSAIL-9",
            b"oSAIL-9",
            b"Option Coin Full Sail Epoch 9",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL9>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL9>>(metadata);
    }
} 
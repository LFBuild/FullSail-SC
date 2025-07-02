module osail::osail7 {
    public struct OSAIL7 has drop {}

    fun init(otw: OSAIL7, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail7_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL7>(
            otw,
            6,
            b"oSAIL-7",
            b"oSAIL-7",
            b"Option Coin Full Sail Epoch 7",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL7>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL7>>(metadata);
    }
} 
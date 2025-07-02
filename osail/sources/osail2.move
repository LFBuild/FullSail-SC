module osail::osail2 {
    public struct OSAIL2 has drop {}

    fun init(otw: OSAIL2, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail2_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL2>(
            otw,
            6,
            b"oSAIL-2",
            b"oSAIL-2",
            b"Option Coin Full Sail Epoch 2",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL2>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL2>>(metadata);
    }
}


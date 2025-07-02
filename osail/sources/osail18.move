module osail::osail18 {
    public struct OSAIL18 has drop {}

    fun init(otw: OSAIL18, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail18_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL18>(
            otw,
            6,
            b"oSAIL-18",
            b"oSAIL-18",
            b"Option Coin Full Sail Epoch 18",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL18>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL18>>(metadata);
    }
}
 
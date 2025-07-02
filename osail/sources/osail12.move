module osail::osail12 {
    public struct OSAIL12 has drop {}

    fun init(otw: OSAIL12, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail12_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL12>(
            otw,
            6,
            b"oSAIL-12",
            b"oSAIL-12",
            b"Option Coin Full Sail Epoch 12",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL12>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL12>>(metadata);
    }
} 
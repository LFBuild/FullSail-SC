module osail::osail10 {
    public struct OSAIL10 has drop {}

    fun init(otw: OSAIL10, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail10_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL10>(
            otw,
            6,
            b"oSAIL-10",
            b"oSAIL-10",
            b"Option Coin Full Sail Epoch 10",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL10>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL10>>(metadata);
    }
} 
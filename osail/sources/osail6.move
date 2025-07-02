module osail::osail6 {
    public struct OSAIL6 has drop {}

    fun init(otw: OSAIL6, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail6_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL6>(
            otw,
            6,
            b"oSAIL-6",
            b"oSAIL-6",
            b"Option Coin Full Sail Epoch 6",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL6>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL6>>(metadata);
    }
} 
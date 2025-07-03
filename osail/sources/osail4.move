module osail::osail4 {
    public struct OSAIL4 has drop {}

    fun init(otw: OSAIL4, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/o_sail4_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<OSAIL4>(
            otw,
            6,
            b"oSAIL-4",
            b"oSAIL-4",
            b"Option Coin Full Sail Epoch 4",
            option::some(url),
            ctx
        );
        transfer::public_transfer<sui::coin::TreasuryCap<OSAIL4>>(treasury_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<OSAIL4>>(metadata);
    }
} 
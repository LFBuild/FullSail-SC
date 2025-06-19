module sail_test::sail_test {
    public struct SAIL_TEST has drop {}

    public struct MinterCap<phantom SailCoinType> has store, key {
        id: UID,
        cap: sui::coin::TreasuryCap<SailCoinType>,
    }

    public fun burn<SailCoinType>(
        minter_cap: &mut MinterCap<SailCoinType>,
        coin_to_burn: sui::coin::Coin<SailCoinType>
    ) {
        minter_cap.cap.burn(coin_to_burn);
    }

    public fun mint<SailCoinType>(
        minter_cap: &mut MinterCap<SailCoinType>,
        amount: u64,
        ctx: &mut TxContext
    ): sui::coin::Coin<SailCoinType> {
        minter_cap.cap.mint(amount, ctx)
    }

    public fun total_supply<SailCoinType>(minter_cap: &MinterCap<SailCoinType>): u64 {
        minter_cap.cap.total_supply()
    }

    fun init(otw: SAIL_TEST, ctx: &mut TxContext) {
        let url = sui::url::new_unsafe(std::ascii::string(b"https://app.fullsail.finance/static_files/sail_test_coin.png"));
        let (treasury_cap, metadata) = sui::coin::create_currency<SAIL_TEST>(
            otw,
            9,
            b"SAIL-TEST",
            b"SAIL-TEST",
            b"",
            option::some(url),
            ctx
        );
        let minter_cap = MinterCap<SAIL_TEST> {
            id: object::new(ctx),
            cap: treasury_cap,
        };
        transfer::transfer<MinterCap<SAIL_TEST>>(minter_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<SAIL_TEST>>(metadata);
    }
}


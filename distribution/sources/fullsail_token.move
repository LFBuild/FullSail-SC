module distribution::fullsail_token {
    public struct FULLSAIL_TOKEN has drop {}

    public struct MinterCap<phantom SailCoinType> has store, key {
        id: sui::object::UID,
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
        // TODO: recipient arg probably useless
        recipient: address,
        ctx: &mut sui::tx_context::TxContext
    ): sui::coin::Coin<SailCoinType> {
        assert!(recipient != @0x0, 0);
        minter_cap.cap.mint(amount, ctx)
    }

    public fun total_supply<SailCoinType>(minter_cap: &MinterCap<SailCoinType>): u64 {
        minter_cap.cap.total_supply()
    }

    fun init(otw: FULLSAIL_TOKEN, ctx: &mut sui::tx_context::TxContext) {
        let (treasury_cap, metadata) = sui::coin::create_currency<FULLSAIL_TOKEN>(
            otw,
            6,
            b"FSAIL",
            b"FullSail",
            b"FullSail Governance Token with ve(4,4) capabilities",
            std::option::none<sui::url::Url>(),
            ctx
        );
        let minter_cap = MinterCap<FULLSAIL_TOKEN> {
            id: sui::object::new(ctx),
            cap: treasury_cap,
        };
        sui::transfer::transfer<MinterCap<FULLSAIL_TOKEN>>(minter_cap, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<sui::coin::CoinMetadata<FULLSAIL_TOKEN>>(metadata, sui::tx_context::sender(ctx));
    }
}


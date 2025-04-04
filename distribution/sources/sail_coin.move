module distribution::sail_coin {
    public struct SAIL_COIN has drop {}

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

    fun init(otw: SAIL_COIN, ctx: &mut TxContext) {
        // TODO: add logo url
        // let logoUrl = sui::url::new_unsafe_from_bytes(b"https://link.to.logo");
        let (treasury_cap, metadata) = sui::coin::create_currency<SAIL_COIN>(
            otw,
            6,
            b"SAIL",
            b"FullSail",
            b"FullSail Governance Token with ve(4,4) capabilities",
            option::none<sui::url::Url>(),
            ctx
        );
        let minter_cap = MinterCap<SAIL_COIN> {
            id: object::new(ctx),
            cap: treasury_cap,
        };
        transfer::transfer<MinterCap<SAIL_COIN>>(minter_cap, tx_context::sender(ctx));
        transfer::public_freeze_object<sui::coin::CoinMetadata<SAIL_COIN>>(metadata);
    }
}


module integrate::fullsail_token {
    public entry fun burn<CoinType>(
        minter_cap: &mut distribution::fullsail_token::MinterCap<CoinType>,
        coin_to_burn: sui::coin::Coin<CoinType>
    ) {
        distribution::fullsail_token::burn<CoinType>(minter_cap, coin_to_burn);
    }

    public entry fun mint<CoinType>(
        minter_cap: &mut distribution::fullsail_token::MinterCap<CoinType>,
        amount: u64,
        address: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
            distribution::fullsail_token::mint<CoinType>(minter_cap, amount, address, ctx),
            address
        );
    }

    // decompiled from Move bytecode v6
}


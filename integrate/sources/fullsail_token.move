module integrate::fullsail_token {
    public entry fun burn<CoinType>(
        minter_cap: &mut distribution::fullsail_token::MinterCap<CoinType>,
        coin_to_burn: sui::coin::Coin<CoinType>
    ) {
        minter_cap.burn(coin_to_burn);
    }

    public entry fun mint<CoinType>(
        minter_cap: &mut distribution::fullsail_token::MinterCap<CoinType>,
        amount: u64,
        address: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
            minter_cap.mint(amount, address, ctx),
            address
        );
    }

    // decompiled from Move bytecode v6
}


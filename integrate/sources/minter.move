module integrate::minter {
    public entry fun set_minter_cap<CoinType>(
        admin_cap: &distribution::minter::AdminCap,
        minter: &mut distribution::minter::Minter<CoinType>,
        minter_cap: distribution::fullsail_token::MinterCap<CoinType>
    ) {
        distribution::minter::set_minter_cap<CoinType>(minter, admin_cap, minter_cap);
    }

    // decompiled from Move bytecode v6
}


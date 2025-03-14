module integrate::minter {
    public entry fun set_minter_cap<T0>(
        arg0: &distribution::minter::AdminCap,
        arg1: &mut distribution::minter::Minter<T0>,
        arg2: distribution::fullsail_token::MinterCap<T0>
    ) {
        distribution::minter::set_minter_cap<T0>(arg1, arg0, arg2);
    }

    // decompiled from Move bytecode v6
}


module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::minter {
    public entry fun set_minter_cap<T0>(arg0: &distribution::minter::AdminCap, arg1: &mut distribution::minter::Minter<T0>, arg2: distribution::magma_token::MinterCap<T0>) {
        distribution::minter::set_minter_cap<T0>(arg1, arg0, arg2);
    }
    
    // decompiled from Move bytecode v6
}


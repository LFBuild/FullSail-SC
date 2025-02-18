module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::minter {
    public entry fun set_minter_cap<T0>(arg0: &0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::AdminCap, arg1: &mut 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::Minter<T0>, arg2: 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::magma_token::MinterCap<T0>) {
        0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::set_minter_cap<T0>(arg1, arg0, arg2);
    }
    
    // decompiled from Move bytecode v6
}


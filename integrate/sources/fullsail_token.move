module integrate::fullsail_token {
    public entry fun burn<T0>(arg0: &mut distribution::magma_token::MinterCap<T0>, arg1: sui::coin::Coin<T0>, arg2: &mut sui::tx_context::TxContext) {
        distribution::magma_token::burn<T0>(arg0, arg1);
    }
    
    public entry fun mint<T0>(arg0: &mut distribution::magma_token::MinterCap<T0>, arg1: u64, arg2: address, arg3: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer<sui::coin::Coin<T0>>(distribution::magma_token::mint<T0>(arg0, arg1, arg2, arg3), arg2);
    }
    
    // decompiled from Move bytecode v6
}


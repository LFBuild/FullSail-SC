module integrate::utils {

    public fun merge_coins<T0>(
        mut arg0: vector<sui::coin::Coin<T0>>,
        arg1: &mut sui::tx_context::TxContext
    ): sui::coin::Coin<T0> {
        if (std::vector::is_empty<sui::coin::Coin<T0>>(&arg0)) {
            std::vector::destroy_empty<sui::coin::Coin<T0>>(arg0);
            sui::coin::zero<T0>(arg1)
        } else {
            let mut v1 = std::vector::pop_back<sui::coin::Coin<T0>>(&mut arg0);
            sui::pay::join_vec<T0>(&mut v1, arg0);
            v1
        }
    }

    public fun send_coin<T0>(arg0: sui::coin::Coin<T0>, arg1: address) {
        if (sui::coin::value<T0>(&arg0) > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<T0>>(arg0, arg1);
        } else {
            sui::coin::destroy_zero<T0>(arg0);
        };
    }

    public fun transfer_coin_to_sender<T0>(arg0: sui::coin::Coin<T0>, arg1: &mut sui::tx_context::TxContext) {
        if (sui::coin::value<T0>(&arg0) > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<T0>>(arg0, sui::tx_context::sender(arg1));
        } else {
            sui::coin::destroy_zero<T0>(arg0);
        };
    }

    // decompiled from Move bytecode v6
}


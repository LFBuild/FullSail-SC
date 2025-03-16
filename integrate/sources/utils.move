module integrate::utils {

    public fun merge_coins<CoinType>(
        mut coins: vector<sui::coin::Coin<CoinType>>,
        ctx: &mut sui::tx_context::TxContext
    ): sui::coin::Coin<CoinType> {
        if (std::vector::is_empty<sui::coin::Coin<CoinType>>(&coins)) {
            std::vector::destroy_empty<sui::coin::Coin<CoinType>>(coins);
            sui::coin::zero<CoinType>(ctx)
        } else {
            let mut last_coin = std::vector::pop_back<sui::coin::Coin<CoinType>>(&mut coins);
            sui::pay::join_vec<CoinType>(&mut last_coin, coins);
            last_coin
        }
    }

    public fun send_coin<CoinType>(
        coin: sui::coin::Coin<CoinType>,
        recipient: address
    ) {
        if (coin.value<CoinType>() > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(coin, recipient);
        } else {
            sui::coin::destroy_zero<CoinType>(coin);
        };
    }

    public fun transfer_coin_to_sender<CoinType>(
        coin: sui::coin::Coin<CoinType>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        if (coin.value<CoinType>() > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(coin, sui::tx_context::sender(ctx));
        } else {
            sui::coin::destroy_zero<CoinType>(coin);
        };
    }
}


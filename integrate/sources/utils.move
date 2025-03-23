module integrate::utils {

    public fun merge_coins<CoinType>(
        mut coins: vector<sui::coin::Coin<CoinType>>,
        ctx: &mut sui::tx_context::TxContext
    ): sui::coin::Coin<CoinType> {
        if (coins.is_empty()) {
            coins.destroy_empty();
            sui::coin::zero<CoinType>(ctx)
        } else {
            let mut last_coin = coins.pop_back();
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
            coin.destroy_zero();
        };
    }

    public fun transfer_coin_to_sender<CoinType>(
        coin: sui::coin::Coin<CoinType>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        if (coin.value<CoinType>() > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(coin, sui::tx_context::sender(ctx));
        } else {
            coin.destroy_zero();
        };
    }
}


module full_sail::router {
    use std::ascii::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::package;
    use sui::dynamic_field;
    use full_sail::coin_wrapper::{Self, WrapperStore};
    use full_sail::liquidity_pool::{Self, LiquidityPool, FeesAccounting, LiquidityPoolConfigs};

    // --- addresses ---
    const DEFAULT_ADMIN: address = @0x123;

    // --- errors ---
    const E_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 1;
    const E_ZERO_RESERVE: u64 = 2;
    const E_VECTOR_LENGTH_MISMATCH: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 6;
    const E_ZERO_AMOUNT: u64 = 7;
    const E_ZERO_TOTAL_POWER: u64 = 8;
    const E_SAME_TOKEN: u64 = 9;

    public fun swap<BaseType, QuoteType>(
        pool_id: &mut UID,
        input_coin: Coin<BaseType>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        ctx: &mut TxContext
    ): Coin<QuoteType> {
        let pool = liquidity_pool::liquidity_pool<BaseType, QuoteType>(
            pool_id,
            base_metadata,
            quote_metadata,
            is_stable,
        );
        let output_coin = liquidity_pool::swap<BaseType, QuoteType>(
            pool,
            configs,
            fees_accounting,
            base_metadata,
            quote_metadata,
            input_coin,
            ctx
        );
        assert!(coin::value(&output_coin) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        output_coin
    }

    public fun get_amount_out<BaseType, QuoteType>(
        pool_id: &mut UID,
        input_amount: u64,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool
    ): (u64, u64) {
        liquidity_pool::get_amount_out(
            liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable),
            base_metadata,
            quote_metadata,
            input_amount
        )
    }

    public fun get_trade_diff<BaseType, QuoteType>(
        pool_id: &mut UID,
        input_amount: u64,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        input_metadata: &CoinMetadata<BaseType>,
        is_stable: bool
    ): (u64, u64) {
        liquidity_pool::get_trade_diff(
            liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable),
            base_metadata,
            quote_metadata,
            input_metadata,
            input_amount
        )
    }

    public fun quote_liquidity<BaseType, QuoteType>(
        pool_id: &mut UID,
        base_metadata: &CoinMetadata<BaseType>, 
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        input_amount: u64
    ): u64 {
        let (reserve_amount_1, reserve_amount_2) = liquidity_pool::pool_reserves<BaseType, QuoteType>(
            liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable)
        );

        let mut reserve_in = reserve_amount_1;
        let mut reserve_out = reserve_amount_2;
        if(!liquidity_pool::is_sorted(base_metadata, quote_metadata)) {
            reserve_out = reserve_amount_1;
            reserve_in = reserve_amount_2;
        };
        if(reserve_in == 0 || reserve_out == 0) {
            0
        } else {
            assert!(reserve_in != 0, E_ZERO_RESERVE);
            (((input_amount as u128) * (reserve_out as u128) / (reserve_in as u128)) as u64)
        }
    }

    fun get_optimal_amounts<BaseType, QuoteType>(
        pool_id: &mut UID,
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        input_amount: u64,
        output_amount: u64
    ): (u64, u64) {
        assert!(input_amount > 0 && output_amount > 0, E_ZERO_AMOUNT);

        let output = quote_liquidity(pool_id, base_metadata, quote_metadata, is_stable, input_amount);
        if(output == 0) {
            (input_amount, output_amount)
        } else if(output < output_amount) {
            (input_amount, output)
        } else {
            (
                quote_liquidity(
                    pool_id, 
                    quote_metadata, 
                    base_metadata, 
                    is_stable, 
                    output_amount
                ), 
                output_amount
            )
        }
    }

    fun exact_deposit<BaseType>(recipient: address, metadata: &CoinMetadata<BaseType>, asset: Coin<BaseType>) {
        transfer::public_transfer(asset, recipient);
    }

    public fun get_amounts_out<BaseType, QuoteType>(
        pool_id: &mut UID, 
        amount_in: u64, 
        token_in: &CoinMetadata<BaseType>, 
        intermediary_tokens: &mut vector<CoinMetadata<QuoteType>>, 
        is_stable: &mut vector<bool>
    ): u64 {
        assert!(vector::length(intermediary_tokens) == vector::length(is_stable), E_VECTOR_LENGTH_MISMATCH);
        vector::reverse(intermediary_tokens);
        vector::reverse(is_stable);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = amount_in;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let (amount_out, _) = get_amount_out<BaseType, QuoteType>(
                pool_id, 
                amount_in, 
                token_in, 
                &next_token, 
                vector::pop_back(is_stable)
            );
            current_amount = amount_out;
            token_count = token_count - 1;
            transfer::public_transfer(next_token, @0x0);
        };
        current_amount
    }

    public fun liquidity_amount_out<BaseType, QuoteType>(
        pool_id: &mut UID, 
        metadata_a: &CoinMetadata<BaseType>, 
        metadata_b: &CoinMetadata<QuoteType>, 
        is_stable: bool, 
        amount_a: u64, 
        amount_b: u64
    ): u64 {
        liquidity_pool::liquidity_out(
            liquidity_pool::liquidity_pool(pool_id, metadata_a, metadata_b, is_stable), 
            metadata_a, 
            metadata_b, 
            amount_a, 
            amount_b, 
            is_stable
        )
    }

    fun remove_liquidity_internal<BaseType, QuoteType>(
        pool_id: &mut UID, 
        metadata_a: &CoinMetadata<BaseType>,
        metadata_b: &CoinMetadata<QuoteType>,
        is_stable: bool,
        lp_amount: u64, 
        min_amount_a: u64,
        min_amount_b: u64,
        ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        let (coin_in, coin_out) = liquidity_pool::burn<BaseType, QuoteType>(
            liquidity_pool::liquidity_pool(pool_id, metadata_a, metadata_b, is_stable),
            lp_amount,
            ctx
        );
        assert!(coin::value(&coin_in) >= min_amount_a && coin::value(&coin_out) >= min_amount_b, E_INSUFFICIENT_OUTPUT_AMOUNT);
        (coin_in, coin_out)
    }

    public fun swap_router<BaseType, QuoteType>(
        pool_id: &mut UID, 
        amount_in: Coin<BaseType>, 
        token_in: &CoinMetadata<BaseType>, 
        intermediary_tokens: &mut vector<CoinMetadata<BaseType>>,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        min_output_amount: u64,
        is_stable: &mut vector<bool>,
        ctx: &mut TxContext
    ): Coin<BaseType> {
        assert!(vector::length(intermediary_tokens) == vector::length(is_stable), E_VECTOR_LENGTH_MISMATCH);
        vector::reverse(intermediary_tokens);
        vector::reverse(is_stable);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = amount_in;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let coin_in = current_amount;
            let amount_out = swap<BaseType, BaseType>(
                pool_id, 
                coin_in, 
                min_output_amount,
                configs,
                fees_accounting,
                token_in, 
                &next_token, 
                vector::pop_back(is_stable),
                ctx
            );
            current_amount = amount_out;
            token_count = token_count - 1; 
            transfer::public_transfer(next_token, @0x0);
        };
        assert!(coin::value(&current_amount) >= min_output_amount, E_INSUFFICIENT_BALANCE);
        current_amount
    }
}
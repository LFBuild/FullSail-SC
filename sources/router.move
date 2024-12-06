module full_sail::router {
    use std::ascii::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use std::type_name;
    use sui::package;
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use full_sail::coin_wrapper::{Self, WrapperStore, COIN_WRAPPER};
    use full_sail::liquidity_pool::{Self, LiquidityPool, FeesAccounting, LiquidityPoolConfigs};
    use full_sail::gauge::{Self, Gauge};
    use sui::clock::{Clock};
    use full_sail::vote_manager::{Self, AdministrativeData};
    use std::debug;

    // --- addresses ---
    const DEFAULT_ADMIN: address = @0x123;

    // --- errors ---
    const E_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 1;
    const E_ZERO_RESERVE: u64 = 2;
    const E_VECTOR_LENGTH_MISMATCH: u64 = 3;
    const E_OUTPUT_IS_WRAPPER: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 6;
    const E_ZERO_AMOUNT: u64 = 7;
    const E_ZERO_TOTAL_POWER: u64 = 8;
    const E_SAME_TOKEN: u64 = 9;
    
    public fun swap<BaseType, QuoteType>(
        pool_id: &mut UID,
        // pool: &mut LiquidityPool<BaseType, QuoteType>,
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

    public fun get_amount_out(
        pool_id: &mut UID,
        input_amount: u64,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
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

    public fun add_liquidity<BaseType, QuoteType>(
        _coin_a: Coin<BaseType>,
        _coin_b: Coin<QuoteType>,
        _is_stable: bool,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun add_liquidity_and_stake_both_coins_entry<BaseType, QuoteType> (
        pool_id: &mut UID,
        fees_accounting: &mut FeesAccounting, 
        is_stable: bool,
        amount_a: u64,
        amount_b: u64,
        store: &mut WrapperStore,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (optimal_a, optimal_b) = get_optimal_amounts<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            coin_wrapper::get_wrapper<BaseType>(store),
            coin_wrapper::get_wrapper<QuoteType>(store),
            is_stable,
            amount_a, 
            amount_b
        );
        
        let pool = liquidity_pool::liquidity_pool(
            pool_id, 
            coin_wrapper::get_wrapper<BaseType>(store),
            coin_wrapper::get_wrapper<QuoteType>(store),
            is_stable
        );

        let input_base_coin = coin_wrapper::borrow_original_coin<BaseType>(store);
        let new_base_coin = coin_wrapper::wrap(store, coin::split(input_base_coin, optimal_a, ctx), ctx);

        let input_quote_coin = coin_wrapper::borrow_original_coin<QuoteType>(store);
        let new_quote_coin = coin_wrapper::wrap(store, coin::split(input_quote_coin, optimal_b, ctx), ctx);

        let lp_tokens = liquidity_pool::mint_lp(
            pool, 
            fees_accounting, 
            coin_wrapper::get_wrapper<BaseType>(store),
            coin_wrapper::get_wrapper<QuoteType>(store),
            new_base_coin,
            new_quote_coin,
            is_stable, 
            ctx
        );
        // gauge::stake(vote_manager::get_gauge(pool_id), lp_tokens ctx, clock);
    }

    public entry fun add_liquidity_and_stake_coin_entry<BaseType, QuoteType>(
        pool_id: &mut UID,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        input_amount: u64,
        output_amount: u64,
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ) {
        let (optimal_a, optimal_b) = get_optimal_amounts<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            coin_wrapper::get_wrapper<QuoteType>(store),
            quote_metadata,
            is_stable,
            input_amount, 
            output_amount
        );

        let base_coin = exact_withdraw<BaseType>(optimal_a, store, ctx);
        let quote_coin = exact_withdraw<QuoteType>(optimal_b, store, ctx);

        assert!(coin::value(&base_coin) == optimal_a, E_INSUFFICIENT_OUTPUT_AMOUNT);
        assert!(coin::value(&quote_coin) == optimal_b, E_INSUFFICIENT_OUTPUT_AMOUNT);
        // gauge::stake(
        //     account,
        //     vote_manager::get_gauge(liquidity_pool::liquidity_pool(coin_wrapper::get_wrapper<CoinType>(), other_metadata, stable)),
        //     liquidity_pool::mint_lp(account, coin_wrapper::wrap<CoinType>(coin::withdraw<CoinType>(account, optimal_a)), asset_b, stable)
        // );
    }

    public entry fun add_liquidity_and_stake_entry<BaseType, QuoteType>(
        pool_id: &mut UID,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        input_amount: u64,
        output_amount: u64,
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ) {
        let (optimal_a, optimal_b) = get_optimal_amounts<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            base_metadata,
            quote_metadata,
            is_stable,
            input_amount, 
            output_amount
        );

        let base_coin = exact_withdraw<BaseType>(optimal_a, store, ctx);
        let quote_coin = exact_withdraw<QuoteType>(optimal_b, store, ctx);

    }

    public entry fun create_pool<BaseType, QuoteType>(
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        ctx: &mut TxContext
    ) {
        let pool = liquidity_pool::create<BaseType, QuoteType>(
            base_metadata, 
            quote_metadata, 
            configs, 
            is_stable, 
            ctx
        );
        // vote_manager::whitelist_default_reward_pool(pool);
        // vote_manager::create_gauge_internal(pool);
    }

    public entry fun create_pool_both_coins<BaseType, QuoteType>(
        configs: &mut LiquidityPoolConfigs,
        is_stable: bool,
        store: &WrapperStore,
        ctx: &mut TxContext
    ) {
        let pool = liquidity_pool::create<COIN_WRAPPER, COIN_WRAPPER>(
            coin_wrapper::get_wrapper<BaseType>(store),
            coin_wrapper::get_wrapper<QuoteType>(store),
            configs,
            is_stable,
            ctx
        );
        // vote_manager::whitelist_default_reward_pool(pool);
        // vote_manager::create_gauge_internal(pool);
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
        } else if(output <= output_amount) {
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

    public(package) fun exact_deposit<BaseType>(recipient: address, asset: Coin<BaseType>) {
        transfer::public_transfer(asset, recipient);
    }

    public(package) fun exact_withdraw<BaseType>(
        amount: u64, 
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        let input_base_coin = coin_wrapper::borrow_original_coin<BaseType>(store);
        let new_base_coin = coin::split(input_base_coin, amount, ctx);
        assert!(coin::value(&new_base_coin) == amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        coin_wrapper::wrap(store, new_base_coin, ctx)
    }

    public fun get_amounts_out(
        pool_id: &mut UID, 
        input_amount: u64, 
        token_in: &CoinMetadata<COIN_WRAPPER>, 
        intermediary_tokens: &mut vector<CoinMetadata<COIN_WRAPPER>>, 
        is_stable: &mut vector<bool>
    ): u64 {
        assert!(vector::length(intermediary_tokens) == vector::length(is_stable), E_VECTOR_LENGTH_MISMATCH);
        vector::reverse(intermediary_tokens);
        vector::reverse(is_stable);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = input_amount;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let (amount_out, _) = get_amount_out(
                pool_id, 
                current_amount, 
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
        base_metadata: &CoinMetadata<BaseType>, 
        quote_metadata: &CoinMetadata<QuoteType>, 
        is_stable: bool, 
        input_amount: u64, 
        output_amount: u64
    ): u64 {
        liquidity_pool::liquidity_out(
            liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable), 
            base_metadata, 
            quote_metadata, 
            input_amount, 
            output_amount, 
            is_stable
        )
    }

    fun remove_liquidity_internal<BaseType, QuoteType>(
        pool_id: &mut UID, 
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        lp_amount: u64, 
        min_input_amount: u64,
        min_output_amount: u64,
        ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        let (coin_in, coin_out) = liquidity_pool::burn<BaseType, QuoteType>(
            liquidity_pool::liquidity_pool(pool_id, base_metadata, quote_metadata, is_stable),
            lp_amount,
            ctx
        );
        assert!(coin::value(&coin_in) >= min_input_amount && coin::value(&coin_out) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        (coin_in, coin_out)
    }

    public fun redeemable_liquidity<BaseType, QuoteType>(
        pool_id: &mut UID, 
        base_metadata: &CoinMetadata<BaseType>,
        quote_metadata: &CoinMetadata<QuoteType>,
        is_stable: bool,
        liquidity_amount: u64
    ): (u64, u64) {
        liquidity_pool::liquidity_amounts<BaseType, QuoteType>(
            liquidity_pool::liquidity_pool(
                pool_id,
                base_metadata,
                quote_metadata,
                is_stable
            ),
            liquidity_amount
        )
    }

    public fun remove_liquidity<BaseType, QuoteType>(
        _base_metadata: &CoinMetadata<BaseType>,
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public fun remove_liquidity_both_coins<BaseType, QuoteType>(
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public entry fun remove_liquidity_both_coins_entry<BaseType, QuoteType>(
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public fun remove_liquidity_coin<BaseType, QuoteType>(
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _ctx: &mut TxContext
    ): (Coin<BaseType>, Coin<QuoteType>) {
        abort 0
    }

    public entry fun remove_liquidity_coin_entry<BaseType, QuoteType>(
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public fun remove_liquidity_entry<BaseType, QuoteType>(
        _base_metadata: &CoinMetadata<BaseType>,
        _quote_metadata: &CoinMetadata<QuoteType>,
        _is_stable: bool,
        _liquidity_amount: u64,
        _min_input_amount: u64,
        _min_output_amount: u64,
        _recipient: address,
        _ctx: &mut TxContext
    ): (&Coin<BaseType>, &Coin<QuoteType>) {
        abort 0
    }

    public fun swap_router(
        pool_id: &mut UID,
        // pool: &mut LiquidityPool<BaseType, QuoteType>, 
        input_amount: Coin<COIN_WRAPPER>, 
        token_in: &CoinMetadata<COIN_WRAPPER>, 
        intermediary_tokens: &mut vector<CoinMetadata<COIN_WRAPPER>>,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting, 
        min_output_amount: u64,
        is_stable: &mut vector<bool>,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        assert!(vector::length(intermediary_tokens) == vector::length(is_stable), E_VECTOR_LENGTH_MISMATCH);
        vector::reverse(intermediary_tokens);
        vector::reverse(is_stable);

        let mut token_count = vector::length(intermediary_tokens);
        let mut current_amount = input_amount;
        while(token_count > 0) {
            let next_token = vector::pop_back(intermediary_tokens);
            let coin_in = current_amount;
            let amount_out = swap(
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
        assert!(coin::value(&current_amount) >= min_output_amount, E_INSUFFICIENT_OUTPUT_AMOUNT);
        current_amount
    }

    public fun swap_coin_for_coin(
        // pool: LiquidityPool<BaseType, QuoteType>,
        pool_id: &mut UID,
        input_coin: Coin<COIN_WRAPPER>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        ctx: &mut TxContext
    ): Coin<COIN_WRAPPER> {
        swap(
            pool_id, 
            input_coin, 
            min_output_amount, 
            configs, 
            fees_accounting, 
            base_metadata, 
            quote_metadata, 
            is_stable, 
            ctx
        )
    }

    public fun swap_coin_for_coin_entry(
        pool_id: &mut UID,
        input_coin: Coin<COIN_WRAPPER>,
        min_output_amount: u64,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        recipient: address,
        ctx: &mut TxContext
    ) {
        exact_deposit(
            recipient, 
            swap_coin_for_coin(
                pool_id, 
                input_coin, 
                min_output_amount, 
                configs, 
                fees_accounting, 
                base_metadata, 
                quote_metadata, 
                is_stable, 
                ctx
            )                         
        );
    }

    public entry fun swap_entry<BaseType, QuoteType>(
        pool_id: &mut UID,
        input_amount: u64, 
        min_output_amount: u64,
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>, 
        quote_metadata: &CoinMetadata<COIN_WRAPPER>, 
        is_stable: bool, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        // assert!(!coin_wrapper::is_wrapper(quote_metadata), E_OUTPUT_IS_WRAPPER);
        exact_deposit(
            recipient,
            swap(
                pool_id, 
                exact_withdraw<BaseType>(
                    input_amount,
                    store,
                    ctx
                ),
                min_output_amount, 
                configs, 
                fees_accounting, 
                base_metadata, 
                quote_metadata, 
                is_stable, 
                ctx
            )
        );
    }

    public entry fun swap_route_entry<BaseType>(
        pool_id: &mut UID,
        input_amount: u64, 
        min_output_amount: u64, 
        store: &mut WrapperStore,
        configs: &LiquidityPoolConfigs,
        fees_accounting: &mut FeesAccounting,
        base_metadata: &CoinMetadata<COIN_WRAPPER>, 
        intermediary_tokens: &mut vector<CoinMetadata<COIN_WRAPPER>>, 
        is_stable: &mut vector<bool>,
        recipient: address, 
        ctx: &mut TxContext
    ) {
        // assert!(!coin_wrapper::is_wrapper(*vector::borrow(&route_metadata, vector::length(&route_metadata) - 1)), E_OUTPUT_IS_WRAPPER);

        exact_deposit(
            recipient,
            swap_router(
                pool_id, 
                exact_withdraw<BaseType>(
                    input_amount,
                    store,
                    ctx
                ),
                base_metadata,
                intermediary_tokens,
                configs, 
                fees_accounting, 
                min_output_amount, 
                is_stable, 
                ctx
            )
        );
    }

    public entry fun unstake_and_remove_liquidity_both_coins_entry<BaseType, QuoteType>(
        pool_id: &mut UID,
        is_stable: bool,
        store: &WrapperStore,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);
        let quote_metadata = coin_wrapper::get_wrapper<QuoteType>(store);
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            vote_manager::get_gauge<COIN_WRAPPER, COIN_WRAPPER>(
                admin_data,
                liquidity_pool::liquidity_pool<COIN_WRAPPER, COIN_WRAPPER>(
                    pool_id,
                    base_metadata,
                    quote_metadata,
                    is_stable
                )
            ),
            lp_amount,
            ctx,
            clock
        ); 
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            base_metadata,
            quote_metadata,
            is_stable,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }

    public entry fun unstake_and_remove_liquidity_coin_entry<BaseType>(
        pool_id: &mut UID,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        store: &WrapperStore,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        let base_metadata = coin_wrapper::get_wrapper<BaseType>(store);
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            vote_manager::get_gauge<COIN_WRAPPER, COIN_WRAPPER>(
                admin_data,
                liquidity_pool::liquidity_pool<COIN_WRAPPER, COIN_WRAPPER>(
                    pool_id,
                    base_metadata,
                    quote_metadata,
                    is_stable
                )
            ),
            lp_amount,
            ctx,
            clock
        ); 
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            base_metadata,
            quote_metadata,
            is_stable,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }

    public entry fun unstake_and_remove_liquidity_entry(
        pool_id: &mut UID,
        base_metadata: &CoinMetadata<COIN_WRAPPER>,
        quote_metadata: &CoinMetadata<COIN_WRAPPER>,
        is_stable: bool,
        store: &WrapperStore,
        lp_amount: u64,
        min_input_amount: u64,
        min_output_amount: u64,
        recipient: address,
        clock: &Clock,
        admin_data: &AdministrativeData,
        ctx: &mut TxContext
    ) {
        gauge::unstake_lp<COIN_WRAPPER, COIN_WRAPPER>(
            vote_manager::get_gauge<COIN_WRAPPER, COIN_WRAPPER>(
                admin_data,
                liquidity_pool::liquidity_pool<COIN_WRAPPER, COIN_WRAPPER>(
                    pool_id,
                    base_metadata,
                    quote_metadata,
                    is_stable
                )
            ),
            lp_amount,
            ctx,
            clock
        ); 
        let (input_coin, output_coin) = remove_liquidity_internal<COIN_WRAPPER, COIN_WRAPPER>(
            pool_id,
            base_metadata,
            quote_metadata,
            is_stable,
            lp_amount,
            min_input_amount,
            min_output_amount,
            ctx
        );
        exact_deposit(recipient, input_coin);
        exact_deposit(recipient, output_coin);
    }
}
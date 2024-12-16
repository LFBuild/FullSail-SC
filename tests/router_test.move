#[test_only]
module full_sail::router_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock;
    use full_sail::router;
    use full_sail::gauge::{Self, Gauge};
    use full_sail::liquidity_pool::{Self, LiquidityPool, LiquidityPoolConfigs, FeesAccounting};
    use full_sail::coin_wrapper::{Self, WrapperStore, WrapperStoreCap};
    use full_sail::vote_manager::{Self, AdministrativeData};
    use full_sail::sui::{Self, SUI};
    use full_sail::usdt::{Self, USDT};

    const OWNER: address = @0xab;

    fun setup(scenario: &mut Scenario) {
        // Initialize all modules
        sui::init_for_testing_sui(ts::ctx(scenario));
        usdt::init_for_testing_usdt(ts::ctx(scenario));
        liquidity_pool::init_for_testing(ts::ctx(scenario));
        coin_wrapper::init_for_testing(ts::ctx(scenario));
        vote_manager::init_for_testing(ts::ctx(scenario));
        next_tx(scenario, OWNER);
        let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
        let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
        ts::return_immutable(base_metadata);
        ts::return_immutable(quote_metadata);
    }

    #[test]
    fun test_add_liquidity_and_stake_both_coins_entry() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);
        let clock = clock::create_for_testing(ts::ctx(scenario));

        next_tx(scenario, OWNER);
        let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
        let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let cap = ts::take_from_sender<WrapperStoreCap>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        coin_wrapper::register_coin_for_testing<USDT>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        coin_wrapper::register_coin_for_testing<SUI>(
            &cap,
            &mut store,
            ts::ctx(scenario)
        );
        let (mut pool, pool_id) = gauge::create_gauge_pool_test<USDT, SUI>(
            &quote_metadata, 
            &base_metadata, 
            &mut configs, 
            false, 
            ts::ctx(scenario)
        );
        gauge::create_gauge_test<USDT, SUI>(
            &quote_metadata, 
            &base_metadata, 
            &mut configs, 
            false,
            ts::ctx(scenario)
        );

        next_tx(scenario, OWNER);
        {
            let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
            let mut gauge = ts::take_shared<Gauge<USDT, SUI>>(scenario);
            let amount = 100000;
            let base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            let base_wrapped_coin = coin_wrapper::wrap<SUI>(&mut store, base_coin, ts::ctx(scenario));
            let quote_wrapped_coin = coin_wrapper::wrap<USDT>(&mut store, quote_coin, ts::ctx(scenario));
            router::add_liquidity_and_stake_both_coins_entry<USDT, SUI>(
                &mut pool,
                &mut gauge,
                &quote_metadata,
                &base_metadata,
                false,
                100000,
                100000,
                &mut store,
                &admin_data,
                &mut fees_accounting,
                &clock,
                ts::ctx(scenario)
            );

            transfer::public_transfer(base_wrapped_coin, @0xcafe);
            transfer::public_transfer(quote_wrapped_coin, @0xcafe);
            ts::return_shared(fees_accounting);
            ts::return_shared(gauge);
        };

        let all_pools = liquidity_pool::all_pool_ids(&configs);
        assert!(vector::length(&all_pools) == 2, 0);
        assert!(vector::contains(&all_pools, &pool_id), 1);

        ts::return_immutable(base_metadata);
        ts::return_immutable(quote_metadata);
        ts::return_shared(configs);
        ts::return_shared(store);
        ts::return_to_sender(scenario, cap);
        ts::return_shared(admin_data);
        clock.destroy_for_testing();
        test_utils::destroy(pool);
        ts::end(scenario_val);
    }
}
#[test_only]
module full_sail::router_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock;
    use full_sail::router;
    use full_sail::liquidity_pool::{Self, LiquidityPool, LiquidityPoolConfigs, FeesAccounting};
    use full_sail::coin_wrapper::{Self, WrapperStore};
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
    fun test_add_liquidity_and_stake_both_coins_entry(): ID {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        setup(scenario);

        next_tx(scenario, OWNER);
        let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
        let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
        let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
        let mut store = ts::take_shared<WrapperStore>(scenario);
        let admin_data = ts::take_shared<AdministrativeData>(scenario);
        let mut clock = clock::create_for_testing(ts::ctx(scenario));
        let mut gauge_registry = vote_manager::create_gauge_registry<USDT, SUI>(ts::ctx(scenario));
        let pool_id = liquidity_pool::create<SUI, USDT>(&base_metadata, &quote_metadata, &mut configs, false, ts::ctx(scenario));
        
        next_tx(scenario, OWNER);
        let mut pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
        let mut fees_accounting = ts::take_shared<FeesAccounting>(scenario);
        router::add_liquidity_and_stake_both_coins_entry<USDT, SUI>(
            &mut pool,
            &quote_metadata,
            &base_metadata,
            false,
            100,
            100,
            &mut store,
            &mut gauge_registry,
            &admin_data,
            &mut fees_accounting,
            &clock,
            ts::ctx(scenario)
        );

        clock.destroy_for_testing();
        ts::return_immutable(base_metadata);
        ts::return_immutable(quote_metadata);
        ts::return_shared(store);
        test_utils::destroy(gauge_registry);
        ts::return_shared(admin_data);
        ts::return_shared(fees_accounting);
        ts::return_shared(configs);
        ts::return_shared(pool);
        ts::end(scenario_val);
        pool_id
    }
}
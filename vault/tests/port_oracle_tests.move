#[test_only]
module vault::port_oracle_tests;

use sui::test_scenario::{Self, Scenario};
use sui::test_utils;
use sui::clock::{Self, Clock};

use switchboard::aggregator::{Self, Aggregator};
use switchboard::decimal;
use vault::usdt_tests::{Self, USDT_TESTS};
use vault::eth_tests::{Self, ETH_TESTS};
use vault::port_oracle::{Self, PortOracle};
use vault::vault_config;
use vault::port;

#[test]
fun test_port_oracle() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let mut usd_aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    let mut eth_aggregator = setup_test_aggregator(&mut scenario, 3000000000000000000000, &clock);

    let (eth_treasury_cap, eth_metadata) = eth_tests::create_eth_tests(&mut scenario, 20);
    let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
    
    // Initialize
    scenario.next_tx(admin);
    {
        port_oracle::test_init(scenario.ctx());
        vault_config::test_init(scenario.ctx());
    };
    
    // Add aggregator to port oracle
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Add switchboard oracle info
        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        port_oracle.add_switchboard_oracle_info<ETH_TESTS>(
            &global_config,
            &eth_metadata,
            &eth_aggregator,
            60,
            scenario.ctx()
        );

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

    // get eth price
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        aggregator_set_current_value(&mut eth_aggregator,  3000000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<ETH_TESTS>(
            &global_config,
            &eth_aggregator,
            &clock
        );

        // Get price
        let price = port_oracle.get_price<ETH_TESTS>(&clock);

        assert!(price.price_value() == 30000000000000, 111);

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    // get usd price
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        aggregator_set_current_value(&mut usd_aggregator,  1000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<USDT_TESTS>(
            &global_config,
            &usd_aggregator,
            &clock
        );

        // Get price
        let price = port_oracle.get_price<USDT_TESTS>(&clock);

        assert!(price.price_value() == 10000000000, 111);

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    // get eth/usd price
    // scenario.next_tx(admin);
    // {
    //     let mut port_oracle = scenario.take_shared<PortOracle>();
    //     let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
        
    //     let (price_1, price_2, price_1_in_quote, price_2_in_base) = port_oracle.calculate_oracle_prices<ETH_TESTS, USDT_TESTS>(&clock);

    //     assert!(price_1 == 30000000000000, 222);
    //     assert!(price_2 == 10000000000, 333);
    //     assert!(price_1_in_quote == 30000000000000, 444);
    //     assert!(price_2_in_base == 10000000000, 555);

    //     test_scenario::return_shared(port_oracle);
    //     test_scenario::return_shared(global_config);
    // };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    transfer::public_transfer(eth_treasury_cap, admin);
    transfer::public_transfer(eth_metadata, admin);
    test_utils::destroy(usd_aggregator);
    test_utils::destroy(eth_aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_port_oracle_calculate_oracle_prices() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let mut usd_aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    let mut eth_aggregator = setup_test_aggregator(&mut scenario, 3000000000000000000000, &clock);

    let (eth_treasury_cap, eth_metadata) = eth_tests::create_eth_tests(&mut scenario, 10);
    let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
    
    // Initialize
    scenario.next_tx(admin);
    {
        port_oracle::test_init(scenario.ctx());
        vault_config::test_init(scenario.ctx());
    };
    
    // Add aggregator to port oracle
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Add switchboard oracle info
        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        port_oracle.add_switchboard_oracle_info<ETH_TESTS>(
            &global_config,
            &eth_metadata,
            &eth_aggregator,
            60,
            scenario.ctx()
        );

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

    // get eth price
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        aggregator_set_current_value(&mut eth_aggregator,  3000000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<ETH_TESTS>(
            &global_config,
            &eth_aggregator,
            &clock
        );

        let eth_type = std::type_name::with_defining_ids<ETH_TESTS>();
        let eth_price = port_oracle.get_price_by_type(eth_type, &clock);
        assert!(eth_price.price_value() == 30000000000000, 898);

        aggregator_set_current_value(&mut usd_aggregator,  1000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<USDT_TESTS>(
            &global_config,
            &usd_aggregator,
            &clock
        );

        let usd_type = std::type_name::with_defining_ids<USDT_TESTS>();
        let usd_price = port_oracle.get_price_by_type(usd_type, &clock);
        assert!(usd_price.price_value() == 10000000000, 977);

        let (price_1, price_2, price_1_in_quote, price_2_in_base) = port_oracle.calculate_oracle_prices<ETH_TESTS, USDT_TESTS>(&clock);

        assert!(price_1 == 3000000000, 222);
        assert!(price_2 == 33333333333, 123);
        assert!(price_1_in_quote == 30000000000000, 444);
        assert!(price_2_in_base == 10000000000, 555);

        let eth_price = port_oracle::switchboard_price_from_oracle_info(&eth_aggregator,port_oracle.oracle_info<ETH_TESTS>(), &clock);
        assert!(eth_price == 30000000000000, 1000);

        let usd_price = port_oracle::switchboard_price_from_oracle_info(&usd_aggregator,port_oracle.oracle_info<USDT_TESTS>(), &clock);
        assert!(usd_price == 10000000000, 1000);

        port_oracle.remove_switchboard_oracle_info<ETH_TESTS>(&global_config, scenario.ctx());

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    transfer::public_transfer(eth_treasury_cap, admin);
    transfer::public_transfer(eth_metadata, admin);
    test_utils::destroy(usd_aggregator);
    test_utils::destroy(eth_aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = vault::error::PRICE_NOT_UPDATED)]
fun test_port_oracle_price_not_updated() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let usd_aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);

    let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
    
    // Initialize
    scenario.next_tx(admin);
    {
        port_oracle::test_init(scenario.ctx());
        vault_config::test_init(scenario.ctx());
    };
    
    // Add aggregator to port oracle
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Add switchboard oracle info
        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

    // get usd price
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Update price 
        port_oracle.external_update_price_from_switchboard<USDT_TESTS>(
            &global_config,
            &usd_aggregator,
            &clock
        );

        // Get price
        let price = port_oracle.get_price<USDT_TESTS>(&clock);

        assert!(price.price_value() == 10000000000, 111);

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(usd_aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_port_oracle_oracle_info_exists() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let usd_aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);

    let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
    
    // Initialize
    scenario.next_tx(admin);
    {
        port_oracle::test_init(scenario.ctx());
        vault_config::test_init(scenario.ctx());
    };
    
    // Add aggregator to port oracle
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Add switchboard oracle info
        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(usd_aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_port_oracle_calculate_tvl_base_on_quote() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let mut usd_aggregator = setup_test_aggregator(&mut scenario, 2000000000000000000, &clock); // 2 USDC/USD
    let mut eth_aggregator = setup_test_aggregator(&mut scenario, 3000000000000000000000, &clock); // 3000 ETH/USD

    let (eth_treasury_cap, eth_metadata) = eth_tests::create_eth_tests(&mut scenario, 0);
    let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
    
    // Initialize
    scenario.next_tx(admin);
    {
        port_oracle::test_init(scenario.ctx());
        vault_config::test_init(scenario.ctx());
    };
    
    // Add aggregator to port oracle
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        // Add switchboard oracle info
        port_oracle.add_switchboard_oracle_info(
            &global_config,
            &usd_metadata,
            &usd_aggregator,
            60,
            scenario.ctx()
        );

        port_oracle.add_switchboard_oracle_info<ETH_TESTS>(
            &global_config,
            &eth_metadata,
            &eth_aggregator,
            60,
            scenario.ctx()
        );

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

    // get eth price
    scenario.next_tx(admin);
    {
        let mut port_oracle = scenario.take_shared<PortOracle>();
        let global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();

        aggregator_set_current_value(&mut eth_aggregator,  3000000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<ETH_TESTS>(
            &global_config,
            &eth_aggregator,
            &clock
        );

        let eth_type = std::type_name::with_defining_ids<ETH_TESTS>();
        let eth_price = port_oracle.get_price_by_type(eth_type, &clock);
        assert!(eth_price.price_value() == 30000000000000, 898);

        aggregator_set_current_value(&mut usd_aggregator,  2000000000000000000, clock.timestamp_ms());

        // Update price 
        port_oracle.external_update_price_from_switchboard<USDT_TESTS>(
            &global_config,
            &usd_aggregator,
            &clock
        );

        let usd_type = std::type_name::with_defining_ids<USDT_TESTS>();
        let usd_price = port_oracle.get_price_by_type(usd_type, &clock);
        assert!(usd_price.price_value() == 20000000000, 977);

        let mut balances = sui::vec_map::empty<std::type_name::TypeName, u64>();
        balances.insert(usd_type, 150000000); // 150 USDC == 300 USD
        balances.insert(eth_type, 1); // 1 ETH == 3000 USD

        let tvl_in_usdc = port::test_calculate_tvl_base_on_quote(
            &port_oracle, 
            &balances, 
            std::option::some< std::type_name::TypeName>(usd_type), 
            &clock
        );
        assert!(tvl_in_usdc == 1650000000, 1000); // 3000 USD + 300 USD / 2 (usdc price) in usdc decimals

        let tvl_in_eth = port::test_calculate_tvl_base_on_quote(
            &port_oracle, 
            &balances, 
            std::option::some< std::type_name::TypeName>(eth_type), 
            &clock
        );
        assert!(tvl_in_eth == 1, 2000); // 3300 USD  / 3000 USD (eth price) in eth decimals

        test_scenario::return_shared(port_oracle);
        test_scenario::return_shared(global_config);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    transfer::public_transfer(eth_treasury_cap, admin);
    transfer::public_transfer(eth_metadata, admin);
    test_utils::destroy(usd_aggregator);
    test_utils::destroy(eth_aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

public fun setup_test_aggregator(
    scenario: &mut Scenario,
    price: u128, // decimals 18
    clock: &Clock,
): switchboard::aggregator::Aggregator {
    let owner = scenario.ctx().sender();

    let mut aggregator = switchboard::aggregator::new_aggregator(
        switchboard::aggregator::example_queue_id(),
        std::string::utf8(b"test_aggregator"),
        owner,
        std::vector::empty(),
        1,
        1000000000000000,
        100000000000,
        5,
        1000,
        scenario.ctx(),
    );

    // Set the current value
    let result = switchboard::decimal::new(price, false);
    let result_timestamp_ms = clock::timestamp_ms(clock);
    let min_result = result;
    let max_result = result;
    let stdev = switchboard::decimal::new(0, false);
    let range = switchboard::decimal::new(0, false);
    let mean = result;

    switchboard::aggregator::set_current_value(
        &mut aggregator,
        result,
        result_timestamp_ms,
        result_timestamp_ms,
        result_timestamp_ms,
        min_result,
        max_result,
        stdev,
        range,
        mean
    );

    aggregator
}

public fun aggregator_set_current_value(
    aggregator: &mut Aggregator,
    price: u128, // decimals 18
    result_timestamp_ms: u64,
) {
    // 1 * 10^18
    let result = decimal::new(price, false);
    let min_result = result;
    let max_result = result;
    let stdev = decimal::new(0, false);
    let range = decimal::new(0, false);
    let mean = result;

    aggregator.set_current_value(
        result,
        result_timestamp_ms,
        result_timestamp_ms,
        result_timestamp_ms,
        min_result,
        max_result,
        stdev,
        range,
        mean
    );
}
// #[test_only]
// module price_monitor::price_monitor_validation_tests;

// use price_monitor::price_monitor::{Self, PriceMonitor, SuperAdminCap};
// use sui::test_scenario::{Self, Scenario};
// use sui::test_utils;
// use sui::clock::{Self, Clock};

// use switchboard::aggregator::{Self, Aggregator};
// use switchboard::decimal;

// // CLMM dependencies
// use clmm_pool::pool::Pool;
// use clmm_pool::factory::{Self, Pools};
// use clmm_pool::config::{Self, GlobalConfig, AdminCap};

// use price_monitor::usd_tests::{Self, USD_TESTS};
// use price_monitor::ausd_tests::{Self, AUSD_TESTS};

// public struct SAIL has drop {}

// // Test setup functions
// public fun setup_test_environment(scenario: &mut Scenario): (address, Clock) {
//     let admin = @0x1;
//     let clock = clock::create_for_testing(scenario.ctx());
//     (admin, clock)
// }

// public fun setup_price_monitor(scenario: &mut Scenario, admin: address): (PriceMonitor, SuperAdminCap) {
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Get the monitor and admin cap
//     scenario.next_tx(admin);
//     {
//         let monitor = scenario.take_shared<PriceMonitor>();
//         let admin_cap = scenario.take_from_sender<SuperAdminCap>();
//         (monitor, admin_cap)
//     }
// }

// public fun setup_clmm_environment(scenario: &mut Scenario, admin: address): (Pools, GlobalConfig, AdminCap) {
//     // Initialize CLMM factory and config
//     scenario.next_tx(admin);
//     {
//         factory::test_init(scenario.ctx());
//         config::test_init(scenario.ctx());
//     };
    
//     // Get the objects and add fee tier
//     scenario.next_tx(admin);
//     {
//         let pools = scenario.take_shared<Pools>();
//         let mut global_config = scenario.take_shared<GlobalConfig>();
//         let admin_cap = scenario.take_from_sender<AdminCap>();
        
//         // Add fee tier with tick_spacing = 1 and fee_rate = 1000
//         config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());
        
//         (pools, global_config, admin_cap)
//     }
// }

// public fun setup_test_aggregator(
//     scenario: &mut Scenario,
//     price: u128, // decimals 18
//     clock: &Clock,
// ): switchboard::aggregator::Aggregator {
//     let owner = scenario.ctx().sender();

//     let mut aggregator = switchboard::aggregator::new_aggregator(
//         switchboard::aggregator::example_queue_id(),
//         std::string::utf8(b"test_aggregator"),
//         owner,
//         std::vector::empty(),
//         1,
//         1000000000000000,
//         100000000000,
//         5,
//         1000,
//         scenario.ctx(),
//     );

//     // Set the current value
//     let result = switchboard::decimal::new(price, false);
//     let result_timestamp_ms = clock::timestamp_ms(clock);
//     let min_result = result;
//     let max_result = result;
//     let stdev = switchboard::decimal::new(0, false);
//     let range = switchboard::decimal::new(0, false);
//     let mean = result;

//     switchboard::aggregator::set_current_value(
//         &mut aggregator,
//         result,
//         result_timestamp_ms,
//         result_timestamp_ms,
//         result_timestamp_ms,
//         min_result,
//         max_result,
//         stdev,
//         range,
//         mean
//     );

//     aggregator
// }

// public fun aggregator_set_current_value(
//     aggregator: &mut Aggregator,
//     price: u128, // decimals 18
//     result_timestamp_ms: u64,
// ) {

//     // 1 * 10^18
//     let result = decimal::new(price, false);
//     let min_result = result;
//     let max_result = result;
//     let stdev = decimal::new(0, false);
//     let range = decimal::new(0, false);
//     let mean = result;

//     aggregator.set_current_value(
//         result,
//         result_timestamp_ms,
//         result_timestamp_ms,
//         result_timestamp_ms,
//         min_result,
//         max_result,
//         stdev,
//         range,
//         mean
//     );

//     // Return aggregator to the calling function
//     // aggregator
// }

// public fun setup_test_pool<CoinTypeA, CoinTypeB>(
//     scenario: &mut Scenario,
//     sqrt_price: u128,
//     pools: &mut Pools,
//     global_config: &GlobalConfig,
//     clock: &Clock,
// ): Pool<CoinTypeA, CoinTypeB> {
//     let _admin = @0x1;
//     let url = std::string::utf8(b"https://test.pool");
//     let feed_id_a = @0x2;
//     let feed_id_b = @0x3;
//     let auto_calc = true;
//     let tick_spacing = 1;

//     factory::create_pool_<CoinTypeA, CoinTypeB>(
//         pools,
//         global_config,
//         tick_spacing,
//         sqrt_price,
//         url,
//         feed_id_a,
//         feed_id_b,
//         auto_calc,
//         clock,
//         scenario.ctx()
//     )
// }

// // Helper function to calculate expected deviation in basis points
// public fun calculate_expected_deviation_bps(price1: u128, price2: u128): u64 {
//     if (price2 == 0) return 0;
    
//     let deviation = if (price1 > price2) {
//         price1 - price2
//     } else {
//         price2 - price1
//     };
    
//     // Convert to basis points: (deviation * 10000) / price2
//     let deviation_bps = (deviation * 10000) / price2;
//     (deviation_bps as u64)
// }

// // Test 1: Normal price validation - no anomalies
// #[test]
// fun test_validate_price_normal() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price (sqrt_price = 1.0, so price = 1.0)
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 18);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 18);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should be valid since prices are similar
//         assert!(price_monitor::get_is_valid(&result), 0);
//         assert!(!price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 1.1: Normal price validation - no anomalies (AUSD, SAIL first)
// #[test]
// fun test_validate_price_normal_ausd_sail_first() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price (sqrt_price = 1.0, so price = 1.0)
//     let pool = setup_test_pool<SAIL, AUSD_TESTS>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<SAIL, AUSD_TESTS, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should be valid since prices are similar
//         assert!(price_monitor::get_is_valid(&result), 0);
//         assert!(!price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 2: Warning level deviation between oracle and pool prices
// #[test]
// fun test_validate_price_warning_deviation() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);

//     clock::increment_for_testing(&mut clock, 3600000*24*7);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with price that deviates by 30% (warning threshold is 25%)
//     // Oracle price: 1.0, Pool price: 1.3 (30% higher)
//     let pool_sqrt_price = 114017542485785; // sqrt(1.3) * 10^8
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, pool_sqrt_price, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should detect warning level deviation
//         assert!(!price_monitor::get_is_valid(&result), 0);
//         assert!(!price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 3: Critical level deviation between oracle and pool prices
// #[test]
// fun test_validate_price_critical_deviation() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);

//     clock::increment_for_testing(&mut clock, 3600000*24*7);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with price that deviates by 60% (critical threshold is 50%)
//     // Oracle price: 1.0, Pool price: 1.6 (60% higher)
//     let pool_sqrt_price = 126491106406735; // sqrt(1.6) * 10^8
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, pool_sqrt_price, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {

//         monitor.update_anomaly_thresholds(
//             1,
//             1,
//             300000,
//             scenario.ctx()
//         );

//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should detect critical level deviation
//         assert!(!price_monitor::get_is_valid(&result), 0);
//         assert!(price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 4: Emergency level deviation between oracle and pool prices
// #[test]
// fun test_validate_price_emergency_deviation() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);

//     clock::increment_for_testing(&mut clock, 3600000*24*7);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with price that deviates by 80% (emergency threshold is 75%)
//     // Oracle price: 1.0, Pool price: 1.8 (80% higher)
//     let pool_sqrt_price = 134164078649987; // sqrt(1.8) * 10^8
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, pool_sqrt_price, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {

//         monitor.update_anomaly_thresholds(
//             1,
//             1,
//             300000,
//             scenario.ctx()
//         );

//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should detect emergency level deviation
//         assert!(!price_monitor::get_is_valid(&result), 0);
//         assert!(price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 5: Outdated oracle price (should fail with EGetTimeCheckedPriceOutdated)
// #[test, expected_failure(abort_code = ::price_monitor::price_monitor::EGetTimeCheckedPriceOutdated)]
// fun test_validate_price_outdated_oracle() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Advance time by more than 1 minute (oracle price max age)
//     scenario.next_tx(admin);
//     {
//         clock::increment_for_testing(&mut clock, 70000); // 70 seconds
//     };
    
//     // Test price validation - should fail due to outdated oracle price
//     scenario.next_tx(admin);
//     {
//         price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 6: Statistical anomaly detection
// #[test]
// fun test_validate_price_statistical_anomaly() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let mut aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Populate price history with normal prices to establish baseline
//     let mut i = 0;
//     while (i < 15) {
//         scenario.next_tx(admin);
//         {
//             price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//                 &mut monitor,
//                 &aggregator,
//                 &pool,
//                 &clock
//             );
//         };
        
//         // Advance time by 1 minute
//         clock::increment_for_testing(&mut clock, 60000);

//         aggregator_set_current_value(&mut aggregator, 1000000000000000000 + (clock.timestamp_ms() as u128), clock.timestamp_ms());
//         i = i + 1;
//     };
    
//     // Now introduce an extreme price deviation
//     let extreme_aggregator = setup_test_aggregator(&mut scenario, 5000000000000000000, &clock); // 5.0 price

//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&extreme_aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation with extreme price - should detect statistical anomaly
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &extreme_aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should detect statistical anomaly
//         assert!(!price_monitor::get_is_valid(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(extreme_aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 7: Circuit breaker escalation after multiple critical anomalies
// #[test]
// fun test_validate_price_circuit_breaker_escalation() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let mut aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with price that deviates by 60% (critical threshold)
//     let pool_sqrt_price = 126491106406735; // sqrt(1.6) * 10^8
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, pool_sqrt_price, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Trigger multiple critical anomalies to activate circuit breaker
//     let mut i = 0;
//     while (i < 3) {
//         scenario.next_tx(admin);
//         {
//             price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//                 &mut monitor,
//                 &aggregator,
//                 &pool,
//                 &clock
//             );
//         };
        
//         // Advance time by 1 minute
//         clock::increment_for_testing(&mut clock, 60000);

//         aggregator_set_current_value(&mut aggregator, 1000000000000000000, clock.timestamp_ms());

//         i = i + 1;
//     };
    
//     // Check circuit breaker status
//     scenario.next_tx(admin);
//     {
//         let _status = price_monitor::get_circuit_breaker_status(&monitor);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 8: Price history management (size limits)
// #[test]
// fun test_validate_price_history_management() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let mut aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         monitor.update_anomaly_thresholds(
//             1,
//             1,
//             300000,
//             scenario.ctx()
//         );

//             monitor.update_time_config(
//             6000000*2,
//             3600000*2,
//             60000,
//             70,
//             1,
//             scenario.ctx()
//         );

//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 6);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Add many price points to test history size management
//     let mut i = 0;
//     while (i < 80) {
//         scenario.next_tx(admin);
//         {
//             price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//                 &mut monitor,
//                 &aggregator,
//                 &pool,
//                 &clock
//             );
//         };
        
//         // Advance time by 1 minute
//         clock::increment_for_testing(&mut clock, 60000);

//         aggregator_set_current_value(&mut aggregator, 1000000000000000000, clock.timestamp_ms());

//         i = i + 1;
//     };
    
//     // Check price statistics to verify history size management
//     scenario.next_tx(admin);
//     {
//         let _stats = price_monitor::get_price_statistics(&monitor);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 9: Invalid pool (should fail with EInvalidSailPool)
// #[test, expected_failure(abort_code = ::price_monitor::price_monitor::EInvalidSailPool)]
// fun test_validate_price_invalid_pool() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, mut clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator and pool
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, 1 << 64, &mut pools, &global_config, &clock);
    
//     // Don't add the pool to the aggregator - this should cause validation to fail
    
//     // Test price validation - should fail due to invalid pool
//     scenario.next_tx(admin);
//     {
//         price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 10: Check correct work with different decimals of pool
// #[test]
// fun test_validate_price_different_decimals() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price (sqrt_price = 1.0, so price = 1.0)
//     let pool = setup_test_pool<USD_TESTS, SAIL>(&mut scenario, (3162 << 64)/100, &mut pools, &global_config, &clock); // (3162 << 64)/100 == sqrt(1000)
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 15);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 18);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<USD_TESTS, SAIL, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should be valid since prices are similar
//         assert!(price_monitor::get_is_valid(&result), 0);
//         assert!(!price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }

// // Test 10.1: Check correct work with different decimals of pool (AUSD, SAIL first)
// #[test]
// fun test_validate_price_different_decimals_ausd_sail_first() {
//     let mut scenario = test_scenario::begin(@0x1);
//     let (admin, clock) = setup_test_environment(&mut scenario);
    
//     let (mut monitor, admin_cap) = setup_price_monitor(&mut scenario, admin);
//     let (mut pools, global_config, clmm_admin_cap) = setup_clmm_environment(&mut scenario, admin);
    
//     // Setup aggregator with price 1.0 (1 * 10^18)
//     let aggregator = setup_test_aggregator(&mut scenario, 1000000000000000000, &clock);
    
//     // Setup pool with similar price (sqrt_price = 1.0, so price = 1.0)
//     let pool = setup_test_pool<SAIL, AUSD_TESTS>(&mut scenario, (1 << 64)/3162*100, &mut pools, &global_config, &clock);
    
//     // Add aggregator to monitor with this pool
//     scenario.next_tx(admin);
//     {
//         let pool_id = object::id(&pool);
//         let mut pool_ids = vector::empty();
//         vector::push_back(&mut pool_ids, pool_id);
//         let mut token_a_decimals = vector::empty();
//         vector::push_back(&mut token_a_decimals, 9);
//         let mut token_b_decimals = vector::empty();
//         vector::push_back(&mut token_b_decimals, 6);
//         price_monitor::add_aggregator(&mut monitor, object::id(&aggregator), pool_ids, token_a_decimals, token_b_decimals, scenario.ctx());
//     };
    
//     // Test price validation
//     scenario.next_tx(admin);
//     {
//         let result = price_monitor::validate_price<SAIL, AUSD_TESTS, SAIL>(
//             &mut monitor,
//             &aggregator,
//             &pool,
//             &clock
//         );
        
//         // Should be valid since prices are similar
//         assert!(price_monitor::get_is_valid(&result), 0);
//         assert!(!price_monitor::get_escalation_activation(&result), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         test_scenario::return_shared(pools);
//         test_scenario::return_shared(global_config);
//         scenario.return_to_sender(admin_cap);
//         scenario.return_to_sender(clmm_admin_cap);
//     };
    
//     // Destroy objects that don't have drop ability
//     test_utils::destroy(aggregator);
//     test_utils::destroy(pool);
//     clock::destroy_for_testing(clock);
    
//     scenario.end();
// }
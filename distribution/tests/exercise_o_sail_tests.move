#[test_only]
module distribution::exercise_o_sail_tests;

use distribution::setup;
use distribution::minter::{Self, Minter};
use distribution::voter::{Self, Voter};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use ve::reward_distributor::{Self, RewardDistributor};
use distribution::distribution_config::{Self, DistributionConfig};
use distribution::exercise_fee_reward;

use clmm_pool::pool::{Self, Pool};
use clmm_pool::config::{Self, GlobalConfig};

use distribution::usd_tests::{Self, USD_TESTS};

use sui::test_scenario;
use sui::test_utils;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use ve::common; // Import common for time constants

use switchboard::aggregator::{Self, Aggregator};
use price_monitor::price_monitor::{Self, PriceMonitor};

use clmm_pool::tick_math;

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

const DEFAULT_GAUGE_EMISSIONS: u64 = 1_000_000;

public struct SAIL has drop {}

// Define oSAIL type for testing epoch 1
public struct OSAIL1 has drop {}

// Define oSAIL type for testing epoch 2
public struct OSAIL2 has drop {}

// Define a random token type for failure testing
public struct RANDOM_TOKEN has drop {}

// public struct USD_TESTS has drop {}

public struct AUSD has drop {}

// ===================================================================================
// exercise_o_sail_calc Tests
// ===================================================================================

// Helper to run the calculation test logic
// fun run_calc_test(
//     scenario: &mut test_scenario::Scenario,
//     price_dec_18: u128,
//     o_sail_amount: u64,
//     discount_percent: u64,
//     expected_usd_to_pay: u64,
//     clock: &Clock
// ) {
//     let admin = @0xA0;
//     let user = @0xA1;

//     // setup distribution config
//     scenario.next_tx(admin);
//     {
//         setup::setup_clmm_factory_with_fee_tier(scenario, admin, 1, 1000);
//         setup::setup_distribution<SAIL>(scenario, admin, clock);
//         setup::setup_price_monitor_and_aggregator(scenario, admin, clock);
//     };

//     // Pool setup needs a unique TX block
//     // Calculation doesn't need a new TX block if pool is shared
//     scenario.next_tx(user);
//     {
//         let dummy_o_sail = coin::mint_for_testing<OSAIL1>(o_sail_amount, scenario.ctx());
//         let mut distribution_config = scenario.take_shared<DistributionConfig>();
//         let aggregator = scenario.take_from_sender<Aggregator>();
//         let price_q64 = common::get_time_checked_price_q64(&aggregator, 6, 6, clock);
//         let calculated_usd = minter::exercise_o_sail_calc<OSAIL1>(
//             &dummy_o_sail,
//             discount_percent,
//             price_q64,
//         );
//         test_utils::destroy(aggregator);

//         // Allow for minor rounding differences (e.g., off by 1)
//         let diff = if (calculated_usd > expected_usd_to_pay) { 
//             calculated_usd - expected_usd_to_pay 
//         } else { 
//             expected_usd_to_pay - calculated_usd 
//         };
//         assert!(diff <= 1, 1337);

//         coin::burn_for_testing(dummy_o_sail);
//         test_scenario::return_shared(distribution_config);
//     }
// }

// #[test]
// fun test_exercise_o_sail_calc_price_1() {
//     let admin = @0xC1;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18: u128 = setup::one_dec18();
//     let o_sail_amount = 100_000;
//     let discount_percent = 50000000; // 50%
//     // Pay for 50% = 50_000 SAIL. Price = 1 USD/SAIL.
//     // USD needed = 50_000 SAIL * (1 USD / 1 SAIL) = 50_000 USD
//     let expected_usd = 50_000;

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

// #[test]
// fun test_exercise_o_sail_calc_price_4() {
//     let admin = @0xC3;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18: u128 = 4 * setup::one_dec18();
//     let o_sail_amount = 100_000;
//     let discount_percent = 50000000; // 50%
//     // Pay for 50% = 50_000 SAIL. Price = 4 USD/SAIL.
//     // USD needed = 50_000 SAIL / 4 = 12_500 USD
//     let expected_usd = 200_000;

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

// #[test]
// fun test_exercise_o_sail_calc_price_point_25() {
//     let admin = @0xC4;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18: u128 = setup::one_dec18() / 4;
//     let o_sail_amount = 100_000;
//     let discount_percent = 50000000; // 50%
//     // Pay for 50% = 50_000 SAIL. Price = 0.25 USD/SAIL.
//     // USD needed = 50_000 SAIL * (0.25 USD / 1 SAIL) = 12_500 USD
//     let expected_usd = 12_500;

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

// #[test]
// fun test_exercise_o_sail_calc_discount_75() {
//     let admin = @0xC5;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18: u128 = setup::one_dec18();
//     let o_sail_amount = 100_000;
//     let discount_percent = 75000000; // 75%
//     // Pay for 25% = 25_000 SAIL. Price = 1 USD/SAIL.
//     // USD needed = 25_000 SAIL * (1 USD / 1 SAIL) = 25_000 USD
//     let expected_usd = 25_000;

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }


// #[test]
// fun test_exercise_o_sail_calc_max_price() {
//     let admin = @0xD1;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18 = (1<<60) * setup::one_dec18();
//     let o_sail_amount = 8;
//     let discount_percent = 50000000; // 50%
//     // sail_to_pay = 8 * 50% = 4
//     let expected_usd = 4 * (1<<60);

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

// #[test]
// fun test_exercise_o_sail_calc_min_price() {
//     let admin = @0xD3;
//     let mut scenario = test_scenario::begin(admin);
//     let clock = clock::create_for_testing(scenario.ctx());

//     let price_dec_18 = 1000;
//     // Use smaller oSAIL amount
//     let o_sail_amount = setup::one_dec18() as u64;
//     let discount_percent = 50000000; // 50%
//     let expected_usd = 500;

//     run_calc_test(&mut scenario, price_dec_18, o_sail_amount, discount_percent, expected_usd, &clock);

//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

// ================================================
// Integration tests
// ================================================

#[test]
fun test_exercise_o_sail() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL,USD_TESTS, SAIL>(&mut scenario, admin, &clock);

    // Tx 3: Whitelist usd
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };


    // Tx 5: Exercise OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>(); // Needed? minter::exercise doesn't list it
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        // Mint OSAIL1 for the user
        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());

        // Mint USD_TESTS fee for the user
        // decimals delta = 3 so multiply by 1000
        let usd_fee = coin::mint_for_testing<USD_TESTS>(12_500 * 1000, scenario.ctx()); // Amount should cover ~50% of SAIL value at price 1
        let usd_limit = 12_500 * 1000;
        
        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18() / 4, clock.timestamp_ms()); 

        // Exercise o_sail_ba because Pool is <USD_TESTS, SAIL>
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee,
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // --- Assertions --- 
        assert!(sail_received.value() == 100_000, 1); // Should receive full SAIL amount
        // Check USD left - depends on exact price and discount. 
        // For price=1, 50% discount -> should pay 50k USD. If fee was 50k, should have 0 left.
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailInvalidUsd)] // Expect failure due to non-whitelisted usd
fun test_exercise_o_sail_fail_not_whitelisted_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock);

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };


    // Tx 5: Exercise OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>(); // Needed? minter::exercise doesn't list it
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        // Mint OSAIL1 for the user
        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());

        // Mint USD_TESTS fee for the user
        let usd_fee = coin::mint_for_testing<USD_TESTS>(12_500, scenario.ctx()); // Amount should cover ~50% of SAIL value at price 1
        let usd_limit = 12_500;

        setup::aggregator_set_current_value(&mut aggregator,  4 * setup::one_dec18(), clock.timestamp_ms());
        
        // Exercise o_sail_ba because Pool is <USD_TESTS, SAIL>
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee,
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // --- Assertions --- 
        assert!(sail_received.value() == 100_000, 1); // Should receive full SAIL amount
        // Check USD left - depends on exact price and discount. 
        // For price=1, 50% discount -> should pay 50k USD. If fee was 50k, should have 0 left.
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseUsdLimitReached)] // Expect failure due to insufficient USD limit
fun test_exercise_o_sail_fail_usd_limit_not_met() {
    let admin = @0xF1; // Use a different address
    let user = @0xF2;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 

    // Tx 3: Whitelist usd
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 5: Attempt Exercise OSAIL1 with insufficient USD limit
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        let o_sail_amount = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount, scenario.ctx());

        setup::aggregator_set_current_value(&mut aggregator,  4 * setup::one_dec18(), clock.timestamp_ms()); 
        
        // Calculate expected USD needed (price=4, discount=50% -> pay for 50% of SAIL value)
        // SAIL to pay for = 100_000 * 0.5 = 50_000 SAIL
        // USD needed = 50_000 SAIL / Price(4 USD/SAIL) = 12_500 USD
        let expected_usd_needed = 12_500;

        // Provide enough USD in the coin, but set the limit lower
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed - 1; // Set limit below required amount

        // Attempt exercise - should fail here because usd_limit is too low
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee, // Pass the insufficient limit
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui::balance::ENotEnough)] // Expect failure when splitting usd_fee
fun test_exercise_o_sail_fail_insufficient_usd_fee() {
    let admin = @0x101; // Use a different address
    let user = @0x102;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock);
    // Tx 3: Whitelist usd
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 5: Attempt Exercise OSAIL1 with insufficient USD coin balance
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        let o_sail_amount = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount, scenario.ctx());

        setup::aggregator_set_current_value(&mut aggregator,  4 * setup::one_dec18(), clock.timestamp_ms());
        
        // Calculate expected USD needed (price=4, discount=50% -> pay for 50% of SAIL value)
        // SAIL to pay for = 100_000 * 0.5 = 50_000 SAIL
        // USD needed = 50_000 SAIL / Price(4 USD/SAIL) = 12_500 USD
        let expected_usd_needed = 12_500 * 1000; // decimals delta = 3

        // Mint less USD than needed, but set limit high enough
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed - 1, scenario.ctx()); 
        let usd_limit = 1_000_000_000;

        // Attempt exercise - should fail here due to insufficient balance in usd_fee coin
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee, // Pass the coin with insufficient balance
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailExpired)] // Expect failure due to expired oSAIL
fun test_exercise_o_sail_fail_expired() {
    let admin = @0x111; // Use a different address
    let user = @0x112;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed for advancing time

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock);

    // Tx 2: Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Advance time by 5 weeks (more than oSAIL expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 4: Attempt Exercise Expired OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());
        let usd_fee = coin::mint_for_testing<USD_TESTS>(100_000, scenario.ctx()); // Mint enough USD
        let usd_limit = 100_000;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms());

        // Attempt exercise - should fail here because oSAIL1 is expired
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>( 
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee, 
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_exercise_o_sail_before_expiry() {
    let admin = @0x121; // Use a different address
    let user = @0x122;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed for advancing time

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 
    // Tx 2: Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Advance time by 4 weeks (within typical expiry)
    let four_weeks_ms = 4 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, four_weeks_ms);

    // Tx 4: Exercise OSAIL1 (Before Expiry)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount_to_exercise = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount_to_exercise, scenario.ctx());

        // Calculate expected USD needed (Price=1, discount=50% -> pay 50%)
        let expected_usd_needed = o_sail_amount_to_exercise / 2 * 1000; // decimals delta = 3
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms()); 

        // Exercise - should succeed
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee, 
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // Assertions
        assert!(sail_received.value() == o_sail_amount_to_exercise, 1); // Should receive full SAIL amount
        assert!(usd_left.value() == 0, 2); // Should have used all provided USD

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailInvalidUsd)] // Expect final exercise attempt to fail
fun test_exercise_o_sail_whitelist_toggle() {
    let admin = @0x131; // Use a different address
    let user = @0x132;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 
    // Tx 2: Whitelist USD_TESTS token (First time)
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 4: First Exercise (USD_TESTS Whitelisted - Should Succeed)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount_to_exercise = 50_000; // Exercise smaller amount
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount_to_exercise, scenario.ctx());

        let expected_usd_needed = o_sail_amount_to_exercise / 2 * 1000; // Price=1, Discount=50%, decimals delta = 3
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());

        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter, 
            &distribution_config,
            &mut voter,
            o_sail_to_exercise, 
            usd_fee, 
            &usd_metadata,
            usd_limit, 
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        assert!(sail_received.value() == o_sail_amount_to_exercise, 1);
        assert!(usd_left.value() == 0, 2);

        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user); // Give SAIL to user
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    // Tx 5: De-Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, false, &clock); // Set listed to false
    };

    // Tx 6: Second Exercise Attempt (USD_TESTS Not Whitelisted - Should Fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(50_000, scenario.ctx());
        let expected_usd_needed = 50000 / 2;
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms());

        // This call is expected to fail with EExerciseOSailInvalidUsd
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>( 
            &mut minter, 
            &distribution_config,
            &mut voter, 
            o_sail_to_exercise, 
            usd_fee, 
            &usd_metadata,
            usd_limit, 
            &mut price_monitor,
            &sail_stablecoin_pool, 
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user); // Give SAIL to user
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); 
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);

    test_utils::destroy(aggregator);

    // Final cleanup transaction can be added if necessary 
    // but not strictly needed as the test expects abort in Tx 7.

    clock::destroy_for_testing(clock);
    scenario.end();
}

fun check_receive_rate(
    scenario: &mut test_scenario::Scenario,
    user: address,
    percent_to_receive: u64,
    clock: &Clock,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>();
    let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

    let initial_o_sail_amount = 100_000;
    let o_sail_to_exercise = o_sail1_coin.split(initial_o_sail_amount, scenario.ctx());
  
    let expected_sail_amount = initial_o_sail_amount * percent_to_receive / common::persent_denominator(); // 100000 * 7500 / 10000 = 75000

    let sail_received = minter::test_exercise_o_sail_free_internal<SAIL, OSAIL1>(
        &mut minter,
        o_sail_to_exercise,
        percent_to_receive,
        clock,
        scenario.ctx()
    );

    // Assertions
    assert!(sail_received.value() == expected_sail_amount, 1); // Should receive 75% SAIL

    // Cleanup
    transfer::public_transfer(sail_received, user);
    test_scenario::return_shared(minter);
    scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
}

#[test]
fun test_exercise_o_sail_free_internal() {
    let admin = @0x141; // Use a different address
    let user = @0x142;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD) - No pool needed for free exercise
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Exercise OSAIL1 with 75% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 75000000, &clock);
    };

    // Tx 4: Exercise OSAIL1 with 100% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 100000000, &clock);
    };

    // Tx 5: Exercise OSAIL1 with 0% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 0, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailFreeTooBigPercent)]
fun test_exercise_o_sail_free_fail_over_100_percent() {
    let admin = @0x151; // Use a different address
    let user = @0x152;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Attempt Exercise OSAIL1 with > 100% receive rate
    scenario.next_tx(user);
    { // This block is expected to abort
        check_receive_rate(&mut scenario, user, common::persent_denominator() + 1, &clock);
    };

    clock::destroy_for_testing(clock); 
    scenario.end(); 
}

fun create_lock(
    scenario: &mut test_scenario::Scenario,
    o_sail_to_lock: u64,
    lock_duration_days: u64,
    permanent_lock: bool,
    clock: &Clock,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>();
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

    assert!(o_sail_coin.value() >= o_sail_to_lock, 0); // Ensure user has enough oSAIL
    let o_sail_for_locking = o_sail_coin.split(o_sail_to_lock, scenario.ctx());

    // Call the function to create the lock
    minter::create_lock_from_o_sail<SAIL, OSAIL1>(
        &mut minter,
        &mut ve,
        o_sail_for_locking, // This coin will be consumed
        lock_duration_days,
        permanent_lock,
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(minter);
    test_scenario::return_shared(ve);
    // Return remaining oSAIL coin
    scenario.return_to_sender(o_sail_coin);
}

fun check_single_non_permanent_lock(
    scenario: &test_scenario::Scenario,
    o_sail_to_lock: u64,
    lock_duration_days: u64,
) {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let user_lock = scenario.take_from_sender<Lock>(); // Take the newly created Lock

        // Calculate expected SAIL based on duration (assuming 50% discount, 4yr max lock)
        // percent = 5000 + (5000 * 182*day_ms / (1460*day_ms)) = 5000 + 623 = 5623
        // expected_sail = 100000 * 5623 / 10000 = 56230
        let max_lock_time_sec = 4 * 52 * 7 * 24 * 60 * 60;
        let lock_duration_sec = lock_duration_days * 24 * 60 * 60;
        let base_discount_pcnt = 50000000; // 50%
        let max_extra_pcnt = common::persent_denominator() - base_discount_pcnt;
        let percent_to_receive = base_discount_pcnt + 
            (max_extra_pcnt * lock_duration_sec / max_lock_time_sec);
        let expected_sail_amount = o_sail_to_lock * percent_to_receive / common::persent_denominator();

        let (locked_balance, lock_exists) = voting_escrow::locked(&ve, object::id(&user_lock));
        // Assertions

        assert!(locked_balance.amount() == expected_sail_amount, 1); // Check locked SAIL amount
        assert!(lock_exists, 2);
        assert!(!locked_balance.is_permanent(), 3);
        assert!(voting_escrow::total_locked(&ve) == expected_sail_amount, 4); // Check VE total locked

        // Cleanup
        test_scenario::return_shared(ve);
        scenario.return_to_sender(user_lock); // Return lock to user
}

#[test]
fun test_create_lock_from_o_sail() {
    let admin = @0x161; // Use a different address
    let user = @0x162;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create Lock from OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 182; // ~6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_2y() {
    let admin = @0x171; // Use a different address
    let user = @0x172;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create Lock from OSAIL1 for 9 months
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 2 * 52 * 7; // 2 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_4y() {
    let admin = @0x181; // Use a different address
    let user = @0x182;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create Lock from OSAIL1 for 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7; // 4 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_less_than_6_months() {
    let admin = @0x191; // Use a different address
    let user = @0x192;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Attempt to Create Lock from OSAIL1 for less than 6 months
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 25 * 7; // 25 weeks < 26 weeks (6 months)
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_more_than_4y() {
    let admin = @0x1A1; // Use a different address
    let user = @0x1A2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Tx 3: Attempt to Create Lock from OSAIL1 for more than 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7 + 1; // 4 years + 1 day
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

// Helper function to check the state of a single permanent lock
fun check_single_permanent_lock(
    scenario: &test_scenario::Scenario,
    o_sail_to_lock: u64,
) {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let user_lock = scenario.take_from_sender<Lock>(); // Take the newly created Lock

        // Calculate expected SAIL (permanent lock gets 100%)
        let expected_sail_amount = o_sail_to_lock; 

        let (locked_balance, lock_exists) = voting_escrow::locked(&ve, object::id(&user_lock));
        
        // Assertions
        assert!(locked_balance.amount() == expected_sail_amount, 1); // Check locked SAIL amount (should be 100%)
        assert!(lock_exists, 2);
        assert!(locked_balance.is_permanent(), 3); // Check that the lock IS permanent
        assert!(voting_escrow::total_locked(&ve) == expected_sail_amount, 4); // Check VE total locked

        // Cleanup
        test_scenario::return_shared(ve);
        scenario.return_to_sender(user_lock); // Return lock to user
}

#[test]
fun test_create_lock_from_o_sail_permanent() {
    let admin = @0x181; // Use a different address
    let user = @0x182;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Tx 3: Create permanent Lock from OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 100; // doesn't matter for permanent lock
    let permanent_lock = true;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_permanent_lock(&scenario, o_sail_to_lock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_after_4_epochs() {
    let admin = @0x1B1; // Use a different address
    let user = @0x1B2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Advance time by 4 weeks (4 epochs)
    let four_weeks_ms = 4 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, four_weeks_ms);

    // Tx 3: Create Lock from OSAIL1 after 4 weeks
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_expired() {
    let admin = @0x1C1; // Use a different address
    let user = @0x1C2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Attempt to Create Lock from expired OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // Attempt 6 month lock
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort because the oSAIL is expired
        // and the duration is not the allowed expired duration (4 years) or permanent
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_expired_o_sail_4y() {
    let admin = @0x1D1; // Use a different address
    let user = @0x1D2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Create Lock from expired OSAIL1 for 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7; // 4 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call should succeed because 4 years is a valid duration for expired oSAIL
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        // Use the non-permanent check, as the lock itself isn't permanent
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_expired_o_sail_permanent() {
    let admin = @0x1E1; // Use a different address
    let user = @0x1E2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };
    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Create Permanent Lock from expired OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // Duration doesn't matter for permanent
    let permanent_lock = true;
    scenario.next_tx(user);
    {
        // This call should succeed because permanent lock is allowed for expired oSAIL
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        // Use the permanent check helper
        check_single_permanent_lock(&scenario, o_sail_to_lock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidToken)] // Expect fail because RANDOM_TOKEN cap is not in Minter
fun test_create_lock_from_invalid_token_fail() {
    let admin = @0x1F1; // Use a different address
    let user = @0x1F2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD) for SAIL and OSAIL1
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1) - Minter now knows about OSAIL1
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1, &mut clock);
        coin::burn_for_testing(o_sail_coin);
    };

    // Tx 3: Mint RANDOM_TOKEN for the user
    scenario.next_tx(admin); // Use admin to mint test token
    {
        let random_coin = coin::mint_for_testing<RANDOM_TOKEN>(100_000, scenario.ctx());
        transfer::public_transfer(random_coin, user);
    };

    // Tx 4: Attempt to Create Lock using RANDOM_TOKEN instead of OSAIL1
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let random_coin = scenario.take_from_sender<Coin<RANDOM_TOKEN>>(); // Take the random token

        // This call is expected to abort because RANDOM_TOKEN is not the expected OSailCoinType
        // Specifically, the minter::burn_o_sail inside will fail trying to borrow a non-existent cap
        minter::create_lock_from_o_sail<SAIL, RANDOM_TOKEN>( 
            &mut minter,
            &mut ve,
            random_coin, // Pass the wrong coin type!
            lock_duration_days,
            permanent_lock,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_exercise_and_lock_after_epoch_update() {
    let admin = @0x201; // Use a different address
    let user = @0x202;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 

    // Tx 2: Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 4: Activate Minter for Epoch 1
    let initial_o_sail_for_user = 200_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, initial_o_sail_for_user, &mut clock);
        transfer::public_transfer(o_sail_coin, user); 
    };

    // Tx 5: check current epoch token
    scenario.next_tx(user);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let current_epoch_token = minter.borrow_current_epoch_o_sail();
        assert!(current_epoch_token == std::type_name::get<OSAIL1>(), 1);
        test_scenario::return_shared(minter);
    };

    // Advance time by 1 week and 1 second to ensure next epoch starts
    let one_week_ms = 7 * 24 * 60 * 60 * 1000 + 1000;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // Tx 6: Update Minter Period with OSAIL2
    scenario.next_tx(admin);
    {
        let o_sail2_initial_supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &mut clock);
        coin::burn_for_testing(o_sail2_initial_supply);
    };

    // Tx 7: check current epoch token
    scenario.next_tx(user);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let current_epoch_token = minter.borrow_current_epoch_o_sail();
        assert!(current_epoch_token == std::type_name::get<OSAIL2>(), 1);
        test_scenario::return_shared(minter);
    };

    // Tx 7: Exercise OSAIL1 (from previous epoch)
    let o_sail1_to_exercise = 100_000;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(o_sail1_to_exercise, scenario.ctx());

        // Calculate expected USD needed (Price=1, discount=50% -> pay 50%)
        let expected_usd_needed = o_sail1_to_exercise / 2 * 1000; // decimals delta = 3
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms()); 

        // Exercise should succeed even though Minter is in Epoch 2
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>( 
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise,
            usd_fee, 
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool, 
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // Assertions
        assert!(sail_received.value() == o_sail1_to_exercise, 1); 
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    // Tx 8: Lock remaining OSAIL1 (from previous epoch)
    let o_sail1_to_lock = initial_o_sail_for_user - o_sail1_to_exercise;
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // Lock should succeed
        create_lock(&mut scenario, o_sail1_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 9: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user);
    {
        check_single_non_permanent_lock(&scenario, o_sail1_to_lock, lock_duration_days);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_exercise_fee_distribution() {
    let admin = @0x211;
    let user1 = @0x212;
    let user2 = @0x213;
    let user3 = @0x214;
    let team_wallet = @0x215;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock 
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution & Set Team Wallet
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock);

    // Tx 2:Set admin as the team wallet
    scenario.next_tx(admin); // New Tx block needed for admin action
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        minter::set_team_wallet(&mut minter, &minter_admin_cap, team_wallet);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(minter_admin_cap);
    };

    // Tx 4: Whitelist USD1 token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 5: activate minter for Epoch 1 (OSAIL1)
    let o_sail_total_supply = 1_000_000; // Define total supply
    scenario.next_tx(admin);
    {
        // Activate minter and mint oSAIL for user3
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, o_sail_total_supply, &mut clock);
        transfer::public_transfer(o_sail_coin, user3);
    };

    let epoch_start = common::current_period(&clock);

    // Tx 6: Create Gauge
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            DEFAULT_GAUGE_EMISSIONS,
            &clock
        );
    };

    let lock1_amount = 10_000;
    let lock2_amount = 20_000;
    let lock_duration_days = 52 * 7; // 1 year

    // create lock 1
    scenario.next_tx(user1);
    {
        let sail_coin1 = coin::mint_for_testing<SAIL>(lock1_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve, 
            sail_coin1, 
            lock_duration_days, 
            false, // non-permanent
            &clock, 
            scenario.ctx()
        );
        test_scenario::return_shared(ve);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // use lock 1 to vote for pool 1
    scenario.next_tx(user1);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock1 = scenario.take_from_sender<Lock>();
        let mut voter = scenario.take_shared<Voter>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        voter.vote<SAIL>(
            &mut ve,
            &dist_config,
            &lock1,
            vector[object::id(&pool)],
            vector[100],
            vector[1_000_000], // 1$ of volume in decimals 6
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock1);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(ve);
    };

    // create lock 2
    scenario.next_tx(user2);
    {
        let sail_coin2 = coin::mint_for_testing<SAIL>(lock2_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve, 
            sail_coin2, 
            lock_duration_days, 
            false, // non-permanent
            &clock, 
            scenario.ctx()
        );
        
        test_scenario::return_shared(ve);
    };

    // advance by time to finality
    clock::increment_for_testing(&mut clock, 500 * 1000);

    // use lock 2 to vote for pool 1
    scenario.next_tx(user2);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock2 = scenario.take_from_sender<Lock>();
        let mut voter = scenario.take_shared<Voter>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        voter.vote<SAIL>(
            &mut ve,
            &dist_config,
            &lock2,
            vector[object::id(&pool)],
            vector[100],
            vector[1_000_000], // 1$ of volume in decimals 6
            &clock,
            scenario.ctx()
        );


        scenario.return_to_sender(lock2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(ve);   
    };
    
    // --- User3 Exercises oSAIL ---
    let o_sail_to_exercise_amount = 100_000;
    // Calculate expected USD needed and team fee (assuming default 5% protocol fee)
    let expected_usd_needed = o_sail_to_exercise_amount / 2 * 1000; // Price=1, discount=50%, decimals delta = 3
    let protocol_fee_rate = 500; // Default rate = 5%
    assert!(protocol_fee_rate * 100 / minter::rate_denom() == 5, 1); // check decimals are correct
    let expected_team_fee = expected_usd_needed * protocol_fee_rate / minter::rate_denom();
    let expected_distributed_fee = expected_usd_needed - expected_team_fee;

    // Calculate expected shares for user1 and user2
    let total_voting_power = lock1_amount + lock2_amount;
    let user1_expected_fee_share = integer_mate::full_math_u64::mul_div_floor(
        expected_distributed_fee, 
        lock1_amount, 
        total_voting_power
    );
    
    let user2_expected_fee_share = integer_mate::full_math_u64::mul_div_floor(
        expected_distributed_fee, 
        lock2_amount, 
        total_voting_power
    );

    // Tx: User3 Exercises OSAIL1 using the specific fee coin
    scenario.next_tx(user3);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx());

        // Check the received coin value is correct (sanity check)
        assert!(usd_fee.value() == expected_usd_needed, 0);

        let o_sail_to_exercise = o_sail1_coin.split(o_sail_to_exercise_amount, scenario.ctx());
        let usd_limit = expected_usd_needed; // Limit is exactly the amount needed
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms()); 

        // Exercise o_sail
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise, 
            usd_fee, // Use the specific coin received from admin
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool, 
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // --- Assertions --- 
        assert!(sail_received.value() == o_sail_to_exercise_amount, 1); 
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user3);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    // Tx: Distribute team fee
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        minter::distribute_team<SAIL, USD_TESTS>(&mut minter, scenario.ctx());
        test_scenario::return_shared(minter);
    };

    // Tx: Admin (Team Wallet) verifies received fee
    scenario.next_tx(team_wallet);
    {
        let team_fee_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        assert!(team_fee_coin.value() == expected_team_fee, 3); // Verify team received the correct fee

        // Cleanup team fee coin (optional, could transfer elsewhere)
        coin::burn_for_testing(team_fee_coin); 
    };

    // advances time cos notified rewards are distributed in the next epoch
    clock::increment_for_testing(&mut clock, 7 * 24 * 60 * 60 * 1000);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        minter::finalize_exercise_fee_weights<SAIL>(
            &mut minter, 
            &mut voter, 
            &distribute_governor_cap, 
            epoch_start,
            &clock, 
            scenario.ctx()
        );
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(distribute_governor_cap);
    };

    // --- Verify Fee Distribution to Voters ---

    // Tx: User1 claims and verifies their share
    scenario.next_tx(user1);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock1 = scenario.take_from_sender<Lock>();
        let earned_fee = voter.earned_exercise_fee<USD_TESTS>(object::id(&lock1), &clock);

        // Claim the reward - this transfers the coin to user1
        voter::claim_exercise_fee_reward<SAIL, USD_TESTS>(&mut voter, &mut ve, &lock1, &clock, scenario.ctx());

        assert!(earned_fee == user1_expected_fee_share, 5); // Verify earned fee
        // Return objects
        scenario.return_to_sender(lock1);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
    };

    // Validate user1 earned fee
    scenario.next_tx(user1);
    {
         // Take the received coin and verify amount
        let received_fee_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        assert!(received_fee_coin.value() == user1_expected_fee_share, 4); // Verify user1 share
        coin::burn_for_testing(received_fee_coin); // Cleanup claimed fee
    };

    // Tx: User2 claims and verifies their share
    scenario.next_tx(user2);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock2 = scenario.take_from_sender<Lock>();
        let earned_fee = voter.earned_exercise_fee<USD_TESTS>(object::id(&lock2), &clock);

        // Claim the reward - this transfers the coin to user2
        voter::claim_exercise_fee_reward<SAIL, USD_TESTS>(&mut voter, &mut ve, &lock2, &clock, scenario.ctx());

        assert!(earned_fee == user2_expected_fee_share, 6); // Verify earned fee
        // Return objects
        scenario.return_to_sender(lock2);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
    };

    // Validate user2 earned fee
    scenario.next_tx(user2);
    {
       // Take the received coin and verify amount
        let received_fee_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        assert!(received_fee_coin.value() == user2_expected_fee_share, 5); // Verify user2 share
        coin::burn_for_testing(received_fee_coin); // Cleanup claimed fee
    };

    clock::destroy_for_testing(clock);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    scenario.end();
}

#[test]
fun test_exercise_o_sail_high_price() {
    let admin = @0x241;
    let user = @0x242;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 9);

    // Create Clock 
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 100, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 

    // Tx 2: Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    let o_sail_supply = 8; 
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, o_sail_supply, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 4: User exercises OSAIL1 with high price
    let o_sail_to_exercise_amount = 8;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(o_sail_to_exercise_amount, scenario.ctx());

        let high_price = (1<<50) * setup::one_dec18();
        let expected_usd_needed = (4 * (1<<50)) * 1000; // decimals delta = 3
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  high_price, clock.timestamp_ms()); 

        // Exercise o_sail
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>( 
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise, 
            usd_fee, 
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // --- Assertions --- 
        assert!(sail_received.value() == o_sail_to_exercise_amount, 1); 

        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    scenario.end();
}

#[test]
fun test_exercise_o_sail_small_price() {
    let admin = @0x241;
    let user = @0x242;
    let mut scenario = test_scenario::begin(admin);

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 7);

    // Create Clock 
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 100, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock); 

    // Tx 2: Whitelist USD_TESTS token
    scenario.next_tx(admin);
    {
        setup::whitelist_usd<SAIL, USD_TESTS>(&mut scenario, true, &clock);
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    let o_sail_supply = setup::one_dec18() as u64; 
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, o_sail_supply, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 4: User exercises OSAIL1 with low price
    let o_sail_to_exercise_amount = setup::one_dec18() as u64;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(o_sail_to_exercise_amount, scenario.ctx());

        let low_price = 1000;
        let expected_usd_needed = 500 * 10; // decimals delta = 1
        let usd_fee = coin::mint_for_testing<USD_TESTS>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  low_price, clock.timestamp_ms());

        // Exercise o_sail
        let (usd_left, sail_received) = minter::exercise_o_sail<USD_TESTS, SAIL, SAIL, USD_TESTS, OSAIL1>(
            &mut minter,
            &distribution_config,
            &mut voter,
            o_sail_to_exercise, 
            usd_fee, 
            &usd_metadata,
            usd_limit,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);

        // --- Assertions --- 
        assert!(sail_received.value() == o_sail_to_exercise_amount, 1); // Should receive full SAIL amount
        assert!(usd_left.value() == 0, 2); // Ideally 0, check calculation precision in exercise_o_sail_calc

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

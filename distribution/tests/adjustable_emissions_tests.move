#[test_only]
module distribution::adjustable_emissions_tests;

use sui::test_scenario::{Self};
use sui::clock::{Self};
use sui::coin::{Self, Coin};
use sui::test_utils;
use distribution::setup;
use clmm_pool::tick_math;
use price_monitor::price_monitor::{Self, PriceMonitor};
use distribution::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_GAUGE_EMISSIONS: u64 = 1_000_000;

// Dummy types
public struct SAIL has drop, store {}
public struct OSAIL1 has drop {}

#[test]
fun test_sync_o_sail_price_mid_epoch() {
    let admin = @0xE1;
    let user = @0xE2;
    let lp = @0xE3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / 2, clock.timestamp_ms());

        setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            &mut aggregator,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        let first_half_reward = DEFAULT_GAUGE_EMISSIONS / 2;
        let second_half_reward = DEFAULT_GAUGE_EMISSIONS; // price is 1/2, so reward is 2x
        let expected_reward = first_half_reward + second_half_reward;
        assert!(expected_reward - reward.value() <= 5, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_late_distribution_and_price_sync() {
    let admin = @0xE4;
    let user = @0xE5;
    let lp = @0xE6;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // Wait for half a week before distributing
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // Wait for another quarter of a week
    clock.increment_for_testing(WEEK / 4);

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / 2, clock.timestamp_ms());
        setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            &mut aggregator,
            &clock
        );
    };

    // Wait for the rest of the epoch
    clock.increment_for_testing(WEEK / 4);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        // Distribution is for half a week.
        // First quarter week: half of the emissions at price 1 = 0.5 * emissions
        // Second quarter week: half of the emissions at price 0.5 = 1 * emissions
        let expected_reward = DEFAULT_GAUGE_EMISSIONS / 2 + DEFAULT_GAUGE_EMISSIONS;
        assert!(expected_reward - reward.value() <= 5, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_increase_emissions_mid_epoch() {
    let admin = @0xE7;
    let user = @0xE8;
    let lp = @0xE9;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let increase_emissions_by = 500_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // Wait for half a week
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            increase_emissions_by,
            &mut aggregator,
            &clock
        );
    };

    // Wait for the rest of the epoch
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        let expected_reward = DEFAULT_GAUGE_EMISSIONS + increase_emissions_by;
        assert!(expected_reward - reward.value() <= 5, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_increase_emissions_then_sync_price_mid_epoch() {
    let admin = @0xEA;
    let user = @0xEB;
    let lp = @0xEC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let increase_emissions_by = 500_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // Wait for half a week
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        // Price is still one_dec18 for the increase
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            increase_emissions_by,
            &mut aggregator,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 4);

    scenario.next_tx(admin);
    {
        // Now sync to new price
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / 10, clock.timestamp_ms());
        setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &mut scenario,
            &mut aggregator,
            &clock
        );
    };

    // Wait for the rest of the epoch
    clock.increment_for_testing(WEEK / 4);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        let first_half_reward = DEFAULT_GAUGE_EMISSIONS / 2;
        let third_quater_reward = DEFAULT_GAUGE_EMISSIONS / 4 + increase_emissions_by / 2;
        let last_quater_reward = (DEFAULT_GAUGE_EMISSIONS / 4 + increase_emissions_by / 2) * 10;
        let expected_reward = first_half_reward + third_quater_reward + last_quater_reward;
        assert!(expected_reward - reward.value() <= 30, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_frequent_price_syncs() {
    let admin = @0xED;
    let user = @0xEE;
    let lp = @0xEF;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        let mut monitor = scenario.take_shared<PriceMonitor>();
        price_monitor::update_escalation_toggles(
            &mut monitor,
            false, // enable_critical_escalation
            false, // enable_emergency_escalation
            scenario.ctx()
        );
        test_scenario::return_shared(monitor);
    };

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    let time_interval = WEEK / 100;
    let mut i = 0;
    while (i < 99) {
        clock.increment_for_testing(time_interval);

        scenario.next_tx(admin);
        {
            setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / ((i + 2) as u128), clock.timestamp_ms());
            setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
                &mut scenario,
                &mut aggregator,
                &clock
            );
        };
        i = i + 1;
    };

    clock.increment_for_testing(time_interval);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        let expected_reward = DEFAULT_GAUGE_EMISSIONS * 5050 / 100;
        assert!(expected_reward - reward.value() <= 200, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_frequent_price_syncs_stable_price() {
    let admin = @0xF0;
    let user = @0xF1;
    let lp = @0xF2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        let mut monitor = scenario.take_shared<PriceMonitor>();
        price_monitor::update_escalation_toggles(
            &mut monitor,
            false, // enable_critical_escalation
            false, // enable_emergency_escalation
            scenario.ctx()
        );
        test_scenario::return_shared(monitor);
    };

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    let time_interval = WEEK / 100;
    let mut i = 0;
    while (i < 99) {
        clock.increment_for_testing(time_interval);

        scenario.next_tx(admin);
        {
            setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
            setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
                &mut scenario,
                &mut aggregator,
                &clock
            );
        };
        i = i + 1;
    };

    clock.increment_for_testing(time_interval);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        
        let expected_reward = DEFAULT_GAUGE_EMISSIONS;
        // Allow some tolerance for rounding errors
        assert!(expected_reward - reward.value() <= 30, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_frequent_syncs_with_swaps() {
    let admin = @0xF3;
    let user_for_lock = @0xF4;
    let lp = @0xF5;
    let swapper = @0xF6;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user_for_lock,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        let mut monitor = scenario.take_shared<PriceMonitor>();
        price_monitor::update_escalation_toggles(
            &mut monitor,
            false, // enable_critical_escalation
            false, // enable_emergency_escalation
            scenario.ctx()
        );
        test_scenario::return_shared(monitor);
    };

    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };
    
    // Create another full range position to provide liquidity for swaps
    scenario.next_tx(admin);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            admin,
            position_tick_lower,
            position_tick_upper,
            position_liquidity * 100, // much larger liquidity
            &clock
        );
    };


    let time_interval = WEEK / 10;
    let mut i = 0;
    while (i < 9) {
        clock.increment_for_testing(time_interval);

        // Swapper performs a swap
        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<SAIL>(1000, scenario.ctx());
            let coin_out = coin::zero<USD_TESTS>(scenario.ctx());

            let (received_coin_out, remaining_coin_in) = setup::swap<USD_TESTS, SAIL>(
                &mut scenario,
                coin_out, // coin_a: USD_TESTS
                coin_in, // coin_b: SAIL
                false,  // a2b = false (SAIL -> USD_TESTS)
                true,  // by_amount_in = true
                1000, // amount
                1, // min amount out
                tick_math::max_sqrt_price(), // for b2a
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };
        
        scenario.next_tx(admin);
        {
            setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / (i + 2), clock.timestamp_ms());
            setup::sync_o_sail_distribution_price_for_sail_pool<USD_TESTS, SAIL, SAIL>(
                &mut scenario,
                &mut aggregator,
                &clock
            );
        };
        i = i + 1;
    };

    clock.increment_for_testing(time_interval);

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        let expected_reward = DEFAULT_GAUGE_EMISSIONS * 55/10;
        // Allow some tolerance for rounding errors
        assert!(expected_reward - reward.value() <= 100, 1);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
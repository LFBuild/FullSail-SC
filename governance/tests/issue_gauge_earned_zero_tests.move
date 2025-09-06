#[test_only]
module governance::issue_gauge_earned_zero_tests;

use governance::minter::{Self, Minter};
use governance::gauge::{Self, Gauge};
use governance::setup;
use sui::test_scenario::{Self, Scenario};
use governance::usd_tests::{Self, USD_TESTS};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use clmm_pool::tick_math;
use clmm_pool::pool::{Self, Pool};
use sui::test_utils;

public struct SAIL has drop, store {}

public struct OSAIL1 has drop {}

const DEFAULT_GAUGE_EMISSIONS: u64 = 1_000_000;

/// positionId 0x176714b99e340a2e40175906038e350dd49caeeba01a891e3c00ef39231da183
/// poolId 0x17bac48cb12d565e5f5fdf37da71705de2bf84045fac5630c6d00138387bf46a
/// gaugeId 0x05e4d855faf3779d357c79878a5819efb56ffe05d189e2b6314eda5a2bc13172
/// 
/// position liquidity 19017719180256

fun gauge_earned_simulation(mut claimed_growth_inside: u128, new_growth_inside: u128, position_liquidity: u128): (u64, u128) {
    // this check for negative growth inside caused us troubles
    // if (integer_mate::math_u128::is_neg(claimed_growth_inside)) {
    //     claimed_growth_inside = 0;
    // };

    let growth_inside_diff = integer_mate::math_u128::wrapping_sub(new_growth_inside, claimed_growth_inside);

    if (integer_mate::math_u128::is_neg(growth_inside_diff)) {
        return (0, new_growth_inside)
    };

    let amount_earned = integer_mate::full_math_u128::mul_div_floor(
        growth_inside_diff,
        position_liquidity,
        1 << 64
    ) as u64;

    (amount_earned, new_growth_inside)
}

#[test]
fun test_issue_gauge_earned_zero_mock() {
    let o_sail_per_day = 28697 * 1_000_000;
    let alkimi_per_day = 11428 * 1_000_000_000;
    // the same position but getters for growth inside called at a different time
    let claimed_growth_inside: u128 = 340282366920938463463374344811684171570;
    let new_growth_inside: u128 = 340282366920938463463374346175968515355;
    let position_liquidity: u128 = 19017719180256;
    let earned_alkimi = 550000000;
    let expected_earned_osail = earned_alkimi * o_sail_per_day / alkimi_per_day;

    let (earned, position_new_growth_inside) = gauge_earned_simulation(claimed_growth_inside, new_growth_inside, position_liquidity);

    assert!((earned - expected_earned_osail) < expected_earned_osail / 50, 1);
}

#[test]
fun test_create_new_position_in_range_with_upper_tick_matching_lower_tick_of_existing_position() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is negative
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_2); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp_2); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_earned - reward.value() <= 1, 5);
        coin::burn_for_testing(reward);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_growth_inside_becomes_positive_after_some_time() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is negative
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 48 hours more to gain growth that is more than zero

    clock.increment_for_testing(48 * 60 * 60 * 1000);

    let expected_earned2 = DEFAULT_GAUGE_EMISSIONS * 3 / 7 + 1;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned2 - earned_minter <= 1, 1);
        // not negative anymore cos we earned this profit.
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned2 - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_2); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp_2); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_earned2 - reward.value() <= 1, 6);
        coin::burn_for_testing(reward);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_position_with_upper_tick_matching_lower_tick_of_existing_position_earned_preserves_after_price_is_shifted_up() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is negative
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // swapper moves price up
    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(amount, scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, amount, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() < 10, 1);
        test_scenario::return_shared(pool);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait more time, the growth is not accumulating cos position inactive
    clock.increment_for_testing(1 * 24 * 60 * 60 * 1000);

        scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_2); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp_2); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_earned - reward.value() <= 1, 5);
        coin::burn_for_testing(reward);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_position_with_upper_tick_matching_lower_tick_of_existing_position_earned_preserves_after_price_is_shifted_down() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is negative
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // swapper moves price up
    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 20, 1);
        test_scenario::return_shared(pool);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait more time, the growth is not accumulating cos position inactive
    clock.increment_for_testing(1 * 24 * 60 * 60 * 1000);

        scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_2); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp_2); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_earned - reward.value() <= 1, 5);
        coin::burn_for_testing(reward);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_position_with_lower_tick_matching_upper_tick_growth_positive() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::zero<USD_TESTS>( scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(amount, scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, amount, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::from(10).as_u32();
        let upper_tick_p2 = integer_mate::i32::from(20).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is positive
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 4);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_2); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp_2); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_earned - reward.value() <= 1, 5);
        coin::burn_for_testing(reward);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_new_position_in_range_with_upper_tick_matching_lower_tick_pool_before_crossing() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    let expected_earned_1 = DEFAULT_GAUGE_EMISSIONS * 3 / 7;

    // swapper trades a little
    scenario.next_tx(swapper); {
        let amount = 10000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is positive
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        // assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(growth_inside_new == growth_inside, 5);
        
        let tick_index = integer_mate::i32::neg_from(10);
        let tick = pool.tick_manager().borrow_tick(tick_index);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // swapper crosses the tick
    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);

        test_scenario::return_shared(pool);
    };

    // check earned is zero, fullsail distribution growth inside is positive
    scenario.next_tx(lp_2); {
               let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check growth again
    clock.increment_for_testing(24 * 60 * 60 * 1000);

    let expected_earned = DEFAULT_GAUGE_EMISSIONS / 7;
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(amount, scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, amount, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() < 10, 1);
        test_scenario::return_shared(pool);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned - earned_minter <= 1, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    scenario.next_tx(lp_1); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(expected_earned_1 - earned_minter <= 1, 1);
        assert!(!integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(expected_earned_1 - earned <= 1, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };


    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_new_position_in_range_with_upper_matching_lower_pool_price_exactly_at_tick_after_crossing() {
    let admin = @0xA1;
    let swapper = @0xA2;
    let lp_full_range = @0xA3; // Provides general liquidity
    let lp_1 = @0xA4; // Povides position lower tick of which is going to be crossed.
    let lp_2 = @0xA5; // Creates a new position with upper tick matching the lower tick of the existing position.

    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, swapper, &mut clock, 50_000, 182, DEFAULT_GAUGE_EMISSIONS, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 100_000_000_000u128, &clock
        );
    };

    // --- 3. Create position 1 ---
    let lower_tick_p1 = integer_mate::i32::neg_from(10).as_u32();
    let upper_tick_p1 = integer_mate::i32::from(10).as_u32();
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_1); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_1, lower_tick_p1, upper_tick_p1, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_1); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // spend some time for growth to accumulate
    clock.increment_for_testing(3 * 24 * 60 * 60 * 1000);

    scenario.next_tx(swapper); {
        let amount = 60000000;
        let coin_a = coin::mint_for_testing<USD_TESTS>(amount, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, true, true, amount, 1, tick_math::min_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() > 10, 1);
        test_scenario::return_shared(pool);
    };

    scenario.next_tx(swapper); {
        let amount = 10000000;
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(amount, scenario.ctx());

        let (coin_a_out, coin_b_out) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, amount, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a_out);
        coin::burn_for_testing(coin_b_out);
    };

    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        assert!(pool.current_tick_index().abs_u32() == 10, 1);
        test_scenario::return_shared(pool);
    };

    // create a new position in range with upper tick matching the lower tick of the existing position
    scenario.next_tx(lp_2); {
        let lower_tick_p2 = integer_mate::i32::neg_from(20).as_u32();
        let upper_tick_p2 = integer_mate::i32::neg_from(10).as_u32();
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_2, lower_tick_p2, upper_tick_p2, 1_000_000_000u128, &clock
        );
    };

    scenario.next_tx(lp_2); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check earned is zero, fullsail distribution growth inside is negative
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // wait for 24 hours, check earned amounts are still zero cos position is inactive
    clock.increment_for_testing(24 * 60 * 60 * 1000);
    scenario.next_tx(lp_2); {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<governance::gauge::StakedPosition>();
        let position_id = staked_position.position_id();

        let earned_minter = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        let growth_inside = gauge.get_current_growth_inside<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        let (earned, growth_inside_new) = gauge.test_earned_internal<USD_TESTS, SAIL>(&pool, position_id, clock.timestamp_ms() / 1000);

        assert!(earned_minter == 0, 1);
        assert!(integer_mate::math_u128::is_neg(growth_inside), 2);
        assert!(earned == 0, 3);
        assert!(growth_inside_new == growth_inside, 5);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };
    // --- Cleanup ---
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


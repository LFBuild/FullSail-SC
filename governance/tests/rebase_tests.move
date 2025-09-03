#[test_only]
module governance::rebase_tests;

use governance::minter;
use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self, Scenario, ctx};
use clmm_pool::tick_math;
use sui::test_utils;

use governance::rebase_distributor::{RebaseDistributor};
use governance::minter::{Minter};
use voting_escrow::voting_escrow::{Self, VotingEscrow, Lock};
use governance::setup;
use switchboard::aggregator::{Aggregator};
use governance::distribution_config::{DistributionConfig};

use governance::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

public struct AUSD has drop, store {}
public struct SAIL has drop, store {}
public struct OSAIL1 has drop, store {}
public struct OSAIL2 has drop, store {}
public struct OSAIL3 has drop, store {}
public struct OSAIL4 has drop, store {}
public struct BUSD has drop, store {}

#[test]
fun test_calculate_rebase_growth() {
    let emissions = 1_000_000;

    // 1. Zero total supply
    let rebase1 = minter::calculate_rebase_growth(emissions, 0, 0);
    assert!(rebase1 == 0, 0);

    // 2. Zero emissions
    let rebase2 = minter::calculate_rebase_growth(0, 1_000_000, 500_000);
    assert!(rebase2 == 0, 1);

    // 3. All tokens locked
    let rebase3 = minter::calculate_rebase_growth(emissions, 1_000_000, 1_000_000);
    assert!(rebase3 == 0, 2);

    // 4. No tokens locked
    let rebase4 = minter::calculate_rebase_growth(emissions, 1_000_000, 0);
    assert!(rebase4 == emissions / 2, 3); // 1_000_000 / 2 = 500_000

    // 5. Half tokens locked
    let rebase5 = minter::calculate_rebase_growth(emissions, 1_000_000, 500_000);
    assert!(rebase5 == emissions / 8, 4); // 1_000_000 * (0.5)^2 / 2 = 125_000

    // 6. 25% tokens locked
    let rebase6 = minter::calculate_rebase_growth(emissions, 1_000_000, 250_000);
    // expected = 1_000_000 * (750_000 / 1_000_000)^2 / 2
    // expected = 1_000_000 * (0.75)^2 / 2
    // expected = 1_000_000 * 0.5625 / 2 = 281_250
    assert!(rebase6 == 281250, 5);

    // 7. 75% tokens locked
    let rebase7 = minter::calculate_rebase_growth(emissions, 1_000_000, 750_000);
    // expected = 1_000_000 * (250_000 / 1_000_000)^2 / 2 = 31_250
    assert!(rebase7 == 31250, 6);

    // 8. Large numbers
    let large_emissions = 1_000_000_000_000_000_000;
    let large_total_supply = 10_000_000_000_000_000_000;
    let large_locked = 4_000_000_000_000_000_000; // 40% locked
    let rebase8 = minter::calculate_rebase_growth(large_emissions, large_total_supply, large_locked);
    // expected = large_emissions * (0.6)^2 / 2
    // expected = 10^18 * 0.36 / 2 = 18 * 10^16
    assert!(rebase8 == 180_000_000_000_000_000, 7);
}

#[test]
fun test_rebase_with_unclaimed_rewards() {
    let admin = @0xD;
    let user = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000; // Set emissions to zero
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Full setup. This will create a lock for `user` with `lock_amount`.
    // The total supply of SAIL will be `lock_amount`. All of it is locked.
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        initial_o_sail_supply
    );

    // 2. Create and deposit a position for the user
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 3. Distribute gauge for epoch 1. Since base emissions are 0, no new SAIL should be minted.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock);
    };

    // 4. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 5. Update minter period for epoch 2. This triggers the first rebase calculation.
    // Since no new SAIL was minted, total supply should equal locked supply.
    // Therefore, rebase amount should be 0.
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 6. Check RebaseDistributor balance. It should be 0.
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 7. Distribute the gauge for epoch 2. Again, no new SAIL should be minted.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock);
    };

    // 8. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 9. Update minter period for epoch 3. Rebase should be 0 again.
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 10. Verify rebase amount is still 0.
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 1);
        test_scenario::return_shared(rd);
    };

    // Cleanup
    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
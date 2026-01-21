#[test_only]
module governance::gauge_killed_tests;

use governance::minter;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self, ctx};
use sui::clock::{Self, Clock};

use clmm_pool::pool::{Self, Pool};
use sui::test_utils;

use governance::distribute_cap::{Self};
use governance::distribution_config::{Self, DistributionConfig};
use governance::rebase_distributor::{Self,RebaseDistributor};
use governance::gauge::{Self, Gauge, StakedPosition};
use gauge_cap::gauge_cap::{Self, CreateCap};
use governance::minter::{AdminCap, Minter};
use governance::voter::{Self, Voter};
use voting_escrow::voting_escrow::{Self, VotingEscrow, Lock};
use voting_escrow::emergency_council::{EmergencyCouncilCap};
use governance::setup;
use sui::sui::SUI;
use voting_escrow::emergency_council;

use switchboard::aggregator::{Self, Aggregator};
use price_monitor::price_monitor::{Self, PriceMonitor};

use governance::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

public struct AUSD has drop, store {}
public struct SAIL has drop, store {}
public struct OSAIL1 has drop, store {}
public struct OSAIL2 has drop, store {}
public struct OSAIL3 has drop, store {}
public struct OSAIL4 has drop, store {}

fun setup_for_gauge_creation(scenario: &mut test_scenario::Scenario, admin: address, clock: &mut Clock) {
    setup::setup_clmm_factory_with_fee_tier(scenario, admin, 1, 1000);

    scenario.next_tx(admin);
    setup::setup_distribution<SAIL>(scenario, admin, clock);

    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(scenario, pool_sqrt_price, 1);
    
    scenario.next_tx(admin);
    let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(scenario, 0, clock);
    o_sail_coin.burn_for_testing();
}

#[test]
#[expected_failure(abort_code = voter::ECreateGaugePoolAlreadyHasGauge)]
fun test_create_gauge_after_kill() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);
    
    // kill the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // try to create another gauge for the same pool
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::EDistributeGaugeGaugeIsKilled)]
fun test_distribute_killed_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // --- EPOCH 1: Successful distribution ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- EPOCH 2 ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Kill the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // Attempt to distribute the killed gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario,
            gauge_base_emissions,
            &usd_metadata,
            &mut aggregator,
            &clock
        );
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_revived_gauge_succeeds() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- EPOCH 2 ---
    clock.increment_for_testing(WEEK);

    // update the minter period
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // --- Kill the gauge in epoch 2 ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // --- EPOCH 3 ---
    clock.increment_for_testing(WEEK);

    // update the minter period
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // reset the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // distribute the revived gauge
    scenario.next_tx(admin);
    {
        // prev epoch sail is OSAIL1, cos second epoch is skipped.
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Verification
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let new_emissions = minter.usd_epoch_emissions();
        // After being killed and revived, the gauge missed a distribution.
        // The emission calculation treats it as a new gauge, so it uses the base emission.
        assert!(new_emissions == gauge_base_emissions, 1);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// test_revive_undistributed_gauge_fails removed - revive_gauge is deprecated

// test_kill_revive_in_same_epoch_rewards removed - revive_gauge is deprecated
// test_revive_gauge_in_next_epoch_fails removed - revive_gauge is deprecated
// For same-epoch recovery, use pause/unpause instead of kill/revive

#[test]
#[expected_failure(abort_code = minter::EResetGaugeAlreadyDistributed)]
fun test_reset_gauge_in_same_epoch_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup, including minter activation
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Distribute Gauge for Epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Advance time 1/3 week and kill the gauge
    clock.increment_for_testing(WEEK / 3);
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 4. Advance time another 1/3 week
    clock.increment_for_testing(WEEK / 3);

    // 5. Attempt to reset the gauge in the same epoch (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reset_and_distribute_undistributed_killed_gauge() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let new_gauge_base_emissions = 500_000;
    let lock_amount = 1_000_000;

    // 1. Full setup, including minter activation
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge before any distribution has occurred
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Advance time by 1/3 of a week
    clock.increment_for_testing(WEEK / 3);

    // 4. Reset the gauge. This is allowed as it was never distributed in this epoch.
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            new_gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // 5. Distribute the gauge now that it's reset and alive
    scenario.next_tx(admin);
    {
        let distributed_amount = setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
        assert!(distributed_amount == new_gauge_base_emissions, 0);
    };

    // 6. Verification
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(minter.usd_epoch_emissions() == new_gauge_base_emissions, 1);
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let emissions_table = minter.borrow_pool_epoch_emissions_usd();
        let gauge_id = object::id(&gauge);
        assert!(emissions_table.borrow(gauge_id) == new_gauge_base_emissions, 2);
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(gauge);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EKillGaugeAlreadyKilled)]
fun test_kill_already_killed_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Attempt to kill the gauge again (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EResetGaugeGaugeAlreadyAlive)]
fun test_reset_already_alive_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 4. Reset the gauge (this should succeed)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // 5. Attempt to reset the gauge again (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_kill_gauge_with_revoked_admin_cap_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Revoke the admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());
        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));
        
        test_scenario::return_shared(minter);
        scenario.return_to_sender(admin_cap);
        test_utils::destroy(publisher);
    };

    // 3. Attempt to kill the gauge with revoked admin cap (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_reset_gauge_with_revoked_admin_cap_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge with valid admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 4. Revoke the admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());
        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));
        
        test_scenario::return_shared(minter);
        scenario.return_to_sender(admin_cap);
        test_utils::destroy(publisher);
    };

    // 5. Attempt to reset the gauge with revoked admin cap (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EKillGaugeDistributionConfigInvalid)]
fun test_kill_gauge_with_wrong_distribution_config_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Create a wrong distribution config
    scenario.next_tx(admin);
    {
        let correct_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(correct_dist_config);
        distribution_config::test_init(scenario.ctx());
    };

    // 3. Attempt to kill the gauge with wrong distribution config (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut wrong_dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EKillGaugeGaugeDoesNotMatchPool)]
fun test_kill_gauge_with_wrong_pool_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup with gauge for USD_TESTS/AUSD pool (tick_spacing=1)
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Add a different fee tier and create a second pool with same coin types but different tick_spacing
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<clmm_pool::config::AdminCap>();
        let mut global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        // Add fee tier with tick_spacing=10
        clmm_pool::config::add_fee_tier(&mut global_config, 10, 3000, scenario.ctx());
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(admin_cap);
    };

    scenario.next_tx(admin);
    {
        let correct_pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        test_utils::destroy(correct_pool);
        let pool_sqrt_price: u128 = 1 << 64; // Price = 1
        // Create second pool with tick_spacing=10 (different from the gauge's pool which has tick_spacing=1)
        setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 10);
    };

    // 3. Attempt to kill the gauge with the wrong pool (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        // Take the correct pool first, then the wrong pool
        let wrong_pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &wrong_pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(wrong_pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EResetGaugeDistributionConfigInvalid)]
fun test_reset_gauge_with_wrong_distribution_config_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge with valid admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 4. Create a wrong distribution config (destroy the correct one first)
    scenario.next_tx(admin);
    {
        let correct_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(correct_dist_config);
        distribution_config::test_init(scenario.ctx());
    };

    // 5. Attempt to reset the gauge with wrong distribution config (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter.reset_gauge_v2<USD_TESTS, AUSD, SAIL>(
            &mut wrong_dist_config,
            &admin_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ESettleKilledGaugeGaugeNotKilled)]
fun test_settle_killed_gauge_on_alive_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (gauge is alive)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Attempt to settle the gauge without killing it first (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());

        minter::settle_killed_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL>(
            &mut minter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ESettleKilledGaugeDistributionConfigInvalid)]
fun test_settle_killed_gauge_with_wrong_distribution_config_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        0 // initial oSAIL supply for activation
    );

    // 2. Kill the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::kill_gauge_v2<SAIL, USD_TESTS, AUSD>(
            &mut minter,
            &mut dist_config,
            &admin_cap,
            &gauge,
            &pool
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 3. Create a wrong distribution config (destroy the correct one first)
    scenario.next_tx(admin);
    {
        let correct_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(correct_dist_config);
        distribution_config::test_init(scenario.ctx());
    };

    // 4. Attempt to settle the killed gauge with wrong distribution config (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let wrong_dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());

        minter::settle_killed_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL>(
            &mut minter,
            &wrong_dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        scenario.return_to_sender(admin_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
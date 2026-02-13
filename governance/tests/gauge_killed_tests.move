#[test_only]
module governance::gauge_killed_tests;

use governance::minter;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self, ctx};
use sui::clock::{Self, Clock};

use clmm_pool::pool::{Self, Pool};
use clmm_pool::tick_math;
use clmm_pool::clmm_math;
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
use voting_escrow::common;
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
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
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
/// Tests that when a gauge is killed in the middle of an epoch, positions staked 
/// into the gauge continue earning rewards until the end of the epoch.
/// This test verifies:
/// 1. Position earns rewards after gauge is killed (mid-epoch claim)
/// 2. Position can still claim rewards after epoch ends
fun test_killed_gauge_rewards_continue_until_epoch_end() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    let lp_position_id: sui::object::ID;
    {
        lp_position_id = setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Advance time by 1/3 of the week
    clock.increment_for_testing(WEEK / 3);

    // 5. Kill the gauge in the middle of the epoch
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

    // 6. Check that LP can still earn rewards after gauge is killed (still in current epoch)
    scenario.next_tx(lp);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // Position should have earned approximately 1/3 of the rewards so far
        // (1/3 of epoch has passed)
        assert!(gauge_base_emissions / 3 - earned <= 2, 2);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 7. Claim rewards BEFORE epoch ends (while gauge is killed)
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    let first_claim_amount: u64;
    {
        let reward = scenario.take_from_sender<sui::coin::Coin<OSAIL1>>();
        first_claim_amount = sui::coin::value(&reward);
        // Should have earned rewards (position staked during 1/3 of epoch)
        // First claim should be less than total emissions
        assert!(gauge_base_emissions / 3 - first_claim_amount <= 2, 3);

        sui::coin::burn_for_testing(reward);
    };

    // 8. Advance time past the end of the epoch
    clock.increment_for_testing(WEEK);

    // 9. Check that LP has earned more rewards (rewards continued after gauge was killed)
    scenario.next_tx(lp);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_after_epoch = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // Position should have earned more rewards (the remaining 2/3 of the epoch)
        assert!(gauge_base_emissions * 2 / 3 - earned_after_epoch <= 2, 5);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 10. Claim remaining rewards AFTER epoch ends
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<sui::coin::Coin<OSAIL1>>();
        let second_claim_amount = sui::coin::value(&reward);
        
        // The total claimed (first + second) should be close to full emissions
        // (with some tolerance for rounding)
        let total_claimed = first_claim_amount + second_claim_amount;
        // Allow 10 units tolerance for rounding errors
        assert!(gauge_base_emissions - total_claimed <= 5, 6);
        
        sui::coin::burn_for_testing(reward);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
/// Tests that settling a killed gauge after epoch end stops reward accrual.
fun test_settle_killed_gauge_after_epoch_end_stops_rewards() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    let lp_position_id: sui::object::ID;
    {
        lp_position_id = setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Advance time by 1/2 of the week and kill the gauge
    clock.increment_for_testing(WEEK / 2);
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

    // 5. Advance time to the end of the epoch
    clock.increment_for_testing(WEEK / 2);

    // 6. Update minter period for the next epoch
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 7. Settle the killed gauge after epoch end
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 8. Snapshot earned rewards at epoch end
    scenario.next_tx(lp);
    let earned_at_end: u64;
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        earned_at_end = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL2>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        std::debug::print(&earned_at_end);

        assert!(gauge_base_emissions - earned_at_end <= 5, 1);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 9. Advance time and ensure rewards do not increase after settle
    clock.increment_for_testing(WEEK);
    scenario.next_tx(lp);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_after_settle = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL2>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        assert!(earned_after_settle == earned_at_end, 2);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that at epoch end we kill the gauge, settle it, and still can claim rewards
/// after wash trades occurred during the epoch.
fun test_kill_and_settle_gauge_after_wash_trades_at_epoch_end() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup, including minter activation and gauge creation
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 5. Perform wash trades during the epoch
    let wash_interval = WEEK / 10;
    let trade_rounds = 5u64;
    let swap_amount = 1_000_000_000;
    let fee_rate_denominator = clmm_math::fee_rate_denominator();
    let pool_fee_rate = {
        scenario.next_tx(admin);
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let fee_rate = pool::fee_rate(&pool);
        test_scenario::return_shared(pool);
        fee_rate
    };
    let protocol_fee_rate = {
        scenario.next_tx(admin);
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let protocol_fee_rate = global_config.protocol_fee_rate();
        test_scenario::return_shared(global_config);
        protocol_fee_rate
    };
    let protocol_fee_rate_denominator = clmm_pool::config::protocol_fee_rate_denom();

    let full_fee_per_swap = integer_mate::full_math_u64::mul_div_floor(
        swap_amount,
        pool_fee_rate,
        fee_rate_denominator
    );
    let protocol_fee_per_swap = integer_mate::full_math_u64::mul_div_floor(
        full_fee_per_swap,
        protocol_fee_rate,
        protocol_fee_rate_denominator
    );
    let expected_fee_per_token = (full_fee_per_swap - protocol_fee_per_swap) * trade_rounds;
    let mut i = 0;
    while (i < trade_rounds) {
        clock.increment_for_testing(wash_interval);

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<USD_TESTS>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<AUSD>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_in,
                coin_out,
                true,  // a2b = true (USD_TESTS -> AUSD)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::min_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<AUSD>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<USD_TESTS>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_out,
                coin_in,
                false, // a2b = false (AUSD -> USD_TESTS)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::max_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        i = i + 1;
    };

    // 6. Advance to end of epoch
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);

    // 7. Kill the gauge at epoch end
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

    // update minter period for the next epoch
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 8. Settle the killed gauge instead of distributing it
    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18(), clock.timestamp_ms());

        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 9. Verify settle redirected all fees to protocol balances
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let protocol_fee_usd = minter::exercise_fee_protocol_balance<SAIL, USD_TESTS>(&minter);
        let protocol_fee_ausd = minter::exercise_fee_protocol_balance<SAIL, AUSD>(&minter);

        assert!(protocol_fee_usd == expected_fee_per_token, 1);
        assert!(protocol_fee_ausd == expected_fee_per_token, 2);

        test_scenario::return_shared(minter);
    };

    // 10. Claim rewards after settling
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        let expected_reward = gauge_base_emissions;
        assert!(expected_reward - reward.value() <= 10, 1);
        coin::burn_for_testing(reward);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that when a gauge is killed before epoch end, the oSAIL price can still be synced
/// and rewards keep accumulating in a position after the price sync.
/// This verifies that sync_o_sail_distribution_price works on killed gauges.
fun test_killed_gauge_osail_price_sync_and_rewards_accumulate() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    let lp_position_id: sui::object::ID;
    {
        lp_position_id = setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Advance time by 1/4 of the week
    clock.increment_for_testing(WEEK / 4);

    // 5. Kill the gauge
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

    // 6. Check earned rewards before price sync (should be ~1/4 of emissions)
    scenario.next_tx(lp);
    let earned_before_sync: u64;
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        earned_before_sync = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // Position should have earned approximately 1/4 of the rewards so far
        // At price 1.0, 1/4 of 1M USD emissions = 250k oSAIL
        let expected_first_quarter = gauge_base_emissions / 4;
        assert!(expected_first_quarter - earned_before_sync <= 2, 1);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 7. Advance time by another 1/4 of the week
    clock.increment_for_testing(WEEK / 4);

    // 8. Sync oSAIL price on the killed gauge (this should work)
    // Use a different price (half the original) to make the effect visible
    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / 2, clock.timestamp_ms());
        
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter::sync_o_sail_distribution_price<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL>(
            &mut minter,
            &mut dist_config,
            &mut gauge,
            &mut pool,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
    };

    // 9. Check that rewards continued to accumulate after price sync
    scenario.next_tx(lp);
    let earned_after_sync: u64;
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        earned_after_sync = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // Position should have earned 1/2 of emissions (two quarters passed)
        // First quarter at price 1.0: 250k oSAIL
        // Second quarter at price 1.0: 250k oSAIL
        // Total: 500k oSAIL
        let expected_after_sync = gauge_base_emissions / 2;
        assert!(expected_after_sync - earned_after_sync <= 2, 2);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 10. Advance time to end of epoch (remaining 1/2 of the week)
    clock.increment_for_testing(WEEK / 2);

    // 11. Check final rewards and claim
    scenario.next_tx(lp);
    let earned_at_end: u64;
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        earned_at_end = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // After the price sync at 0.5, the remaining 1/2 of USD emissions converts to 2x oSAIL
        // First half at price 1.0: 500k oSAIL
        // Second half at price 0.5: 500k USD / 0.5 = 1M oSAIL
        // Total: 1.5M oSAIL
        let expected_total = gauge_base_emissions / 2 + gauge_base_emissions;
        assert!(expected_total - earned_at_end <= 5, 3);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // 12. Claim all rewards
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<sui::coin::Coin<OSAIL1>>();
        let claimed_amount = sui::coin::value(&reward);
        
        // The claimed amount should match the earned amount
        // The total should be higher than base emissions because price dropped to 1/2
        // After the price sync, the remaining USD value is converted to more oSAIL tokens
        // First half at price 1.0: 500k oSAIL
        // Second half at price 0.5: 500k USD / 0.5 = 1M oSAIL
        // Total expected: 1.5M oSAIL
        let expected_total = gauge_base_emissions / 2 + gauge_base_emissions;
        assert!(expected_total - claimed_amount <= 5, 4);
        
        sui::coin::burn_for_testing(reward);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that voting fees are zero when gauge is killed and settled without distribution.
fun test_vote_then_kill_and_settle_without_distribution_earns_zero() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let voter_user = @0xD;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup, including minter activation and gauge creation
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Perform wash trades during the epoch
    let wash_interval = WEEK / 10;
    let trade_rounds = 5u64;
    let swap_amount = 1_000_000_000;
    let mut i = 0;
    while (i < trade_rounds) {
        clock.increment_for_testing(wash_interval);

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<USD_TESTS>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<AUSD>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_in,
                coin_out,
                true,  // a2b = true (USD_TESTS -> AUSD)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::min_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<AUSD>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<USD_TESTS>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_out,
                coin_in,
                false, // a2b = false (AUSD -> USD_TESTS)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::max_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        i = i + 1;
    };

    // 5. Advance to end of epoch 1 and update period for epoch 2
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 6. Voter user creates a lock for voting in epoch 2
    scenario.next_tx(voter_user);
    let voter_lock_id: ID;
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, 182, &clock);
    };
    scenario.next_tx(voter_user);
    {
        let lock = scenario.take_from_sender<Lock>();
        voter_lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 7. Advance to voting period in epoch 2 and vote for the pool
    clock.increment_for_testing(WEEK / 14 + 1);
    let vote_epoch = common::current_period(&clock);
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let mut pool_ids = vector::empty<ID>();
        pool_ids.push_back(object::id(&pool));

        let mut weights = vector::empty<u64>();
        weights.push_back(10000);

        let mut volumes = vector::empty<u64>();
        volumes.push_back(1_000_000);

        voter::vote<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            pool_ids,
            weights,
            volumes,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // 8. Kill the gauge without distributing in epoch 2
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

    // 9. Settle the killed gauge in epoch 2
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 10. Advance one more week and finalize voted weights for epoch 2
    clock.increment_for_testing(WEEK);
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[voter_lock_id],
        vector[10000],
        vote_epoch,
        admin,
        &clock
    );

    // 11. Check voter earned zero for voting fees
    scenario.next_tx(voter_user);
    {
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool_id = object::id(&pool);

        let earned_usd = voter::earned_voting_fee<USD_TESTS>(&voter, voter_lock_id, pool_id, &clock);
        let earned_ausd = voter::earned_voting_fee<AUSD>(&voter, voter_lock_id, pool_id, &clock);

        assert!(earned_usd == 0, 1);
        assert!(earned_ausd == 0, 2);

        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that a voter can claim trading fees after voting, then gauge is killed and settled.
fun test_vote_then_kill_and_settle_claims_trading_fees() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let voter_user = @0xD;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup, including minter activation and gauge creation
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Perform wash trades during the epoch
    let wash_interval = WEEK / 10;
    let trade_rounds = 5u64;
    let swap_amount = 1_000_000_000;
    let fee_rate_denominator = clmm_math::fee_rate_denominator();
    let pool_fee_rate = {
        scenario.next_tx(admin);
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let fee_rate = pool::fee_rate(&pool);
        test_scenario::return_shared(pool);
        fee_rate
    };
    let protocol_fee_rate = {
        scenario.next_tx(admin);
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let protocol_fee_rate = global_config.protocol_fee_rate();
        test_scenario::return_shared(global_config);
        protocol_fee_rate
    };
    let protocol_fee_rate_denominator = clmm_pool::config::protocol_fee_rate_denom();
    let full_fee_per_swap = integer_mate::full_math_u64::mul_div_floor(
        swap_amount,
        pool_fee_rate,
        fee_rate_denominator
    );
    let protocol_fee_per_swap = integer_mate::full_math_u64::mul_div_floor(
        full_fee_per_swap,
        protocol_fee_rate,
        protocol_fee_rate_denominator
    );
    let expected_fee_per_token = (full_fee_per_swap - protocol_fee_per_swap) * trade_rounds;
    let mut i = 0;
    while (i < trade_rounds) {
        clock.increment_for_testing(wash_interval);

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<USD_TESTS>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<AUSD>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_in,
                coin_out,
                true,  // a2b = true (USD_TESTS -> AUSD)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::min_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        scenario.next_tx(swapper);
        {
            let coin_in = coin::mint_for_testing<AUSD>(swap_amount, scenario.ctx());
            let coin_out = coin::zero<USD_TESTS>(scenario.ctx());

            let (remaining_coin_in, received_coin_out) = setup::swap<USD_TESTS, AUSD>(
                &mut scenario,
                coin_out,
                coin_in,
                false, // a2b = false (AUSD -> USD_TESTS)
                true,  // by_amount_in = true
                swap_amount,  // amount
                1,     // min amount out
                tick_math::max_sqrt_price(),
                &clock,
            );
            coin::burn_for_testing(remaining_coin_in);
            coin::burn_for_testing(received_coin_out);
        };

        i = i + 1;
    };

    // 5. Advance to end of epoch 1 and update period for epoch 2
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute Gauge for Epoch 2 (OSAIL2)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 6. Voter user creates a lock for voting in epoch 2
    scenario.next_tx(voter_user);
    let voter_lock_id: ID;
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, 182, &clock);
    };
    scenario.next_tx(voter_user);
    {
        let lock = scenario.take_from_sender<Lock>();
        voter_lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 7. Advance to voting period in epoch 2 and vote for the pool
    clock.increment_for_testing(WEEK / 14 + 1);
    let vote_epoch = common::current_period(&clock);
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let mut pool_ids = vector::empty<ID>();
        pool_ids.push_back(object::id(&pool));

        let mut weights = vector::empty<u64>();
        weights.push_back(10000);

        let mut volumes = vector::empty<u64>();
        volumes.push_back(1_000_000);

        voter::vote<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            pool_ids,
            weights,
            volumes,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // 8. Advance to epoch 3 and update period
    clock.increment_for_testing(WEEK);
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 9. Kill the gauge and settle in epoch 3
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
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 11. Update and finalize voted weights for epoch 2
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[voter_lock_id],
        vector[10000],
        vote_epoch,
        admin,
        &clock
    );

    // 12. Claim trading fee rewards for the voter
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            &pool,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    scenario.next_tx(voter_user);
    {
        let reward_usd = scenario.take_from_sender<Coin<USD_TESTS>>();
        let reward_ausd = scenario.take_from_sender<Coin<AUSD>>();

        assert!(reward_usd.value() == expected_fee_per_token, 1);
        assert!(reward_ausd.value() == expected_fee_per_token, 2);

        coin::burn_for_testing(reward_usd);
        coin::burn_for_testing(reward_ausd);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EKillGaugeAlreadyPaused)]
fun test_kill_paused_gauge_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    // Pause the gauge first
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::pause_gauge<SAIL>(
            &minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(gauge);
        test_utils::destroy(emergency_cap);
    };

    // Killing a paused gauge should fail
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

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_pause_killed_gauge_succeeds() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    // Kill the gauge first
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

    // Pause the killed gauge (should succeed)
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::pause_gauge<SAIL>(
            &minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        assert!(dist_config.is_gauge_paused(gauge_id), 0);
        assert!(!dist_config.is_gauge_alive(gauge_id), 1);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(gauge);
        test_utils::destroy(emergency_cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EKillGaugeUnstakedFeeRateNotZero)]
fun test_kill_gauge_with_nonzero_unstaked_fee_rate_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    // Set unstaked fee rate to a non-zero value that is not the default
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<clmm_pool::config::AdminCap>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let new_rate = 1000;

        clmm_pool::pool::update_unstaked_liquidity_fee_rate(&global_config, &mut pool, new_rate, scenario.ctx());

        test_scenario::return_shared(global_config);
        test_scenario::return_shared(pool);
        transfer::public_transfer(admin_cap, admin);
    };

    // Killing a gauge with non-zero unstaked fee rate should fail
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

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that syncing oSAIL price mid-epoch, killing the gauge later, and settling after
/// epoch end preserves oSAIL emission accounting.
fun test_sync_price_kill_and_settle_updates_osail_emissions() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Advance time by half the week and sync oSAIL price
    clock.increment_for_testing(WEEK / 2);
    scenario.next_tx(admin);
    {
        setup::aggregator_set_current_value(&mut aggregator, setup::one_dec18() / 2, clock.timestamp_ms());

        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter::sync_o_sail_distribution_price<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL>(
            &mut minter,
            &mut dist_config,
            &mut gauge,
            &mut pool,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
    };

    // 5. Advance time by 1/4 of the week, then kill the gauge
    clock.increment_for_testing(WEEK / 4);
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

    // 6. Advance time to the end of the epoch
    clock.increment_for_testing(WEEK / 4);

    // 7. Update minter period for the next epoch
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 8. Settle the killed gauge after epoch end
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 9. Verify total, epoch, and gauge oSAIL emissions
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();

        let prev_epoch_start = common::current_period(&clock) - common::week();
        let expected_total = gauge_base_emissions / 2 + gauge_base_emissions;

        let total_o_sail_emissions = minter::o_sail_emissions_by_epoch(&minter, prev_epoch_start);
        let epoch_o_sail_emissions = minter::o_sail_epoch_emissions(&minter, &dist_config);
        let gauge_o_sail_emissions = gauge::o_sail_emission_by_epoch(&gauge, prev_epoch_start);
        let usd_reward_rate = gauge::usd_reward_rate(&gauge);
        let o_sail_reward_rate = gauge::o_sail_reward_rate(&gauge);

        assert!(expected_total - total_o_sail_emissions <= 5, 1);
        assert!(expected_total - epoch_o_sail_emissions <= 5, 2);
        assert!(expected_total - gauge_o_sail_emissions <= 5, 3);
        assert!(usd_reward_rate == 0, 4);
        assert!(o_sail_reward_rate == 0, 5);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
    };

    // 10. Settle the killed gauge again after epoch end
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 11. Verify oSAIL emissions and reward rates again
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();

        let prev_epoch_start = common::current_period(&clock) - common::week();
        let expected_total = gauge_base_emissions / 2 + gauge_base_emissions;

        let total_o_sail_emissions = minter::o_sail_emissions_by_epoch(&minter, prev_epoch_start);
        let epoch_o_sail_emissions = minter::o_sail_epoch_emissions(&minter, &dist_config);
        let gauge_o_sail_emissions = gauge::o_sail_emission_by_epoch(&gauge, prev_epoch_start);
        let usd_reward_rate = gauge::usd_reward_rate(&gauge);
        let o_sail_reward_rate = gauge::o_sail_reward_rate(&gauge);

        assert!(expected_total - total_o_sail_emissions <= 5, 6);
        assert!(expected_total - epoch_o_sail_emissions <= 5, 7);
        assert!(expected_total - gauge_o_sail_emissions <= 5, 8);
        assert!(usd_reward_rate == 0, 9);
        assert!(o_sail_reward_rate == 0, 10);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
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
/// Tests killing a gauge, settling after epoch end, resetting, distributing, and verifying
/// oSAIL counters and LP earnings across epochs.
fun test_kill_settle_reset_distribute_and_check_emissions() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    let lp_position_id: sui::object::ID;
    {
        lp_position_id = setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Advance time by half the week and kill the gauge
    clock.increment_for_testing(WEEK / 2);
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

    // 5. Advance time to the end of the epoch
    clock.increment_for_testing(WEEK / 2);

    // 6. Update minter period for the next epoch
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 7. Settle the killed gauge after epoch end
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(admin_cap);
    };

    // 8. Claim epoch 1 rewards (OSAIL1)
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        let claimed = reward.value();
        assert!(gauge_base_emissions - claimed <= 5, 1);
        coin::burn_for_testing(reward);
    };

    // 9. Reset gauge in epoch 2
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

    // 10. Distribute Gauge for Epoch 2 (OSAIL2)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 11. Advance to next epoch and update period
    clock.increment_for_testing(WEEK);
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 10. Distribute Gauge for Epoch 3 (OSAIL3)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 12. Check oSAIL counters for epoch 2
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();

        let prev_epoch_start = common::current_period(&clock) - common::week();
        let total_o_sail_emissions = minter::o_sail_emissions_by_epoch(&minter, prev_epoch_start);
        let epoch_o_sail_emissions = minter::o_sail_epoch_emissions(&minter, &dist_config);
        let gauge_o_sail_emissions = gauge::o_sail_emission_by_epoch(&gauge, prev_epoch_start);

        assert!(gauge_base_emissions - total_o_sail_emissions <= 5, 2);
        assert!(gauge_base_emissions - epoch_o_sail_emissions <= 5, 3);
        assert!(gauge_base_emissions - gauge_o_sail_emissions <= 5, 4);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
    };

    // 13. Check LP earnings for epoch 2 (OSAIL2)
    scenario.next_tx(lp);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL3>(
            &minter,
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        assert!(gauge_base_emissions - earned <= 5, 5);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL3>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL3>>();
        let claimed = reward.value();
        assert!(gauge_base_emissions - claimed <= 5, 6);
        coin::burn_for_testing(reward);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that when a gauge is killed before the epoch end, staked positions can be
/// withdrawn both before and after the epoch ends.
/// This test verifies:
/// 1. Position can be withdrawn before the epoch ends (after claiming rewards)
/// 2. Position can be withdrawn after the epoch ends (after claiming rewards)
fun test_killed_gauge_position_withdrawal_before_and_after_epoch_end() {
    let admin = @0xA;
    let user = @0xB;
    let lp1 = @0xC;
    let lp2 = @0xD;
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

    // 3. LP1 creates and stakes a position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. LP2 creates and stakes a position
    scenario.next_tx(lp2);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp2,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp2);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 5. Advance time by 1/3 of the week
    clock.increment_for_testing(WEEK / 3);

    // 6. Kill the gauge in the middle of the epoch
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

    // 7. Verify gauge is killed
    scenario.next_tx(admin);
    {
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        
        assert!(!dist_config.is_gauge_alive(object::id(&gauge)), 0);
        
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
    };

    // 8. LP1 claims rewards and withdraws position BEFORE epoch ends
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<sui::coin::Coin<OSAIL1>>();
        // LP1 should have earned roughly 1/6 of emissions (1/3 epoch * 1/2 share)
        // (since both LP1 and LP2 have equal liquidity)
        let expected_reward = gauge_base_emissions / 6;
        assert!(expected_reward - sui::coin::value(&reward) <= 2, 1);
        sui::coin::burn_for_testing(reward);
    };

    // LP1 withdraws position before epoch ends (gauge is killed but not paused)
    scenario.next_tx(lp1);
    {
        setup::withdraw_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // Verify LP1 got their position back
    scenario.next_tx(lp1);
    {
        let position = scenario.take_from_sender<clmm_pool::position::Position>();
        assert!(clmm_pool::position::liquidity(&position) == 1_000_000_000u128, 2);
        transfer::public_transfer(position, lp1);
    };

    // 9. Advance time past the epoch end
    clock.increment_for_testing(WEEK);

    // 10. LP2 claims rewards and withdraws position AFTER epoch ends
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<sui::coin::Coin<OSAIL1>>();
        // LP2 should have earned more since they stayed for the full epoch
        // They earned:
        // - 1/6 of emissions for first 1/3 epoch (sharing with LP1)
        // - 2/3 of emissions for remaining 2/3 epoch (LP2 is alone after LP1 withdrew)
        // Total: 1/6 + 2/3 = 1/6 + 4/6 = 5/6 of emissions
        let expected_reward = gauge_base_emissions * 5 / 6;
        assert!(expected_reward - sui::coin::value(&reward) <= 5, 3);
        sui::coin::burn_for_testing(reward);
    };

    // LP2 withdraws position after epoch ends (gauge is killed but not paused)
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // Verify LP2 got their position back
    scenario.next_tx(lp2);
    {
        let position = scenario.take_from_sender<clmm_pool::position::Position>();
        assert!(clmm_pool::position::liquidity(&position) == 1_000_000_000u128, 4);
        transfer::public_transfer(position, lp2);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EDepositPositionGaugeNotAlive)]
/// Tests that depositing a position into a killed gauge fails.
/// The gauge is killed before the epoch ends, and the deposit attempt should fail
/// because the gauge is no longer alive.
fun test_deposit_position_into_killed_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. LP creates a position (but doesn't stake it yet)
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    // 4. Advance time by 1/3 of the week
    clock.increment_for_testing(WEEK / 3);

    // 5. Kill the gauge in the middle of the epoch
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

    // 6. Attempt to deposit position into the killed gauge (should fail)
    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // Cleanup (unreachable due to expected failure)
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that pool rewards can still be claimed after a gauge is killed before the epoch end.
/// This verifies that killing a gauge does not prevent LPs from claiming their accrued pool rewards.
fun test_claim_pool_rewards_after_gauge_killed_before_epoch_end() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
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

    // 3. Add rewards to the RewarderGlobalVault
    let reward_amount = 10_000_000_000u64;
    scenario.next_tx(admin);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        
        let reward_coin = coin::mint_for_testing<USD_TESTS>(reward_amount, scenario.ctx());
        
        clmm_pool::rewarder::deposit_reward<USD_TESTS>(
            &global_config,
            &mut vault,
            reward_coin.into_balance()
        );
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
    };

    // 4. Initialize rewarder for USD_TESTS in the pool
    scenario.next_tx(admin);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        
        clmm_pool::pool::initialize_rewarder<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut pool,
            scenario.ctx()
        );
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(pool);
    };

    // 5. Update emission to start distributing rewards
    scenario.next_tx(admin);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        
        let emissions_per_second = 10 << 64; // some emission rate
        clmm_pool::pool::update_emission<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut pool,
            &mut vault,
            emissions_per_second,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(pool);
    };

    // 6. LP creates and stakes a position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1_000_000_000u128,
            &clock
        );
    };

    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 7. Advance time by half of the week to accrue rewards (and pass cooldown)
    clock.increment_for_testing(WEEK / 2);

    // 8. Kill the gauge before the epoch ends
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

    // 9. Verify gauge is killed
    scenario.next_tx(admin);
    {
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        
        assert!(!dist_config.is_gauge_alive(object::id(&gauge)), 0);
        
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
    };

    // 10. LP claims pool rewards after gauge is killed (should succeed)
    scenario.next_tx(lp);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        
        let reward_balance = gauge::get_pool_reward<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock
        );
        
        // Pool rewards should be claimable even after gauge is killed
        let claimed_amount = sui::balance::value(&reward_balance);
        assert!(claimed_amount > 0, 1);
        
        // Transfer the claimed balance to LP
        let reward_coin = sui::coin::from_balance(reward_balance, scenario.ctx());
        transfer::public_transfer(reward_coin, lp);
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
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
        let admin_cap = scenario.take_from_sender<AdminCap>();

        minter::settle_killed_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &wrong_dist_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            &clock
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
#[expected_failure(abort_code = voter::EVoteInternalGaugeNotAlive)]
/// Tests that when a gauge is killed at the epoch end, voting for the pool
/// in the new epoch fails with EVoteInternalGaugeNotAlive error.
fun test_vote_for_killed_gauge_in_new_epoch_fails() {
    let admin = @0xA;
    let user = @0xB;
    let voter_user = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup with gauge and initial lock
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

    // 3. Voter user creates a lock for voting in epoch 2
    scenario.next_tx(voter_user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, 182, &clock);
    };

    // 4. Advance to end of epoch 1
    clock.increment_for_testing(WEEK);

    // 5. Kill the gauge at the epoch end
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

    // 6. Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 7. Verify gauge is killed
    scenario.next_tx(admin);
    {
        let dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        
        assert!(!dist_config.is_gauge_alive(object::id(&gauge)), 0);
        
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
    };

    // 8. Advance to voting period in epoch 2
    clock.increment_for_testing(WEEK / 14 + 1);

    // 9. Attempt to vote for the killed gauge in the new epoch (should fail with EVoteInternalGaugeNotAlive)
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let mut pool_ids = vector::empty<ID>();
        pool_ids.push_back(object::id(&pool));

        let mut weights = vector::empty<u64>();
        weights.push_back(10000);

        let mut volumes = vector::empty<u64>();
        volumes.push_back(1_000_000);

        voter::vote<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            pool_ids,
            weights,
            volumes,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // Cleanup (unreachable due to expected failure)
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
/// Tests that votes can be reset after a gauge is killed.
fun test_reset_votes_after_gauge_kill_succeeds() {
    let admin = @0xA;
    let user = @0xB;
    let voter_user = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup with gauge and initial lock
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

    // 2. Voter user creates a lock for voting
    scenario.next_tx(voter_user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, 182, &clock);
    };

    // 3. Advance to voting period in epoch 1
    clock.increment_for_testing(WEEK / 14 + 1);

    // 4. Vote for the pool
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let mut pool_ids = vector::empty<ID>();
        pool_ids.push_back(object::id(&pool));

        let mut weights = vector::empty<u64>();
        weights.push_back(10000);

        let mut volumes = vector::empty<u64>();
        volumes.push_back(1_000_000);

        voter::vote<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            pool_ids,
            weights,
            volumes,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // 5. Kill the gauge in the middle of the epoch
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

    // 6. Advance time a bit after the gauge is killed
    clock.increment_for_testing(1000);

    // 7. Reset votes even though the gauge is killed
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::reset<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            &clock,
            scenario.ctx()
        );

        let voted_pools = voter::voted_pools(&voter, object::id(&lock));
        assert!(voted_pools.length() == 0, 0);
        assert!(voter::get_pool_weight(&voter, object::id(&pool)) == 0, 0);

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::EVoteInternalGaugeNotAlive)]
/// Tests that when a gauge is killed in the middle of an epoch, voting for the pool
/// in the same epoch fails with EVoteInternalGaugeNotAlive error.
fun test_vote_for_killed_gauge_before_epoch_end_fails() {
    let admin = @0xA;
    let user = @0xB;
    let voter_user = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup with gauge and initial lock
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

    // 2. Voter user creates a lock for voting
    scenario.next_tx(voter_user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, 182, &clock);
    };

    // 3. Advance to voting period in epoch 1
    // epoch_vote_start is usually at 1/14 of the week (half a day)
    clock.increment_for_testing(WEEK / 14 + 1);

    // 4. Kill the gauge in the middle of the epoch
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

    // 5. Attempt to vote for the killed gauge (should fail with EVoteInternalGaugeNotAlive)
    scenario.next_tx(voter_user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let mut pool_ids = vector::empty<ID>();
        pool_ids.push_back(object::id(&pool));

        let mut weights = vector::empty<u64>();
        weights.push_back(10000);

        let mut volumes = vector::empty<u64>();
        volumes.push_back(1_000_000);

        voter::vote<SAIL>(
            &mut voter,
            &mut voting_escrow,
            &dist_config,
            &lock,
            pool_ids,
            weights,
            volumes,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    // Cleanup (unreachable due to expected failure)
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

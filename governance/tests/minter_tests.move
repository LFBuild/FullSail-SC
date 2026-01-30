#[test_only]
module governance::minter_tests;

use governance::minter;
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::package::{Self, Publisher};
use sui::object::{Self, ID, UID};
use sui::transfer::{Self, transfer};
use sui::test_scenario::{Self, Scenario, ctx};
use sui::math::sqrt;

use clmm_pool::pool::{Self, Pool};
use clmm_pool::config as clmm_config;
use clmm_pool::config::GlobalConfig;
use clmm_pool::tick_math;
use sui::test_utils;

use voting_escrow::common;
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
fun test_create_gauge_success() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);
    
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);
    
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);
        let emissions = minter::borrow_pool_epoch_emissions_usd(&minter);
        assert!(emissions.contains(gauge_id), 0);
        assert!(*emissions.borrow(gauge_id) == 100, 1);

        // total supply should be 0 as no emissions have been distributed yet
        assert!(minter.total_supply() == 0, 2);
        assert!(minter.o_sail_minted_supply() == 0, 3);
        assert!(minter.sail_total_supply() == 0, 4);

        // epoch emissions should be 0 as no emissions have been distributed yet
        assert!(minter.usd_epoch_emissions() == 0, 5);
        let current_epoch  = common::current_period(&clock);
        assert!(minter.usd_emissions_by_epoch(current_epoch) == 0, 6);
        
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = distribute_cap::EValidateDistributeInvalidVoter)]
fun test_create_gauge_wrong_voter() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    // create another voter
    scenario.next_tx(admin);
    {
        // destroy the correct voter
        let correct_voter = scenario.take_shared<Voter>();
        test_utils::destroy(correct_voter);

        let voter_publisher = voter::test_init(scenario.ctx());
        let global_config_obj = scenario.take_shared<GlobalConfig>();
        let global_config_id = object::id(&global_config_obj);
        test_scenario::return_shared(global_config_obj);
        let distribution_config_obj = scenario.take_shared<DistributionConfig>();
        let distribution_config_id = object::id(&distribution_config_obj);
        test_scenario::return_shared(distribution_config_obj);
        let (wrong_voter, wrong_distribute_cap) = voter::create(
            &voter_publisher,
            global_config_id,
            distribution_config_id,
            scenario.ctx()
        );
        transfer::public_share_object(wrong_voter);
        // we don't need this cap, but we need to destroy it
        test_utils::destroy(wrong_distribute_cap);
        test_utils::destroy(voter_publisher);
    };
    
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_voter = scenario.take_shared<Voter>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let create_cap = scenario.take_from_sender<CreateCap>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let gauge = minter::create_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &mut wrong_voter,
            &mut dist_config,
            &create_cap,
            &admin_cap,
            &ve,
            &mut pool,
            100,
            &clock,
            scenario.ctx()
        );
        // The following lines will not be reached, but are here to satisfy the compiler
        // in case the test does not fail as expected.
        transfer::public_share_object(gauge);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_voter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(create_cap);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::ECreateGaugeInvalidCreateCap)] // using a generic expected_failure as we are not sure about exact error
fun test_create_gauge_revoked_create_cap() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    // revoke create cap
    scenario.next_tx(admin);
    {
        let voter_publisher = voter::test_init(scenario.ctx());
        let create_cap = scenario.take_from_sender<CreateCap>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        voter.revoke_gauge_create_cap(&distribution_config, &voter_publisher, object::id<CreateCap>(&create_cap));
        test_utils::destroy(voter_publisher);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(create_cap);
        test_scenario::return_shared(distribution_config);
    };
    
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        // this will fail as create_cap was destroyed
        let create_cap = scenario.take_from_sender<CreateCap>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let gauge = minter::create_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &mut voter,
            &mut dist_config,
            &create_cap,
            &admin_cap,
            &ve,
            &mut pool,
            100,
            &clock,
            scenario.ctx()
        );

        transfer::public_share_object(gauge);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(create_cap);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::ECreateGaugeDistributionConfigInvalid)]
fun test_create_gauge_wrong_distribution_config() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    // create another distribution config
    scenario.next_tx(admin);
    {
        // destroy the correct distribution config
        let existing_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(existing_dist_config);
        
        distribution_config::test_init(scenario.ctx());
    };
    
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut wrong_dist_config = scenario.take_shared<DistributionConfig>();
        let create_cap = scenario.take_from_sender<CreateCap>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let gauge = minter::create_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &mut voter,
            &mut wrong_dist_config,
            &create_cap,
            &admin_cap,
            &ve,
            &mut pool,
            100,
            &clock,
            scenario.ctx()
        );

        transfer::public_share_object(gauge);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(wrong_dist_config);
        scenario.return_to_sender(create_cap);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_create_gauge_revoked_admin_cap() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    // revoke admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());
        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));
        
        test_scenario::return_shared(minter);
        scenario.return_to_sender(admin_cap);
        transfer::public_transfer(publisher, admin);
    };
    
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let create_cap = scenario.take_from_sender<CreateCap>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let gauge = minter::create_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &mut voter,
            &mut dist_config,
            &create_cap,
            &admin_cap,
            &ve,
            &mut pool,
            100,
            &clock,
            scenario.ctx()
        );

        transfer::public_share_object(gauge);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(create_cap);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// wrong voting escrow

#[test]
#[expected_failure(abort_code = voter::ECreateGaugeVotingEscrowInvalidVoter)] // Not sure about the exact abort code, so using a generic one.
fun test_create_gauge_wrong_voting_escrow() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    // create another voting escrow
    scenario.next_tx(admin);
    {
        // destroy the correct voting escrow
        let correct_ve = scenario.take_shared<VotingEscrow<SAIL>>();
        test_utils::destroy(correct_ve);
        
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let voter = scenario.take_shared<Voter>();
        let voter_id = object::id_from_address(@0x123456); // wrong voter id
        let (wrong_ve, wrong_ve_cap) = voting_escrow::create<SAIL>(
            &ve_publisher,
            voter_id,
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(wrong_ve_cap);
        transfer::public_share_object(wrong_ve);
        test_scenario::return_shared(voter);
        test_utils::destroy(ve_publisher);
    };
    
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let create_cap = scenario.take_from_sender<CreateCap>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let wrong_ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        let gauge = minter::create_gauge<USD_TESTS, AUSD, SAIL>(
            &mut minter,
            &mut voter,
            &mut dist_config,
            &create_cap,
            &admin_cap,
            &wrong_ve,
            &mut pool,
            100,
            &clock,
            scenario.ctx()
        );

        transfer::public_share_object(gauge);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(create_cap);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(wrong_ve);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateGaugeZeroBaseEmissions)]
fun test_create_gauge_zero_base_emissions() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 0, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::ECreateGaugePoolAlreadyHasGauge)]
fun test_create_gauge_already_exists() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 100, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_gauge_initial_amount() {
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
        1000000,
        182,
        gauge_base_emissions,
        0
    );
    let current_period = common::current_period(&clock);

    // distribute the gauge
    scenario.next_tx(admin);
    let distributed_amount: u64;
    {
        distributed_amount = setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);

        assert!(distributed_amount == gauge_base_emissions, 0);
        assert!(minter.usd_epoch_emissions() == gauge_base_emissions, 1);
        assert!(minter.usd_emissions_by_epoch(current_period) == gauge_base_emissions, 2);

        let emissions = minter::borrow_pool_epoch_emissions_usd(&minter);
        assert!(emissions.contains(gauge_id), 0);
        assert!(*emissions.borrow(gauge_id) == gauge_base_emissions, 1);

        // total supply should be lock amount.
        assert!(minter.total_supply() == 1000000, 2);
        assert!(minter.o_sail_minted_supply() == 0, 3);
        assert!(minter.sail_total_supply() == 1000000, 4);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(gauge);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeFirstEpochEmissionsInvalid)]
fun test_distribute_gauge_initial_epoch_with_wrong_metrics_fails() {
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

    // distribute the gauge with metrics different from the base emissions
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
            &mut scenario,
            999_999, //next epoch emissions
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
#[expected_failure(abort_code = minter::EDistributeGaugeEmissionsZero)]
fun test_distribute_gauge_second_epoch_with_zero_metrics_fails() {
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

    // --- EPOCH 2: Attempt distribution with zero metrics (should fail) ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute for epoch 2 with all-zero metrics
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>( 
            &mut scenario,
            0, // next epoch emissions
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
#[expected_failure(abort_code = minter::EDistributeGaugeEmissionsChangeTooBig)]
fun test_distribute_gauge_second_epoch_too_big_change_fails() {
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

    // --- EPOCH 2: Attempt distribution with zero metrics (should fail) ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute for epoch 2 with all-zero metrics
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>( 
            &mut scenario,
            20_000_001, // more than 20x is not allowed
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
#[expected_failure(abort_code = minter::EDistributeGaugeEmissionsChangeTooBig)]
fun test_distribute_gauge_second_epoch_too_big_change_down_fails() {
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

    // --- EPOCH 2: Attempt distribution with zero metrics (should fail) ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute for epoch 2 with all-zero metrics
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>( 
            &mut scenario,
            49_999, // more than 20x even down is not allowed
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
fun test_create_gauge_without_minter_activation_succeeds() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // --- Setup without activating the minter ---
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    scenario.next_tx(admin);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    let pool_sqrt_price: u128 = 1 << 64;
    scenario.next_tx(admin);
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);

    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, 1_000_000, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeMinterNotActive)]
fun test_distribute_gauge_without_minter_activation_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    
    // Setup without minter activation
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    let mut aggregator = setup::setup_price_monitor_and_aggregator<USD_TESTS, SAIL>(&mut scenario, admin, true, &clock);

    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);

    // Try to distribute the gauge, which should fail.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
fun test_distribute_gauge_increase_emissions() {
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
        1000000,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(minter.usd_epoch_emissions() == gauge_base_emissions, 0);
        test_scenario::return_shared(minter);
    };

    // --- EPOCH 2 ---
    clock.increment_for_testing(WEEK);

    // update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // distribute the gauge for epoch 2 with metrics that should cause a 10% increase
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario,
            gauge_base_emissions * 2, // next epoch emissions
            &usd_metadata,
            &mut aggregator,
            &clock
        );
    };

    // advance to the end of the epoch
    clock.increment_for_testing(WEEK);

    // claim rewards OSAIL2
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // --- VERIFICATION ---
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let new_emissions = minter.usd_epoch_emissions();
        // we advanced by the week, so we should go back to check emissions
        let current_period = common::current_period(&clock) - common::week();

        let expected_emissions = gauge_base_emissions * 2; // 5% increase

        assert!(expected_emissions - new_emissions <= 1, 1);
        assert!(minter.usd_emissions_by_epoch(current_period) == new_emissions, 2);

        let expected_o_sail_supply = gauge_base_emissions + expected_emissions;
        assert!(expected_o_sail_supply - minter.o_sail_minted_supply() <= 5, 3);
        // total_supply is o_sail_total_supply + sail_total_supply (which is lock amount)
        assert!(minter.total_supply() - expected_o_sail_supply + 5 - 1_000_000 <= 5, 4);

        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_gauge_with_emission_changes() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    let initial_sail_supply = 1000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        100,
        182,
        gauge_base_emissions,
        initial_sail_supply
    );

    // Distribute the gauge for epoch 1 (base emissions)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // Verification after Epoch 1
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let current_period = common::current_period(&clock);
        assert!(minter.usd_epoch_emissions() == gauge_base_emissions, 0);
        assert!(minter.usd_emissions_by_epoch(current_period) == gauge_base_emissions, 1);
        assert!(minter.o_sail_minted_supply() == initial_sail_supply, 2);
        // initial supply + lock amount
        assert!(minter.total_supply() == initial_sail_supply + 100, 3);
        test_scenario::return_shared(minter);
    };

    // --- EPOCH 2 (10% INCREASE) ---
    let emissions_epoch_2 = gauge_base_emissions * 11 / 10;
    clock.increment_for_testing(WEEK);

    // get rewards OSAIL1
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute for epoch 2 with metrics causing a 10% increase
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario,
            gauge_base_emissions * 11 / 10, // next epoch emissions
            &usd_metadata,
            &mut aggregator,
            &clock
        );
    };

    // Verification after Epoch 2
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let new_emissions = minter.usd_epoch_emissions();
        let current_period = common::current_period(&clock);

        assert!(emissions_epoch_2 - new_emissions <= 1, 1);
        assert!(minter.usd_emissions_by_epoch(current_period) == new_emissions, 2);

        let expected_o_sail_supply = initial_sail_supply + gauge_base_emissions;

        assert!(expected_o_sail_supply - minter.o_sail_minted_supply() <= 5, 3);
        assert!(expected_o_sail_supply + 100 - minter.total_supply() <= 5, 4);

        test_scenario::return_shared(minter);
    };

    // --- EPOCH 3 (10% DECREASE) ---
    let emissions_epoch_3 = emissions_epoch_2 * 9 / 10;
    clock.increment_for_testing(WEEK);

    // get rewards OSAIL2
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // Distribute for epoch 3 with metrics causing a 10% decrease
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(
            &mut scenario,
            emissions_epoch_2 * 9 / 10, // next epoch emissions
            &usd_metadata,
            &mut aggregator,
            &clock
        );
    };

    // Verification after Epoch 3
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let new_emissions = minter.usd_epoch_emissions();
        let current_period = common::current_period(&clock);

        assert!(emissions_epoch_3 - new_emissions <= 1, 1);
        assert!(minter.usd_emissions_by_epoch(current_period) == new_emissions, 2);

        let expected_o_sail_supply = initial_sail_supply + gauge_base_emissions + emissions_epoch_2;
        assert!(expected_o_sail_supply - minter.o_sail_minted_supply() <= 5, 3);

        test_scenario::return_shared(minter);
    };

    // advance to the end of the epoch
    clock.increment_for_testing(WEEK);

    // get rewards OSAIL3
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL3>(&mut scenario, &clock);
    };

        // Verification after Epoch 3
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let new_emissions = minter.usd_epoch_emissions();

        // we advanced by the week, so we should go back to check emissions
        let current_period = common::current_period(&clock) - common::week();

        assert!(emissions_epoch_3 - new_emissions <= 1, 1);
        assert!(new_emissions == minter.usd_emissions_by_epoch(current_period), 2);

        let expected_o_sail_supply = initial_sail_supply + gauge_base_emissions + emissions_epoch_2 + emissions_epoch_3;
        assert!(expected_o_sail_supply - minter.o_sail_minted_supply() <= 10, 3);

        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeAlreadyDistributed)]
fun test_distribute_same_gauge_twice_in_one_epoch_fails() {
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

    // --- Advance time by a few hours ---
    clock.increment_for_testing(2 * 60 * 60 * 1000); // 2 hours

    // --- Attempt to distribute the same gauge again (should fail) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeInvalidToken)]
fun test_distribute_gauge_with_wrong_o_sail_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    // Full setup, minter activated with OSAIL1
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
        // distribute_gauge uses <SUI, OSAIL1> as <Prev, Next>
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- EPOCH 2 ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2, sets current oSAIL to OSAIL2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Attempt to distribute gauge for epoch 2, but pass OSAIL1 as the token to distribute.
    // This should fail because the minter expects OSAIL2.
    scenario.next_tx(admin);
    {
        // Here, CurrentEpochOSail (PrevEpochOSail in wrapper) is OSAIL1, 
        // and we are trying to distribute OSAIL1 again as NextEpochOSail (EpochOSail in wrapper)
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
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
#[expected_failure(abort_code = distribute_cap::EValidateDistributeInvalidVoter)]
fun test_distribute_gauge_with_wrong_voter_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // 1. Full setup, which creates a VALID voter and gauge
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // 2. Create a WRONG voter
    let wrong_voter_id: ID;
    scenario.next_tx(admin);
    {
        let voter_publisher = voter::test_init(scenario.ctx());
        let global_config = scenario.take_shared<GlobalConfig>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let (wrong_voter, wrong_distribute_cap) = voter::create(
            &voter_publisher,
            object::id(&global_config),
            object::id(&distribution_config),
            scenario.ctx()
        );
        wrong_voter_id = object::id(&wrong_voter);

        // We don't need this cap, but we need to destroy it to avoid dangling objects
        test_utils::destroy(wrong_distribute_cap);
        test_utils::destroy(voter_publisher);
        transfer::public_share_object(wrong_voter);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
    };


    // 3. Attempt to distribute the gauge using the WRONG voter
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_voter_obj = scenario.take_shared_by_id<Voter>(wrong_voter_id);
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter.distribute_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL, OSAIL1>(
            &mut wrong_voter_obj,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut pool,
            0,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_voter_obj);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
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
#[expected_failure(abort_code = minter::ECheckDistributeGovernorRevoked)]
fun test_distribute_gauge_with_revoked_governor_cap_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);


    let gauge_base_emissions = 1_000_000;

    // 1. Full setup
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // 2. Revoke the DistributeGovernorCap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let publisher = minter::test_init(scenario.ctx());

        minter::revoke_distribute_governor(&mut minter, &publisher, object::id(&governor_cap));

        test_utils::destroy(publisher);
        scenario.return_to_sender(governor_cap);
        test_scenario::return_shared(minter);
    };

    // 3. Attempt to distribute the gauge with the revoked cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter.distribute_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL, OSAIL1>(
            &mut voter,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut pool,
            0,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeDistributionConfigInvalid)]
fun test_distribute_gauge_with_wrong_distribution_config_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    // 1. Full setup, which creates a valid distribution config
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // 2. Destroy the correct distribution config and create a new, wrong one
    scenario.next_tx(admin);
    {
        let correct_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(correct_dist_config);
        distribution_config::test_init(scenario.ctx());
    };

    // 3. Attempt to distribute the gauge with the wrong config
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let wrong_distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>(); 

        minter.distribute_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL, OSAIL1>(
            &mut voter,
            &distribute_governor_cap,
            &wrong_distribution_config,
            &mut gauge,
            &mut pool,
            0,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(wrong_distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::EDistributeGaugeInvalidPool)]
fun test_distribute_gauge_with_wrong_pool_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    // 1. Full setup, which creates an initial pool and gauge
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // 2. Add a new fee tier for the pool
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<clmm_pool::config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        clmm_pool::config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(admin_cap);
    };

    // 2. Destroy the original pool and create a new one of the same type
    scenario.next_tx(admin);
    {
        let original_pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        test_utils::destroy(original_pool);

        // Create a new pool
        let pool_sqrt_price: u128 = 1 << 64; // Price = 1
        setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 2);
    };

    // 3. Attempt to distribute the gauge using the new (wrong) pool
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut new_pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter.distribute_gauge<USD_TESTS, AUSD, USD_TESTS, SAIL, SAIL, OSAIL1>(
            &mut voter,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut new_pool,
            gauge_base_emissions,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(price_monitor);
        test_scenario::return_shared(sail_stablecoin_pool);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(new_pool);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = distribute_cap::EValidateDistributeInvalidVoter)]
fun test_update_period_with_wrong_voter_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        1_000_000,
        0
    );

    // 2. Distribute gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 4. Create a "wrong" voter
    let wrong_voter_id: ID;
    scenario.next_tx(admin);
    {
        let voter_publisher = voter::test_init(scenario.ctx());
        let global_config = scenario.take_shared<GlobalConfig>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let (wrong_voter, wrong_distribute_cap) = voter::create(
            &voter_publisher,
            object::id(&global_config),
            object::id(&distribution_config),
            scenario.ctx()
        );
        wrong_voter_id = object::id(&wrong_voter);

        test_utils::destroy(wrong_distribute_cap);
        test_utils::destroy(voter_publisher);
        transfer::public_share_object(wrong_voter);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
    };

    // 5. Attempt to update period with the wrong voter
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_voter = scenario.take_shared_by_id<Voter>(wrong_voter_id);
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut o_sail_cap_2 = coin::create_treasury_cap_for_testing<OSAIL2>(scenario.ctx());
        let initial_supply = o_sail_cap_2.mint(0, scenario.ctx());
        initial_supply.burn_for_testing();

        minter::update_period_test<SAIL, OSAIL2>(
            &mut minter,
            &mut wrong_voter,
            &distribution_config,
            &distribute_governor_cap,
            &voting_escrow,
            &mut rebase_distributor,
            o_sail_cap_2,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(rebase_distributor);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EUpdatePeriodDistributionConfigInvalid)]
fun test_update_period_with_wrong_distribution_config_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        1_000_000,
        0
    );

    // 2. Distribute gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 4. Create a "wrong" distribution config
    scenario.next_tx(admin);
    {
        let correct_dist_config = scenario.take_shared<DistributionConfig>();
        test_utils::destroy(correct_dist_config);
        distribution_config::test_init(scenario.ctx());
    };

    // 5. Attempt to update period with the wrong config
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let wrong_distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut o_sail_cap_2 = coin::create_treasury_cap_for_testing<OSAIL2>(scenario.ctx());
        let initial_supply = o_sail_cap_2.mint(0, scenario.ctx());
        initial_supply.burn_for_testing();

        minter::update_period_test<SAIL, OSAIL2>(
            &mut minter,
            &mut voter,
            &wrong_distribution_config,
            &distribute_governor_cap,
            &voting_escrow,
            &mut rebase_distributor,
            o_sail_cap_2,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(wrong_distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(rebase_distributor);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckDistributeGovernorRevoked)]
fun test_update_period_with_revoked_governor_cap_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        1_000_000,
        0
    );

    // 2. Distribute gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Revoke the DistributeGovernorCap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let publisher = minter::test_init(scenario.ctx());

        minter::revoke_distribute_governor(&mut minter, &publisher, object::id(&governor_cap));

        test_utils::destroy(publisher);
        scenario.return_to_sender(governor_cap);
        test_scenario::return_shared(minter);
    };

    // 4. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 5. Attempt to update period with the revoked cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut o_sail_cap_2 = coin::create_treasury_cap_for_testing<OSAIL2>(scenario.ctx());
        let initial_supply = o_sail_cap_2.mint(0, scenario.ctx());
        initial_supply.burn_for_testing();

        minter::update_period_test<SAIL, OSAIL2>(
            &mut minter,
            &mut voter,
            &distribution_config,
            &distribute_governor_cap,
            &voting_escrow,
            &mut rebase_distributor,
            o_sail_cap_2,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(rebase_distributor);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = distribute_cap::EValidateDistributeInvalidVoter)]
fun test_activate_with_wrong_voter_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup without activating the minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);

    // 2. Create a "wrong" voter
    let wrong_voter_id: ID;
    scenario.next_tx(admin);
    {
        let voter_publisher = voter::test_init(scenario.ctx());
        let global_config = scenario.take_shared<GlobalConfig>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let (wrong_voter, wrong_distribute_cap) = voter::create(
            &voter_publisher,
            object::id(&global_config),
            object::id(&distribution_config),
            scenario.ctx()
        );
        wrong_voter_id = object::id(&wrong_voter);

        test_utils::destroy(wrong_distribute_cap);
        test_utils::destroy(voter_publisher);
        transfer::public_share_object(wrong_voter);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
    };
    
    // 3. Attempt to activate with the wrong voter
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut wrong_voter = scenario.take_shared_by_id<Voter>(wrong_voter_id);
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut o_sail_cap = coin::create_treasury_cap_for_testing<OSAIL1>(scenario.ctx());
        o_sail_cap.mint(0, scenario.ctx()).burn_for_testing();
        
        minter.activate_test<SAIL, OSAIL1>(
            &mut wrong_voter,
            &admin_cap,
            &mut rebase_distributor,
            o_sail_cap,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(wrong_voter);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(rebase_distributor);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_activate_with_revoked_admin_cap_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup without activating the minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);

    // 2. Revoke the AdminCap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());

        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));

        test_utils::destroy(publisher);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
    };

    // 3. Attempt to activate with the revoked cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut o_sail_cap = coin::create_treasury_cap_for_testing<OSAIL1>(scenario.ctx());
        o_sail_cap.mint(0, scenario.ctx()).burn_for_testing();
        
        minter.activate_test<SAIL, OSAIL1>(
            &mut voter,
            &admin_cap,
            &mut rebase_distributor,
            o_sail_cap,
            &clock,
            scenario.ctx()
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(rebase_distributor);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EActivateMinterAlreadyActive)]
fun test_double_activation_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup and activate the minter for the first time
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    // 2. Attempt to activate the minter again
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EScheduleSailMintPublisherInvalid)]
fun test_schedule_sail_mint_with_wrong_publisher_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution (but don't activate minter yet)
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // Create a publisher from the voter module instead of minter module
        let mut wrong_publisher = voter::test_init(scenario.ctx());
        
        // This should fail because we're using a publisher from the wrong module
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut wrong_publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(wrong_publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EScheduleSailMintAmountZero)]
fun test_schedule_sail_mint_with_zero_amount_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // Create a valid publisher from the minter module
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because we're passing zero amount
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut publisher,
            0, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExecuteSailMintStillLocked)]
fun test_execute_sail_mint_before_unlock_time_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Schedule a SAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Immediately try to execute the mint without waiting for unlock time
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should fail because not enough time has passed (need 1 day)
        let sail_coin = minter.execute_sail_mint(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExecuteSailMintStillLocked)]
fun test_execute_sail_mint_one_millisecond_before_unlock_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Schedule a SAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Advance time by 24 hours - 1 millisecond (still 1ms short of unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms - 1); // 1ms short

    // Try to execute the mint (should fail as it's still 1ms too early)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should fail because we're still 1ms short of the unlock time
        let sail_coin = minter.execute_sail_mint(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_execute_sail_mint_after_unlock_time_succeeds() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    let mint_amount = 1_000_000;

    // Schedule a SAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Advance time by exactly 24 hours (unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms);

    // Execute the mint (should succeed now)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should succeed because exactly 24 hours have passed
        let sail_coin = minter.execute_sail_mint(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Verify the minted amount is exactly what was scheduled
        assert!(sail_coin.value() == mint_amount, 0);
        
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_cancel_sail_mint_no_tokens_minted() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    let mint_amount = 1_000_000;

    // Record initial SAIL total supply
    let initial_supply: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        initial_supply = minter.sail_total_supply();
        test_scenario::return_shared(minter);
    };

    // Schedule a SAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &distribution_config,
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Cancel the mint
    scenario.next_tx(admin);
    {
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // Cancel the mint - this should not mint any tokens
        minter::cancel_sail_mint<SAIL>(&minter, time_locked_mint);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Verify SAIL total supply hasn't changed
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let final_supply = minter.sail_total_supply();
        
        // Total supply should remain exactly the same
        assert!(final_supply == initial_supply, 0);
        
        test_scenario::return_shared(minter);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EScheduleOSailMintPublisherInvalid)]
fun test_schedule_o_sail_mint_with_wrong_publisher_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter to have valid oSAIL
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        
        // Create a publisher from the voter module instead of minter module
        let mut wrong_publisher = voter::test_init(scenario.ctx());
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should fail because we're using a publisher from the wrong module
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut wrong_publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(wrong_publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EScheduleOSailMintAmountZero)]
fun test_schedule_o_sail_mint_with_zero_amount_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter to have valid oSAIL
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because we're passing zero amount
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            0, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EScheduleOSailMintInvalidOSail)]
fun test_schedule_o_sail_mint_with_invalid_o_sail_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution but don't activate minter, so OSAIL1 is not valid
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because OSAIL1 is not a valid oSAIL type (minter not activated)
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExecuteOSailMintStillLocked)]
fun test_execute_o_sail_mint_before_unlock_time_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    // Schedule an oSAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Immediately try to execute the mint without waiting for unlock time
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should fail because not enough time has passed (need 1 day)
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(distribution_config);
        // Cleanup - these lines won't be reached if the test fails as expected
        o_sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExecuteOSailMintStillLocked)]
fun test_execute_o_sail_mint_one_millisecond_before_unlock_fails() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    // Schedule an oSAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Advance time by 24 hours - 1 millisecond (still 1ms short of unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms - 1); // 1ms short

    // Try to execute the mint (should fail as it's still 1ms too early)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should fail because we're still 1ms short of the unlock time
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        o_sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_execute_o_sail_mint_after_unlock_time_succeeds() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    let mint_amount = 1_000_000;

    // Schedule an oSAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Advance time by exactly 24 hours (unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms);

    // Execute the mint (should succeed now)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // This should succeed because exactly 24 hours have passed
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Verify the minted amount is exactly what was scheduled
        assert!(o_sail_coin.value() == mint_amount, 0);
        
        o_sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_cancel_o_sail_mint_no_tokens_minted() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup distribution and activate minter
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 0, &mut clock);
        o_sail_coin.burn_for_testing();
    };

    let mint_amount = 1_000_000;

    // Record initial oSAIL total supply
    let initial_o_sail_supply: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        initial_o_sail_supply = minter.o_sail_minted_supply();
        test_scenario::return_shared(minter);
    };

    // Schedule an oSAIL mint
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &distribution_config,
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Cancel the mint
    scenario.next_tx(admin);
    {
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        
        // Cancel the mint - this should not mint any tokens
        minter::cancel_o_sail_mint(&distribution_config, time_locked_mint);
        test_scenario::return_shared(distribution_config);
    };

    // Verify oSAIL total supply hasn't changed
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let final_o_sail_supply = minter.o_sail_minted_supply();
        
        // Total supply should remain exactly the same
        assert!(final_o_sail_supply == initial_o_sail_supply, 0);
        
        test_scenario::return_shared(minter);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_earned_on_position_without_minter_activation_succeeds() {
    // 1. Setup
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup CLMM factory
    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);

    // Setup distribution without activating minter
    scenario.next_tx(admin);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Setup pool
    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    
    // 2. Create gauge
    scenario.next_tx(admin);
    let gauge_base_emissions = 1_000_000;
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);

    // 3. User creates a position
    scenario.next_tx(user);
    setup::create_position_with_liquidity<USD_TESTS, AUSD>(
        &mut scenario,
        user,
        tick_math::min_tick().as_u32(),
        tick_math::max_tick().as_u32(),
        1000000,
        &clock
    );

    // 4. User deposits the position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 5. Call earned
    scenario.next_tx(user);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        let earned_amount = minter::earned_by_position<USD_TESTS, AUSD, SAIL, OSAIL1>(&minter, &gauge, &pool, staked_position.position_id(), &clock);

        assert!(earned_amount == 0, 0);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    // 6. Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_get_position_reward_with_cooldown_zero_reward() {
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
        1000000,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // set liquidity_update_cooldown to 600 seconds
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        
        minter.set_liquidity_update_cooldown<SAIL>(
            &admin_cap,
            &mut distribution_config,
            600 // 600 seconds cooldown
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
    };

    // try to claim rewards immediately - should return zero because cooldown hasn't passed
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // USD_TESTS is not a valid reward token
        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        assert!(coin::value(&reward) == 0, 0);

        coin::burn_for_testing(reward);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);      
    };

    // increment time by 600 seconds (600000 milliseconds) to pass the cooldown
    clock.increment_for_testing(600 * 1000);

    // now claim rewards again - should succeed because cooldown has passed
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        // reward should be greater than zero now that cooldown has passed
        assert!(coin::value(&reward) == 992, 1);

        sui::transfer::public_transfer(reward, scenario.ctx().sender());

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
    };

    // new create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000000,
            &clock
        );
    };

    // new deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    clock.increment_for_testing(600 * 1000);

    // now claim rewards again - should succeed because cooldown has passed
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position2 = scenario.take_from_sender<StakedPosition>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        // reward should be greater than zero now that cooldown has passed
        assert!(coin::value(&reward) == 495 || coin::value(&reward) == 496, 325234);

        sui::transfer::public_transfer(reward, scenario.ctx().sender());

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
        scenario.return_to_sender(position2);
    };

    // decrease liquidity by half (500000 out of 1000000) directly on staked position
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position2 = scenario.take_from_sender<StakedPosition>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        
        let liquidity_to_remove = 1000000/2; // half of initial liquidity
        let (balance_a, balance_b) = gauge::decrease_liquidity<USD_TESTS, AUSD>(
            &mut gauge,
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            &staked_position,
            liquidity_to_remove,
            &clock,
            scenario.ctx()
        );

        // destroy the returned balances
        test_utils::destroy(balance_a);
        test_utils::destroy(balance_b);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
        scenario.return_to_sender(staked_position2);
    };

    // increment time by 300 seconds - cooldown hasn't passed yet
    clock.increment_for_testing(300 * 1000);

    // try to claim rewards after 300 seconds - should return zero because cooldown hasn't passed
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position2 = scenario.take_from_sender<StakedPosition>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        // reward should be zero because cooldown hasn't passed yet
        assert!(coin::value(&reward) == 0, 2);

        coin::burn_for_testing(reward);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
        scenario.return_to_sender(position2);
    };

    // increment time by another 300 seconds - cooldown should have passed now
    clock.increment_for_testing(300 * 1000);

    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position2 = scenario.take_from_sender<StakedPosition>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        let reward_value = coin::value(&reward);
        assert!(reward_value == 495*2/3 || reward_value == 496*2/3, 3);

        sui::transfer::public_transfer(reward, scenario.ctx().sender());

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
        scenario.return_to_sender(position2);
    };

    clock.increment_for_testing(600 * 1000);

    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let position2 = scenario.take_from_sender<StakedPosition>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            &clock,
            scenario.ctx()
        );

        let reward_value = coin::value(&reward);
        assert!(reward_value == 495*2/3 || reward_value == 496*2/3, 3);

        sui::transfer::public_transfer(reward, scenario.ctx().sender());

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
        scenario.return_to_sender(position2);
    };

    // --- Test get_pool_reward with cooldown ---
    // Add rewards to the pool rewarder vault
    scenario.next_tx(admin);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        
        let reward_amount = 10000000000u64;
        let reward_coin = coin::mint_for_testing<USD_TESTS>(reward_amount, scenario.ctx());
        
        clmm_pool::rewarder::deposit_reward<USD_TESTS>(
            &global_config,
            &mut vault,
            reward_coin.into_balance()
        );
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
    };

    // Initialize rewarder for USD_TESTS in the pool
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

    // Update emission to start distributing rewards
    scenario.next_tx(admin);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        
        let emissions_per_second = 10<<64; // some emission rate
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

    clock.increment_for_testing(100 * 1000);

    // Try to claim pool reward immediately after deposit - should return zero because cooldown hasn't passed
    scenario.next_tx(user);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        gauge.test_update_reward_profile(&staked_position, clock.timestamp_ms() / 1000);
        
        let reward_balance = gauge::get_pool_reward<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock
        );
        
        // reward should be zero because cooldown hasn't passed
        assert!(sui::balance::value(&reward_balance) == 0, 4);
        
        sui::balance::destroy_zero(reward_balance);
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
    };

    clock.increment_for_testing(100 * 1000);

    // set unrestricted address to user
    scenario.next_tx(admin);
    {
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let publisher = scenario.take_from_sender<Publisher>();
        
        distribution_config.add_unrestricted_address(&publisher,  user);

        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(publisher);
    };

    // Try to claim pool reward after setting unrestricted address - should return non-zero reward
    scenario.next_tx(user);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        gauge.test_update_reward_profile(&staked_position, clock.timestamp_ms() / 1000);

        
        let reward_balance = gauge::get_pool_reward_v2<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        
        // reward should be non-zero because unrestricted address
        assert!(sui::balance::value(&reward_balance) == 666, 4);
        
        let reward_coin = coin::from_balance(reward_balance, scenario.ctx());
        sui::transfer::public_transfer(reward_coin, scenario.ctx().sender());

        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
    };

    // remove unrestricted address from user
    scenario.next_tx(admin);
    {
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let publisher = scenario.take_from_sender<Publisher>();
        
        distribution_config.remove_unrestricted_address(&publisher,  user);

        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(publisher);
    };

    clock.increment_for_testing(300 * 1000);

    // Try to claim pool reward after removing unrestricted address - should return zero because cooldown hasn't passed
    scenario.next_tx(user);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        gauge.test_update_reward_profile(&staked_position, clock.timestamp_ms() / 1000);

        
        let reward_balance = gauge::get_pool_reward_v2<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        
        // reward should be zero because cooldown hasn't passed
        assert!(sui::balance::value(&reward_balance) == 0, 4);
        
        sui::balance::destroy_zero(reward_balance);
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
    };

    // increment time by 600 seconds - cooldown should have passed now
    clock.increment_for_testing(600 * 1000);

    // Now claim pool reward - should succeed because cooldown has passed
    scenario.next_tx(user);
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
        
        // reward should be greater than zero now that cooldown has passed
        let reward_value = sui::balance::value(&reward_balance);
        assert!(reward_value == 3999, 5);
        
        let reward_coin = coin::from_balance(reward_balance, scenario.ctx());
        sui::transfer::public_transfer(reward_coin, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(staked_position);
    };

    clock.increment_for_testing(600 * 1000);

    scenario.next_tx(user);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        
        let reward_balance = gauge::get_pool_reward<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock
        );
        
        // reward should be greater than zero now that cooldown has passed
        let reward_value = sui::balance::value(&reward_balance);
        assert!(reward_value == 3999, 5);
        
        let reward_coin = coin::from_balance(reward_balance, scenario.ctx());
        sui::transfer::public_transfer(reward_coin, scenario.ctx().sender());

        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        let position = gauge.withdraw_position_v2<USD_TESTS, AUSD>(
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            staked_position,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(position, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // decrease liquidity to update the second position counter
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();

        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());
        
        let liquidity_to_remove = 1000000/5; 
        let (balance_a, balance_b) = gauge::decrease_liquidity<USD_TESTS, AUSD>(
            &mut gauge,
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            &staked_position,
            liquidity_to_remove,
            &clock,
            scenario.ctx()
        );

        // destroy the returned balances
        test_utils::destroy(balance_a);
        test_utils::destroy(balance_b);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(staked_position);
    };

    clock.increment_for_testing(300 * 1000);

    // closing position without rewards
    scenario.next_tx(user);
    {
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        
        let reward_balance = gauge::get_pool_reward<USD_TESTS, AUSD, USD_TESTS>(
            &global_config,
            &mut vault,
            &mut gauge,
            &distribution_config,
            &mut pool,
            &staked_position,
            &clock
        );
        
        // reward should be greater than zero now that cooldown has passed
        let reward_value = sui::balance::value(&reward_balance);
        assert!(reward_value == 0, 5);
        
        let reward_coin = coin::from_balance(reward_balance, scenario.ctx());
        sui::transfer::public_transfer(reward_coin, scenario.ctx().sender());

        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        let position = gauge.withdraw_position_v2<USD_TESTS, AUSD>(
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            staked_position,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(position, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // claim unclaimed o_sail
    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        
        let osail_reward = minter.claim_unclaimed_o_sail<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &admin_cap,
            &mut gauge,
            scenario.ctx()
        );

        assert!(osail_reward.value() == 496, 5);
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_early_withdrawal_penalty_distributed_to_voters() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let initial_liquidity = 15_000_000; // Increased to ensure penalty exceeds epochCoinPerSecond (604800)
    let penalty_percentage = 500; // 5% = 500 / 10000

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        initial_liquidity,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            initial_liquidity as u128,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // set liquidity_update_cooldown to 600 seconds and early withdrawal penalty to 5%
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        
        minter.set_liquidity_update_cooldown<SAIL>(
            &admin_cap,
            &mut distribution_config,
            600 // 600 seconds cooldown
        );
        
        minter.set_early_withdrawal_penalty_percentage<SAIL>(
            &admin_cap,
            &mut distribution_config,
            penalty_percentage // 5% penalty
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
    };

    // Get initial position liquidity before withdrawal
    let initial_position_liquidity: u128;
    scenario.next_tx(user);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        
        initial_position_liquidity = gauge.position_liquidity<USD_TESTS, AUSD>(&staked_position);
        
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(staked_position);
    };

    // Calculate expected penalty: liquidity * penalty_percentage / multiplier
    let expected_penalty_liquidity = (initial_position_liquidity * (penalty_percentage as u128)) / (governance::distribution_config::get_early_withdrawal_penalty_multiplier() as u128);
    let expected_final_liquidity = initial_position_liquidity - expected_penalty_liquidity;

    // withdraw position early (before cooldown expires) - penalty should be collected
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        // Claim rewards first (required before withdrawal)
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        // Withdraw position early - penalty should be collected
        let position = gauge.withdraw_position_v2<USD_TESTS, AUSD>(
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            staked_position,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(position, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // Verify that position liquidity decreased by penalty amount
    scenario.next_tx(user);
    {
        let position = scenario.take_from_sender<clmm_pool::position::Position>();
        let final_liquidity = position.liquidity();
        
        // Position liquidity should be reduced by the penalty amount
        // Allow small rounding differences (within 1 unit)
        assert!(final_liquidity == expected_final_liquidity, 10);
        
        // Verify penalty was actually applied (liquidity decreased)
        assert!(final_liquidity < initial_position_liquidity, 12);
        
        // Calculate actual penalty applied
        let actual_penalty = initial_position_liquidity - final_liquidity;
        // Actual penalty should be close to expected (within rounding tolerance)
        assert!(actual_penalty == expected_penalty_liquidity, 13);
        
        scenario.return_to_sender(position);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);

    // Vote for the pool with the user's lock (before distribute_gauge to make fees claimable)
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, &mut clock);
    };

    // Store the epoch when the vote was cast
    let vote_epoch: u64;
    scenario.next_tx(user);
    {
        vote_epoch = common::current_period(&clock);
    };

    // Advance by 1 epoch
    clock.increment_for_testing(WEEK);

    // Get epoch 2 start timestamp (before updating minter period)
    let epoch_2: u64;
    scenario.next_tx(user);
    {
        epoch_2 = common::current_period(&clock);
    };

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Get the lock ID for updating weights
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };
    
    // Finalize voted weights for epoch 1 (when vote was cast)
    // Fees distributed in epoch 2 will use voting power from epoch 1
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch, // Epoch 1 start timestamp (finished epoch)
        admin,
        &clock,
    );
    
    // Note: We don't finalize epoch 2 because it's still current (not finished)
    // Fees distributed in epoch 2 will use voting power from epoch 1

    // Inject some fees to ensure fees are distributed (fees are distributed only if amount > epochCoinPerSecond)
    // This helps ensure the penalty fees will also be distributed
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, 1_000_000, &clock);
    };

    // Check fee balance in gauge BEFORE distribute_gauge
    let fee_balance_before_a: u64;
    let fee_balance_before_b: u64;
    scenario.next_tx(admin);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool_id = object::id(&pool);
        let gauge_id = voter::pool_to_gauge(&voter, pool_id);
        
        fee_balance_before_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        fee_balance_before_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);
        
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    // Distribute gauge in epoch 2 to make penalty fees available for voters
    // This should distribute the penalty fees that were collected during early withdrawal
    // Note: fees are distributed only if their amount > epochCoinPerSecond (604800)
    // With increased liquidity (15M), penalty should be 750K liquidity, which combined with injected fees should be enough
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Check fee balance in gauge AFTER distribute_gauge
    let fee_balance_after_a: u64;
    let fee_balance_after_b: u64;
    scenario.next_tx(admin);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool_id = object::id(&pool);
        let gauge_id = voter::pool_to_gauge(&voter, pool_id);
        
        fee_balance_after_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        fee_balance_after_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);
        // Verify that fees were distributed (balance increased)
        assert!(fee_balance_after_a > fee_balance_before_a || fee_balance_after_b > fee_balance_before_b, 18);
        
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    // Advance by 1 more epoch to epoch 3 (for claiming rewards)
    // We need to advance first, so epoch 2 becomes finished
    clock.increment_for_testing(WEEK);

    // Finalize voted weights for epoch 2 (where fees were distributed)
    // Now epoch 2 is finished, so we can finalize it
    // This is required before claiming rewards in epoch 3
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        epoch_2, // Epoch 2 start timestamp (now finished epoch)
        admin,
        &clock,
    );

    // Update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // Verify that fees were distributed to fee_voting_reward before claiming
    scenario.next_tx(admin);
    {
        let voter = scenario.take_shared<Voter>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);
        
        // Check that fees are available in fee_voting_reward (should include penalty + injected fees)
        let fee_balance_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        let fee_balance_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);
        
        // Fees should be available (penalty + injected fees were distributed)
        assert!(fee_balance_a > 0 || fee_balance_b > 0, 19);
        
        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
    };

    // Check fee balance and earned amount before claiming
    scenario.next_tx(user);
    {
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool_id = object::id(&pool);
        let gauge_id = voter::pool_to_gauge(&voter, pool_id);
        
        let fee_balance_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        let fee_balance_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);

        // Check gauge weight (voting power)
        let gauge_weight = voter::get_gauge_weight(&voter, gauge_id);
        
        // Verify that fees are available in fee_voting_reward
        assert!(fee_balance_a > 0 || fee_balance_b > 0, 19);
        
        // Verify that gauge has voting weight (user voted for it)
        assert!(gauge_weight > 0, 22);
        
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    // Claim voting fee rewards with the user's lock - should receive the penalty
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool);
    };

    // Verify the user received the penalty as rewards
    // claim_voting_fee_by_pool calls claim_voting_fee twice - once for each token type
    // So we should receive two coins: USD_TESTS and AUSD
    // Expected: 
    // - USD_TESTS: penalty (749999) + injected fees (1000000) = 1749999
    // - AUSD: penalty (749999) only (no injected fees for AUSD)
    let expected_penalty_amount_usd = 1749999; // penalty + injected fees
    let expected_penalty_amount_ausd = 749999; // penalty only
    
    scenario.next_tx(user);
    {
        // First coin (USD_TESTS) - claim_voting_fee_by_pool calls claim_voting_fee for CoinTypeA first
        let reward_coin_a = scenario.take_from_sender<Coin<USD_TESTS>>();
        let received_a = coin::value(&reward_coin_a);
        
        // Verify that received amount includes penalty (749999) + injected fees (1000000)
        assert!(received_a == expected_penalty_amount_usd, 20);
        
        // Also verify that penalty is included (at least 749999)
        assert!(received_a >= 749999, 23);
        
        reward_coin_a.burn_for_testing();
    };
    
    scenario.next_tx(user);
    {
        // Second coin (AUSD) - claim_voting_fee_by_pool calls claim_voting_fee for CoinTypeB second
        let reward_coin_b = scenario.take_from_sender<Coin<AUSD>>();
        let received_b = coin::value(&reward_coin_b);
        
        // Verify exact penalty amount for AUSD (no injected fees for AUSD)
        assert!(received_b == expected_penalty_amount_ausd, 21);
        
        reward_coin_b.burn_for_testing();
    };


    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_no_penalty_after_cooldown() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let initial_liquidity = 10_000_000;
    let cooldown_seconds = 600; // 600 seconds cooldown
    let penalty_percentage = 500; // 5% = 500 / 10000

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        initial_liquidity,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            initial_liquidity as u128,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // set liquidity_update_cooldown to 600 seconds and early withdrawal penalty to 5%
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        
        minter.set_liquidity_update_cooldown<SAIL>(
            &admin_cap,
            &mut distribution_config,
            cooldown_seconds // 600 seconds cooldown
        );
        
        minter.set_early_withdrawal_penalty_percentage<SAIL>(
            &admin_cap,
            &mut distribution_config,
            penalty_percentage // 5% penalty
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
    };

    // Get initial position liquidity before withdrawal
    let initial_position_liquidity: u128;
    scenario.next_tx(user);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        
        initial_position_liquidity = gauge.position_liquidity<USD_TESTS, AUSD>(&staked_position);
        
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(staked_position);
    };

    // Wait for cooldown to expire (wait more than cooldown_seconds)
    // cooldown_seconds = 600 seconds = 600 * 1000 milliseconds
    clock.increment_for_testing((cooldown_seconds + 100) * 1000); // Wait 700 seconds to ensure cooldown expired

    // withdraw position after cooldown expires - no penalty should be collected
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        // Claim rewards first (required before withdrawal)
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        // Withdraw position after cooldown - no penalty should be collected
        let position = gauge.withdraw_position_v2<USD_TESTS, AUSD>(
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            staked_position,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(position, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // Verify that position liquidity did NOT decrease (no penalty applied)
    scenario.next_tx(user);
    {
        let position = scenario.take_from_sender<clmm_pool::position::Position>();
        let final_liquidity = position.liquidity();
        
        // Position liquidity should be equal to initial liquidity (no penalty)
        // Allow small rounding differences (within 1 unit)
        assert!(final_liquidity == initial_position_liquidity, 30);
        
        scenario.return_to_sender(position);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_no_penalty_for_unrestricted_address() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let initial_liquidity = 10_000_000;
    let cooldown_seconds = 600; // 600 seconds cooldown
    let penalty_percentage = 500; // 5% = 500 / 10000

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        initial_liquidity,
        182,
        gauge_base_emissions,
        0
    );

    // distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // create and deposit position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            initial_liquidity as u128,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // set liquidity_update_cooldown to 600 seconds and early withdrawal penalty to 5%
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        
        minter.set_liquidity_update_cooldown<SAIL>(
            &admin_cap,
            &mut distribution_config,
            cooldown_seconds // 600 seconds cooldown
        );
        
        minter.set_early_withdrawal_penalty_percentage<SAIL>(
            &admin_cap,
            &mut distribution_config,
            penalty_percentage // 5% penalty
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
    };

    // Add user to unrestricted addresses list
    scenario.next_tx(admin);
    {
        let mut distribution_config = scenario.take_shared<DistributionConfig>();
        let publisher = scenario.take_from_sender<Publisher>();
        
        distribution_config.add_unrestricted_address(&publisher, user);

        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(publisher);
    };

    // Get initial position liquidity before withdrawal
    let initial_position_liquidity: u128;
    scenario.next_tx(user);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();
        
        initial_position_liquidity = gauge.position_liquidity<USD_TESTS, AUSD>(&staked_position);
        
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(staked_position);
    };

    // Withdraw position BEFORE cooldown expires - no penalty should be collected because user is unrestricted
    scenario.next_tx(user);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let global_config = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let mut vault = scenario.take_shared<clmm_pool::rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let staked_position = scenario.take_from_sender<StakedPosition>();

        // Claim rewards first (required before withdrawal)
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let osail_reward = minter.get_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &staked_position,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_transfer(osail_reward, scenario.ctx().sender());

        // Withdraw position before cooldown - no penalty should be collected because user is unrestricted
        let position = gauge.withdraw_position_v2<USD_TESTS, AUSD>(
            &distribution_config,
            &global_config,
            &mut vault,
            &mut pool,
            staked_position,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(position, scenario.ctx().sender());
        
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(vault);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(minter);
    };

    // Verify that position liquidity did NOT decrease (no penalty applied because user is unrestricted)
    scenario.next_tx(user);
    {
        let position = scenario.take_from_sender<clmm_pool::position::Position>();
        let final_liquidity = position.liquidity();
        
        // Position liquidity should be equal to initial liquidity (no penalty)
        assert!(final_liquidity == initial_position_liquidity, 40);
        
        scenario.return_to_sender(position);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
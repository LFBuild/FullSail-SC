#[test_only]
module distribution::minter_tests;

use distribution::minter;
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
use sui::test_utils;

use distribution::common;
use distribution::distribute_cap::{Self, DistributeCap};
use distribution::distribution_config::{Self, DistributionConfig};
use distribution::gauge::{Self, Gauge};
use gauge_cap::gauge_cap::{Self, CreateCap};
use distribution::minter::{AdminCap, Minter, ECreateGaugeMinterNotActive, ECheckAdminRevoked};
use distribution::reward_distributor;
use distribution::reward_distributor_cap;
use distribution::voter::{Self, Voter};
use distribution::voting_escrow::{Self, VotingEscrow};
use std::option;
use distribution::setup;
use distribution::voter::ECreateGaugePoolAlreadyHasGauge;
use sui::sui::SUI;

public struct USD1 has drop {}
public struct AUSD has drop {}
public struct SAIL has drop, store {}
public struct OSAIL has drop, store {}

fun setup_for_gauge_creation(scenario: &mut test_scenario::Scenario, admin: address, clock: &mut Clock) {
    setup::setup_clmm_factory_with_fee_tier(scenario, admin, 1, 1000);

    scenario.next_tx(admin);
    setup::setup_distribution<SAIL>(scenario, admin, clock);

    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    setup::setup_pool_with_sqrt_price<USD1, AUSD>(scenario, pool_sqrt_price, 1);
    
    scenario.next_tx(admin);
    setup::activate_minter<SAIL>(scenario, clock);
}

#[test]
fun test_minter_calculate_next_pool_emissions() {
    let max_growth_small_inputs = minter::calculate_next_pool_emissions(
        100,
        2,
        1,
        2,
        2,
        1,
        2
    );
    assert!(110 - max_growth_small_inputs <= 1, 1);

    let max_decrease_small_inputs = minter::calculate_next_pool_emissions(
        100,
        2,
        2,
        2,
        1,
        2,
        1
    );
    assert!(90 - max_decrease_small_inputs <= 1, 2);

    let max_growth_large_inputs = minter::calculate_next_pool_emissions(
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000
    );
    assert!(1_100_000_000_000_000_000 - max_growth_large_inputs <= 1, 3);

    let max_decrease_large_inputs = minter::calculate_next_pool_emissions(
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000,
        1_000_000_000_000_000_000
    );
    assert!(900_000_000_000_000_000 - max_decrease_large_inputs <= 1, 4);

     let max_growth_extra_large_inputs = minter::calculate_next_pool_emissions(
        1<<62,
        1<<62,
        1<<62,
        1<<62,
        1<<63,
        1<<62,
        1<<63
    );
    assert!(5072854620270126694 - max_growth_extra_large_inputs <= 1, 3);

    let max_decrease_extra_large_inputs = minter::calculate_next_pool_emissions(
        1<<62,
        1<<62,
        1<<63,
        1<<62,
        1<<62,
        1<<63,
        1<<62
    );
    assert!(4150517416584649114 - max_decrease_extra_large_inputs <= 1, 4);

    let max_growth_roe_large_numbers = minter::calculate_next_pool_emissions(
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000
    );
    assert!(1_100_000_000_000_000_000 - max_growth_roe_large_numbers <= 1, 5);

    let max_growth_vol_large_numbers = minter::calculate_next_pool_emissions(
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        1_000_000_000_000_000_000,
        2_000_000_000_000_000_000
    );
    assert!(1_100_000_000_000_000_000 - max_growth_vol_large_numbers <= 1, 6);

    let max_growth_roe_small_numbers = minter::calculate_next_pool_emissions(
        100,
        1,
        1,
        1,
        2,
        1,
        1
    );
    assert!(110 - max_growth_roe_small_numbers <= 1, 7);

    let max_growth_vol_small_numbers = minter::calculate_next_pool_emissions(
        100,
        1,
        1,
        1,
        2,
        1,
        1
    );
    assert!(110 - max_growth_vol_small_numbers <= 1, 8);

    // 10% in roe increase should result in 5% emissions increase
    let roe_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_100_000,
        1_000_000,
        1_000_000
    );
    assert!(1_050_000 - roe_increase_10 <= 1, 9);

    // 10% in vol increase should result in 5% emissions increase
    let vol_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_100_000
    );
    assert!(1_050_000 - vol_increase_10 <= 1, 10);

    // 10% in roe increase and 10% in vol increase should result in 10% emissions increase
    let roe_increase_10_vol_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_100_000,
        1_000_000,
        1_100_000
    );
    assert!(1_100_000 - roe_increase_10_vol_increase_10 <= 1, 11);

    // 5% in roe increase and 5% in vol increase should result in 5% emissions increase
    let roe_increase_5_vol_increase_5 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_050_000,
        1_000_000,
        1_050_000
    );
    assert!(1_050_000 - roe_increase_5_vol_increase_5 <= 1, 12);

    // 5% in roe increase should result in 2.5% emissions increase
    let roe_increase_5 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_050_000,
        1_000_000,
        1_000_000
    );
    assert!(1_025_000 - roe_increase_5 <= 1, 13);

    // 5% in volume increase should result in 2.5% emissions increase
    let vol_increase_5 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_050_000
    );
    assert!(1_025_000 - vol_increase_5 <= 1, 14);

    // stable roe and vol should result in stable emissions
    let stable_roe_vol = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000
    );
    assert!(1_000_000 - stable_roe_vol <= 1, 15);

    // 10% in roe decrease should result in 5% emissions decrease
    let roe_decrease_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        900_000,
        1_000_000,
        1_000_000
    );
    assert!(950_000 - roe_decrease_10 <= 1, 16);

    // 10% in roe decrease and 10% in vol decrease should result in 10% emissions decrease
    let roe_decrease_10_vol_decrease_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        900_000,
        1_000_000,
        900_000
    );
    assert!(900_000 - roe_decrease_10_vol_decrease_10 <= 1, 17);

    // 5% in roe decrease should result in 2.5% emissions decrease
    let roe_decrease_5 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        950_000,
        1_000_000,
        1_000_000
    );
    assert!(975_000 - roe_decrease_5 <= 1, 18);

    // 5% in volume decrease should result in 2.5% emissions decrease
    let vol_decrease_5 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        950_000
    );
    assert!(975_000 - vol_decrease_5 <= 1, 19);

    // 10% in roe increase and 10% in vol decrease should result in stable emissions
    let roe_increase_10_vol_decrease_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_100_000,
        1_000_000,
        900_000
    );
    assert!(1_000_000 - roe_increase_10_vol_decrease_10 <= 1, 20);

    // 10% in roe decrease and 10% in vol increase should result in stable emissions
    let roe_decrease_10_vol_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        900_000,
        1_000_000,
        1_100_000
    );
    assert!(1_000_000 - roe_decrease_10_vol_increase_10 <= 1, 21);

    // 50% in roe increase and 50% in vol decrease should result in stable emissions
    let roe_increase_50_vol_decrease_50 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_500_000,
        1_000_000,
        500_000
    );
    assert!(1_000_000 - roe_increase_50_vol_decrease_50 <= 1, 22);

    // 10% in roe increase and 2% in vol decrease should result in 4% emissions increase
    let roe_increase_10_vol_decrease_2 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_100_000,
        1_000_000,
        980_000
    );
    assert!(1_040_000 - roe_increase_10_vol_decrease_2 <= 1, 23);

    // 2% in roe decrease and 10% in vol increase should result in 4% emissions increase
    let roe_decrease_2_vol_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        980_000,
        1_000_000,
        1_100_000
    );
    assert!(1_040_000 - roe_decrease_2_vol_increase_10 <= 1, 24);

    // 10% in roe decrease and 2% in vol increase should result in 4% emissions decrease
    let roe_decrease_10_vol_increase_2 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        900_000,
        1_000_000,
        1_020_000
    );
    assert!(960_000 - roe_decrease_10_vol_increase_2 <= 1, 25);

    // 2% in roe increase and 10% in vol decrease should result in 4% emissions decrease
    let roe_decrease_2_vol_increase_10 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1020_000,
        1_000_000,
        900_000
    );
    assert!(960_000 - roe_decrease_2_vol_increase_10 <= 1, 26);

    // 0.001% in roe increase should result in 0.0005% emissions increase
    let roe_increase_0_001 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_010,
        1_000_000,
        1_000_000
    );
    assert!(1_000_005 - roe_increase_0_001 <= 1, 27);

    // 0.001% in vol increase should result in 0.0005% emissions increase
    let vol_increase_0_001 = minter::calculate_next_pool_emissions(
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_000,
        1_000_010
    );
    assert!(1_000_005 - vol_increase_0_001 <= 1, 28);
}


#[test]
fun test_create_gauge_success() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);
    
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 100, &clock);
    
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, AUSD>>();
        let gauge_id = object::id(&gauge);
        let emissions = minter::borrow_pool_epoch_emissions(&minter);
        assert!(emissions.contains(gauge_id), 0);
        assert!(*emissions.borrow(gauge_id) == 100, 1);

        // total supply should be 0 as no emissions have been distributed yet
        assert!(minter.total_supply() == 0, 2);
        assert!(minter.o_sail_total_supply() == 0, 3);
        assert!(minter.sail_total_supply() == 0, 4);

        // epoch emissions should be 0 as no emissions have been distributed yet
        assert!(minter.epoch_emissions() == 0, 5);
        let current_epoch  = common::current_period(&clock);
        assert!(minter.emissions_by_epoch(current_epoch) == 0, 6);
        
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
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();

        let gauge = minter::create_gauge<USD1, AUSD, SAIL>(
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
        voter.revoke_gauge_create_cap(&voter_publisher, object::id<CreateCap>(&create_cap));
        test_utils::destroy(voter_publisher);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(create_cap);
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
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();

        let gauge = minter::create_gauge<USD1, AUSD, SAIL>(
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
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();

        let gauge = minter::create_gauge<USD1, AUSD, SAIL>(
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
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();

        let gauge = minter::create_gauge<USD1, AUSD, SAIL>(
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
        let wrong_ve = voting_escrow::create<SAIL>(
            &ve_publisher,
            voter_id,
            &clock,
            scenario.ctx()
        );
        
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
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();

        let gauge = minter::create_gauge<USD1, AUSD, SAIL>(
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
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 0, &clock);

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
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 100, &clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 100, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voter::ECreateGaugePoolAlreadyHasGauge)]
fun test_create_gauge_after_kill() {
    let admin = @0xA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    setup_for_gauge_creation(&mut scenario, admin, &mut clock);

    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 100, &clock);
    
    // kill the gauge
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD1, AUSD>>();
        let gauge_id = object::id(&gauge);

        let emergency_cap = voter::test_init_emergency_council(&voter, scenario.ctx());
        voter.kill_gauge<SAIL>(&mut dist_config, &emergency_cap, gauge_id);
        
        test_scenario::return_shared(voter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        transfer::public_transfer(emergency_cap, admin);
    };

    // try to create another gauge for the same pool
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD1, AUSD, SAIL>(&mut scenario, 100, &clock);

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_gauge_initial_amount() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;

    setup::full_setup_with_lock<USD1, AUSD, SAIL>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000000,
        182,
        gauge_base_emissions
    );
    
    // advance time to the next epoch
    scenario.next_tx(admin);
    {
        clock.increment_for_testing(common::week() + 1);
    };

    // update minter period
    scenario.next_tx(admin);
    {
        // the initial supply doesn't matter for this test
        let o_sail_coin = setup::update_minter_period<SAIL, OSAIL>(&mut scenario, 1000000, &clock);
        o_sail_coin.burn_for_testing();
    };

    // distribute the gauge
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, AUSD>>();
        let mut pool = scenario.take_shared<Pool<USD1, AUSD>>();
        let dist_config = scenario.take_shared<DistributionConfig>();
        let dist_gov_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();

        let distributed_amount = minter::distribute_gauge<USD1, AUSD, SAIL, SUI, OSAIL>(
            &mut minter,
            &mut voter,
            &dist_gov_cap,
            &dist_config,
            &mut gauge,
            &mut pool,
            0, 0, 0, 0, 0, 0,
            &clock,
            scenario.ctx()
        );

        assert!(distributed_amount == gauge_base_emissions, 0);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(dist_gov_cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}


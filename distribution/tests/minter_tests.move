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
use clmm_pool::tick_math;
use sui::test_utils;

use distribution::common;
use distribution::distribute_cap::{Self};
use distribution::distribution_config::{Self, DistributionConfig};
use distribution::rebase_distributor::{Self,RebaseDistributor};
use distribution::gauge::{Self, Gauge, StakedPosition};
use gauge_cap::gauge_cap::{Self, CreateCap};
use distribution::minter::{AdminCap, Minter};
use distribution::voter::{Self, Voter};
use distribution::voting_escrow::{Self, VotingEscrow, Lock};
use distribution::setup;
use sui::sui::SUI;
use distribution::emergency_council;

use switchboard::aggregator::{Self, Aggregator};
use price_monitor::price_monitor::{Self, PriceMonitor};

use distribution::usd_tests::{Self, USD_TESTS};

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
        let mut voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);

        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        transfer::public_transfer(emergency_cap, admin);
    };

    // try to create another gauge for the same pool
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
        distributed_amount = setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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

        // total supply should be 0 as no emissions have been distributed yet
        assert!(minter.total_supply() == 0, 2);
        assert!(minter.o_sail_minted_supply() == 0, 3);
        assert!(minter.sail_total_supply() == 0, 4);

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
#[expected_failure(abort_code = minter::EDistributeGaugeFirstEpochMetricsInvalid)]
fun test_distribute_gauge_initial_epoch_with_non_zero_metrics_fails() {
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

    // distribute the gauge with non-zero metrics
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
            &mut scenario,
            1_000_000, // prev_epoch_pool_emissions
            1_000_000, // prev_epoch_pool_fees_usd
            1_000_000, // epoch_pool_emissions_usd
            1_000_000, // epoch_pool_fees_usd
            1_000_000, // epoch_pool_volume_usd
            1_000_000, // epoch_pool_predicted_volume_usd
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
#[expected_failure(abort_code = minter::EDistributeGaugeMetricsInvalid)]
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
            0, // prev_epoch_pool_emissions
            0, // prev_epoch_pool_fees_usd
            0, // epoch_pool_emissions_usd
            0, // epoch_pool_fees_usd
            0, // epoch_pool_volume_usd
            0, // epoch_pool_predicted_volume_usd
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

    let mut aggregator = setup::setup_price_monitor_and_aggregator<SAIL, SAIL, USD_TESTS, SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64;
    setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, pool_sqrt_price, 1);
    
    scenario.next_tx(admin);
    setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);

    // Try to distribute the gauge, which should fail.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
            0,
            0,
            gauge_base_emissions,
            1_000_000, // not used in calculations for first epoch but are known values
            1_000_000,
            1_100_000, // 10% Vol increase
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

        let expected_emissions = gauge_base_emissions * 105 / 100; // 5% increase

        assert!(expected_emissions - new_emissions <= 1, 1);
        assert!(minter.usd_emissions_by_epoch(current_period) == new_emissions, 2);

        let expected_o_sail_supply = gauge_base_emissions + expected_emissions;
        assert!(expected_o_sail_supply - minter.o_sail_minted_supply() <= 5, 3);
        // total_supply is o_sail_total_supply + sail_total_supply (which is 0)
        assert!(expected_o_sail_supply - minter.total_supply() <= 5, 4);

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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        assert!(minter.total_supply() == initial_sail_supply, 3);
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
            0,
            0,
            gauge_base_emissions,
            1_000_000, // not used in calculations for first epoch but are known values
            1_000_000,
            1_200_000, // 20% Vol increase
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
        assert!(expected_o_sail_supply - minter.total_supply() <= 5, 4);

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
            1_000_000,    // prev_epoch_pool_emissions (from N-2, which is epoch 2)
            1_000_000,          // prev_epoch_pool_fees_usd
            1_000_000,          // epoch_pool_emissions_usd (from N-1)
            900_000,            // epoch_pool_fees_usd -> 10% ROE decrease
            1_000_000,          // epoch_pool_volume_usd (from N-1)
            900_000,            // epoch_pool_predicted_volume_usd -> 10% Vol decrease
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
#[expected_failure(abort_code = minter::EUpdatePeriodNotAllGaugesDistributed)]
fun test_skip_distribution_epoch() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let gauge_base_emissions = 1_000_000;

    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000000,
        182,
        gauge_base_emissions,
        0
    );

    // --- EPOCH 2 ---
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- Advance time by a few hours ---
    clock.increment_for_testing(2 * 60 * 60 * 1000); // 2 hours

    // --- Attempt to distribute the same gauge again (should fail) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        // distribute_gauge_epoch_1 uses <SUI, OSAIL1> as <Prev, Next>
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
            0,                  // prev_epoch_pool_emissions (N-2 is epoch 0, so 0)
            0,                  // prev_epoch_pool_fees_usd (N-2 is epoch 0, so 0)
            1_000_000,          // epoch_pool_emissions_usd (N-1)
            1_000_000,          // epoch_pool_fees_usd (N-1)
            1_000_000,          // epoch_pool_volume_usd (N-1)
            1_000_000,          // epoch_pool_predicted_volume_usd (N)
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        let mut voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);

        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        transfer::public_transfer(emergency_cap, admin);
    };

    // Attempt to distribute the killed gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_emissions_controlled<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario,
            0,
            0,
            gauge_base_emissions,
            1_000_000, 
            1_000_000,
            1_100_000,
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        transfer::public_transfer(emergency_cap, admin);
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
        let emergency_cap = scenario.take_from_sender<distribution::emergency_council::EmergencyCouncilCap>();

        minter.reset_gauge(
            &mut dist_config,
            &emergency_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(emergency_cap);
    };

    // distribute the revived gauge
    scenario.next_tx(admin);
    {
        // prev epoch sail is OSAIL1, cos second epoch is skipped.
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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

#[test]
#[expected_failure(abort_code = minter::EReviveGaugeNotKilledInCurrentEpoch)]
fun test_revive_undistributed_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

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

    // 2. Kill the gauge before any distribution has occurred
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 3. Advance time by 1/3 of a week
    clock.increment_for_testing(WEEK / 3);

    // 4. Attempt to revive the gauge (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_kill_revive_in_same_epoch_rewards() {
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. User creates and deposits a position
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

    // 4. Advance time 1/3 week and kill the gauge
    clock.increment_for_testing(WEEK / 3);
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 5. Advance time another 1/3 week and revive the gauge
    clock.increment_for_testing(WEEK / 3);
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // 6. Advance time for the final 1/3 of the week
    clock.increment_for_testing(WEEK / 3 + 1);

    // 7. User claims rewards and we check if they got the full amount
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(user);
    {
        // Check user has the rewards. Should be close to the total emissions for the gauge.
        let reward_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        // allow for small rounding discrepancies
        assert!(gauge_base_emissions - reward_coin.value() <= 3, 0); 
        reward_coin.burn_for_testing();
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EReviveGaugeNotKilledInCurrentEpoch)]
fun test_revive_gauge_in_next_epoch_fails() {
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Advance time 1/2 week and kill the gauge
    clock.increment_for_testing(WEEK / 2);
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 4. Advance time to the next epoch
    clock.increment_for_testing(WEEK / 2 + 1); // +1 to be safely in the next week

    // 5. Update minter period for Epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 6. Attempt to revive the gauge in the new epoch (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Advance time 1/3 week and kill the gauge
    clock.increment_for_testing(WEEK / 3);
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );
        
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 4. Advance time another 1/3 week
    clock.increment_for_testing(WEEK / 3);

    // 5. Attempt to reset the gauge in the same epoch (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter.reset_gauge<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &emergency_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(emergency_cap);
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
        let gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );
        
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 3. Advance time by 1/3 of a week
    clock.increment_for_testing(WEEK / 3);

    // 4. Reset the gauge. This is allowed as it was never distributed in this epoch.
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter.reset_gauge(
            &mut dist_config,
            &emergency_cap,
            &mut gauge,
            new_gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(emergency_cap);
    };

    // 5. Distribute the gauge now that it's reset and alive
    scenario.next_tx(admin);
    {
        let distributed_amount = setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 3. Attempt to kill the gauge again (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EReviveGaugeAlreadyAlive)]
fun test_revive_already_alive_gauge_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

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

    // 2. Distribute the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // 3. Kill the gauge
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 4. Revive the gauge (this should succeed)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // 5. Attempt to revive the gauge again (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        scenario.return_to_sender(emergency_cap);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
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
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
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
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter.reset_gauge<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &emergency_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(emergency_cap);
    };

    // 5. Attempt to reset the gauge again (should fail)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let emergency_cap = scenario.take_from_sender<emergency_council::EmergencyCouncilCap>();

        minter.reset_gauge<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &emergency_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        scenario.return_to_sender(emergency_cap);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = emergency_council::EEmergencyCouncilDoesNotMatchMinter)]
fun test_kill_gauge_with_invalid_emergency_cap_fails() {
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

    // 2. Attempt to kill the gauge with an invalid emergency cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();

        // Create an emergency cap with a fake minter ID
        let invalid_minter_id = object::id_from_address(@0xDEADBEEF);
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            invalid_minter_id,
            object::id(&voting_escrow),
            scenario.ctx()
        );

        // This should fail because the cap's minter ID doesn't match the actual minter
        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        // Cleanup in case the test doesn't fail as expected
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // Cleanup
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = emergency_council::EEmergencyCouncilDoesNotMatchMinter)]
fun test_revive_gauge_with_invalid_emergency_cap_fails() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

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

    // 2. Distribute the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock); 
    };

    // 3. Kill the gauge
    let gauge_id: ID;
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    // 4. Attempt to revive with an INVALID cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();

        // Create an invalid cap with a fake minter ID
        let invalid_minter_id = object::id_from_address(@0xDEADBEEF);
        let invalid_emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            invalid_minter_id,
            object::id(&voting_escrow),
            scenario.ctx()
        );

        // This should fail
        minter::revive_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &invalid_emergency_cap,
            gauge_id
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(invalid_emergency_cap, admin);
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = emergency_council::EEmergencyCouncilDoesNotMatchMinter)]
fun test_reset_gauge_with_invalid_emergency_cap_fails() {
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
        let gauge_id = object::id(&gauge);

        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            object::id(&minter),
            object::id(&voting_escrow),
            scenario.ctx()
        );

        minter::kill_gauge<SAIL>(
            &mut minter,
            &mut dist_config,
            &emergency_cap,
            gauge_id
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(emergency_cap, admin);
    };

    clock.increment_for_testing(WEEK / 2);

    // 4. Attempt to reset with an INVALID cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut dist_config = scenario.take_shared<DistributionConfig>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();

        // Create an invalid cap with a fake minter ID
        let invalid_minter_id = object::id_from_address(@0xDEADBEEF);
        let invalid_emergency_cap = emergency_council::create_for_testing(
            object::id(&voter),
            invalid_minter_id,
            object::id(&voting_escrow),
            scenario.ctx()
        );

        // This should fail
        minter.reset_gauge<USD_TESTS, AUSD, SAIL>(
            &mut dist_config,
            &invalid_emergency_cap,
            &mut gauge,
            gauge_base_emissions,
            &clock
        );

        // Cleanup if test doesn't fail
        test_scenario::return_shared(minter);
        test_scenario::return_shared(dist_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        transfer::public_transfer(invalid_emergency_cap, admin);
    };

    // Cleanup
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
            0, 0, 0, 0, 0, 0, // Zero metrics for initial distribution
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
            0, 0, 0, 0, 0, 0, // Zero metrics for initial distribution
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
            0, 0, 0, 0, 0, 0, // Zero metrics for initial distribution
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
            0, 0, 0, 0, 0, 0, // Zero metrics for initial distribution
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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
        setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
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


// TODO: fix rebase
// #[test]
// fun test_rebase_distribution_and_claim() {
//     let admin = @0xA;
//     let user = @0xB;
//     let mut scenario = test_scenario::begin(admin);
//     let mut clock = clock::create_for_testing(scenario.ctx());

//     let gauge_base_emissions = 1_000_000;
//     let lock_amount = 500_000;
//     let initial_o_sail_supply = 0;

//     // 1. Full setup
//     setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1>(
//         &mut scenario,
//         admin,
//         user,
//         &mut clock,
//         lock_amount,
//         182, // lock_duration_days
//         gauge_base_emissions,
//         initial_o_sail_supply
//     );

//     // Create and deposit a position for the user
//     scenario.next_tx(user);
//     {
//         setup::create_position_with_liquidity<USD_TESTS, AUSD>(
//             &mut scenario,
//             user,
//             tick_math::min_tick().as_u32(),
//             tick_math::max_tick().as_u32(),
//             100_000_000,
//             &clock
//         );
//     };
//     scenario.next_tx(user);
//     {
//         setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
//     };

//     // 2. Distribute gauge for epoch 1
//     scenario.next_tx(admin);
//     {
//         setup::distribute_gauge_epoch_1<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &clock); 
//     };

//     // 3. Advance to the next epoch
//     clock.increment_for_testing(WEEK);

//     // get reward for lock
//     scenario.next_tx(user);
//     {
//         setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
//     };

//     // 4. Check RewardDistributor balance before update (should be 0)
//     scenario.next_tx(admin);
//     {
//         let rd = scenario.take_shared<RewardDistributor<SAIL>>();
//         assert!(reward_distributor::balance(&rd) == 0, 0);
//         test_scenario::return_shared(rd);
//     };

//     // 5. Update minter period for epoch 2, which triggers rebase
//     scenario.next_tx(admin);
//     {
//         let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
//         o_sail_coin_2.burn_for_testing();
//     };

//     // distribute the gauge for epoch 2
//     scenario.next_tx(admin);
//     {
//         setup::distribute_gauge_epoch_2<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &clock);
//     };

//     scenario.next_tx(admin);
//     {
//         // print the total supply
//         let minter = scenario.take_shared<Minter<SAIL>>();
//         test_scenario::return_shared(minter);
//     };

//     clock.increment_for_testing(WEEK);

//     // get position reward oSAIL2
//     scenario.next_tx(user);
//     {
//         setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
//     };

//     // update minter period for epoch 3
//     scenario.next_tx(admin);
//     {
//         let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
//         o_sail_coin_3.burn_for_testing();
//     };

//         // 6. Verify rebase amount was distributed to RewardDistributor
//     scenario.next_tx(admin);
//     {
//         let rd = scenario.take_shared<RewardDistributor<SAIL>>();
//         assert!(reward_distributor::balance(&rd) == 125000, 1);
//         test_scenario::return_shared(rd);
//     };

//     // 7. User claims rewards
//     scenario.next_tx(user);
//     {
//         let mut rd = scenario.take_shared<RewardDistributor<SAIL>>();
//         let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
//         let mut lock = scenario.take_from_sender<Lock>();

//         let claimed_amount = reward_distributor::claim(&mut rd, &mut ve, &mut lock, &clock, scenario.ctx());
//         assert!(125000 - claimed_amount <= 1, 2);

//         // The reward should be added to the lock amount since it's still active
//         let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
//         assert!(lock_amount + 125000 - locked_balance.amount() <= 1, 3);
//         assert!(reward_distributor::balance(&rd) <= 1, 4);

//         test_scenario::return_shared(rd);
//         test_scenario::return_shared(ve);
//         scenario.return_to_sender(lock);
//     };

//     clock.increment_for_testing(WEEK);

//     // update to epoch 4
//     scenario.next_tx(admin);
//     {
//         let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
//         o_sail_coin_2.burn_for_testing();
//     };

//     // expected total supply is 1_000_000 + 1_000_000 + 125000;
//     // locked supply is 500_000 + 125000
//     // expected rebase is 249136

//     // 8. Verify rebase amount was distributed to RewardDistributor
//     scenario.next_tx(admin);
//     {
//         let rd = scenario.take_shared<RewardDistributor<SAIL>>();
//         assert!(249136 - reward_distributor::balance(&rd) <= 2, 1);
//         test_scenario::return_shared(rd);
//     };

//     // 9. User claims rewards
//     scenario.next_tx(user);
//     {
//         let mut rd = scenario.take_shared<RewardDistributor<SAIL>>();
//         let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
//         let mut lock = scenario.take_from_sender<Lock>();

//         let claimed_amount = reward_distributor::claim(&mut rd, &mut ve, &mut lock, &clock, scenario.ctx());
//         assert!(249136 - claimed_amount <= 2, 2);

//         // The reward should be added to the lock amount since it's still active
//         let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
//         assert!(lock_amount + 125000 + 249136 - locked_balance.amount() <= 3, 3);
//         assert!(reward_distributor::balance(&rd) <= 2, 4);

//         test_scenario::return_shared(rd);
//         test_scenario::return_shared(ve);
//         scenario.return_to_sender(lock);
//     };


//     clock::destroy_for_testing(clock);
//     scenario.end();
// }

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
        
        // Create a publisher from the voter module instead of minter module
        let mut wrong_publisher = voter::test_init(scenario.ctx());
        
        // This should fail because we're using a publisher from the wrong module
        let time_locked_mint = minter.schedule_sail_mint(
            &mut wrong_publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(wrong_publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
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
        
        // Create a valid publisher from the minter module
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because we're passing zero amount
        let time_locked_mint = minter.schedule_sail_mint(
            &mut publisher,
            0, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Immediately try to execute the mint without waiting for unlock time
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        
        // This should fail because not enough time has passed (need 1 day)
        let sail_coin = minter.execute_sail_mint(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Advance time by 24 hours - 1 millisecond (still 1ms short of unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms - 1); // 1ms short

    // Try to execute the mint (should fail as it's still 1ms too early)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        
        // This should fail because we're still 1ms short of the unlock time
        let sail_coin = minter.execute_sail_mint(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Advance time by exactly 24 hours (unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms);

    // Execute the mint (should succeed now)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        
        // This should succeed because exactly 24 hours have passed
        let sail_coin = minter.execute_sail_mint(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Verify the minted amount is exactly what was scheduled
        assert!(sail_coin.value() == mint_amount, 0);
        
        sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_sail_mint(
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Cancel the mint
    scenario.next_tx(admin);
    {
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedSailMint>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        
        // Cancel the mint - this should not mint any tokens
        minter::cancel_sail_mint<SAIL>(&minter, time_locked_mint);

        test_scenario::return_shared(minter);
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
        
        // This should fail because we're using a publisher from the wrong module
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut wrong_publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(wrong_publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because we're passing zero amount
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            0, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        // This should fail because OSAIL1 is not a valid oSAIL type (minter not activated)
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Immediately try to execute the mint without waiting for unlock time
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        
        // This should fail because not enough time has passed (need 1 day)
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            1_000_000, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Advance time by 24 hours - 1 millisecond (still 1ms short of unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms - 1); // 1ms short

    // Try to execute the mint (should fail as it's still 1ms too early)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        
        // This should fail because we're still 1ms short of the unlock time
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup - these lines won't be reached if the test fails as expected
        o_sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Advance time by exactly 24 hours (unlock time)
    let lock_time_ms = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    clock.increment_for_testing(lock_time_ms);

    // Execute the mint (should succeed now)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        
        // This should succeed because exactly 24 hours have passed
        let o_sail_coin = minter.execute_o_sail_mint<SAIL, OSAIL1>(
            time_locked_mint,
            &clock,
            scenario.ctx()
        );
        
        // Verify the minted amount is exactly what was scheduled
        assert!(o_sail_coin.value() == mint_amount, 0);
        
        o_sail_coin.burn_for_testing();
        test_scenario::return_shared(minter);
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
        let mut publisher = minter::test_init(scenario.ctx());
        
        let time_locked_mint = minter.schedule_o_sail_mint<SAIL, OSAIL1>(
            &mut publisher,
            mint_amount, // amount
            &clock,
            scenario.ctx()
        );
        
        test_utils::destroy(publisher);
        transfer::public_transfer(time_locked_mint, admin);
        test_scenario::return_shared(minter);
    };

    // Cancel the mint
    scenario.next_tx(admin);
    {
        let time_locked_mint = scenario.take_from_sender<minter::TimeLockedOSailMint<OSAIL1>>();
        
        // Cancel the mint - this should not mint any tokens
        minter::cancel_o_sail_mint(time_locked_mint);
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
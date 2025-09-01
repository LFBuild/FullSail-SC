#[test_only]
module governance::distribute_o_sail_tests;

use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, CoinMetadata};
use std::type_name;

use governance::minter::{Self, Minter};
use governance::setup;
use governance::voter::{Voter};
use governance::distribution_config::{DistributionConfig};
use governance::voter_cap::{VoterCap};
use governance::gauge::{Self, Gauge, StakedPosition};
use clmm_pool::config::{Self, GlobalConfig};
use clmm_pool::pool::{Pool};
use clmm_pool::tick_math;
use sui::test_utils;
use voting_escrow::voting_escrow::{Lock, VotingEscrow};
use switchboard::aggregator::{Self, Aggregator};
use price_monitor::price_monitor::{Self, PriceMonitor};

use governance::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

const DEFAULT_GAUGE_EMISSIONS: u64 = 1_000_000;

// Define dummy types used in setup
public struct SAIL has drop, store {}

public struct OSAIL1 has drop {}

public struct OSAIL2 has drop {}

public struct OSAIL3 has drop {}

public struct OSAIL4 has drop {}
public struct OSAIL5 has drop {}
public struct OSAIL6 has drop {}
public struct OSAIL7 has drop {}
public struct OSAIL8 has drop {}
public struct OSAIL9 has drop {}
public struct OSAIL10 has drop {}

public struct OTHER has drop, store {}

// used if you want to call some methods that are only supposed to be called by Voter
fun create_voter_cap(
    scenario: &mut Scenario,
    admin: address,
) {
        let voter = scenario.take_shared<Voter>();
        let voter_cap = governance::voter_cap::create_voter_cap(
            object::id(&voter),
            scenario.ctx()
        );
        transfer::public_transfer(voter_cap, admin);
        test_scenario::return_shared(voter);
}

#[test]
public fun test_gauge_notify_epoch_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
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
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let prev_epoch_emissions = gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        assert!(prev_epoch_emissions == 0, 1);

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };


    scenario.next_tx(admin);
    {
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        assert!(gauge.borrow_epoch_token() == type_name::get<OSAIL1>(), 2);
        assert!(gauge.period_finish() == WEEK * 2 / 1000, 1);

        test_scenario::return_shared(gauge);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenAlreadyNotifiedToken)] 
public fun test_gauge_notify_epoch_token_twice_fail(
) {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
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
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };
    clock.increment_for_testing(WEEK);

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenEpochAlreadyStarted)]
public fun test_gauge_notify_epoch_token_epoch_already_started() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
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

        // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, SAIL, SAIL>(&mut scenario, &mut clock)
    };

    scenario.next_tx(admin);
    {
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    clock::increment_for_testing(&mut clock, WEEK * 2 / 3);
    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let prev_epoch_emissions = gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL2>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        assert!(prev_epoch_emissions == 0, 1);

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenInvalidPool)]
public fun test_gauge_notify_epoch_token_invalid_pool() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // Tx 2: Add another fee tier to use it to create second pool
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, 10, 2000, scenario.ctx());
        test_scenario::return_shared(global_config);
        transfer::public_transfer(admin_cap, admin);
    };

    // destroy old pool and create a new one to change pool id
    scenario.next_tx(admin);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD_TESTS, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(admin);
    {
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EInvalidVoter)]
public fun test_gauge_notify_epoch_token_invalid_voter() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
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
        let voter_cap = governance::voter_cap::create_voter_cap(
            // random voter_id
            object::id_from_address(@0xABC123),
            scenario.ctx()
        );
        transfer::public_transfer(voter_cap, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenEpochAlreadyStarted)] 
public fun test_gauge_notify_epoch_token_already_started(
) {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
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
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL1>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };
    // we are not chaning epoch, so the notification would fail
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        gauge.notify_epoch_token<USD_TESTS, SAIL, OSAIL2>(
            &distribution_config,
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EGetPositionRewardInvalidRewardToken)]
public fun test_gauge_get_position_reward_invalid_reward_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // setup position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };


    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, USD_TESTS>(&mut scenario, &clock);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EUpdateRewardGaugeDoesNotMatchPool)]
public fun test_gauge_get_position_reward_invalid_pool() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

        scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };


    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

        // Tx 2: Add another fee tier to use it to create second pool
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, 10, 2000, scenario.ctx());
        test_scenario::return_shared(global_config);
        transfer::public_transfer(admin_cap, admin);
    };

    // destroy old pool and create a new one to change pool id
    scenario.next_tx(admin);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD_TESTS, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = minter::EGetPositionRewardInvalidRewardToken)]
public fun test_gauge_get_reward_invalid_reward_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let default_gauge_base_emissions = 1_000_000;

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        default_gauge_base_emissions,
        0
    );

    // setup position
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    scenario.next_tx(user);
    {
        // USD_TESTS is not a valid reward token
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, USD_TESTS>(&mut scenario, &clock);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EUpdateRewardGaugeDoesNotMatchPool)]
public fun test_gauge_get_reward_invalid_pool() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

        scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

        // Tx 2: Add another fee tier to use it to create second pool
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, 10, 2000, scenario.ctx());
        test_scenario::return_shared(global_config);
        transfer::public_transfer(admin_cap, admin);
    };

    // destroy old pool and create a new one to change pool id
    scenario.next_tx(admin);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD_TESTS, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

fun full_setup_with_two_positions(
    scenario: &mut Scenario,
    user: address,
    admin: address,
    lp1: address,
    lp2: address,
    pos1_liquidity: u128,
    pos1_lower_tick: u32,
    pos1_upper_tick: u32,
    pos2_liquidity: u128,
    pos2_lower_tick: u32,
    pos2_upper_tick: u32,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    clock: &mut Clock,
): (u64, ID, ID) {

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        scenario,
        admin,
        user,
        clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // distribute gauge
    // not at the start of the epoch, but it is pretty close to the real world situation
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(scenario, usd_metadata, &mut aggregator, clock); 
    };

    // lp1 creates and stakes position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            scenario,
            lp1, // Staked record associated with lp1
            pos1_lower_tick,
            pos1_upper_tick,
            pos1_liquidity,
            clock
        );
    };

    let lp1_position_id: ID;

    // lp1 deposits position into gauge
    scenario.next_tx(lp1);
    {
        lp1_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            scenario,
            clock
        );
    };

    // lp2 creates and stakes position
    scenario.next_tx(lp2);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            scenario,
            lp2, // Staked record associated with lp2
            pos2_lower_tick,
            pos2_upper_tick,
            pos2_liquidity,
            clock
        );
    };

    let lp2_position_id: ID;

    // lp2 deposits position into gauge
    scenario.next_tx(lp2);
    {
        lp2_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            scenario,
            clock
        );
    };
    test_utils::destroy(aggregator);

    (epoch_emissions, lp1_position_id, lp2_position_id)
}



fun check_two_positions_single_epoch(
    scenario: &mut Scenario,
    admin: address,
    pos1_liquidity: u128,
    pos1_lower_tick: u32,
    pos1_upper_tick: u32,
    pos2_liquidity: u128,
    pos2_lower_tick: u32,
    pos2_upper_tick: u32,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    clock: &mut Clock,
) {
    let user = @0xA2;
    let lp1 = @0xA3;
    let lp2 = @0xA4;

    let ms_in_week = 7 * 24 * 60 * 60 * 1000;

    let (epoch_emissions, lp1_position_id, lp2_position_id) = full_setup_with_two_positions(
        scenario,
        admin,
        user,
        lp1,
        lp2,
        pos1_liquidity,
        pos1_lower_tick,
        pos1_upper_tick,
        pos2_liquidity,
        pos2_lower_tick,
        pos2_upper_tick,
        usd_metadata,
        clock
    );

    let total_liquidity = pos1_liquidity + pos2_liquidity;
    let expected_lp1_earned = integer_mate::full_math_u128::mul_div_floor(
        epoch_emissions as u128,
        pos1_liquidity,
        total_liquidity
    ) as u64;
    let expected_lp2_earned = integer_mate::full_math_u128::mul_div_floor(
        epoch_emissions as u128,
        pos2_liquidity,
        total_liquidity
    ) as u64;

    // advance time to make lp's earn their rewards
    clock.increment_for_testing(ms_in_week);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp1_position_id,
            clock
        );
        let earned_lp2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp2_position_id,
            clock
        );

        let earned_lp1_nonepoch_coin = minter.earned_by_position<USD_TESTS, SAIL, SAIL, USD_TESTS>(
            &gauge,
            &pool,
            lp1_position_id,
            clock
        );

        let earned_lp2_nonepoch_coin = minter.earned_by_position<USD_TESTS, SAIL, SAIL, USD_TESTS>(
            &gauge,
            &pool,
            lp2_position_id,
            clock
        );

        let earned_lp1_by_pos_ids = minter.earned_by_position_ids<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            &vector[lp1_position_id],
            clock
        );

        let earned_lp2_by_pos_ids = minter.earned_by_position_ids<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            &vector[lp2_position_id],
            clock
        );

        assert!(expected_lp1_earned - earned_lp1 <= 1, 1);
        assert!(expected_lp2_earned - earned_lp2 <= 1, 2);
        assert!(earned_lp1_nonepoch_coin == 0, 3);
        assert!(earned_lp2_nonepoch_coin == 0, 4);
        assert!(expected_lp1_earned - earned_lp1_by_pos_ids <= 1, 5);
        assert!(expected_lp2_earned - earned_lp2_by_pos_ids <= 1, 6);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(scenario, clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 1, 4);

        coin::burn_for_testing(reward);
    };


    // lp2 claims reward
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(scenario, clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_earned - reward.value() <= 1, 5);

        coin::burn_for_testing(reward);
    };
}

#[test]
fun test_o_sail_single_epoch_distribute() {
    let admin = @0xA1;
    let position_liquidity: u128 = 1_000_000_000;
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        &usd_metadata,
        &mut clock,
    );

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_different_pos_sizes_distribute() {
    let admin = @0xA1;
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        1_000_000_000,
        position_tick_lower,
        position_tick_upper,
        2_000_000_000,
        position_tick_lower,
        position_tick_upper,
        &usd_metadata,
        &mut clock,
    );

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_different_tick_ranges_distribute() {
    let admin = @0xA1;
    let position_liquidity: u128 = 1_000_000_000;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        position_liquidity,
        integer_mate::i32::neg_from(100).as_u32(),
        integer_mate::i32::from(100).as_u32(),
        position_liquidity,
        tick_math::min_tick().as_u32(),
        tick_math::max_tick().as_u32(),
        &usd_metadata,
        &mut clock,
    );

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_different_tick_ranges_different_liquidity_distribute() {
    let admin = @0xA1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        1,
        integer_mate::i32::neg_from(5555).as_u32(),
        integer_mate::i32::from(1111).as_u32(),
        10_000_000_000,
        tick_math::min_tick().as_u32(),
        tick_math::max_tick().as_u32(),
        &usd_metadata,
        &mut clock,
    );

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EUpdatePeriodOSailAlreadyUsed)]
fun test_update_minter_period_with_same_o_sail_fails() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
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

    // Distribute Gauge Rewards (OSAIL1)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    clock.increment_for_testing(WEEK);

    // Update Minter Period with OSAIL1, should fail
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            0, 
            &clock
        );
        coin::burn_for_testing(o_sail1_initial_supply);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock.destroy_for_testing();
    scenario.end();
}

#[test]
fun test_single_position_reward_over_time_distribute() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup --- 
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );


    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };


    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let lp1_position_id: ID;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Then deposit/stake the position
    scenario.next_tx(lp1);
    {
        lp1_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by HALF a week ---
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock::increment_for_testing(&mut clock, WEEK / 2 - 500);
    let expected_first_half_reward = epoch1_emissions / 2;
    let expected_second_half_reward: u64;

    // --- Verify Earned Rewards After Half Week ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_half = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );

        let diff_first_half = expected_first_half_reward - earned_half;
        assert!(diff_first_half <= epoch1_emissions / 1_000_000, 1); // Allow rounding by 1/1000000

        expected_second_half_reward = epoch1_emissions - earned_half;

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // claim half reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // verify half reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_first_half_reward - reward.value() <= epoch1_emissions / 1_000_000, 2);

        coin::burn_for_testing(reward);
    };

    // --- Advance time by the OTHER HALF week ---
    clock::increment_for_testing(&mut clock, WEEK);

    // --- Verify Earned Rewards After Full Week ---
    scenario.next_tx(lp1);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_full = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>( 
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );
        let diff_full = expected_second_half_reward - earned_full;
        assert!(diff_full <= 2, 2); // Allow rounding by 1

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // claim second half reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // verify second half reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_second_half_reward - reward.value() <= 2, 3);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_single_position_withdraw_distribute() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, SAIL, SAIL>(&mut scenario, &mut clock)
    };


    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Then deposit/stake the position
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by HALF a week ---
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock::increment_for_testing(&mut clock, WEEK / 2 - 500);
    let expected_lp1_reward = epoch1_emissions / 2;

    // get rewards prior to withdrawing position
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // --- Withdraw the position ---
    scenario.next_tx(lp1);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        );
    };


    // verify half reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward - reward.value() <= epoch1_emissions / 1_000_000, 2);

        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_single_position_deposit_for_1h() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

        // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, SAIL, SAIL>(&mut scenario, &mut clock)
    };


    clock.increment_for_testing(WEEK / 2 - 10 * 60 * 60 * 1000);

    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Then deposit/stake the position
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by one hour ---
    clock::increment_for_testing(&mut clock, 60 * 60 * 1000);
    let expected_lp1_reward = ((epoch1_emissions as u128 * 60 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // claim rewards
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        );
    };


    // verify reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward - reward.value() <= 1, 2);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_position_deposit_for_1h_widthrawal_and_deposit_again_for_1h() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, SAIL, SAIL>(&mut scenario, &mut clock)
    };

    clock.increment_for_testing(WEEK / 3 - 10 * 60 * 60 * 1000);

    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Then deposit/stake the position
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by one hour ---
    clock::increment_for_testing(&mut clock, 60 * 60 * 1000);
    let expected_lp1_reward = ((epoch1_emissions as u128 * 60 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // claim rewards
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        );
    };


    // verify reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward - reward.value() <= 1, 2);
        coin::burn_for_testing(reward);
    };

    clock.increment_for_testing(WEEK / 3);

    // lp1 deposits position again
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // Advance time by half an hour
    clock::increment_for_testing(&mut clock, 30 * 60 * 1000);
    let expected_lp1_reward_dep_2 = ((epoch1_emissions as u128 * 30 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // claim rewards
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        );
    };

    // verify reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward_dep_2 - reward.value() <= 1, 2);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

/// After this fucntions is called the state is as two epochs have passed and rewards 
/// were distributes for this two epochs (so one week passed after last distribute_gauge call)
/// Returns (lp_position_id, first_epoch_emissions, second_epoch_emissions)
fun multi_epoch_distribute_setup(
    scenario: &mut Scenario,
    admin: address,
    user: address,
    lp: address,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    clock: &mut Clock,
): (ID, u64, u64) {
    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year

    let first_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;
    let second_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        scenario,
        admin,
        user,
        clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // Distribute OSAIL1 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(scenario, usd_metadata, &mut aggregator, clock);
    };

    // --- 4. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 2_000_000_000u128; // Example liquidity
    let lp_position_id: ID;

    // Create position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            scenario,
            lp, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            clock
        );
    };

    // Deposit position
    scenario.next_tx(lp);
    {
        lp_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            scenario,
            clock
        );
    };

    // --- 5. Advance to Epoch 2 (OSAIL2) ---
    clock::increment_for_testing(clock, WEEK); // Advance clock by one week

    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            scenario,
            500_000, // Arbitrary supply for OSAIL2
            clock
        );
        coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(scenario, usd_metadata, &mut aggregator, clock); 
    };

    // --- 6. Advance Time by One More Week ---
    clock::increment_for_testing(clock, WEEK);
    test_utils::destroy(aggregator);

    (lp_position_id, first_epoch_emissions, second_epoch_emissions)
}

#[test]
fun test_gauge_get_position_reward() {
        let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (
        lp_position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &usd_metadata,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let earned_osail1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        ); 
        let earned_osail2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL2>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // user can earn only current epoch token
        assert!(earned_osail1 == 0, 1);
        assert!(second_epoch_emissions + first_epoch_emissions - earned_osail2 <= 3, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions + first_epoch_emissions - reward.value() <= 3, 4);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_increase_time_after_distribute() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (
        lp_position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &usd_metadata,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let earned_osail1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        ); 
        let earned_osail2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL2>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // user can earn only current epoch token
        assert!(earned_osail1 == 0, 1);
        assert!(second_epoch_emissions + first_epoch_emissions - earned_osail2 <= 3, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // --- 7. Advance Time by 1 more week, rewards should not change ---
    clock::increment_for_testing(&mut clock, WEEK);

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let earned_osail1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        ); 
        let earned_osail2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL2>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        // user can earn only current epoch token
        assert!(earned_osail1 == 0, 1);
        assert!(second_epoch_emissions + first_epoch_emissions - earned_osail2 <= 3, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions + first_epoch_emissions - reward.value() <= 3, 4);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = minter::EIncreaseEmissionsNotDistributed)]
fun test_increase_gauge_emissions_before_distribution_fails() {
    let admin = @0xD1;
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let initial_emissions = 1_000_000;
    let increase_emissions_by = 2_000_000;

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        initial_emissions,
        0
    );

    // --- Increase gauge emissions before distribution (should fail) ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut sail_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        // let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        minter.increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &voter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut sail_pool,
            increase_emissions_by,
            &mut price_monitor,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(sail_pool);
        test_scenario::return_shared(price_monitor);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_increase_gauge_emissions_mid_epoch() {
    let admin = @0xD1;
    let user = @0xD2;
    let lp = @0xD3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let initial_emissions = 1_000_000;
    let increase_emissions_by = 2_000_000;
    let total_expected_emissions = initial_emissions + increase_emissions_by;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        initial_emissions,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);   
    };

    // --- Tx: lp Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let lp_position_id: ID;

    // First create the position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Then deposit/stake the position
    scenario.next_tx(lp);
    {
        lp_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by HALF a week ---
    clock::increment_for_testing(&mut clock, WEEK / 2);

    // --- Increase gauge emissions ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut sail_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        // let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms());

        minter.increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &voter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut sail_pool,
            increase_emissions_by,
            &mut price_monitor,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(sail_pool);
        test_scenario::return_shared(price_monitor);
    };

    // --- Advance time to the end of the week ---
    clock::increment_for_testing(&mut clock, WEEK / 2);

    // --- Verify rewards ---
    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let earned = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );
        
        assert!(total_expected_emissions - earned <= 3, 1);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_increase_gauge_emissions_revoked_admin_cap_fails() {
    let admin = @0xD1;
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let initial_emissions = 1_000_000;
    let increase_emissions_by = 2_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        initial_emissions,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    let admin_cap_id: ID;
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        admin_cap_id = object::id(&admin_cap);
        scenario.return_to_sender(admin_cap);
    };

    // --- Revoke admin cap ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let publisher = minter::test_init(scenario.ctx());
        minter.revoke_admin(&publisher, admin_cap_id);

        test_scenario::return_shared(minter);
        test_utils::destroy(publisher);
    };

    // --- Increase gauge emissions with revoked cap (should fail) ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        // this is the old, invalid cap
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut sail_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        // let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();


        minter.increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &voter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut sail_pool,
            increase_emissions_by,
            &mut price_monitor,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(sail_pool);
        test_scenario::return_shared(price_monitor);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EIncreaseEmissionsDistributionConfigInvalid)]
fun test_increase_gauge_emissions_invalid_distribution_config_fails() {
    let admin = @0xD1;
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let initial_emissions = 1_000_000;
    let increase_emissions_by = 2_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        initial_emissions,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- Create a new, invalid distribution config ---
    scenario.next_tx(admin);
    {
        governance::distribution_config::test_init(scenario.ctx());
    };

    // --- Increase gauge emissions with invalid config (should fail) ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut sail_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        // let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms());

        minter.increase_gauge_emissions_for_sail_pool<USD_TESTS, SAIL, SAIL>(
            &voter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut sail_pool,
            increase_emissions_by,
            &mut price_monitor,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(sail_pool);
        test_scenario::return_shared(price_monitor);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyRewardWithoutClaimInvalidPool)]
fun test_increase_gauge_emissions_invalid_pool_fails() {
    let admin = @0xD1;
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let initial_emissions = 1_000_000;
    let increase_emissions_by = 2_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1000,
        182,
        initial_emissions,
        0
    );

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- Add a new fee tier ---
    scenario.next_tx(admin);
    {
        let admin_cap = scenario.take_from_sender<config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, 10, 100, scenario.ctx());
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(admin_cap);
    };

    // --- Create a new, invalid pool ---
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, SAIL>(&mut scenario, 1 << 64, 10);
    };

    // --- Increase gauge emissions with invalid pool (should fail) ---
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let mut price_monitor = scenario.take_shared<PriceMonitor>();
        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        setup::aggregator_set_current_value(&mut aggregator,  setup::one_dec18(), clock.timestamp_ms());

        minter.increase_gauge_emissions<USD_TESTS, SAIL, USD_TESTS, SAIL, SAIL>(
            &voter,
            &distribution_config,
            &admin_cap,
            &mut gauge,
            &mut pool,
            increase_emissions_by,
            &mut price_monitor,
            &sail_stablecoin_pool,
            &aggregator,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
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
fun test_gauge_get_reward() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (
        position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &usd_metadata,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();
        let earned_osail1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            position_id,
            &clock
        );
        let earned_osail2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL2>(
            &gauge,
            &pool,
            position_id,
            &clock
        );

        // user can earn only current epoch token
        assert!(earned_osail1 == 0, 1);
        assert!(second_epoch_emissions + first_epoch_emissions - earned_osail2 <= 3, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions + first_epoch_emissions - reward.value() <= 3, 4);
        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EGetPositionRewardInvalidRewardToken)]
fun test_gauge_get_reward_fails_wrong_token() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &usd_metadata,
        &mut clock,
    );

    // Claim all rewards
    // Should error because oSAIL2 is current epoch token, but we are trying to claim OSAIL1
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_half_epoch_staking_distribute() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let lp2 = @0xA4;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let ms_in_week = 7 * 24 * 60 * 60 * 1000;

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };


    // distribute gauge


    // --- Add and Stake Positions ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    // during first half of the week the first position gets all the rewards
    // during second part of the week these positions earn equal portions of the reward, so 1/2 of 1/2 of the reward for each.
    let expected_lp1_earned = epoch_emissions / 2 + epoch_emissions / 4;
    let expected_lp2_earned = epoch_emissions / 4;

    // lp1 creates and stakes position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1, // Staked record associated with lp1
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    let lp1_position_id: ID;

    // lp1 deposits position into gauge
    scenario.next_tx(lp1);
    {
        lp1_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // advance half a week.
    // minus 500ms, cos we advanced 1000ms extra duting minter activation
    clock.increment_for_testing(ms_in_week / 2 - 500);

    // lp2 creates and stakes position
    scenario.next_tx(lp2);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp2, // Staked record associated with lp2
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    let lp2_position_id: ID;

    // lp2 deposits position into gauge
    scenario.next_tx(lp2);
    {
        lp2_position_id = setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // advance to end of the week
    clock.increment_for_testing(ms_in_week / 2 - 500);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>( 
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );
        let earned_lp2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp2_position_id,
            &clock
        );

        let earned_lp2_nonepoch_coin = minter.earned_by_position<USD_TESTS, SAIL, SAIL, USD_TESTS>(
            &gauge,
            &pool,
            lp2_position_id,
            &clock
        );

        assert!(expected_lp1_earned - earned_lp1 <= 2, 1);
        assert!(expected_lp2_earned - earned_lp2 <= 2, 2);
        assert!(earned_lp2_nonepoch_coin == 0, 3);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 2, 4);

        coin::burn_for_testing(reward);
    };


    // lp2 claims reward
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_half_epoch_withdrawal_distribute() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let lp2 = @0xA4;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let (epoch_emissions, lp1_position_id, lp2_position_id) = full_setup_with_two_positions(
        &mut scenario,
        admin,
        user,
        lp1,
        lp2,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        &usd_metadata,
        &mut clock
    );
    // Both positions are deposited at the begining of the week, but the second one is withdrawn after half of the week.
    // During first part of the week these positions earn equal portions of the reward, so 1/2 of 1/2 of the reward for each.
    // During second half of the week only the first position gets all the rewards
    let expected_lp1_earned = epoch_emissions / 4 + epoch_emissions / 2;
    let expected_lp2_earned = epoch_emissions / 4;

    let expected_lp1_half_week_earned = epoch_emissions / 4;

    // advance by half of the week
    // We have added extra 1000ms during minter activation, so now half of the period is 500ms shorter
    clock.increment_for_testing(WEEK / 2 - 500);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>( 
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );
        let earned_lp2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp2_position_id,
            &clock
        );

        assert!(expected_lp1_half_week_earned - earned_lp1 <= 2, 1);
        assert!(expected_lp2_earned - earned_lp2 <= 2, 2);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // lp2 claims reward
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // lp2 withdraws the position
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        )
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_earned - reward.value() <= 2, 4);

        coin::burn_for_testing(reward);
    };

    clock.increment_for_testing(WEEK / 2 - 500);

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_position_increase_after_deposit() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let lp2 = @0xA4;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- Add and Stake Positions ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_initial_liquidity = 1_000_000_000u128;

    let (epoch_emissions, lp1_position_id, lp2_position_id) = full_setup_with_two_positions(
        &mut scenario,
        admin,
        user,
        lp1,
        lp2,
        position_initial_liquidity,
        position_tick_lower,
        position_tick_upper,
        position_initial_liquidity,
        position_tick_lower,
        position_tick_upper,
        &usd_metadata,
        &mut clock
    );

    let liquidity_to_add = position_initial_liquidity;
    // Both positions are deposited at the begining of the week, but the second one is increased 2x in liquidity after half of the week.
    // During first part of the week these positions earn equal portions of the reward, so 1/2 of 1/2 of the reward for each.
    // During second half of the week, the second position earns 2x the reward of the first position.
    let expected_lp1_earned = epoch_emissions / 4 + epoch_emissions / 2 / 3;
    let expected_lp2_earned = epoch_emissions / 4 + epoch_emissions / 3;

    let expected_lp1_half_week_earned = epoch_emissions / 4;
    let expected_lp2_half_week_earned = epoch_emissions / 4;
    let expected_lp2_second_half_week_earned = expected_lp2_earned - expected_lp2_half_week_earned;

    // advance by half of the week
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock.increment_for_testing(WEEK / 2 - 500);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>( 
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );
        let earned_lp2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp2_position_id,
            &clock
        );

        assert!(expected_lp1_half_week_earned - earned_lp1 <= 2, 1);
        assert!(expected_lp2_half_week_earned - earned_lp2 <= 2, 2);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // get rewards prior to withdrawing position
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // lp2 withdraws position to increase its liquidity
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        )
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_half_week_earned - reward.value() <= 2, 4);

        coin::burn_for_testing(reward);
    };

    // lp2 increases position liquidity
    scenario.next_tx(lp2);
    {
        setup::add_liquidity<USD_TESTS, SAIL>(&mut scenario, liquidity_to_add, &clock);
    };

    // lp2 deposits position again
    scenario.next_tx(lp2);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 2 - 500);

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

    // lp2 claims reward
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_second_half_week_earned - reward.value() <= 2, 6);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_position_decrease_after_deposit() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let lp2 = @0xA4;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    // --- Add and Stake Positions ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_initial_liquidity = 1_000_000_000u128;

    let (epoch_emissions, lp1_position_id, lp2_position_id) = full_setup_with_two_positions(
        &mut scenario,
        admin,
        user,
        lp1,
        lp2,
        position_initial_liquidity,
        position_tick_lower,
        position_tick_upper,
        position_initial_liquidity,
        position_tick_lower,
        position_tick_upper,
        &usd_metadata,
        &mut clock
    );

    let liquidity_to_remove = position_initial_liquidity / 2;
    // Both positions are deposited at the begining of the week, but the second one is decreased 0.5x in liquidity after half of the week.
    // During first part of the week these positions earn equal portions of the reward, so 1/2 of 1/2 of the reward for each.
    // During second half of the week, the first position earns 2x the reward of the second position (as second position is half of the liquidity).
    let expected_lp1_earned = epoch_emissions / 4 + epoch_emissions / 3;
    let expected_lp2_earned = epoch_emissions / 4 + epoch_emissions / 2 / 3;

    let exptected_lp1_half_week_earned = epoch_emissions / 4;
    let expected_lp2_half_week_earned = epoch_emissions / 4;
    let expected_lp2_second_half_week_earned = expected_lp2_earned - expected_lp2_half_week_earned;

    // advance by half of the week
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock.increment_for_testing(WEEK / 2 - 500);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>( 
            &gauge,
            &pool,
            lp1_position_id,
            &clock
        );
        let earned_lp2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp2_position_id,
            &clock
        );

        assert!(exptected_lp1_half_week_earned - earned_lp1 <= 2, 1);
        assert!(expected_lp2_half_week_earned - earned_lp2 <= 2, 2);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // get rewards prior to withdrawing position
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // lp2 withdraws position to decrease its liquidity
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock,
        )
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_half_week_earned - reward.value() <= 2, 4);

        coin::burn_for_testing(reward);
    };

    // lp2 decreases position liquidity
    scenario.next_tx(lp2);
    {
        setup::remove_liquidity<USD_TESTS, SAIL>(&mut scenario, liquidity_to_remove, &clock);
    };

    // lp2 deposits position again
    scenario.next_tx(lp2);
    {
        setup::deposit_position<USD_TESTS, SAIL>(
            &mut scenario,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 2 - 500);

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

    // lp2 claims reward
    scenario.next_tx(lp2);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_second_half_week_earned - reward.value() <= 2, 6);

        coin::burn_for_testing(reward);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// After this function is called, the first epoch is distributed and finished.
// The second epoch has distributed gauge, but has no positions deposited yet.
// Supposed to be called to check distribution during second week.
fun rollover_setup(
    scenario: &mut Scenario,
    admin: address,
    user: address,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    clock: &mut Clock,
): (u64, u64, Aggregator) {
    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year
    let first_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;
    let second_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        scenario,
        admin,
        user,
        clock,
        lock_amount,
        lock_duration,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    // Distribute OSAIL1 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(scenario, usd_metadata, &mut aggregator, clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(clock, 10 * 60 * 60 * 1000);

    // --- 2. User Votes for the Pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, SAIL, SAIL>(scenario, clock)
    };

    // --- 3. Advance to Epoch 1 (OSAIL1) ---
    clock::increment_for_testing(clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch start

    // --- 5. Advance to Epoch 2 (OSAIL2) ---
    clock::increment_for_testing(clock, WEEK); // Advance clock by one week

    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            scenario,
            0,
            clock
        );
        coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(scenario, usd_metadata, &mut aggregator, clock);
    };

    (first_epoch_emissions, second_epoch_emissions, aggregator)
}

#[test]
fun test_distribution_no_positions_no_emissions() {
    let admin = @0xA1;
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (_, _, aggregator) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &usd_metadata,
        &mut clock
    );

    // we are not expecting any emissions as there are not positions deposited 
    let expected_total_supply = 0;
    // check total supply of oSAIL
    scenario.next_tx(admin);
    {
        // first epoch was not distributed, so current total supply is only from second epoch
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(expected_total_supply - minter.o_sail_minted_supply() <= 2, 1);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribution_no_rollover() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (_, second_epoch_emissions, aggregator) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &usd_metadata,
        &mut clock
    );

    // we are depositing position only on second epoch, so we are expecting only second epoch emissions
    let expected_total_supply = second_epoch_emissions;

    // create position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    clock.increment_for_testing(WEEK);

    // get rewards prior to withdrawing position
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // withdraw position
    scenario.next_tx(lp1);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check emissions are equal to the second epoch emissions
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(expected_total_supply - minter.o_sail_minted_supply() <= 2, 1);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribution_rollover_no_rewards_in_non_distributed_epoch() {
        let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (_, _, aggregator) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &usd_metadata,
        &mut clock
    );

    // we are depositing position only on second epoch, so we are expecting only second epoch emissions
    let expected_total_supply = 0;

    // advance to the next epoch so there should be no rewards
    clock.increment_for_testing(WEEK);

    // create position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario,
            lp1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            1000,
            &clock
        );
    };

    // deposit position
    scenario.next_tx(lp1);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    clock.increment_for_testing(WEEK);

    // get rewards prior to withdrawing position
    // rewards should be 0 as this epoch was not distributed
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // withdraw position
    scenario.next_tx(lp1);
    {
        setup::withdraw_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // check emissions are equal to the second epoch emissions
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(minter.o_sail_minted_supply() - expected_total_supply <= 2, 1);
        test_scenario::return_shared(minter);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDistributeGaugeInvalidToken)]
fun test_distribute_rollover_random_next_token_is_invalid() {
    let admin = @0xA1;
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let (_, _, mut aggregator) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &usd_metadata,
        &mut clock
    );
     //  Advance to Epoch 3 (OSAIL3) ---
    clock.increment_for_testing(WEEK); // Advance clock by one week

    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail3_supply = setup::update_minter_period<SAIL, OSAIL3>(
            &mut scenario,
            500_000, // Arbitrary supply for OSAIL3
            &clock
        );
        coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
    };

    // Distribute OSAIL2 (wrong token) rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_full_epoch_reward_in_next_epoch() {
    let admin = @0xE1;
    let user = @0xE2; // User with the lock
    let lp = @0xE3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let first_epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        first_epoch_emissions,
        0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // Create position
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

    // Deposit position
    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 4. Advance to end of Epoch 1 ---
    clock::increment_for_testing(&mut clock, WEEK);

    // --- 5. Advance to Epoch 2 ---
    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            &mut scenario,
            0, // No initial supply for OSAIL2 needed for this test
            &clock
        );
        coin::burn_for_testing(initial_o_sail2_supply);
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 6. Claim Rewards ---
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // --- 7. Verify Rewards ---
    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        // The reward should be equal to the first epoch's emissions as the position
        // was the only one and staked for the entire duration.
        // A small tolerance is allowed for potential rounding differences.
        assert!(first_epoch_emissions - reward.value() <= 3, 1);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_mid_epoch_then_rollover_and_claim_rest() {
    let admin = @0xF1;
    let user = @0xF2;
    let lp = @0xF3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let first_epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup for Epoch 1 ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, first_epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(&mut scenario, lp, position_tick_lower, position_tick_upper, position_liquidity, &clock);
    };
    scenario.next_tx(lp); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 4. Advance time by HALF a week and claim ---
    clock::increment_for_testing(&mut clock, WEEK / 2);

    let expected_first_claim = first_epoch_emissions / 2;
    scenario.next_tx(lp); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_first_claim - reward.value() <= 2, 1);
        coin::burn_for_testing(reward);
    };

    // --- 5. Advance to end of Epoch 1 ---
    clock::increment_for_testing(&mut clock, WEEK / 2);

    // --- 6. Advance to Epoch 2 ---
    scenario.next_tx(admin); {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(initial_o_sail2_supply);
    };

    // Distribute 0 emissions for Epoch 2 to isolate testing of rollover rewards
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock); 
    };

    // --- 7. Claim remaining rewards in Epoch 2 ---
    let expected_second_claim = first_epoch_emissions / 2;
    scenario.next_tx(lp); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    scenario.next_tx(lp); {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(expected_second_claim - reward.value() <= 3, 2);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_rewards_after_10_epochs() {
    let admin = @0x101;
    let user = @0x102;
    let lp = @0x103;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup for Epoch 1 ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    scenario.next_tx(lp); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(&mut scenario, lp, position_tick_lower, position_tick_upper, position_liquidity, &clock);
    };
    scenario.next_tx(lp); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- Advance through epochs 2 to 10 ---
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 2
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 3
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 4
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL4, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 5
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL5>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL5, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 6
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL6>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL6, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 7
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL7>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL7, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 8
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL8>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL8, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 9
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL9>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL9, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // Epoch 10
    scenario.next_tx(admin); {
        let o_sail_supply = setup::update_minter_period<SAIL, OSAIL10>(&mut scenario, 0, &clock);
        coin::burn_for_testing(o_sail_supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL10, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock::increment_for_testing(&mut clock, WEEK);

    // --- Claim all rewards ---
    scenario.next_tx(lp); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL10>(&mut scenario, &clock);
    };

    // --- Verify Rewards ---
    scenario.next_tx(lp); {
        let reward = scenario.take_from_sender<Coin<OSAIL10>>();
        let total_expected_emissions = 10 * epoch_emissions;
        assert!(total_expected_emissions - reward.value() <= 20, 1); // Allow tolerance for rounding
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_inactive_position_stops_earning_rewards() {
    let admin = @0x201;
    let user = @0x202; // a swapper
    let lp_full_range = @0x203; // LP with a full-range, non-staked position
    let lp_tight_range = @0x204; // LP with a tight-range, staked position
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP (full range) Creates a Non-Staked Position ---
    // This position provides liquidity for the swap.
    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 10_000_000_000u128, &clock
        );
    };

    // --- 4. LP (tight range) Creates and Stakes a Position ---
    let tick_lower = integer_mate::i32::neg_from(10).as_u32();
    let tick_upper = integer_mate::i32::from(10).as_u32();
    scenario.next_tx(lp_tight_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_tight_range, tick_lower, tick_upper, 1_000_000_000u128, &clock
        );
    };
    scenario.next_tx(lp_tight_range); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 5. Advance time by HALF a week ---
    clock.increment_for_testing(WEEK / 2);

    // --- 6. Swap to move price out of the tight range ---
    scenario.next_tx(user);
    {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());

        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };

    // --- 7. Claim rewards immediately after position becomes inactive ---
    let expected_first_claim = epoch_emissions / 2;
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_first_claim - reward.value() <= 5, 1);
        coin::burn_for_testing(reward);
    };

    // --- 8. Wait for the rest of the epoch and check for new rewards ---
    clock.increment_for_testing(WEEK / 2);
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(reward.value() == 0, 2);
        coin::burn_for_testing(reward);
    };

    // --- 9. Advance to next epoch, wait, and check rewards again ---
    scenario.next_tx(admin); {
        let supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock.increment_for_testing(WEEK);

    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(reward.value() == 0, 3);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_then_inactive_position_stops_earning() {
    let admin = @0x301;
    let user = @0x302; // a swapper
    let lp_full_range = @0x303; // LP with a full-range, non-staked position
    let lp_tight_range = @0x304; // LP with a tight-range, staked position
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP (full range) Creates a Non-Staked Position ---
    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 10_000_000_000u128, &clock
        );
    };

    // --- 4. LP (tight range) Creates and Stakes a Position ---
    let tick_lower = integer_mate::i32::neg_from(10).as_u32();
    let tick_upper = integer_mate::i32::from(10).as_u32();
    scenario.next_tx(lp_tight_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_tight_range, tick_lower, tick_upper, 1_000_000_000u128, &clock
        );
    };
    scenario.next_tx(lp_tight_range); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 5. Advance time by HALF a week, claim, then swap ---
    clock.increment_for_testing(WEEK / 2);

    // Claim rewards for the first half of the epoch
    let expected_first_claim = epoch_emissions / 2;
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_first_claim - reward.value() <= 5, 1);
        coin::burn_for_testing(reward);
    };

    // Swap to move price out of the tight range, making the position inactive
    scenario.next_tx(user);
    {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());

        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };

    // --- 6. Wait for the rest of the epoch and check for new rewards ---
    clock.increment_for_testing(WEEK / 2);
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(reward.value() == 0, 2); // Should be zero as position was inactive
        coin::burn_for_testing(reward);
    };

    // --- 7. Advance to next epoch, wait, and check rewards again ---
    scenario.next_tx(admin); {
        let supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    clock.increment_for_testing(WEEK);

    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(reward.value() == 0, 3); // Should still be zero
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_inactive_position_claim_at_epoch_end() {
    let admin = @0x401;
    let user = @0x402; // a swapper
    let lp_full_range = @0x403; // LP with a full-range, non-staked position
    let lp_tight_range = @0x404; // LP with a tight-range, staked position
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP (full range) Creates a Non-Staked Position ---
    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 10_000_000_000u128, &clock
        );
    };

    // --- 4. LP (tight range) Creates and Stakes a Position ---
    let tick_lower = integer_mate::i32::neg_from(10).as_u32();
    let tick_upper = integer_mate::i32::from(10).as_u32();
    scenario.next_tx(lp_tight_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_tight_range, tick_lower, tick_upper, 1_000_000_000u128, &clock
        );
    };
    scenario.next_tx(lp_tight_range); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 5. Advance time by HALF a week, then swap ---
    clock.increment_for_testing(WEEK / 2);

    // Swap to move price out of the tight range, making the position inactive
    scenario.next_tx(user);
    {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());

        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(
            &mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock
        );
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };

    // --- 6. Wait for the rest of the epoch ---
    clock.increment_for_testing(WEEK / 2);

    // --- 7. Claim rewards at the end of the epoch ---
    let expected_claim = epoch_emissions / 2;
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_claim - reward.value() <= 5, 1);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_rewards_accrue_only_when_active_across_epochs() {
    let admin = @0x501;
    let user = @0x502; // a swapper
    let lp_full_range = @0x503; // LP for swap liquidity
    let lp_tight_range = @0x504; // Staked LP
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup for Epoch 1 ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. Create Positions ---
    // Full-range position to provide liquidity for swaps
    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 10_000_000_000u128, &clock
        );
    };
    // Tight-range position to be staked
    let tick_lower = integer_mate::i32::neg_from(10).as_u32();
    let tick_upper = integer_mate::i32::from(10).as_u32();
    scenario.next_tx(lp_tight_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_tight_range, tick_lower, tick_upper, 1_000_000_000u128, &clock
        );
    };
    scenario.next_tx(lp_tight_range); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 4. Wait for Epoch 1 to end (position is active) ---
    clock.increment_for_testing(WEEK);

    // --- 5. Make position inactive and advance to Epoch 2 ---
    scenario.next_tx(user); {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };

    scenario.next_tx(admin); {
        let supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 6. Wait for Epoch 2 to end (position is inactive) ---
    clock.increment_for_testing(WEEK);

    // --- 7. Make position active again and advance to Epoch 3 ---
    scenario.next_tx(user); {
        let coin_a = coin::mint_for_testing<USD_TESTS>(475783117, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, true, true, 475783117, 1, tick_math::min_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };

    scenario.next_tx(admin); {
        let supply = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        coin::burn_for_testing(supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 8. Wait for Epoch 3 to end (position is active) ---
    clock.increment_for_testing(WEEK);

    // --- 9. Claim rewards ---
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL3>(&mut scenario, &clock);
    };

    // --- 10. Verify rewards ---
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL3>>();
        // Should have rewards from epoch 1 and 3 (2 * emissions), but not from epoch 2.
        let expected_rewards = 2 * epoch_emissions;
        assert!(expected_rewards - reward.value() <= 5, 1);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_intermittent_active_position_rewards() {
    let admin = @0x601;
    let user = @0x602; // a swapper
    let lp_full_range = @0x603; // LP for swap liquidity
    let lp_tight_range = @0x604; // Staked LP
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182;
    let epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock, lock_amount, lock_duration, epoch_emissions, 0
    );

    // --- 2. Distribute Gauge Rewards ---
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. Create Positions ---
    scenario.next_tx(lp_full_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_full_range, tick_math::min_tick().as_u32(), tick_math::max_tick().as_u32(), 10_000_000_000u128, &clock
        );
    };
    let tick_lower = integer_mate::i32::neg_from(10).as_u32();
    let tick_upper = integer_mate::i32::from(10).as_u32();
    scenario.next_tx(lp_tight_range); {
        setup::create_position_with_liquidity<USD_TESTS, SAIL>(
            &mut scenario, lp_tight_range, tick_lower, tick_upper, 1_000_000_000u128, &clock
        );
    };
    scenario.next_tx(lp_tight_range); {
        setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 4. Intermittent Active/Inactive Periods ---
    // Q1: Inactive
    scenario.next_tx(user); {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };
    clock.increment_for_testing(WEEK / 4);

    // Q2: Active
    scenario.next_tx(user); {
        let coin_a = coin::mint_for_testing<USD_TESTS>(475783117, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, true, true, 475783117, 1, tick_math::min_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };
    clock.increment_for_testing(WEEK / 4);

    // Q3: Inactive
    scenario.next_tx(user); {
        let coin_a = coin::zero<USD_TESTS>(scenario.ctx());
        let coin_b = coin::mint_for_testing<SAIL>(500000000, scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, false, true, 500000000, 1, tick_math::max_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };
    clock.increment_for_testing(WEEK / 4);

    // Q4: Active
    scenario.next_tx(user); {
        let coin_a = coin::mint_for_testing<USD_TESTS>(475783117, scenario.ctx());
        let coin_b = coin::zero<SAIL>(scenario.ctx());
        let (coin_a, coin_b) = setup::swap<USD_TESTS, SAIL>(&mut scenario, coin_a, coin_b, true, true, 475783117, 1, tick_math::min_sqrt_price(), &clock);
        coin::burn_for_testing(coin_a);
        coin::burn_for_testing(coin_b);
    };
    clock.increment_for_testing(WEEK / 4);

    // --- 5. Claim and Verify Rewards ---
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL1>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        let expected_rewards = epoch_emissions / 2;
        assert!(expected_rewards - reward.value() <= 10, 1);
        coin::burn_for_testing(reward);
    };

    // --- 6. Advance to next epoch and check for zero earnings ---
    scenario.next_tx(admin); {
        let supply = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        coin::burn_for_testing(supply);
    };
    scenario.next_tx(admin); {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    scenario.next_tx(lp_tight_range); {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(reward.value() == 0, 2);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_reward_without_distribution_in_next_epoch() {
    let admin = @0xF1;
    let user = @0xF2; // User with the lock
    let lp = @0xF3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let first_epoch_emissions = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration,
        first_epoch_emissions,
        0
    );

    // --- 2. Distribute Gauge Rewards for Epoch 1 (OSAIL1) ---
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // --- 3. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let lp_position_id: ID;

    // Create position
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

    // Deposit position
    scenario.next_tx(lp);
    {
        lp_position_id = setup::deposit_position<USD_TESTS, SAIL>(&mut scenario, &clock);
    };

    // --- 4. Advance to end of Epoch 1 ---
    clock::increment_for_testing(&mut clock, WEEK);

    // --- 5. Advance to Epoch 2 ---
    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            &mut scenario,
            0, // No initial supply for OSAIL2 needed for this test
            &clock
        );
        coin::burn_for_testing(initial_o_sail2_supply);
    };

    // --- 6. Advance another week without distributing gauge for Epoch 2 ---
    clock::increment_for_testing(&mut clock, WEEK);

    // --- 7. Check Earned Rewards ---
    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_osail1 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );
        let earned_osail2 = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL2>(
            &gauge,
            &pool,
            lp_position_id,
            &clock
        );

        assert!(earned_osail1 == 0, 1);
        assert!(first_epoch_emissions - earned_osail2 <= 3, 2);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // --- 8. Claim Rewards ---
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD_TESTS, SAIL, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // --- 9. Verify Rewards ---
    scenario.next_tx(lp);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        // The reward should be equal to the first epoch's emissions.
        assert!(first_epoch_emissions - reward.value() <= 3, 3);
        coin::burn_for_testing(reward);
    };

    // --- Cleanup ---
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_earned_on_random_position_id_is_zero() {
    let admin = @0xD1;
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let aggregator = setup::full_setup_with_lock<USD_TESTS, SAIL, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, 
        admin,
        user,
        &mut clock,
        1000,
        182,
        DEFAULT_GAUGE_EMISSIONS,
        0
    );

    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let random_position_id = object::id_from_address(@0xDEADBEEF);

        let earned = minter.earned_by_position<USD_TESTS, SAIL, SAIL, OSAIL1>(
            &gauge,
            &pool,
            random_position_id,
            &clock
        );

        assert!(earned == 0, 1);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
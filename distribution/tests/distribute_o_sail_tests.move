#[test_only]
module distribution::distribute_o_sail_tests;

use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use std::type_name;

use distribution::minter::{Self, Minter};
use distribution::setup;
use distribution::voter::{Voter};
use distribution::distribution_config::{DistributionConfig};
use distribution::voter_cap::{VoterCap};
use distribution::gauge::{Self, Gauge, StakedPosition};
use clmm_pool::config::{Self, GlobalConfig};
use clmm_pool::pool::{Pool};
use clmm_pool::tick_math;
use sui::test_utils;
use distribution::voting_escrow::{Lock, VotingEscrow};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

const DEFAULT_GAUGE_EMISSIONS: u64 = 1_000_000;

// Define dummy types used in setup
public struct SAIL has drop, store {}

public struct OSAIL1 has drop {}

public struct OSAIL2 has drop {}

public struct OSAIL3 has drop {}

public struct USD1 has drop, store {}

public struct OTHER has drop, store {}

// used if you want to call some methods that are only supposed to be called by Voter
fun create_voter_cap(
    scenario: &mut Scenario,
    admin: address,
) {
        let voter = scenario.take_shared<Voter>();
        let voter_cap = distribution::voter_cap::create_voter_cap(
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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OTHER, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };


    scenario.next_tx(admin);
    {
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();

        // token notification should not change the
        assert!(gauge.period_finish() == 0, 1);
        assert!(gauge.borrow_epoch_token() == type_name::get<OSAIL1>(), 2);

        test_scenario::return_shared(gauge);
    };


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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OTHER, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };
    clock.increment_for_testing(WEEK);

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OSAIL1, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::vote_for_pool<USD1, SAIL, SAIL>(&mut scenario, &mut clock)
    };

    scenario.next_tx(admin);
    {
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
    };

    clock::increment_for_testing(&mut clock, WEEK * 2 / 3);
    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OSAIL1, OSAIL2>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        test_utils::destroy(undistributed);

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD1, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(admin);
    {
        create_voter_cap(&mut scenario, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OTHER, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        let voter_cap = distribution::voter_cap::create_voter_cap(
            // random voter_id
            object::id_from_address(@0xABC123),
            scenario.ctx()
        );
        transfer::public_transfer(voter_cap, admin);
    };

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OTHER, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenAlreadyNotifiedThisEpoch)] 
public fun test_gauge_notify_epoch_token_already_notified(
) {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OTHER, OSAIL1>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };
    // we are not chaning epoch, so the notification would fail
    clock.increment_for_testing(WEEK / 2);

    scenario.next_tx(admin);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let voter_cap = scenario.take_from_sender<VoterCap>();
        let undistributed = gauge.notify_epoch_token<USD1, SAIL, OSAIL1, OSAIL2>(
            &mut pool,
            &voter_cap,
            &clock,
            scenario.ctx()
        );
        undistributed.destroy_zero();

        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(voter_cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EGetPositionRewardInvalidRewardToken)]
public fun test_gauge_get_position_reward_invalid_reward_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD1, SAIL, USD1>(&mut scenario, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EGetPositionRewardGaugeDoesNotMatchPool)]
public fun test_gauge_get_position_reward_invalid_pool() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD1, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = gauge::EGetPositionRewardInvalidRewardToken)]
public fun test_gauge_get_reward_invalid_reward_token() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let default_gauge_base_emissions = 1_000_000;

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    scenario.next_tx(user);
    {
        // USD1 is not a valid reward token
        setup::get_staked_position_reward<USD1, SAIL, USD1>(&mut scenario, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EGetPositionRewardGaugeDoesNotMatchPool)]
public fun test_gauge_get_reward_invalid_pool() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        test_utils::destroy(pool);

        setup::setup_pool_with_sqrt_price<USD1, SAIL>(&mut scenario, 1<<64, 10);
    };

    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

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
    clock: &mut Clock,
): (u64, ID, ID) {

    let ms_in_week = 7 * 24 * 60 * 60 * 1000;

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(scenario, clock);
    };

    // lp1 creates and stakes position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp1_position_id = setup::deposit_position<USD1, SAIL>(
            scenario,
            clock
        );
    };

    // lp2 creates and stakes position
    scenario.next_tx(lp2);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp2_position_id = setup::deposit_position<USD1, SAIL>(
            scenario,
            clock
        );
    };

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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_lp1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp1_position_id,
            clock
        );
        let (earned_lp2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp2_position_id,
            clock
        );

        let (earned_lp1_nonepoch_coin, _) = gauge.earned_by_position<USD1, SAIL, USD1>(
            &pool,
            lp1_position_id,
            clock
        );

        let (earned_lp2_nonepoch_coin, _) = gauge.earned_by_position<USD1, SAIL, USD1>(
            &pool,
            lp2_position_id,
            clock
        );

        let earned_lp1_by_pos_ids = gauge.earned_by_position_ids<USD1, SAIL, OSAIL1>(
            &pool,
            &vector[lp1_position_id],
            clock
        );

        let earned_lp2_by_pos_ids = gauge.earned_by_position_ids<USD1, SAIL, OSAIL1>(
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(scenario, clock);
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(scenario, clock);
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

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        position_liquidity,
        position_tick_lower,
        position_tick_upper,
        &mut clock,
    );

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

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        1_000_000_000,
        position_tick_lower,
        position_tick_upper,
        2_000_000_000,
        position_tick_lower,
        position_tick_upper,
        &mut clock,
    );

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_different_tick_ranges_distribute() {
    let admin = @0xA1;
    let position_liquidity: u128 = 1_000_000_000;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        position_liquidity,
        integer_mate::i32::neg_from(100).as_u32(),
        integer_mate::i32::from(100).as_u32(),
        position_liquidity,
        tick_math::min_tick().as_u32(),
        tick_math::max_tick().as_u32(),
        &mut clock,
    );

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_different_tick_ranges_different_liquidity_distribute() {
    let admin = @0xA1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    check_two_positions_single_epoch(
        &mut scenario,
        admin,
        1,
        integer_mate::i32::neg_from(5555).as_u32(),
        integer_mate::i32::from(1111).as_u32(),
        10_000_000_000,
        tick_math::min_tick().as_u32(),
        tick_math::max_tick().as_u32(),
        &mut clock,
    );

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

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
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

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
fun test_single_position_reward_over_time_distribute() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup --- 
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
    };


    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let lp1_position_id: ID;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp1_position_id = setup::deposit_position<USD1, SAIL>(
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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();

        let (earned_half, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp1_position_id,
            &clock
        );

        let diff_first_half = expected_first_half_reward - earned_half;
        assert!(diff_first_half <= epoch1_emissions / 1_000_000, 1); // Allow rounding by 1/1000000

        expected_second_half_reward = epoch1_emissions - earned_half;

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // claim half reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();

        let (earned_full, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            lp1_position_id,
            &clock
        );
        let diff_full = expected_second_half_reward - earned_full;
        assert!(diff_full <= 2, 2); // Allow rounding by 1

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // claim second half reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // verify second half reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_second_half_reward - reward.value() <= 2, 3);

        coin::burn_for_testing(reward);
    };

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

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
    };


    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD1, SAIL, SAIL>(&mut scenario, &mut clock)
    };


    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by HALF a week ---
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock::increment_for_testing(&mut clock, WEEK / 2 - 500);
    let expected_lp1_reward = epoch1_emissions / 2;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
            &mut scenario,
            &clock,
        );
    };


    // verify half reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward - reward.value() <= epoch1_emissions / 1_000_000, 2);

        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        coin::burn_for_testing(reward);
    };

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

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD1, SAIL, SAIL>(&mut scenario, &mut clock)
    };


    clock.increment_for_testing(WEEK / 2 - 10 * 60 * 60 * 1000);

    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by one hour ---
    clock::increment_for_testing(&mut clock, 60 * 60 * 1000);
    let expected_lp1_reward = ((epoch1_emissions as u128 * 60 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    let epoch1_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- Initial Setup ---
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD1, SAIL, SAIL>(&mut scenario, &mut clock)
    };

    clock.increment_for_testing(WEEK / 3 - 10 * 60 * 60 * 1000);

    // --- Tx: lp1 Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;

    // First create the position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // --- Advance time by one hour ---
    clock::increment_for_testing(&mut clock, 60 * 60 * 1000);
    let expected_lp1_reward = ((epoch1_emissions as u128 * 60 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // Advance time by half an hour
    clock::increment_for_testing(&mut clock, 30 * 60 * 1000);
    let expected_lp1_reward_dep_2 = ((epoch1_emissions as u128 * 30 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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
    clock: &mut Clock,
): (ID, u64, u64) {
    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year

    let first_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;
    let second_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(scenario, clock);
    };

    // --- 4. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 2_000_000_000u128; // Example liquidity
    let lp_position_id: ID;

    // Create position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp_position_id = setup::deposit_position<USD1, SAIL>(
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
        setup::distribute_gauge_epoch_2<USD1, SAIL, SAIL, OSAIL1, OSAIL2>(scenario, clock);
    };

    // --- 6. Advance Time by One More Week ---
    clock::increment_for_testing(clock, WEEK);

    (lp_position_id, first_epoch_emissions, second_epoch_emissions)
}

#[test]
fun test_gauge_get_position_reward() {
        let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (
        lp_position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let (earned_osail1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, lp_position_id, &clock); 
        let (earned_osail2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, lp_position_id, &clock);

        assert!(first_epoch_emissions - earned_osail1 <= 2, 1);
        assert!(second_epoch_emissions - earned_osail2 <= 2, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

        // Claim all rewards
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward1 = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(first_epoch_emissions - reward1.value() <= 2, 3);
        coin::burn_for_testing(reward1);

        let reward2 = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions - reward2.value() <= 2, 4);
        coin::burn_for_testing(reward2);
    };

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

    let (
        lp_position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let (earned_osail1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, lp_position_id, &clock); 
        let (earned_osail2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, lp_position_id, &clock);

        assert!(first_epoch_emissions - earned_osail1 <= 2, 1);
        assert!(second_epoch_emissions - earned_osail2 <= 2, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // --- 7. Advance Time by 1 more week, rewards should not change ---
    clock::increment_for_testing(&mut clock, WEEK);

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let (earned_osail1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, lp_position_id, &clock); 
        let (earned_osail2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, lp_position_id, &clock);

        assert!(first_epoch_emissions - earned_osail1 <= 2, 1);
        assert!(second_epoch_emissions - earned_osail2 <= 2, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // Claim all rewards
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward1 = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(first_epoch_emissions - reward1.value() <= 2, 3);
        coin::burn_for_testing(reward1);

        let reward2 = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions - reward2.value() <= 2, 4);
        coin::burn_for_testing(reward2);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = gauge::EGetRewardPrevTokenNotClaimed)]
fun test_gauge_get_position_reward_fails_wrong_order() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &mut clock,
    );

    // Claim all rewards
    // Should error because of wrong order
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

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

    let (
        position_id,
        first_epoch_emissions,
        second_epoch_emissions
    ) = multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &mut clock,
    );

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let (earned_osail1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, position_id, &clock);
        let (earned_osail2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, position_id, &clock);

        assert!(first_epoch_emissions - earned_osail1 <= 2, 1);
        assert!(second_epoch_emissions - earned_osail2 <= 2, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

        // Claim all rewards
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // Verify all rewards were claimed
    scenario.next_tx(lp);
    {
        let reward1 = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(first_epoch_emissions - reward1.value() <= 2, 3);
        coin::burn_for_testing(reward1);

        let reward2 = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(second_epoch_emissions - reward2.value() <= 2, 4);
        coin::burn_for_testing(reward2);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::EGetRewardPrevTokenNotClaimed)]
fun test_gauge_get_reward_fails_wrong_order() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    multi_epoch_distribute_setup(
        &mut scenario,
        admin,
        user,
        lp,
        &mut clock,
    );

    // Claim all rewards
    // Should error because of wrong order
    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    scenario.next_tx(lp);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

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

    let ms_in_week = 7 * 24 * 60 * 60 * 1000;
    let gap_to_vote = 60 * 60 * 1000 + 1000;

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months
    let epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(&mut scenario, &clock);
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp1_position_id = setup::deposit_position<USD1, SAIL>(
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
        setup::create_position_with_liquidity<USD1, SAIL>(
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
        lp2_position_id = setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    // advance to end of the week
    clock.increment_for_testing(ms_in_week / 2 - 500);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_lp1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            lp1_position_id,
            &clock
        );
        let (earned_lp2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp2_position_id,
            &clock
        );

        let (earned_lp2_nonepoch_coin, _) = gauge.earned_by_position<USD1, SAIL, USD1>(
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_lp1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            lp1_position_id,
            &clock
        );
        let (earned_lp2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
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

    // lp2 withdraws the reward
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_lp1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            lp1_position_id,
            &clock
        );
        let (earned_lp2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
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

    // lp2 withdraws position to increase its liquidity
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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
        setup::add_liquidity<USD1, SAIL>(&mut scenario, liquidity_to_add, &clock);
    };

    // lp2 deposits position again
    scenario.next_tx(lp2);
    {
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 2 - 500);

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_second_half_week_earned - reward.value() <= 2, 6);

        coin::burn_for_testing(reward);
    };


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
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_lp1, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            lp1_position_id,
            &clock
        );
        let (earned_lp2, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
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

    // lp2 withdraws position to decrease its liquidity
    scenario.next_tx(lp2);
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
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
        setup::remove_liquidity<USD1, SAIL>(&mut scenario, liquidity_to_remove, &clock);
    };

    // lp2 deposits position again
    scenario.next_tx(lp2);
    {
        setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    clock.increment_for_testing(WEEK / 2 - 500);

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
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
        setup::get_staked_position_reward<USD1, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_second_half_week_earned - reward.value() <= 2, 6);

        coin::burn_for_testing(reward);
    };


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
    clock: &mut Clock,
): (u64, u64, u64) {
    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year
    let mut extra_o_sail_supply = 0;
    let first_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;
    let second_epoch_emissions: u64 = DEFAULT_GAUGE_EMISSIONS;

    // --- 1. Full Setup ---
    setup::full_setup_with_lock<USD1, SAIL, SAIL, OSAIL1>(
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
        setup::distribute_gauge_epoch_1<USD1, SAIL, SAIL, OTHER, OSAIL1>(scenario, clock);
    };

    // advance time to make sure that voting started
    clock::increment_for_testing(clock, 10 * 60 * 60 * 1000);

    // --- 2. User Votes for the Pool ---
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD1, SAIL, SAIL>(scenario, clock)
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
            500_000, // Arbitrary supply for OSAIL2
            clock
        );
        extra_o_sail_supply = extra_o_sail_supply + initial_o_sail2_supply.value();
        coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_2<USD1, SAIL, SAIL, OSAIL1, OSAIL2>(scenario, clock);
    };

    (first_epoch_emissions, second_epoch_emissions, extra_o_sail_supply)
}

#[test]
fun test_distribution_rollover_is_burnt() {
    let admin = @0xA1;
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (_, second_epoch_emissions, extra_o_sail_supply) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &mut clock
    );

    let expected_total_supply = second_epoch_emissions + extra_o_sail_supply;

    // check total supply of oSAIL
    scenario.next_tx(admin);
    {
        // first epoch was not distributed, so current total supply is only from second epoch
        let minter = scenario.take_shared<Minter<SAIL>>();
        assert!(minter.o_sail_total_supply() - expected_total_supply <= 2, 1);
        test_scenario::return_shared(minter);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_distribute_rollover_not_affecting_next_epoch() {
    let admin = @0xA1;
    let user = @0xA2;
    let lp1 = @0xA3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (_, second_epoch_emissions, _) = rollover_setup(
        &mut scenario,
        admin,
        user,
        &mut clock
    );

    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128;
    let expected_rewards_second_epoch = second_epoch_emissions;

    // lp1 creates a position
    scenario.next_tx(lp1);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
            &mut scenario,
            lp1,
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // lp1 deposits the position
    let position_id: ID;
    scenario.next_tx(lp1);
    {
        position_id = setup::deposit_position<USD1, SAIL>(&mut scenario, &clock);
    };

    // Advance time by one week to earn the rewards
    clock::increment_for_testing(&mut clock, WEEK);

    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let (earned_first_epoch, _) = gauge.earned_by_position<USD1, SAIL, OSAIL1>( 
            &pool,
            position_id,
            &clock
        );
        let (earned_second_epoch, _) = gauge.earned_by_position<USD1, SAIL, OSAIL2>(
            &pool,
            position_id,
            &clock
        );

        assert!(earned_first_epoch == 0, 1);
        assert!(expected_rewards_second_epoch - earned_second_epoch <= 2, 2);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // lp1 claims reward for second epoch
    scenario.next_tx(lp1);
    {
        setup::get_staked_position_reward<USD1, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // check claimed rewards
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL2>>();
        assert!(expected_rewards_second_epoch - reward.value() <= 2, 4);

        coin::burn_for_testing(reward);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenInvalidCurrentToken)]
fun test_distribute_rollover_random_current_token_is_invalid() {
    let admin = @0xA1;
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (_, _, _) = rollover_setup(
        &mut scenario,
        admin,
        user,
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

    // use wrong current epoch token
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_3<USD1, SAIL, SAIL, OTHER, OSAIL3>(&mut scenario, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = gauge::ENotifyEpochTokenInvalidCurrentToken)]
fun test_distribute_rollover_wrong_epoch_current_token_is_invalid() {
    let admin = @0xA1;
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (_, _, _) = rollover_setup(
        &mut scenario,
        admin,
        user,
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

    // use current epoch token from wrong epoch
    scenario.next_tx(admin);
    {
        setup::distribute_gauge_epoch_3<USD1, SAIL, SAIL, OSAIL1, OSAIL3>(&mut scenario, &clock);
    };

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

    let (_, _, _) = rollover_setup(
        &mut scenario,
        admin,
        user,
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
        setup::distribute_gauge_epoch_3<USD1, SAIL, SAIL, OSAIL2, OTHER>(&mut scenario, &clock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}
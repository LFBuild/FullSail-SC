#[test_only]
module distribution::distribute_o_sail_tests;

use sui::test_scenario::{Self, Scenario};
use sui::test_utils;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use distribution::minter::{Self, Minter};
use distribution::voter_cap;
use distribution::setup;
use distribution::voting_escrow::{Self, Lock, VotingEscrow};
use distribution::voter::{Self, Voter};
use distribution::distribution_config::{DistributionConfig};
use distribution::reward_distributor::{RewardDistributor};
use distribution::gauge::{Self, Gauge};
use clmm_pool::pool::{Pool};
use clmm_pool::position::{Position};
use clmm_pool::tick_math;

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

// Define dummy types used in setup
public struct SAIL has drop, store {}
public struct OSAIL1 has drop {}
public struct OSAIL2 has drop {}
public struct OSAIL3 has drop {}
public struct USD1 has drop, store {}

/// Sets up the entire environment: CLMM, Distribution, Pool, Gauge, 
/// activates Minter, and creates a lock for the user.
/// Assumes standard tick spacing and price for the pool.
/// The admin address receives MinterAdminCap, GovernorCap, CreateCap.
/// The user address receives the specified oSAIL and the created Lock.
#[test_only]
public fun full_setup_with_lock(
    scenario: &mut Scenario,
    admin: address,
    user: address,
    clock: &mut Clock, // Make clock mutable as activate_minter needs it
    lock_amount: u64,
    lock_duration_days: u64,
) {
    // Tx 1: Setup CLMM Factory & Fee Tier (using tick_spacing=1)
    {
        setup::setup_clmm_factory_with_fee_tier(scenario, admin, 1, 1000);
    };

    // Tx 2: Setup Distribution (admin gets caps)
    {
        // Needs CLMM config initialized
        setup::setup_distribution<SAIL>(scenario, admin, clock);
    };

    // Tx 3: Setup Pool (USD1/SAIL, price=1)
    let pool_sqrt_price: u128 = 1 << 64;
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        setup::activate_minter<SAIL>(scenario, clock);
    };

    // Tx 5: Create Gauge for the USD1/SAIL pool
    scenario.next_tx(admin); // Admin needs caps to create gauge
    {
        setup::setup_gauge_for_pool<USD1, SAIL, SAIL>(
            scenario,
            clock // Pass immutable clock ref here
        );
    };

    // Tx 6: Create Lock for the user
    scenario.next_tx(user); // User needs to be sender to receive the lock
    {
        setup::mint_and_create_lock<SAIL>(
            scenario, 
            lock_amount, 
            lock_duration_days, 
            clock
        );
        // Lock object is automatically transferred to user
    };
}

// Example test using the setup utility (optional)
#[test]
fun test_o_sail_single_epoch_distribute() {
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

    full_setup_with_lock(
        &mut scenario, 
        admin, 
        user, 
        &mut clock, 
        lock_amount, 
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, gap_to_vote);

    // Tx Vote for the pool
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let pool_id = object::id(&pool);
        let lock = scenario.take_from_sender<Lock>();

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool_id],
            vector[100],
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(lock);
    };

    clock.increment_for_testing(ms_in_week - gap_to_vote + 1000);

    let epoch_emissions: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period with OSAIL2
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            lock_amount, // to make total supply = total locked, cos sail is minted outside of the minter
            &clock
        );
        coin::burn_for_testing(o_sail1_initial_supply);
    };

    // distribute gauge
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        voter.distribute_gauge<USD1, SAIL, OSAIL1>(
            &distribution_config,
            &mut gauge,
            &mut pool,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(distribution_config);
    };

    // --- Add and Stake Positions ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 1_000_000_000u128; // Example liquidity
    let expected_lp1_earned = epoch_emissions / 2;
    let expected_lp2_earned = epoch_emissions / 2;

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

    // advance time to make lp's earn their rewards
    clock.increment_for_testing(ms_in_week);


    scenario.next_tx(user); // Any user can read shared state
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let minter = scenario.take_shared<Minter<SAIL>>();

        let earned_lp1 = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp1_position_id,
            &clock
        );
        let earned_lp2 = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp2_position_id,
            &clock
        );

        let earned_lp2_nonepoch_coin = gauge.earned_by_position<USD1, SAIL, USD1>(
            &pool,
            lp2_position_id,
            &clock
        );

        assert!(expected_lp1_earned - earned_lp1 <= 1, 1);
        assert!(expected_lp2_earned - earned_lp2 <= 1, 2);
        assert!(earned_lp2_nonepoch_coin == 0, 3);

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(minter);
    };

    // lp1 claims reward
    scenario.next_tx(lp1);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        gauge.get_position_reward<USD1, SAIL, OSAIL1>(
            &mut pool,
            lp1_position_id,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
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
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        gauge.get_position_reward<USD1, SAIL, OSAIL1>(
            &mut pool,
            lp2_position_id,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // check claimed rewards
    scenario.next_tx(lp2);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp2_earned - reward.value() <= 1, 5);
        
        coin::burn_for_testing(reward);
    };
    
    clock::destroy_for_testing(clock);
    scenario.end();
}


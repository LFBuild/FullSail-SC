#[test_only]
module distribution::distribute_o_sail_tests;

use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use distribution::minter::{Self, Minter};
use distribution::setup;
use distribution::voting_escrow::{Lock, VotingEscrow};
use distribution::voter::{Voter};
use distribution::distribution_config::{DistributionConfig};
use distribution::gauge::{Self, Gauge};
use clmm_pool::pool::{Pool};
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

fun vote(
    scenario: &mut Scenario,
    pools: vector<ID>,
    weights: vector<u64>,
    clock: &mut Clock,
) {
    let mut voter = scenario.take_shared<Voter>();
    let distribution_config = scenario.take_shared<DistributionConfig>();
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let lock = scenario.take_from_sender<Lock>();

    voter.vote(
        &mut ve,
        &distribution_config,
        &lock,
        pools,
        weights,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(voter);
    test_scenario::return_shared(ve);
    test_scenario::return_shared(distribution_config);
    scenario.return_to_sender(lock);
}

fun vote_for_pool<CoinTypeA, CoinTypeB>(
    scenario: &mut Scenario,
    clock: &mut Clock,
) {
    let pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let pool_id = object::id(&pool);
    vote(
        scenario,
        vector[pool_id],
        vector[10000], // 100% weight
        clock,
    );
    test_scenario::return_shared(pool);
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
    let gap_to_vote = 60 * 60 * 1000 + 1000;

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    full_setup_with_lock(
        scenario,
        admin,
        user,
        clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(clock, gap_to_vote);

    // Tx Vote for the pool
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(scenario, clock)
    };

    clock.increment_for_testing(ms_in_week - gap_to_vote + 1000);

    let epoch_emissions: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period with OSAIL1
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = setup::update_minter_period<SAIL, OSAIL1>(
            scenario,
            lock_amount, // to make total supply = total locked, cos sail is minted outside of the minter
            clock
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
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(distribution_config);
    };

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
            clock
        );
        let earned_lp2 = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
            &pool,
            lp2_position_id,
            clock
        );

        let earned_lp1_nonepoch_coin = gauge.earned_by_position<USD1, SAIL, USD1>(
            &pool,
            lp1_position_id,
            clock
        );

        let earned_lp2_nonepoch_coin = gauge.earned_by_position<USD1, SAIL, USD1>(
            &pool,
            lp2_position_id,
            clock
        );

        let earned_lp1_by_account = gauge.earned_by_account<USD1, SAIL, OSAIL1>(
            &pool,
            lp1,
            clock
        );

        let earned_lp2_by_account = gauge.earned_by_account<USD1, SAIL, OSAIL1>(
            &pool,
            lp2,
            clock
        );

        assert!(expected_lp1_earned - earned_lp1 <= 1, 1);
        assert!(expected_lp2_earned - earned_lp2 <= 1, 2);
        assert!(earned_lp1_nonepoch_coin == 0, 3);
        assert!(earned_lp2_nonepoch_coin == 0, 4);
        assert!(expected_lp1_earned - earned_lp1_by_account <= 1, 5);
        assert!(expected_lp2_earned - earned_lp2_by_account <= 1, 6);

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
            clock,
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
            clock,
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
fun test_single_position_reward_over_time_distribute() {
    let admin = @0xB1;
    let user = @0xB2; // User with the lock
    let lp1 = @0xB3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let lock_amount = 50_000;
    let lock_duration = 182; // ~6 months

    // --- Initial Setup --- 
    full_setup_with_lock(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    // --- Get Expected Emissions for Epoch 1 ---
    let epoch1_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let (current_emissions, _next_emissions) = minter::calculate_epoch_emissions(&minter);
        epoch1_emissions = current_emissions; // Store the emissions for the upcoming epoch
        test_scenario::return_shared(minter);
    };

    // --- Advance Time to Epoch 1 & Update Period ---
    clock::increment_for_testing(&mut clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch
    scenario.next_tx(admin);
    {
        let initial_o_sail_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            1_000_000,
            &clock
        );
        coin::burn_for_testing(initial_o_sail_supply);
    };

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // Distribute OSAIL1 rewards to the gauge based on the user's vote
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

        let earned_half = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
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

        let earned_full = gauge.earned_by_position<USD1, SAIL, OSAIL1>(
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

    // --- Initial Setup ---
    full_setup_with_lock(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    // --- Get Expected Emissions for Epoch 1 ---
    let epoch1_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let (current_emissions, _next_emissions) = minter::calculate_epoch_emissions(&minter);
        epoch1_emissions = current_emissions; // Store the emissions for the upcoming epoch
        test_scenario::return_shared(minter);
    };

    // --- Advance Time to Epoch 1 & Update Period ---
    clock::increment_for_testing(&mut clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch
    scenario.next_tx(admin);
    {
        let initial_o_sail_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            1_000_000,
            &clock
        );
        coin::burn_for_testing(initial_o_sail_supply);
    };

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // Distribute OSAIL1 rewards to the gauge based on the user's vote
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
    let expected_lp1_reward = epoch1_emissions / 2;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
            &mut scenario,
            lp1_position_id,
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

    // --- Initial Setup ---
    full_setup_with_lock(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- Tx: User votes for the pool ---
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    // --- Get Expected Emissions for Epoch 1 ---
    let epoch1_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let (current_emissions, _next_emissions) = minter::calculate_epoch_emissions(&minter);
        epoch1_emissions = current_emissions; // Store the emissions for the upcoming epoch
        test_scenario::return_shared(minter);
    };

    // --- Advance Time to Epoch 1 & Update Period ---
    clock::increment_for_testing(&mut clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch
    scenario.next_tx(admin);
    {
        let initial_o_sail_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            1_000_000,
            &clock
        );
        coin::burn_for_testing(initial_o_sail_supply);
    };

    // --- Tx: Distribute Gauge Rewards (OSAIL1) ---
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // Distribute OSAIL1 rewards to the gauge based on the user's vote
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

    clock.increment_for_testing(WEEK / 2);

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

    // --- Advance time by one hour ---
    clock::increment_for_testing(&mut clock, 60 * 60 * 1000);
    let expected_lp1_reward = ((epoch1_emissions as u128 * 60 * 60 * 1000) / (WEEK as u128 - 1000)) as u64;

    // --- Withdraw the position ---
    scenario.next_tx(lp1); // lp1 checks their rewards
    {
        setup::withdraw_position<USD1, SAIL, OSAIL1>(
            &mut scenario,
            lp1_position_id,
            &clock,
        );
    };


    // verify reward was claimed
    scenario.next_tx(lp1);
    {
        let reward = scenario.take_from_sender<Coin<OSAIL1>>();
        assert!(expected_lp1_reward - reward.value() <= 1, 2);

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
fun test_multi_epoch_reward_distribute() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year

    // --- 1. Full Setup ---
    full_setup_with_lock(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- 2. User Votes for the Pool ---
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    // --- 3. Advance to Epoch 1 (OSAIL1) ---
    clock::increment_for_testing(&mut clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch start

    let first_epoch_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        first_epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period to OSAIL1
    scenario.next_tx(admin);
    {
        let initial_o_sail_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            1_000_000, // Arbitrary supply for OSAIL1
            &clock
        );
        coin::burn_for_testing(initial_o_sail_supply); // Burn the minted OSAIL1 as it's not directly used here
    };

    // Distribute OSAIL1 rewards to the gauge
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

    // --- 4. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 2_000_000_000u128; // Example liquidity
    let lp_position_id: ID;

    // Create position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
            &mut scenario,
            lp, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Deposit position
    scenario.next_tx(lp);
    {
        lp_position_id = setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    let second_epoch_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        second_epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // --- 5. Advance to Epoch 2 (OSAIL2) ---
    clock::increment_for_testing(&mut clock, WEEK); // Advance clock by one week

    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            &mut scenario,
            500_000, // Arbitrary supply for OSAIL2
            &clock
        );
        coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // Distribute OSAIL2 rewards
        voter.distribute_gauge<USD1, SAIL, OSAIL2>(
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

    // --- 6. Advance Time by 1 week ---
    clock::increment_for_testing(&mut clock, WEEK);

    scenario.next_tx(lp);
    {
        let pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let earned_osail1 = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, lp_position_id, &clock);
        let earned_osail2 = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, lp_position_id, &clock);

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
        let earned_osail1 = gauge.earned_by_position<USD1, SAIL, OSAIL1>(&pool, lp_position_id, &clock);
        let earned_osail2 = gauge.earned_by_position<USD1, SAIL, OSAIL2>(&pool, lp_position_id, &clock);

        assert!(first_epoch_emissions - earned_osail1 <= 2, 1);
        assert!(second_epoch_emissions - earned_osail2 <= 2, 2);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
    };

    // Claim all rewards
    scenario.next_tx(lp);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();

        gauge.get_position_reward<USD1, SAIL, OSAIL1>(
            &mut pool,
            lp_position_id,
            &clock,
            scenario.ctx()
        );

        gauge.get_position_reward<USD1, SAIL, OSAIL2>(
            &mut pool,
            lp_position_id,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
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
fun test_multi_epoch_distribute_fails_when_claimed_wrong_order() {
    let admin = @0xC1;
    let user = @0xC2; // User with the lock
    let lp = @0xC3;  // Liquidity Provider
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let lock_amount = 100_000;
    let lock_duration = 365; // 1 year

    // --- 1. Full Setup ---
    full_setup_with_lock(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        lock_duration
    );

    // advance time to make sure that voting started
    clock::increment_for_testing(&mut clock, 10 * 60 * 60 * 1000);

    // --- 2. User Votes for the Pool ---
    scenario.next_tx(user);
    {
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    // --- 3. Advance to Epoch 1 (OSAIL1) ---
    clock::increment_for_testing(&mut clock, WEEK - (10 * 60 * 60 * 1000)); // Advance to next epoch start

    let first_epoch_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        first_epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period to OSAIL1
    scenario.next_tx(admin);
    {
        let initial_o_sail_supply = setup::update_minter_period<SAIL, OSAIL1>(
            &mut scenario,
            1_000_000, // Arbitrary supply for OSAIL1
            &clock
        );
        coin::burn_for_testing(initial_o_sail_supply); // Burn the minted OSAIL1 as it's not directly used here
    };

    // Distribute OSAIL1 rewards to the gauge
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

    // --- 4. LP Creates and Stakes Position ---
    let position_tick_lower = tick_math::min_tick().as_u32();
    let position_tick_upper = tick_math::max_tick().as_u32();
    let position_liquidity = 2_000_000_000u128; // Example liquidity
    let lp_position_id: ID;

    // Create position
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD1, SAIL>(
            &mut scenario,
            lp, // Position owner
            position_tick_lower,
            position_tick_upper,
            position_liquidity,
            &clock
        );
    };

    // Deposit position
    scenario.next_tx(lp);
    {
        lp_position_id = setup::deposit_position<USD1, SAIL>(
            &mut scenario,
            &clock
        );
    };

    let second_epoch_emissions: u64;
    scenario.next_tx(admin); // Read minter state before update
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        second_epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // --- 5. Advance to Epoch 2 (OSAIL2) ---
    clock::increment_for_testing(&mut clock, WEEK); // Advance clock by one week

    // Update Minter Period to OSAIL2
    scenario.next_tx(admin);
    {
        let initial_o_sail2_supply = setup::update_minter_period<SAIL, OSAIL2>(
            &mut scenario,
            500_000, // Arbitrary supply for OSAIL2
            &clock
        );
        coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
    };

    // Distribute OSAIL2 rewards to the gauge
    scenario.next_tx(admin);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // Distribute OSAIL2 rewards
        voter.distribute_gauge<USD1, SAIL, OSAIL2>(
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

    // --- 6. Advance Time by 1 week ---
    clock::increment_for_testing(&mut clock, WEEK);


    // Claim all rewards
    // Should error because of wrong order
    scenario.next_tx(lp);
    {
        let mut gauge = scenario.take_shared<Gauge<USD1, SAIL>>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();

        gauge.get_position_reward<USD1, SAIL, OSAIL2>(
            &mut pool,
            lp_position_id,
            &clock,
            scenario.ctx()
        );

        gauge.get_position_reward<USD1, SAIL, OSAIL1>(
            &mut pool,
            lp_position_id,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pool);
        test_scenario::return_shared(gauge);
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
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    clock.increment_for_testing(ms_in_week - gap_to_vote + 1000);

    let epoch_emissions: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period with OSAIL1
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
    // so half of that is 500ms
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
        assert!(expected_lp1_earned - reward.value() <= 2, 4);

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
        vote_for_pool<USD1, SAIL>(&mut scenario, &mut clock)
    };

    clock.increment_for_testing(ms_in_week - gap_to_vote + 1000);

    let epoch_emissions: u64;
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        epoch_emissions = minter.epoch_emissions();
        test_scenario::return_shared(minter);
    };

    // Update Minter Period with OSAIL1
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
    let position_liquidity = 1_000_000_000u128;
    // Both positions are deposited at the begining of the week, but the second one is withdrawn after half of the week.
    // During first part of the week these positions earn equal portions of the reward, so 1/2 of 1/2 of the reward for each.
    // During second half of the week only the first position gets all the rewards
    let expected_lp1_earned = epoch_emissions / 4 + epoch_emissions / 2;
    let expected_lp2_earned = epoch_emissions / 4;

    let exptected_lp1_half_week_earned = epoch_emissions / 4;

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

    // advance by half of the week
    // We have added extra 1000ms during minter activation, so now halv of the period is 500ms shorter
    clock.increment_for_testing(ms_in_week / 2 - 500);


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

        assert!(exptected_lp1_half_week_earned - earned_lp1 <= 2, 1);
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
            lp2_position_id,
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

    clock.increment_for_testing(ms_in_week / 2 - 500);

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
        assert!(expected_lp1_earned - reward.value() <= 2, 5);

        coin::burn_for_testing(reward);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// check deposit for 1 hour and then withdrawal of the position when only one position is present

// check deposit for 1 hour and then withdrawal of the position when two positions are present

// check position increase after deposit
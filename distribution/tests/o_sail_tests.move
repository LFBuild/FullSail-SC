#[test_only]
module distribution::o_sail_tests;

use distribution::setup;
use distribution::minter::{Self, Minter, AdminCap as MinterAdminCap};
use distribution::voter::{Self, Voter};
use distribution::voting_escrow::{Self, VotingEscrow, Lock};
use distribution::reward_distributor::{Self, RewardDistributor};
use distribution::notify_reward_cap::{Self, NotifyRewardCap};
use distribution::distribution_config::{Self, DistributionConfig};

use clmm_pool::pool::{Self, Pool};
use clmm_pool::config::{Self, GlobalConfig};

use sui::test_scenario;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::object;
use std::debug;
use distribution::common; // Import common for time constants

public struct SAIL has drop {}

// Define oSAIL type for testing epoch 1
public struct OSAIL1 has drop {}

// Define oSAIL type for testing epoch 2
public struct OSAIL2 has drop {}

// Define a random token type for failure testing
public struct RANDOM_TOKEN has drop {}

public struct USD1 has drop {}

fun activate_minter<OSailCoinType>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
    initial_o_sail_supply: u64,
    clock: &mut Clock
): Coin<OSailCoinType> {
    let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
    let mut voter = scenario.take_shared<Voter>();
    let mut rd = scenario.take_shared<RewardDistributor<SAIL>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    // Create TreasuryCap for OSAIL1
    let mut o_sail1_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
    let initial_supply = o_sail1_cap.mint(initial_o_sail_supply, scenario.ctx());

    // non-zero timestamp to ensure that minter.is_active returns true
    clock::increment_for_testing(clock, 1000);

    minter_obj.activate<SAIL, OSailCoinType>(
        &mut voter,
        &minter_admin_cap,
        &mut rd,
        o_sail1_cap,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(minter_obj);
    test_scenario::return_shared(voter);
    test_scenario::return_shared(rd);
    scenario.return_to_sender(minter_admin_cap);

    initial_supply
}

fun whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
) {
    let pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut minter = scenario.take_shared<Minter<SailCoinType>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    minter.whitelist_pool(&minter_admin_cap, &pool, true);

    test_scenario::return_shared(minter);
    scenario.return_to_sender(minter_admin_cap);
    test_scenario::return_shared(pool);
}

#[test]
fun test_exercise_o_sail_ab() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL)
    let pool_sqrt_price: u128 = 2 << 64; // Price = 4, as sqrt(4) = 2
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        // Assuming USD1 > SAIL lexicographically
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 5: Exercise OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let distribution_config = scenario.take_shared<DistributionConfig>(); // Needed? minter::exercise doesn't list it
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        // Whitelist the pool for exercising

        // Mint OSAIL1 for the user
        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());

        // Mint USD1 fee for the user
        let usd_fee = coin::mint_for_testing<USD1>(12_500, scenario.ctx()); // Amount should cover ~50% of SAIL value at price 1
        let usd_limit = 12_500;

        // Exercise o_sail_ba because Pool is <USD1, SAIL>
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee,
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // --- Assertions --- 
        assert!(sail_received.value() == 100_000, 1); // Should receive full SAIL amount
        // Check USD left - depends on exact price and discount. 
        // For price=1, 50% discount -> should pay 50k USD. If fee was 50k, should have 0 left.
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailPoolNotWhitelisted)] // Expect failure due to non-whitelisted pool
fun test_exercise_o_sail_fail_not_whitelisted_pool() {
    let admin = @0xE1; // Use a different address
    let user = @0xE2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };
    
    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        // Assuming USD1 > SAIL lexicographically
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 4: Attempt Exercise OSAIL1 (Pool NOT whitelisted)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());
        let usd_fee = coin::mint_for_testing<USD1>(50_000, scenario.ctx()); 
        let usd_limit = 50_000;

        // Attempt exercise - should fail here because pool wasn't whitelisted
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee,
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseUsdLimitReached)] // Expect failure due to insufficient USD limit
fun test_exercise_o_sail_fail_usd_limit_not_met() {
    let admin = @0xF1; // Use a different address
    let user = @0xF2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 2 << 64; // Price = 4
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 5: Attempt Exercise OSAIL1 with insufficient USD limit
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount, scenario.ctx());
        
        // Calculate expected USD needed (price=4, discount=50% -> pay for 50% of SAIL value)
        // SAIL to pay for = 100_000 * 0.5 = 50_000 SAIL
        // USD needed = 50_000 SAIL / Price(4 USD/SAIL) = 12_500 USD
        let expected_usd_needed = 12_500;

        // Provide enough USD in the coin, but set the limit lower
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed - 1; // Set limit below required amount

        // Attempt exercise - should fail here because usd_limit is too low
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee, // Pass the insufficient limit
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui::balance::ENotEnough)] // Expect failure when splitting usd_fee
fun test_exercise_o_sail_fail_insufficient_usd_fee() {
    let admin = @0x101; // Use a different address
    let user = @0x102;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 2 << 64; // Price = 4
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 5: Attempt Exercise OSAIL1 with insufficient USD coin balance
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount, scenario.ctx());
        
        // Calculate expected USD needed (price=4, discount=50% -> pay for 50% of SAIL value)
        // SAIL to pay for = 100_000 * 0.5 = 50_000 SAIL
        // USD needed = 50_000 SAIL / Price(4 USD/SAIL) = 12_500 USD
        let expected_usd_needed = 12_500;

        // Mint less USD than needed, but set limit high enough
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed - 1, scenario.ctx()); 
        let usd_limit = 1_000_000;

        // Attempt exercise - should fail here due to insufficient balance in usd_fee coin
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee, // Pass the coin with insufficient balance
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExercieOSailExpired)] // Expect failure due to expired oSAIL
fun test_exercise_o_sail_fail_expired() {
    let admin = @0x111; // Use a different address
    let user = @0x112;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed for advancing time

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 5 weeks (more than oSAIL expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 5: Attempt Exercise Expired OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());
        let usd_fee = coin::mint_for_testing<USD1>(100_000, scenario.ctx()); // Mint enough USD
        let usd_limit = 100_000;

        // Attempt exercise - should fail here because oSAIL1 is expired
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee, 
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached due to expected abort)
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_exercise_o_sail_before_expiry() {
    let admin = @0x121; // Use a different address
    let user = @0x122;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed for advancing time

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 4 weeks (within typical expiry)
    let four_weeks_ms = 4 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, four_weeks_ms);

    // Tx 5: Exercise OSAIL1 (Before Expiry)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount_to_exercise = 100_000;
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount_to_exercise, scenario.ctx());

        // Calculate expected USD needed (Price=1, discount=50% -> pay 50%)
        let expected_usd_needed = o_sail_amount_to_exercise / 2;
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;

        // Exercise - should succeed
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee, 
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Assertions
        assert!(sail_received.value() == o_sail_amount_to_exercise, 1); // Should receive full SAIL amount
        assert!(usd_left.value() == 0, 2); // Should have used all provided USD

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailPoolNotWhitelisted)] // Expect final exercise attempt to fail
fun test_exercise_o_sail_whitelist_toggle() {
    let admin = @0x131; // Use a different address
    let user = @0x132;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool (First time)
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 5: First Exercise (Pool Whitelisted - Should Succeed)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_amount_to_exercise = 50_000; // Exercise smaller amount
        let o_sail_to_exercise = o_sail1_coin.split(o_sail_amount_to_exercise, scenario.ctx());

        let expected_usd_needed = o_sail_amount_to_exercise / 2; // Price=1, Discount=50%
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;

        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter, &mut voter, &global_config, &mut pool, 
            o_sail_to_exercise, usd_fee, usd_limit, &clock, scenario.ctx()
        );

        assert!(sail_received.value() == o_sail_amount_to_exercise, 1);
        assert!(usd_left.value() == 0, 2);

        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user); // Give SAIL to user
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    // Tx 6: De-Whitelist pool
    scenario.next_tx(admin);
    {
        // Need MinterAdminCap to de-whitelist
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let minter_admin_cap = scenario.take_from_sender<MinterAdminCap>();
        let pool = scenario.take_shared<Pool<USD1, SAIL>>(); // Need pool ref
        
        minter::whitelist_pool(&mut minter, &minter_admin_cap, &pool, false); // Set listed to false
        
        test_scenario::return_shared(minter);
        scenario.return_to_sender(minter_admin_cap);
        test_scenario::return_shared(pool);
    };

    // Tx 7: Second Exercise Attempt (Pool Not Whitelisted - Should Fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(50_000, scenario.ctx());
        let expected_usd_needed = 50000 / 2;
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;

        // This call is expected to fail with EExerciseOSailPoolNotWhitelisted
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter, &mut voter, &global_config, &mut pool, 
            o_sail_to_exercise, usd_fee, usd_limit, &clock, scenario.ctx()
        );

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user); // Give SAIL to user
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin); 
    };

    // Final cleanup transaction can be added if necessary 
    // but not strictly needed as the test expects abort in Tx 7.

    clock::destroy_for_testing(clock);
    scenario.end();
}

fun check_receive_rate(
    scenario: &mut test_scenario::Scenario,
    user: address,
    percent_to_receive: u64,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>();
    let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

    let initial_o_sail_amount = 100_000;
    let o_sail_to_exercise = o_sail1_coin.split(initial_o_sail_amount, scenario.ctx());
  
    let expected_sail_amount = initial_o_sail_amount * percent_to_receive / common::persent_denominator(); // 100000 * 7500 / 10000 = 75000

    let sail_received = minter::test_exercise_o_sail_free_internal<SAIL, OSAIL1>(
        &mut minter,
        o_sail_to_exercise,
        percent_to_receive,
        scenario.ctx()
    );

    // Assertions
    assert!(sail_received.value() == expected_sail_amount, 1); // Should receive 75% SAIL

    // Cleanup
    transfer::public_transfer(sail_received, user);
    test_scenario::return_shared(minter);
    scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
}

#[test]
fun test_exercise_o_sail_free_internal() {
    let admin = @0x141; // Use a different address
    let user = @0x142;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD) - No pool needed for free exercise
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Exercise OSAIL1 with 75% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 75000000);
    };

    // Tx 4: Exercise OSAIL1 with 100% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 100000000);
    };

    // Tx 5: Exercise OSAIL1 with 0% receive rate
    scenario.next_tx(user);
    {
        check_receive_rate(&mut scenario, user, 0);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EExerciseOSailFreeTooBigPercent)]
fun test_exercise_o_sail_free_fail_over_100_percent() {
    let admin = @0x151; // Use a different address
    let user = @0x152;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut      clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Attempt Exercise OSAIL1 with > 100% receive rate
    scenario.next_tx(user);
    { // This block is expected to abort
        check_receive_rate(&mut scenario, user, common::persent_denominator() + 1);
    };

    clock::destroy_for_testing(clock); 
    scenario.end(); 
}

fun create_lock(
    scenario: &mut test_scenario::Scenario,
    o_sail_to_lock: u64,
    lock_duration_days: u64,
    permanent_lock: bool,
    clock: &Clock,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>();
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

    assert!(o_sail_coin.value() >= o_sail_to_lock, 0); // Ensure user has enough oSAIL
    let o_sail_for_locking = o_sail_coin.split(o_sail_to_lock, scenario.ctx());

    // Call the function to create the lock
    minter::create_lock_from_o_sail<SAIL, OSAIL1>(
        &mut minter,
        &mut ve,
        o_sail_for_locking, // This coin will be consumed
        lock_duration_days,
        permanent_lock,
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(minter);
    test_scenario::return_shared(ve);
    // Return remaining oSAIL coin
    scenario.return_to_sender(o_sail_coin);
}

fun check_single_non_permanent_lock(
    scenario: &test_scenario::Scenario,
    o_sail_to_lock: u64,
    lock_duration_days: u64,
) {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let user_lock = scenario.take_from_sender<Lock>(); // Take the newly created Lock

        // Calculate expected SAIL based on duration (assuming 50% discount, 4yr max lock)
        // percent = 5000 + (5000 * 182*day_ms / (1460*day_ms)) = 5000 + 623 = 5623
        // expected_sail = 100000 * 5623 / 10000 = 56230
        let max_lock_time_sec = 4 * 52 * 7 * 24 * 60 * 60;
        let lock_duration_sec = lock_duration_days * 24 * 60 * 60;
        let base_discount_pcnt = 50000000; // 50%
        let max_extra_pcnt = common::persent_denominator() - base_discount_pcnt;
        let percent_to_receive = base_discount_pcnt + 
            (max_extra_pcnt * lock_duration_sec / max_lock_time_sec);
        let expected_sail_amount = o_sail_to_lock * percent_to_receive / common::persent_denominator();

        let (locked_balance, lock_exists) = voting_escrow::locked(&ve, object::id(&user_lock));
        // Assertions

        assert!(locked_balance.amount() == expected_sail_amount, 1); // Check locked SAIL amount
        assert!(lock_exists, 2);
        assert!(!locked_balance.is_permanent(), 3);
        assert!(voting_escrow::total_locked(&ve) == expected_sail_amount, 4); // Check VE total locked

        // Cleanup
        test_scenario::return_shared(ve);
        scenario.return_to_sender(user_lock); // Return lock to user
}

#[test]
fun test_create_lock_from_o_sail() {
    let admin = @0x161; // Use a different address
    let user = @0x162;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Create Lock from OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 182; // ~6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_2y() {
    let admin = @0x171; // Use a different address
    let user = @0x172;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Create Lock from OSAIL1 for 9 months
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 2 * 52 * 7; // 2 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_4y() {
    let admin = @0x181; // Use a different address
    let user = @0x182;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Create Lock from OSAIL1 for 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7; // 4 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_less_than_6_months() {
    let admin = @0x191; // Use a different address
    let user = @0x192;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Attempt to Create Lock from OSAIL1 for less than 6 months
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 25 * 7; // 25 weeks < 26 weeks (6 months)
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_more_than_4y() {
    let admin = @0x1A1; // Use a different address
    let user = @0x1A2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Attempt to Create Lock from OSAIL1 for more than 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7 + 1; // 4 years + 1 day
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

// Helper function to check the state of a single permanent lock
fun check_single_permanent_lock(
    scenario: &test_scenario::Scenario,
    o_sail_to_lock: u64,
) {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let user_lock = scenario.take_from_sender<Lock>(); // Take the newly created Lock

        // Calculate expected SAIL (permanent lock gets 100%)
        let expected_sail_amount = o_sail_to_lock; 

        let (locked_balance, lock_exists) = voting_escrow::locked(&ve, object::id(&user_lock));
        
        // Assertions
        assert!(locked_balance.amount() == expected_sail_amount, 1); // Check locked SAIL amount (should be 100%)
        assert!(lock_exists, 2);
        assert!(locked_balance.is_permanent(), 3); // Check that the lock IS permanent
        assert!(voting_escrow::total_locked(&ve) == expected_sail_amount, 4); // Check VE total locked

        // Cleanup
        test_scenario::return_shared(ve);
        scenario.return_to_sender(user_lock); // Return lock to user
}

#[test]
fun test_create_lock_from_o_sail_permanent() {
    let admin = @0x181; // Use a different address
    let user = @0x182;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 3: Create permanent Lock from OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 100; // doesn't matter for permanent lock
    let permanent_lock = true;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_permanent_lock(&scenario, o_sail_to_lock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_o_sail_after_4_epochs() {
    let admin = @0x1B1; // Use a different address
    let user = @0x1B2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 4 weeks (4 epochs)
    let four_weeks_ms = 4 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, four_weeks_ms);

    // Tx 3: Create Lock from OSAIL1 after 4 weeks
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidDuraton)]
fun test_create_lock_from_o_sail_fail_expired() {
    let admin = @0x1C1; // Use a different address
    let user = @0x1C2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Attempt to Create Lock from expired OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // Attempt 6 month lock
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call is expected to abort because the oSAIL is expired
        // and the duration is not the allowed expired duration (4 years) or permanent
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Verification step is not needed as the previous tx aborts

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_expired_o_sail_4y() {
    let admin = @0x1D1; // Use a different address
    let user = @0x1D2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Create Lock from expired OSAIL1 for 4 years
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 4 * 52 * 7; // 4 years
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // This call should succeed because 4 years is a valid duration for expired oSAIL
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        // Use the non-permanent check, as the lock itself isn't permanent
        check_single_non_permanent_lock(&scenario, o_sail_to_lock, lock_duration_days);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_create_lock_from_expired_o_sail_permanent() {
    let admin = @0x1E1; // Use a different address
    let user = @0x1E2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD)
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Advance time by 5 weeks (past typical expiry)
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 3: Create Permanent Lock from expired OSAIL1
    let o_sail_to_lock = 100_000; // Amount of oSAIL to lock
    let lock_duration_days = 26 * 7; // Duration doesn't matter for permanent
    let permanent_lock = true;
    scenario.next_tx(user);
    {
        // This call should succeed because permanent lock is allowed for expired oSAIL
        create_lock(&mut scenario, o_sail_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 4: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user); // User owns the new Lock
    {
        // Use the permanent check helper
        check_single_permanent_lock(&scenario, o_sail_to_lock);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::ECreateLockFromOSailInvalidToken)] // Expect fail because RANDOM_TOKEN cap is not in Minter
fun test_create_lock_from_invalid_token_fail() {
    let admin = @0x1F1; // Use a different address
    let user = @0x1F2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution (Minter, Voter, VE, RD) for SAIL and OSAIL1
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter for Epoch 1 (OSAIL1) - Minter now knows about OSAIL1
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &mut clock);
        // Burn the initial supply, user will use RANDOM_TOKEN
        coin::burn_for_testing(o_sail1_initial_supply);
    };

    // Tx 3: Mint RANDOM_TOKEN for the user
    scenario.next_tx(admin); // Use admin to mint test token
    {
        let random_coin = coin::mint_for_testing<RANDOM_TOKEN>(100_000, scenario.ctx());
        transfer::public_transfer(random_coin, user);
    };

    // Tx 4: Attempt to Create Lock using RANDOM_TOKEN instead of OSAIL1
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let random_coin = scenario.take_from_sender<Coin<RANDOM_TOKEN>>(); // Take the random token

        // This call is expected to abort because RANDOM_TOKEN is not the expected OSailCoinType
        // Specifically, the minter::burn_o_sail inside will fail trying to borrow a non-existent cap
        minter::create_lock_from_o_sail<SAIL, RANDOM_TOKEN>( 
            &mut minter,
            &mut ve,
            random_coin, // Pass the wrong coin type!
            lock_duration_days,
            permanent_lock,
            &clock,
            scenario.ctx()
        );

        // Cleanup (won't be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_exercise_and_lock_after_epoch_update() {
    let admin = @0x201; // Use a different address
    let user = @0x202;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let mut clock = clock::create_for_testing(scenario.ctx()); // Mutable clock needed

    // Tx 1: Setup CLMM Factory & Distribution
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL) 
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    let initial_o_sail_for_user = 200_000;
    scenario.next_tx(admin);
    {
        let user_o_sail1 = activate_minter<OSAIL1>(&mut scenario, admin, initial_o_sail_for_user, &mut clock);
        transfer::public_transfer(user_o_sail1, user); 
    };

    // Tx 5: check current epoch token
    scenario.next_tx(user);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let current_epoch_token = minter.borrow_current_epoch_o_sail();
        assert!(current_epoch_token == std::type_name::get<OSAIL1>(), 1);
        test_scenario::return_shared(minter);
    };

    // Advance time by 1 week and 1 second to ensure next epoch starts
    let one_week_ms = 7 * 24 * 60 * 60 * 1000 + 1000;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // Tx 6: Update Minter Period with OSAIL2
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut reward_distributor = scenario.take_shared<RewardDistributor<SAIL>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();

        // Create TreasuryCap for OSAIL2 for the next epoch
        let o_sail2_cap = coin::create_treasury_cap_for_testing<OSAIL2>(scenario.ctx());

        minter::update_period<SAIL, OSAIL1, OSAIL2>(
            &minter_admin_cap,
            &mut minter,
            &mut voter,
            &voting_escrow,
            &mut reward_distributor,
            o_sail2_cap, 
            &clock,
            scenario.ctx()
        );

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(reward_distributor);
        scenario.return_to_sender(minter_admin_cap);
    };

    // Tx 7: check current epoch token
    scenario.next_tx(user);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let current_epoch_token = minter.borrow_current_epoch_o_sail();
        assert!(current_epoch_token == std::type_name::get<OSAIL2>(), 1);
        test_scenario::return_shared(minter);
    };

    // Tx 8: Exercise OSAIL1 (from previous epoch)
    let o_sail1_to_exercise = 100_000;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_exercise = o_sail1_coin.split(o_sail1_to_exercise, scenario.ctx());

        // Calculate expected USD needed (Price=1, discount=50% -> pay 50%)
        let expected_usd_needed = o_sail1_to_exercise / 2; 
        let usd_fee = coin::mint_for_testing<USD1>(expected_usd_needed, scenario.ctx()); 
        let usd_limit = expected_usd_needed;

        // Exercise should succeed even though Minter is in Epoch 2
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee, 
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // Assertions
        assert!(sail_received.value() == o_sail1_to_exercise, 1); 
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        scenario.return_to_sender(o_sail1_coin); // Return remaining OSAIL1
    };

    // Tx 9: Lock remaining OSAIL1 (from previous epoch)
    let o_sail1_to_lock = initial_o_sail_for_user - o_sail1_to_exercise;
    let lock_duration_days = 26 * 7; // 6 months
    let permanent_lock = false;
    scenario.next_tx(user);
    {
        // Lock should succeed
        create_lock(&mut scenario, o_sail1_to_lock, lock_duration_days, permanent_lock, &clock);
    };

    // Tx 10: Verify Lock creation and Voting Escrow state
    scenario.next_tx(user);
    {
        check_single_non_permanent_lock(&scenario, o_sail1_to_lock, lock_duration_days);
    };


    clock::destroy_for_testing(clock);
    scenario.end();
}
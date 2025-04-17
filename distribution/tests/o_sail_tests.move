#[test_only]
module distribution::o_sail_tests;

use distribution::setup;
use distribution::minter::{Self, Minter, AdminCap as MinterAdminCap};
use distribution::voter::{Self, Voter};
use distribution::voting_escrow::{Self, VotingEscrow};
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

public struct USD1 has drop {}

fun activate_minter<OSailCoinType>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
    initial_o_sail_supply: u64,
    clock: &Clock
): Coin<OSailCoinType> {
    let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
    let mut voter = scenario.take_shared<Voter>();
    let mut rd = scenario.take_shared<RewardDistributor<SAIL>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    // Create TreasuryCap for OSAIL1
    let mut o_sail1_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
    let initial_supply = o_sail1_cap.mint(initial_o_sail_supply, scenario.ctx());

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
    let clock = clock::create_for_testing(scenario.ctx());

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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
    let clock = clock::create_for_testing(scenario.ctx());

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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
    let clock = clock::create_for_testing(scenario.ctx());

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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
    let clock = clock::create_for_testing(scenario.ctx());

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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
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
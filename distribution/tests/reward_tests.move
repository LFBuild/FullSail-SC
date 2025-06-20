#[test_only]
module distribution::reward_tests;

use sui::test_scenario::{Self, Scenario};
use sui::object::{Self, ID};
use sui::types;
use std::option::{Self, Option};
use std::type_name::{Self, TypeName};

use distribution::reward::{Self, Reward};
use sui::test_utils;
use sui::clock::{Self, Clock};
use distribution::reward_authorized_cap::{Self, RewardAuthorizedCap};
use integer_mate::full_math_u64;
use sui::coin::{Self, Coin};

// Define dummy types for testing
public struct USD1 has drop {}
public struct SAIL has drop {}
public struct OTHER has drop {}

#[test]
fun test_create_reward() {
    let admin = @0xAA;
    let mut scenario = test_scenario::begin(admin);

    // Define dummy IDs and reward types
    let voter_id: ID = object::id_from_address(@0x1);
    let ve_id: ID = object::id_from_address(@0x2);
    let ve_id_option: Option<ID> = option::some(ve_id);
    let authorized_id: ID = object::id_from_address(@0x3); // E.g., Voter ID or specific cap ID
    let reward_types = vector[
        type_name::get<USD1>(),
        type_name::get<SAIL>()
    ];

    // Call the create function
    let reward_obj = reward::create(
        voter_id,
        ve_id_option,
        authorized_id,
        reward_types,
        scenario.ctx()
    );

    // --- Assertions ---
    assert!(reward::total_supply(&reward_obj) == 0, 1);
    assert!(reward::voter(&reward_obj) == voter_id, 2);
    assert!(reward::ve(&reward_obj) == ve_id, 3);
    assert!(reward::authorized(&reward_obj) == authorized_id, 4);
    assert!(reward::rewards_list_length(&reward_obj) == 2, 5);
    assert!(reward::rewards_contains(&reward_obj, type_name::get<USD1>()), 6);
    assert!(reward::rewards_contains(&reward_obj, type_name::get<SAIL>()), 7);
    assert!(!reward::rewards_contains(&reward_obj, type_name::get<OTHER>()), 8);

    test_utils::destroy(reward_obj);

    scenario.end();
}

fun create_default_reward(scenario: &mut Scenario, authorized_id: ID): Reward {

    let voter_id: ID = object::id_from_address(@0x1);
    let ve_id: ID = object::id_from_address(@0x2);
    let ve_id_option: Option<ID> = option::some(ve_id);
    let reward_types = vector[type_name::get<USD1>()];

    reward::create(voter_id, ve_id_option, authorized_id, reward_types, scenario.ctx())
}

#[test]
fun test_deposit_reward() {
    let admin = @0xBB;
    let authorized_id: ID = object::id_from_address(@0xCC);
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());


    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);

    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define deposit details
    let lock_id: ID = object::id_from_address(@0x100);
    let deposit_amount = 10000;

    // Initial state check
    assert!(reward_obj.total_supply() == 0, 0);
    assert!(reward_obj.balance_of(lock_id) == 0, 1);
    assert!(reward_obj.earned<USD1>(lock_id, &clock) == 0, 2);

    // Call reward::deposit
    reward_obj.deposit(
        &reward_cap,
        deposit_amount,
        lock_id,
        &clock,
        scenario.ctx()
    );

    // --- Assertions ---
    assert!(reward_obj.total_supply() == deposit_amount, 3);
    assert!(reward_obj.balance_of(lock_id) == deposit_amount, 4);
    assert!(reward_obj.earned<USD1>(lock_id, &clock) == 0, 5);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_withdraw_reward() {
    let admin = @0xCC;
    let authorized_id: ID = object::id_from_address(@0xDD); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id: ID = object::id_from_address(@0x101);
    let initial_deposit = 10000;
    let first_withdraw = 4000;
    let second_withdraw = initial_deposit - first_withdraw; // 6000

    // Deposit initial amount
    reward_obj.deposit(&reward_cap, initial_deposit, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id) == initial_deposit, 2);

    clock::increment_for_testing(&mut clock, 1000); // Advance time for checkpointing

    // Withdraw partial amount
    reward_obj.withdraw(&reward_cap, first_withdraw, lock_id, &clock, scenario.ctx());

    // Assert state after first withdraw
    assert!(reward_obj.total_supply() == second_withdraw, 3); // total supply decreased
    assert!(reward_obj.balance_of(lock_id) == second_withdraw, 4); // lock balance decreased

    clock::increment_for_testing(&mut clock, 1000);

    // Withdraw remaining amount
    reward_obj.withdraw(&reward_cap, second_withdraw, lock_id, &clock, scenario.ctx());

    // Assert state after second withdraw
    assert!(reward_obj.total_supply() == 0, 5); // total supply is zero
    assert!(reward_obj.balance_of(lock_id) == 0, 6); // lock balance is zero

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_deposit_withdraw_reward_multi_epoch() {
    let admin = @0xEE;
    let authorized_id: ID = object::id_from_address(@0xFF); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id: ID = object::id_from_address(@0x102);
    let deposit1 = 10000;
    let deposit2 = 5000;
    let withdraw1 = 8000;
    let withdraw2 = deposit1 + deposit2 - withdraw1; // 7000
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 0, 10);

    // --- Epoch 1: Initial Deposit ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id) == deposit1, 2);
    // the first checkpoint index is 0
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 0, 11);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2: Second Deposit ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit1 + deposit2, 3);
    assert!(reward_obj.balance_of(lock_id) == deposit1 + deposit2, 4);
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 1, 12);


    // --- Advance to Epoch 3 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3: First Withdraw ---
    reward_obj.withdraw(&reward_cap, withdraw1, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == withdraw2, 5); // withdraw2 is remaining balance
    assert!(reward_obj.balance_of(lock_id) == withdraw2, 6);
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 2, 13);

    // --- Advance to Epoch 4 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 4: Second (Final) Withdraw ---
    reward_obj.withdraw(&reward_cap, withdraw2, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == 0, 7);
    assert!(reward_obj.balance_of(lock_id) == 0, 8);
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 3, 14);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_multi_lock_simple_reward_distribution() {
    let admin = @0xFF;
    let authorized_id: ID = object::id_from_address(@0xEE); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x103);
    let lock_id2: ID = object::id_from_address(@0x104);
    let deposit1 = 6000;  // 60% of total initial deposit
    let deposit2 = 4000;  // 40% of total initial deposit
    let total_deposit = deposit1 + deposit2;
    let notify_amount = 5000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposits ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 3);

    // advance half a week to check that the moment of reward notification does not matter
    clock.increment_for_testing(one_week_ms / 2);

    // --- Epoch 1: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    // Use the internal notify function accessible within the package tests
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    clock.increment_for_testing( 10000);

    // Verify earned is 0 immediately after notify (rewards apply to next epoch start)
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms/2);

    // --- Epoch 2: Verify Earned Rewards ---
    let lock1_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit1, total_deposit
    );
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_deposit
    );

    // Allow for rounding difference (total earned might be slightly less than notify_amount)
    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1 = earned1 - lock1_expected_share; // should not distribute more than expected
    let diff2 = earned2 - lock2_expected_share;

    assert!(diff1 <= 1, 6); // Check lock1 share (allowing rounding by 1)
    assert!(diff2 <= 1, 7); // Check lock2 share (allowing rounding by 1)
    assert!(earned1 + earned2 <= notify_amount, 8); // Total earned should not exceed notified
    assert!(earned1 + earned2 >= notify_amount - 1, 9); // Total earned should be very close to notified

    // --- Claim Rewards using get_reward_internal ---

    // Claim for lock1
    let balance_opt1 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        admin, // Recipient address (using admin for test)
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt1), 10);
    let balance1 = option::destroy_some(balance_opt1);
    assert!(balance1.value() == earned1, 11); // Check claimed amount matches earned
    sui::balance::destroy_for_testing(balance1);

    // Claim for lock2
    let balance_opt2 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        admin, // Recipient address (using admin for test)
        lock_id2, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt2), 12);
    let balance2 = option::destroy_some(balance_opt2);
    assert!(balance2.value() == earned2, 13); // Check claimed amount matches earned
    sui::balance::destroy_for_testing(balance2);

    // Verify earned is now 0 after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 14);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 15);

    // Check that other tokens still have 0 earned
    let earned1_other_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    let earned2_other_token = reward_obj.earned<OTHER>(lock_id2, &clock);
    assert!(earned1_other_token == 0, 16);
    assert!(earned2_other_token == 0, 17);


    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_mid_epoch_deposit_reward() {
    let admin = @0xEE;
    let authorized_id: ID = object::id_from_address(@0xFF); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x105);
    let lock_id2: ID = object::id_from_address(@0x106);
    let deposit1 = 7500;  // 75%
    let deposit2 = 2500;  // 25%
    let total_deposit_end_epoch = deposit1 + deposit2;
    let notify_amount = 10000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1, Step 1: Deposit lock1 ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2) == 0, 3);

    clock::increment_for_testing(&mut clock, 1000); // Small time increment

    // --- Epoch 1, Step 2: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Earned should still be 0 within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // getting close to the end of the epoch
    clock::increment_for_testing(&mut clock, one_week_ms - 10000);

    // --- Epoch 1, Step 3: Deposit lock2 ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit_end_epoch, 6);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 7);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 8);
    // Earned should *still* be 0 within the same epoch, even after second deposit
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 9);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 10);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, 10000);

    // --- Epoch 2: Verify Earned Rewards ---
    // Rewards are distributed based on balances relative to total supply *at the end* of the reward epoch.
    let lock1_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit1, total_deposit_end_epoch
    );
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_deposit_end_epoch
    );

    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1 = earned1 - lock1_expected_share;
    let diff2 = earned2 - lock2_expected_share;

    assert!(diff1 <= 1, 11); // Check lock1 share (allowing rounding by 1)
    assert!(diff2 <= 1, 12); // Check lock2 share (allowing rounding by 1)
    assert!(earned1 + earned2 <= notify_amount, 13); 
    assert!(earned1 + earned2 >= notify_amount - 1, 14); 

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_mid_epoch_deposit_withdraw_reward() {
    let admin = @0x11;
    let authorized_id: ID = object::id_from_address(@0x22); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x107);
    let lock_id2: ID = object::id_from_address(@0x108);
    let deposit1 = 6000;
    let deposit2 = 4000;
    let notify_amount = 5000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1, Step 1: Deposit lock1 ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 2: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 3: Deposit lock2 ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit1 + deposit2, 4);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 5);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 6);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 7);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 4: Withdraw lock1 ---
    reward_obj.withdraw(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit2, 8); // Only deposit2 remains
    assert!(reward_obj.balance_of(lock_id1) == 0, 9);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 10);
    // Earned is still 0
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 11);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 12);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2: Verify Earned Rewards ---
    // Only lock2 was present at the end of Epoch 1, so it gets all the reward.
    let total_supply_end_epoch1 = deposit2;
    let lock1_expected_share = 0; // Withdrew before epoch end
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_supply_end_epoch1
    );
    assert!(lock2_expected_share == notify_amount, 13); // Should be exactly notify_amount

    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff2 = earned2 - lock2_expected_share;

    assert!(earned1 == lock1_expected_share, 14); // lock1 earned nothing
    assert!(diff2 <= 1, 15); // lock2 earned close to notify_amount (allow rounding)
    assert!(earned1 + earned2 <= notify_amount, 16);
    assert!(earned1 + earned2 >= notify_amount - 1, 17);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_withdraw_after_epoch_reward() {
    let admin = @0x33;
    let authorized_id: ID = object::id_from_address(@0x44); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x109);
    let lock_id2: ID = object::id_from_address(@0x10A);
    let deposit1 = 6000;
    let deposit2 = 4000;
    let total_deposit_epoch1 = deposit1 + deposit2;
    let notify_amount = 10000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposits and Notify ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    clock::increment_for_testing(&mut clock, 1000);
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit_epoch1, 1);

    clock::increment_for_testing(&mut clock, 1000);
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Earned is still 0 in Epoch 1
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 2);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 3);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2, Step 1: Withdraw lock1 ---
    reward_obj.withdraw(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == deposit2, 4); // Only deposit2 remains
    assert!(reward_obj.balance_of(lock_id1) == 0, 5);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 6);

    // --- Epoch 2, Step 2: Verify Earned Rewards ---
    // Both locks should have earned their share from Epoch 1, even though lock1 withdrew in Epoch 2.
    let lock1_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit1, total_deposit_epoch1
    );
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_deposit_epoch1
    );

    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1 = earned1 - lock1_expected_share;
    let diff2 = earned2 - lock2_expected_share;

    assert!(diff1 <= 1, 7); // Check lock1 share
    assert!(diff2 <= 1, 8); // Check lock2 share
    assert!(earned1 + earned2 <= notify_amount, 9);
    assert!(earned1 + earned2 >= notify_amount - 1, 10); 

    let balance_opt1 = reward::get_reward_internal<USD1>(&mut reward_obj, admin, lock_id1, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt1), 11);
    sui::balance::destroy_for_testing(option::destroy_some(balance_opt1));
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 12); // Earned becomes 0 after claim

    let balance_opt2 = reward::get_reward_internal<USD1>(&mut reward_obj, admin, lock_id2, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt2), 13);
    sui::balance::destroy_for_testing(option::destroy_some(balance_opt2));
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 14); // Earned becomes 0 after claim

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_rewards_across_multiple_epochs() {
    let admin = @0x55;
    let authorized_id: ID = object::id_from_address(@0x66); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x10B);
    let lock_id2: ID = object::id_from_address(@0x10C);
    let deposit1 = 8000;
    let deposit2 = 2000;
    let total_deposit_e1 = deposit1;            // Total supply at end of Epoch 1
    let total_deposit_e2 = deposit1 + deposit2; // Total supply at end of Epoch 2
    let notify_amount1 = 10000; // Reward in Epoch 1
    let notify_amount2 = 5000;  // Reward in Epoch 2
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposit lock1 & Notify reward1 ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit_e1, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);

    clock::increment_for_testing(&mut clock, 1000);
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3); // Earned is 0 in current epoch

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2: Deposit lock2 & Notify reward2 ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit_e2, 4);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 5);

    clock::increment_for_testing(&mut clock, 1000);
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Earned for lock1 should reflect reward1, earned for lock2 still 0
    let earned1_mid_e2 = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned1_mid_e2 <= notify_amount1 && earned1_mid_e2 >= notify_amount1 -1 , 6); 
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 7);

    // --- Advance to Epoch 3 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3: Verify Earned Rewards ---
    // lock1 gets all of reward1 + its share of reward2
    // lock2 gets only its share of reward2

    let lock1_share_reward1 = full_math_u64::mul_div_floor(notify_amount1, deposit1, total_deposit_e1);
    let lock1_share_reward2 = full_math_u64::mul_div_floor(notify_amount2, deposit1, total_deposit_e2);
    let lock2_share_reward2 = full_math_u64::mul_div_floor(notify_amount2, deposit2, total_deposit_e2);

    let lock1_expected_total = lock1_share_reward1 + lock1_share_reward2;
    let lock2_expected_total = lock2_share_reward2;

    let earned1_e3 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2_e3 = reward_obj.earned<USD1>(lock_id2, &clock);

    let diff1 = earned1_e3 - lock1_expected_total;
    let diff2 = earned2_e3 - lock2_expected_total;

    assert!(lock1_share_reward1 == notify_amount1, 8); // lock1 should get all of reward1
    assert!(diff1 <= 1, 9);  // Check lock1 total share
    assert!(diff2 <= 1, 10); // Check lock2 total share

    // Total earned should be close to total notified across both epochs
    assert!(earned1_e3 + earned2_e3 <= notify_amount1 + notify_amount2, 11);
    assert!(earned1_e3 + earned2_e3 >= notify_amount1 + notify_amount2 - 2, 12); // Allow rounding up to 2 (1 per epoch/calc)

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_multi_token_reward_same_epoch() {
    let admin = @0x77;
    let authorized_id: ID = object::id_from_address(@0x88); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Modify default reward creation to include SAIL
    let voter_id: ID = object::id_from_address(@0x1);
    let ve_id: ID = object::id_from_address(@0x2);
    let ve_id_option: Option<ID> = option::some(ve_id);
    let reward_types = vector[type_name::get<USD1>(), type_name::get<SAIL>()];
    let mut reward_obj = reward::create(
        voter_id, ve_id_option, authorized_id, reward_types, scenario.ctx()
    );
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x10D);
    let lock_id2: ID = object::id_from_address(@0x10E);
    let deposit1 = 9000;  // 90%
    let deposit2 = 1000;  // 10%
    let total_deposit = deposit1 + deposit2;
    let notify_amount_usd = 20000;
    let notify_amount_sail = 5000;
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposits and Multi-Token Notify ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit, 1);

    clock::increment_for_testing(&mut clock, 1000);
    // Notify USD1
    let reward_coin_usd = coin::mint_for_testing<USD1>(notify_amount_usd, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin_usd.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Notify SAIL
    let reward_coin_sail = coin::mint_for_testing<SAIL>(notify_amount_sail, scenario.ctx());
    reward::notify_reward_amount_internal<SAIL>(
        &mut reward_obj,
        reward_coin_sail.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Verify earned is 0 for both tokens in Epoch 1
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 2);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 3);
    assert!(reward_obj.earned<SAIL>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<SAIL>(lock_id2, &clock) == 0, 5);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2: Verify Earned Rewards for both tokens ---
    // USD1 distribution
    let lock1_expected_usd = full_math_u64::mul_div_floor(notify_amount_usd, deposit1, total_deposit);
    let lock2_expected_usd = full_math_u64::mul_div_floor(notify_amount_usd, deposit2, total_deposit);
    let earned1_usd = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2_usd = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1_usd = earned1_usd - lock1_expected_usd;
    let diff2_usd = earned2_usd - lock2_expected_usd;
    assert!(diff1_usd <= 1, 6); 
    assert!(diff2_usd <= 1, 7); 
    assert!(earned1_usd + earned2_usd <= notify_amount_usd, 8);
    assert!(earned1_usd + earned2_usd >= notify_amount_usd - 1, 9);

    // SAIL distribution
    let lock1_expected_sail = full_math_u64::mul_div_floor(notify_amount_sail, deposit1, total_deposit);
    let lock2_expected_sail = full_math_u64::mul_div_floor(notify_amount_sail, deposit2, total_deposit);
    let earned1_sail = reward_obj.earned<SAIL>(lock_id1, &clock);
    let earned2_sail = reward_obj.earned<SAIL>(lock_id2, &clock);
    let diff1_sail = earned1_sail - lock1_expected_sail;
    let diff2_sail = earned2_sail - lock2_expected_sail;
    assert!(diff1_sail <= 1, 10); 
    assert!(diff2_sail <= 1, 11); 
    assert!(earned1_sail + earned2_sail <= notify_amount_sail, 12);
    assert!(earned1_sail + earned2_sail >= notify_amount_sail - 1, 13);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_large_nums() {
    let admin = @0xFF;
    let authorized_id: ID = object::id_from_address(@0xEE); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx()); 

    // Define details
    let lock_id1: ID = object::id_from_address(@0x103);
    let lock_id2: ID = object::id_from_address(@0x104);
    let deposit1 = (1<<60) * 6;  // 60% of total initial deposit
    let deposit2 = (1<<60) * 4;  // 40% of total initial deposit
    let total_deposit = deposit1 + deposit2;
    let notify_amount = 1<<63; // nearly max amount
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposits ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 3);

    // advance half a week to check that the moment of reward notification does not matter
    clock.increment_for_testing(one_week_ms / 2);

    // --- Epoch 1: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    // Use the internal notify function accessible within the package tests
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    clock.increment_for_testing( 10000);

    // Verify earned is 0 immediately after notify (rewards apply to next epoch start)
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms/2);

    // --- Epoch 2: Verify Earned Rewards ---
    let lock1_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit1, total_deposit
    );
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_deposit
    );

    // Allow for rounding difference (total earned might be slightly less than notify_amount)
    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1 = earned1 - lock1_expected_share; // should not distribute more than expected
    let diff2 = earned2 - lock2_expected_share;

    assert!(diff1 <= 1, 6); // Check lock1 share (allowing rounding by 1)
    assert!(diff2 <= 1, 7); // Check lock2 share (allowing rounding by 1)
    assert!(earned1 + earned2 <= notify_amount, 8); // Total earned should not exceed notified
    assert!(earned1 + earned2 >= notify_amount - 1, 9); // Total earned should be very close to notified

    // --- Claim Rewards using get_reward_internal ---

    // Claim for lock1
    let balance_opt1 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        admin, // Recipient address (using admin for test)
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt1), 10);
    let balance1 = option::destroy_some(balance_opt1);
    assert!(balance1.value() == earned1, 11); // Check claimed amount matches earned
    sui::balance::destroy_for_testing(balance1);

    // Claim for lock2
    let balance_opt2 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        admin, // Recipient address (using admin for test)
        lock_id2, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt2), 12);
    let balance2 = option::destroy_some(balance_opt2);
    assert!(balance2.value() == earned2, 13); // Check claimed amount matches earned
    sui::balance::destroy_for_testing(balance2);

    // Verify earned is now 0 after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 14);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 15);

    // Check that other tokens still have 0 earned
    let earned1_other_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    let earned2_other_token = reward_obj.earned<OTHER>(lock_id2, &clock);
    assert!(earned1_other_token == 0, 16);
    assert!(earned2_other_token == 0, 17);


    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_distribution_at_epoch_start() {
    let admin = @0xABC;
    let authorized_id: ID = object::id_from_address(@0xDEF); // ID for auth
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let mut reward_obj = create_default_reward(&mut scenario, authorized_id);
    let reward_cap = reward_authorized_cap::create(authorized_id, scenario.ctx());

    // Define details
    let lock_id1: ID = object::id_from_address(@0x201);
    let lock_id2: ID = object::id_from_address(@0x202);
    let deposit1 = 7000;  // 70%
    let deposit2 = 3000;  // 30%
    let total_deposit_epoch1 = deposit1 + deposit2;
    let notify_amount = 10000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    // advance clock by a couple of seconds
    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1: Deposits ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply() == total_deposit_epoch1, 1);
    assert!(reward_obj.balance_of(lock_id1) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2) == deposit2, 3);
    // Earned should be 0 before any reward notification
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // --- Epoch 2: Notify Reward immediately after epoch change ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        reward_coin.into_balance(),
        &clock, // Clock is now at the beginning of Epoch 2
        scenario.ctx()
    );

    // Earned should still be 0 immediately after notification, as rewards are calculated for the *next* view.
    // The notification sets the reward for the epoch that just started (Epoch 2).
    // When `earned` is called, it looks at completed past epochs.
    // So, to see the rewards from Epoch 2, we need to advance into Epoch 3 or later.
    // Or, if we want to check rewards *for* epoch 2, we'd call earned() *after* epoch 2 has passed.

    // For this test, we want to verify that if a reward is added AT THE START of epoch 2,
    // it becomes available when epoch 2 completes.

    // Let's verify earned is 0 *within* Epoch 2, just after notification
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 6);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 7);

    // --- Advance to Epoch 3 to check rewards from Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3: Verify Earned Rewards from Epoch 2 ---
    // Rewards were notified at the start of Epoch 2. Balances from end of Epoch 1 are used.
    let lock1_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit1, total_deposit_epoch1
    );
    let lock2_expected_share = full_math_u64::mul_div_floor(
        notify_amount, deposit2, total_deposit_epoch1
    );

    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    let diff1 = earned1 - lock1_expected_share;
    let diff2 = earned2 - lock2_expected_share;

    assert!(diff1 <= 1, 8); // Check lock1 share (allowing rounding by 1)
    assert!(diff2 <= 1, 9); // Check lock2 share (allowing rounding by 1)
    assert!(earned1 + earned2 <= notify_amount, 10);
    assert!(earned1 + earned2 >= notify_amount - 1, 11);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

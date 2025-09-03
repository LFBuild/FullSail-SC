#[test_only]
module voting_escrow::reward_tests;

use sui::test_scenario::{Self, Scenario};
use sui::object::{Self, ID};
use sui::types;
use std::option::{Self, Option};
use std::type_name::{Self, TypeName};

use voting_escrow::reward::{Self, Reward};
use sui::test_utils;
use sui::clock::{Self, Clock};
use voting_escrow::reward_cap::{Self, RewardCap};
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
    let clock = clock::create_for_testing(scenario.ctx());

    // Define dummy IDs and reward types
    let reward_types = vector[
        type_name::get<USD1>(),
        type_name::get<SAIL>()
    ];

    // Call the create function
    let (reward_obj, reward_cap) = reward::create(
        object::id_from_address(@0x0),
        reward_types,
        false,
        scenario.ctx()
    );

    // --- Assertions ---
    assert!(reward::total_supply(&reward_obj, &clock) == 0, 1);
    assert!(reward::rewards_list_length(&reward_obj) == 2, 5);
    assert!(reward::rewards_contains(&reward_obj, type_name::get<USD1>()), 6);
    assert!(reward::rewards_contains(&reward_obj, type_name::get<SAIL>()), 7);
    assert!(!reward::rewards_contains(&reward_obj, type_name::get<OTHER>()), 8);

    test_utils::destroy(reward_obj);
    test_utils::destroy(reward_cap);
    
    clock::destroy_for_testing(clock);
    scenario.end();
}
fun create_default_reward(
    scenario: &mut Scenario,
    balance_update_enabled: bool
): (Reward, RewardCap) {
    let reward_types = vector[type_name::get<USD1>()];

    reward::create(
        object::id_from_address(@0x0),
        reward_types,
        balance_update_enabled,
        scenario.ctx()
    )
}

#[test]
fun test_deposit_reward() {
    let admin = @0xBB;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());


    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define deposit details
    let lock_id: ID = object::id_from_address(@0x100);
    let deposit_amount = 10000;

    // Initial state check
    assert!(reward_obj.total_supply(&clock) == 0, 0);
    assert!(reward_obj.balance_of(lock_id, &clock) == 0, 1);
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
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 3);
    assert!(reward_obj.balance_of(lock_id, &clock) == deposit_amount, 4);
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id: ID = object::id_from_address(@0x101);
    let initial_deposit = 10000;
    let first_withdraw = 4000;
    let second_withdraw = initial_deposit - first_withdraw; // 6000

    // Deposit initial amount
    reward_obj.deposit(&reward_cap, initial_deposit, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id, &clock) == initial_deposit, 2);

    clock::increment_for_testing(&mut clock, 1000); // Advance time for checkpointing

    // Withdraw partial amount
    reward_obj.withdraw(&reward_cap, first_withdraw, lock_id, &clock, scenario.ctx());

    // Assert state after first withdraw
    assert!(reward_obj.total_supply(&clock) == second_withdraw, 3); // total supply decreased
    assert!(reward_obj.balance_of(lock_id, &clock) == second_withdraw, 4); // lock balance decreased

    clock::increment_for_testing(&mut clock, 1000);

    // Withdraw remaining amount
    reward_obj.withdraw(&reward_cap, second_withdraw, lock_id, &clock, scenario.ctx());

    // Assert state after second withdraw
    assert!(reward_obj.total_supply(&clock) == 0, 5); // total supply is zero
    assert!(reward_obj.balance_of(lock_id, &clock) == 0, 6); // lock balance is zero

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_deposit_withdraw_reward_multi_epoch() {
    let admin = @0xEE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id, &clock) == deposit1, 2);
    // the first checkpoint index is 0
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 0, 11);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2: Second Deposit ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1 + deposit2, 3);
    assert!(reward_obj.balance_of(lock_id, &clock) == deposit1 + deposit2, 4);
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 1, 12);


    // --- Advance to Epoch 3 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3: First Withdraw ---
    reward_obj.withdraw(&reward_cap, withdraw1, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == withdraw2, 5); // withdraw2 is remaining balance
    assert!(reward_obj.balance_of(lock_id, &clock) == withdraw2, 6);
    assert!(reward_obj.get_prior_balance_index(lock_id, clock.timestamp_ms() / 1000) == 2, 13);

    // --- Advance to Epoch 4 ---
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 4: Second (Final) Withdraw ---
    reward_obj.withdraw(&reward_cap, withdraw2, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == 0, 7);
    assert!(reward_obj.balance_of(lock_id, &clock) == 0, 8);
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == total_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 3);

    // advance half a week to check that the moment of reward notification does not matter
    clock.increment_for_testing(one_week_ms / 2);

    // --- Epoch 1: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    // Use the internal notify function accessible within the package tests
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    clock.increment_for_testing( 10000);
    let notified_epoch_start = voting_escrow::common::epoch_start(clock.timestamp_ms() / 1000);

    assert!(reward::rewards_at_epoch<USD1>(&reward_obj, notified_epoch_start) == notify_amount, 10);
    assert!(reward::rewards_this_epoch<USD1>(&reward_obj, &clock) == notify_amount, 11);


    // Verify earned is 0 immediately after notify (rewards apply to next epoch start)
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms/2);

    // rewards were notified in the previous epoch, but not in the current one
    assert!(reward::rewards_at_epoch<USD1>(&reward_obj, notified_epoch_start) == notify_amount, 10);
    assert!(reward::rewards_this_epoch<USD1>(&reward_obj, &clock) == 0, 11);

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
        &reward_cap,
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
        &reward_cap,
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

    // check that rewards amount are still the same
    assert!(reward::rewards_at_epoch<USD1>(&reward_obj, notified_epoch_start) == notify_amount, 10);
    assert!(reward::rewards_this_epoch<USD1>(&reward_obj, &clock) == 0, 11);


    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_mid_epoch_deposit_reward() {
    let admin = @0xEE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2, &clock) == 0, 3);

    clock::increment_for_testing(&mut clock, 1000); // Small time increment

    // --- Epoch 1, Step 2: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
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
    assert!(reward_obj.total_supply(&clock) == total_deposit_end_epoch, 6);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 7);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 8);
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x107);
    let lock_id2: ID = object::id_from_address(@0x108);
    let deposit1 = 6000;
    let deposit2 = 4000;
    let notify_amount = 5000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1, Step 1: Deposit lock1 ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 2: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 3: Deposit lock2 ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1 + deposit2, 4);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 5);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 6);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 7);

    clock::increment_for_testing(&mut clock, 1000);

    // --- Epoch 1, Step 4: Withdraw lock1 ---
    reward_obj.withdraw(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit2, 8); // Only deposit2 remains
    assert!(reward_obj.balance_of(lock_id1, &clock) == 0, 9);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 10);
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == total_deposit_epoch1, 1);

    clock::increment_for_testing(&mut clock, 1000);
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
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
    assert!(reward_obj.total_supply(&clock) == deposit2, 4); // Only deposit2 remains
    assert!(reward_obj.balance_of(lock_id1, &clock) == 0, 5);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 6);

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

    let balance_opt1 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id1, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt1), 11);
    sui::balance::destroy_for_testing(option::destroy_some(balance_opt1));
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 12); // Earned becomes 0 after claim

    let balance_opt2 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id2, &clock, scenario.ctx());
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == total_deposit_e1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);

    clock.increment_for_testing(1000);
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3); // Earned is 0 in current epoch

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 2: Deposit lock2 & Notify reward2 ---
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == total_deposit_e2, 4);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 5);

    clock.increment_for_testing(1000);
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Earned for lock1 should reflect reward1, earned for lock2 still 0
    let earned1_mid_e2 = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned1_mid_e2 <= notify_amount1 && earned1_mid_e2 >= notify_amount1 -1 , 6); 
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 7);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Modify default reward creation to include SAIL
    let reward_types = vector[
        type_name::get<USD1>(),
        type_name::get<SAIL>()
    ];
    let (mut reward_obj, reward_cap) = reward::create(
        object::id_from_address(@0x0),
        reward_types,
        false,
        scenario.ctx()
    );

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
    assert!(reward_obj.total_supply(&clock) == total_deposit, 1);

    clock.increment_for_testing(1000);
    // Notify USD1
    let reward_coin_usd = coin::mint_for_testing<USD1>(notify_amount_usd, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin_usd.into_balance(),
        &clock,
        scenario.ctx()
    );
    // Notify SAIL
    let reward_coin_sail = coin::mint_for_testing<SAIL>(notify_amount_sail, scenario.ctx());
    reward::notify_reward_amount_internal<SAIL>(
        &mut reward_obj,
        &reward_cap,
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
    clock.increment_for_testing(one_week_ms);

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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

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
    assert!(reward_obj.total_supply(&clock) == total_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 3);

    // advance half a week to check that the moment of reward notification does not matter
    clock.increment_for_testing(one_week_ms / 2);

    // --- Epoch 1: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    // Use the internal notify function accessible within the package tests
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
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
        &reward_cap,
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
        &reward_cap,
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
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x201);
    let lock_id2: ID = object::id_from_address(@0x202);
    let deposit1 = 7000;  // 70%
    let deposit2 = 3000;  // 30%
    let total_deposit_epoch1 = deposit1 + deposit2;
    let notify_amount = 10000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    // advance clock by a couple of seconds
    clock.increment_for_testing(1000);

    // --- Epoch 1: Deposits ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == total_deposit_epoch1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 3);
    // Earned should be 0 before any reward notification
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 5);

    // --- Epoch 2: Notify Reward immediately after epoch change ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
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
    clock.increment_for_testing(one_week_ms);

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

#[test]
#[expected_failure(abort_code = voting_escrow::reward::EUpdateBalancesDisabled)]
fun test_reward_update_balances_disabled_should_fail() {
    let admin = @0x99;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = false using utility function
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Try to call update_balances - this should fail
    let lock_ids = vector[object::id_from_address(@0x123)];
    let balances = vector[1000u64];
    let for_epoch_start = 0; // Start of epoch 0

    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        for_epoch_start,
        true, // final
        &clock,
        scenario.ctx()
    );

    // Cleanup (this won't be reached due to expected failure)
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reward_balance_update_enabled_no_finalization() {
    let admin = @0x11;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x301);
    let deposit1 = 6000;
    let notify_amount = 10000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposits ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);

    clock.increment_for_testing(1000);

    // --- Epoch 1: Notify Reward ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Verify earned is 0 within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 2: Verify Earned is Still Zero (No Balance Update Called) ---
    // Since balance_update_enabled = true but update_balances was never called,
    // the epoch was never finalized, so earned should return 0
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);

    // Advance one more epoch to be sure
    clock.increment_for_testing(one_week_ms);
    
    // Still should be 0 because epoch 1 (where rewards were notified) was never finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 5);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_balance_update_enabled_not_finalized() {
    let admin = @0x33;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x401);
    let deposit1 = 5000;
    let updated_deposit1 = 6000;
    let notify_amount = 1000; // Amount of USD1 reward
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposit and Notify Reward ---
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);

    clock.increment_for_testing(1000);

    // Notify reward for Epoch 1
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Verify earned is 0 within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // Get the epoch start for Epoch 1 (for update_balances call)
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);

    // Total supply should remain unchanged after advancing epochs
    assert!(reward_obj.total_supply(&clock) == deposit1, 4);

    // --- Epoch 2: Call update_balances with final = false ---
    // This should update the balances but NOT finalize the epoch
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_deposit1]; 
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1
        false, // final = false - this is the key point!
        &clock,
        scenario.ctx()
    );

    assert!(reward_obj.total_supply(&clock) == updated_deposit1, 5);

    // --- Verify Earned is Still Zero (Epoch Not Finalized) ---
    // Since final=false was passed to update_balances, the epoch is not finalized
    // Therefore, earned should return 0 even though rewards were notified and balances updated
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 6);

    // Advance one more epoch to be sure
    clock.increment_for_testing(one_week_ms);
    
    assert!(reward_obj.total_supply(&clock) == updated_deposit1, 7);
    // Still should be 0 because epoch 1 was never finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 8);

    // --- Now finalize the epoch and verify earned works ---
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1
        true, // final = true - now finalize the epoch
        &clock,
        scenario.ctx()
    );

    assert!(reward_obj.total_supply(&clock) == updated_deposit1, 9);

    // Now earned should return the expected reward amount
    let earned = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned == notify_amount, 10); // Should equal notified amount

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_update_balances_specific_epoch() {
    let admin = @0x55;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x501);
    let initial_deposit = 3000;
    let updated_balance_epoch2 = 5000;
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Deposit lock ---
    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 2);

    // Get epoch start times for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));
    
    // Verify total_supply_at for epoch 1
    let epoch1_total_supply = reward_obj.total_supply_at(epoch1_start);
    assert!(epoch1_total_supply == initial_deposit, 3);

    clock.increment_for_testing(1000);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Total supply should still be the same (no balance updates yet)
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 4);
    
    // Verify total_supply_at for both epochs before update
    assert!(reward_obj.total_supply_at(epoch1_start) == initial_deposit, 5);
    assert!(reward_obj.total_supply_at(epoch2_start) == initial_deposit, 6);

    clock.increment_for_testing(1000);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

    // --- Update balance for Epoch 2 specifically ---
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch2];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch2_start, // Update balances for Epoch 2 specifically
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // --- Verify total_supply_at for different epochs ---
    
    // Epoch 1 total supply should remain unchanged
    let epoch1_total_supply_after = reward_obj.total_supply_at(epoch1_start);
    assert!(epoch1_total_supply_after == initial_deposit, 7);
    
    // Epoch 2 total supply should be updated
    let epoch2_total_supply_after = reward_obj.total_supply_at(epoch2_start);
    assert!(epoch2_total_supply_after == updated_balance_epoch2, 8);

    // Current total supply should reflect the latest state
    assert!(reward_obj.total_supply(&clock) == updated_balance_epoch2, 9);

    // Verify individual lock balance is also updated
    assert!(reward_obj.balance_of(lock_id1, &clock) == updated_balance_epoch2, 10);

    // Verify balance_of_at for specific epochs
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == initial_deposit, 11);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance_epoch2, 12);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

fun check_epoch_time_points(
    reward_obj: &Reward,
    lock_id: ID,
    epoch_start: u64,
    expected_balance: u64,
    one_week_seconds: u64,
    assertion_base: u64
) {
    // Calculate time points within the epoch
    let epoch_start_plus_1 = epoch_start + 1;
    let epoch_middle = epoch_start + (one_week_seconds / 2);
    let epoch_end = epoch_start + one_week_seconds - 1;

    let base = assertion_base * 10;

    // Check balance and total supply at epoch start
    assert!(reward_obj.balance_of_at(lock_id, epoch_start) == expected_balance, base + 1);
    assert!(reward_obj.total_supply_at(epoch_start) == expected_balance, base + 2);
    
    // Check balance and total supply at epoch start + 1 second
    assert!(reward_obj.balance_of_at(lock_id, epoch_start_plus_1) == expected_balance, base + 3);
    assert!(reward_obj.total_supply_at(epoch_start_plus_1) == expected_balance, base + 4);
    
    // Check balance and total supply at epoch middle
    assert!(reward_obj.balance_of_at(lock_id, epoch_middle) == expected_balance, base + 5);
    assert!(reward_obj.total_supply_at(epoch_middle) == expected_balance, base + 6);
    
    // Check balance and total supply at epoch end
    assert!(reward_obj.balance_of_at(lock_id, epoch_end) == expected_balance, base + 7);
    assert!(reward_obj.total_supply_at(epoch_end) == expected_balance, base + 8);
}

fun setup_3_epoch_scenario(
    scenario: &mut Scenario,
    clock: &mut Clock,
    authorized_id: ID
): (Reward, RewardCap, ID, u64, u64, u64, u64) {
    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(scenario, true);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x601);
    let initial_deposit = 2000;
    let additional_deposit = 1500;
    let withdrawal_amount = 800;
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Initial Deposit ---
    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, clock, scenario.ctx());

    // Get epoch start times for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(clock));
    
    clock.increment_for_testing(1000);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 2: Additional Deposit ---
    reward_obj.deposit(&reward_cap, additional_deposit, lock_id1, clock, scenario.ctx());
    let total_after_deposit2 = initial_deposit + additional_deposit;

    clock.increment_for_testing(1000);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 3: Partial Withdrawal ---
    reward_obj.withdraw(&reward_cap, withdrawal_amount, lock_id1, clock, scenario.ctx());
    let total_after_withdrawal = total_after_deposit2 - withdrawal_amount;

    clock.increment_for_testing(1000);

    (
        reward_obj,
        reward_cap,
        lock_id1,
        epoch1_start,
        initial_deposit, // epoch 1 total supply
        total_after_deposit2, // epoch 2 total supply
        total_after_withdrawal, // epoch 3 total supply
    )
}


#[test]
fun test_epoch_time_point_balances() {
    let admin = @0x99;
    let authorized_id: ID = object::id_from_address(@0xAA);
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup 3 epoch scenario with deposits and withdrawals
    let (
        reward_obj,
        reward_cap,
        lock_id1,
        epoch1_start,
        total_epoch_1,
        total_epoch_2,
        total_epoch_3,
    ) = setup_3_epoch_scenario(&mut scenario, &mut clock, authorized_id);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_seconds = one_week_ms / 1000;
    
    // Calculate epoch start times
    let epoch2_start = epoch1_start + one_week_seconds;
    let epoch3_start = epoch2_start + one_week_seconds;

    // --- Test Epoch 1 Time Points ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch1_start, 
        total_epoch_1, 
        one_week_seconds, 
        1
    );

    // --- Test Epoch 2 Time Points ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch2_start, 
        total_epoch_2, 
        one_week_seconds, 
        2
    );

    // --- Test Epoch 3 Time Points ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch3_start, 
        total_epoch_3, 
        one_week_seconds, 
        3
    );


    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_first_epoch_balance_updates() {
    let admin = @0x77;
    let authorized_id: ID = object::id_from_address(@0x88);
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup complex scenario with deposits and withdrawals across epochs
    let (
        mut reward_obj,
        reward_cap,
        lock_id1,
        epoch1_start,
        _,
        total_epoch_2,
        total_epoch_3,
    ) = setup_3_epoch_scenario(&mut scenario, &mut clock, authorized_id);

    // Define the updated balance for testing update_balances functionality
    let updated_balance_epoch1 = 100000; // What we'll set via update_balances

    // Calculate additional epoch starts for verification
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let epoch2_start = epoch1_start + (one_week_ms / 1000);
    let epoch3_start = epoch2_start + (one_week_ms / 1000);

    // --- Update balance for Epoch 1 specifically ---
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch1];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1 specifically
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // --- Verify balances after update_balances ---
    
    // Epoch 1 should now have the updated balance
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance_epoch1, 9);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance_epoch1, 10);
    
    // Epoch 2 and 3 should remain unchanged from the update_balances call
    // (They should still reflect the natural progression of deposits/withdrawals)
    assert!(reward_obj.total_supply_at(epoch2_start) == total_epoch_2, 11);
    assert!(reward_obj.total_supply_at(epoch3_start) == total_epoch_3, 12);
    
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == total_epoch_2, 13);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == total_epoch_3, 14);

    // Current total supply should still reflect the latest natural state
    assert!(reward_obj.total_supply(&clock) == total_epoch_3, 15);
    assert!(reward_obj.balance_of(lock_id1, &clock) == total_epoch_3, 16);

    // --- Comprehensive Time Point Verification After Update ---
    let one_week_seconds = one_week_ms / 1000;
    
    // --- Test Epoch 1 Time Points (Updated Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch1_start, 
        updated_balance_epoch1, 
        one_week_seconds, 
        3
    );

    // --- Test Epoch 2 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch2_start, 
        total_epoch_2, 
        one_week_seconds, 
        4
    );

    // --- Test Epoch 3 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch3_start, 
        total_epoch_3, 
        one_week_seconds, 
        5
    );

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_second_epoch_balance_updates() {
    let admin = @0x88;
    let authorized_id: ID = object::id_from_address(@0x99);
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup complex scenario with deposits and withdrawals across epochs
    let (
        mut reward_obj,
        reward_cap,
        lock_id1,
        epoch1_start,
        total_epoch_1,
        _,
        total_epoch_3,
    ) = setup_3_epoch_scenario(&mut scenario, &mut clock, authorized_id);

    // Define the updated balance for testing update_balances functionality on second epoch
    let updated_balance_epoch2 = 100000; // What we'll set via update_balances

    // Calculate additional epoch starts for verification
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let epoch2_start = epoch1_start + (one_week_ms / 1000);
    let epoch3_start = epoch2_start + (one_week_ms / 1000);

    // --- Update balance for Epoch 2 specifically ---
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch2];
    let one_week_seconds = one_week_ms / 1000;
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch2_start, // Update balances for Epoch 2 specifically
        true, // final = true
        &clock,
        scenario.ctx()
    );
    
    // --- Test Epoch 1 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch1_start, 
        total_epoch_1, 
        one_week_seconds, 
        2
    );

    // --- Test Epoch 2 Time Points (Updated Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch2_start, 
        updated_balance_epoch2, 
        one_week_seconds, 
        3
    );

    // --- Test Epoch 3 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch3_start, 
        total_epoch_3, 
        one_week_seconds, 
        4
    );

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_third_epoch_balance_updates() {
    let admin = @0x99;
    let authorized_id: ID = object::id_from_address(@0xAA);
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Setup complex scenario with deposits and withdrawals across epochs
    let (
        mut reward_obj,
        reward_cap,
        lock_id1,
        epoch1_start,
        total_epoch_1,
        total_epoch_2,
        _,
    ) = setup_3_epoch_scenario(&mut scenario, &mut clock, authorized_id);

    // Define the updated balance for testing update_balances functionality on third epoch
    let updated_balance_epoch3 = 100000; // What we'll set via update_balances

    // Calculate additional epoch starts for verification
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let epoch2_start = epoch1_start + (one_week_ms / 1000);
    let epoch3_start = epoch2_start + (one_week_ms / 1000);

    // --- Update balance for Epoch 3 specifically ---
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch3];
    let one_week_seconds = one_week_ms / 1000;

    // advance time to the next epoch, cos we only allowed to update balances for finished epochs
    clock.increment_for_testing(one_week_ms);
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch3_start, // Update balances for Epoch 3 specifically
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // --- Test Epoch 1 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch1_start, 
        total_epoch_1, 
        one_week_seconds, 
        1
    );

    // --- Test Epoch 2 Time Points (Original Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch2_start, 
        total_epoch_2, 
        one_week_seconds, 
        2
    );

    // --- Test Epoch 3 Time Points (Updated Balance) ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch3_start, 
        updated_balance_epoch3, 
        one_week_seconds, 
        3
    );

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_update_balances_of_non_existing_lock() {
    let admin = @0xBB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: No deposits, just advance time ---
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 2: Still no deposits, advance time ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 3: Now deposit a lock for the first time ---
    let lock_id1: ID = object::id_from_address(@0x701);
    let deposit_amount = 5000;
    
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit_amount, 2);

    let lock_ids = vector[lock_id1];
    let balances = vector[10000u64];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start,
        true,
        &clock,
        scenario.ctx()
    );

    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 10000, 3);
    assert!(reward_obj.total_supply_at(epoch1_start) == 10000, 4);

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reward_balance_of_non_existing_lock() {
    let admin = @0xDD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Create reward with default settings
    let (reward_obj, reward_cap) = create_default_reward(&mut scenario, false);
    let current_time = voting_escrow::common::current_timestamp(&clock);
    let epoch_start = voting_escrow::common::epoch_start(current_time);

    // Create some lock IDs that never get deposited
    let non_existing_lock1: ID = object::id_from_address(@0x801);
    // Test balance_of for non-existing locks should return 0
    assert!(reward_obj.balance_of(non_existing_lock1, &clock) == 0, 1);
    assert!(reward_obj.balance_of_at(non_existing_lock1, epoch_start) == 0, 4);
    assert!(reward_obj.balance_of_at(non_existing_lock1, epoch_start + 1) == 0, 4);
    assert!(reward_obj.balance_of_at(non_existing_lock1, epoch_start + 1 * voting_escrow::common::epoch() - 1) == 0, 4);
    assert!(reward_obj.balance_of_at(non_existing_lock1, epoch_start + voting_escrow::common::epoch() / 2) == 0, 4);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_update_balances_non_deposited_lock() {
    let admin = @0xFF;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // Get current epoch start
    let current_time = voting_escrow::common::current_timestamp(&clock);
    let epoch_start = voting_escrow::common::epoch_start(current_time);

    // Create a lock ID that was never deposited to the system
    let non_existing_lock: ID = object::id_from_address(@0x901);

    // Try to update balance for a lock that was never deposited
    // This should fail because the lock doesn't exist in the reward system
    let lock_ids = vector[non_existing_lock];
    let balances = vector[5000u64]; // Try to set some balance for the non-existing lock

    // advance time to the next epoch
    clock.increment_for_testing(one_week_ms);
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch_start, // Update balances for current epoch
        true, // final = true
        &clock,
        scenario.ctx()
    );

    assert!(reward_obj.balance_of_at(non_existing_lock, epoch_start) == 5000u64, 1);
    assert!(reward_obj.total_supply_at(epoch_start) == 5000u64, 2);

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reward_multiple_update_balances_latest_wins() {
    let admin = @0xAC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Set up initial deposits ---
    let lock_id1: ID = object::id_from_address(@0xA01);
    let lock_id2: ID = object::id_from_address(@0xA02);
    let initial_deposit1 = 1000;
    let initial_deposit2 = 2000;

    reward_obj.deposit(&reward_cap, initial_deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, initial_deposit2, lock_id2, &clock, scenario.ctx());

    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Advance to next epoch to be able to update the previous epoch
    clock.increment_for_testing(one_week_ms);

    // --- First update_balances call (not final) ---
    let lock_ids = vector[lock_id1, lock_id2];
    let first_balances = vector[5000u64, 6000u64]; // First attempt
    
    reward_obj.update_balances(
        &reward_cap,
        first_balances,
        lock_ids,
        epoch1_start,
        false, // final = false, should allow more updates
        &clock,
        scenario.ctx()
    );

    // Verify first update is applied
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 5000, 1);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == 6000, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == 11000, 3);

    // --- Second update_balances call (not final) - should overwrite first ---
    let second_balances = vector[7000u64, 8000u64]; // Second attempt
    
    reward_obj.update_balances(
        &reward_cap,
        second_balances,
        lock_ids,
        epoch1_start,
        false, // final = false, should still allow more updates
        &clock,
        scenario.ctx()
    );

    // Verify second update overwrote first
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 7000, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == 8000, 5);
    assert!(reward_obj.total_supply_at(epoch1_start) == 15000, 6);

    // --- Third update_balances call (final) - should overwrite and finalize ---
    let final_balances = vector[10000u64, 12000u64]; // Final values
    
    reward_obj.update_balances(
        &reward_cap,
        final_balances,
        lock_ids,
        epoch1_start,
        true, // final = true, this should be the final update
        &clock,
        scenario.ctx()
    );

    // Verify final update is applied (latest wins)
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 10000, 7);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == 12000, 8);
    assert!(reward_obj.total_supply_at(epoch1_start) == 22000, 9);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward::EUpdateBalancesAlreadyFinal)]
fun test_reward_update_balances_after_final_should_fail() {
    let admin = @0xCE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Set up initial deposits ---
    let lock_id1: ID = object::id_from_address(@0xB01);
    let initial_deposit1 = 3000;

    reward_obj.deposit(&reward_cap, initial_deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Advance to next epoch to be able to update the previous epoch
    clock.increment_for_testing(one_week_ms);

    // --- First update_balances call (final = true) ---
    let lock_ids = vector[lock_id1];
    let final_balances = vector[8000u64];
    
    reward_obj.update_balances(
        &reward_cap,
        final_balances,
        lock_ids,
        epoch1_start,
        true, // final = true, this finalizes the epoch
        &clock,
        scenario.ctx()
    );

    // Verify the update was applied
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 8000, 1);

    // --- Try to update again after finalization - this should fail ---
    let second_balances = vector[9000u64]; // Try to change to a different value
    
    reward_obj.update_balances(
        &reward_cap,
        second_balances,
        lock_ids,
        epoch1_start,
        false, // Doesn't matter what we set here, should fail regardless
        &clock,
        scenario.ctx()
    );

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward::EUpdateBalancesOnlyFinishedEpochAllowed)]
fun test_reward_update_balances_current_epoch_should_fail() {
    let admin = @0xDE;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // --- Deposit a lock in the current epoch ---
    let lock_id1: ID = object::id_from_address(@0xC01);
    let deposit_amount = 4000;

    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit_amount, 2);

    // Get the current time and epoch start
    let current_time = voting_escrow::common::current_timestamp(&clock);
    let current_epoch_start = voting_escrow::common::epoch_start(current_time);

    // --- Try to update balances for the current epoch ---
    // This should fail because you can't update balances for the active epoch
    let lock_ids = vector[lock_id1];
    let balances = vector[6000u64]; // Try to change the balance
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        current_epoch_start, // Using current_time instead of epoch_start - this should fail
        true,
        &clock,
        scenario.ctx()
    );

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward::EUpdateBalancesOnlyFinishedEpochAllowed)]
fun test_reward_update_balances_future_epoch_should_fail() {
    let admin = @0xF0;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // --- Deposit a lock in the current epoch ---
    let lock_id1: ID = object::id_from_address(@0xF01);
    let deposit_amount = 3000;

    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit_amount, 2);

    // Get the current time and epoch start
    let current_time = voting_escrow::common::current_timestamp(&clock);
    let current_epoch_start = voting_escrow::common::epoch_start(current_time);
    
    // Calculate a future epoch start (10 weeks in the future)
    let one_week = voting_escrow::common::epoch();
    let future_epoch_start = current_epoch_start + (10 * one_week);

    // --- Try to update balances for the future epoch ---
    // This should fail because you can only update balances for finished (past) epochs
    let lock_ids = vector[lock_id1];
    let balances = vector[5000u64]; // Try to change the balance
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        future_epoch_start, // Using future epoch start - this should fail
        true,
        &clock,
        scenario.ctx()
    );

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reward_update_balances_past_epoch_after_time_advance() {
    let admin = @0xF2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // --- Epoch 1: Deposit a lock ---
    let lock_id1: ID = object::id_from_address(@0xF02);
    let initial_deposit = 2000;

    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 2);

    // Store epoch starts for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_seconds = one_week_ms / 1000;

    // Calculate future epoch starts
    let epoch2_start = epoch1_start + one_week_seconds;
    let epoch3_start = epoch2_start + one_week_seconds;
    let epoch4_start = epoch3_start + one_week_seconds;
    let epoch5_start = epoch4_start + one_week_seconds;
    let epoch6_start = epoch5_start + one_week_seconds;

    // --- Advance time by 5 epochs (from epoch 1 to epoch 6) ---
    clock.increment_for_testing(5 * one_week_ms);

    // Verify we're now in epoch 6
    let current_time = voting_escrow::common::current_timestamp(&clock);
    let current_epoch_start = voting_escrow::common::epoch_start(current_time);
    assert!(current_epoch_start == epoch6_start, 3);

    // Verify the deposit is still tracked correctly
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 4);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 5);

    // --- Update balances for 4th epoch (which is now in the past) ---
    let lock_ids = vector[lock_id1];
    let updated_balance_epoch4 = 8000; // New balance for epoch 4
    let balances = vector[updated_balance_epoch4];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch4_start, // Update balances for 4th epoch (past epoch)
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // --- Verify the update was successful ---
    
    // Epoch 4 and 5 should now have the updated balance
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == updated_balance_epoch4, 6);
    assert!(reward_obj.balance_of_at(lock_id1, epoch5_start) == updated_balance_epoch4, 7);

    assert!(reward_obj.total_supply_at(epoch4_start) == updated_balance_epoch4, 8);
    assert!(reward_obj.total_supply_at(epoch5_start) == updated_balance_epoch4, 9);

    // Other epochs should still have the original balance
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == initial_deposit, 10);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == initial_deposit, 11);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == initial_deposit, 12);

    assert!(reward_obj.total_supply_at(epoch1_start) == initial_deposit, 14);
    assert!(reward_obj.total_supply_at(epoch2_start) == initial_deposit, 15);
    assert!(reward_obj.total_supply_at(epoch3_start) == initial_deposit, 16);

    // Current total supply should still reflect the natural progression (original deposit)
    assert!(reward_obj.total_supply(&clock) == updated_balance_epoch4, 17);
    assert!(reward_obj.balance_of(lock_id1, &clock) == updated_balance_epoch4, 18);

    // --- Test specific time points within epoch 4 and 5 to verify the update ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch4_start, 
        updated_balance_epoch4, 
        one_week_seconds, 
        2
    );

    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch5_start, 
        updated_balance_epoch4, 
        one_week_seconds, 
        3
    );

    // --- Test that other epochs still have original balances ---
    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch1_start, 
        initial_deposit, 
        one_week_seconds, 
        4
    );

    check_epoch_time_points(
        &reward_obj, 
        lock_id1, 
        epoch3_start, 
        initial_deposit, 
        one_week_seconds, 
        5
    );

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward::EUpdateBalancesInvalidLocksLength)]
fun test_reward_update_balances_no_weights_should_fail() {
    let admin = @0xF4;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    // --- Deposit a lock first ---
    let lock_id1: ID = object::id_from_address(@0xF03);
    let initial_deposit = 1500;

    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 2);

    // Store epoch start for the deposit
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // Advance to next epoch so we can update the previous epoch
    clock.increment_for_testing(one_week_ms);

    // --- Try to call update_balances with mismatched vector lengths ---
    // Provide lock_ids but no corresponding balances (empty balances vector)
    let lock_ids = vector[lock_id1]; // Non-empty vector with 1 element
    let balances = vector<u64>[]; // Empty vector with 0 elements
    
    reward_obj.update_balances(
        &reward_cap,
        balances, // Empty vector (0 elements)
        lock_ids, // Non-empty vector (1 element)
        epoch1_start,
        true,
        &clock,
        scenario.ctx()
    );

    // Should never reach here due to expected failure
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reward_notify_then_deposits_update_balances_and_claim() {
    let admin = @0xF6;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let notify_amount = 10000; // USD1 reward amount

    // --- Epoch 1, Step 1: Notify Reward Amount First ---
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Verify no earned rewards yet (no deposits, no locks)
    let lock_id1: ID = object::id_from_address(@0xF04);
    let lock_id2: ID = object::id_from_address(@0xF05);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 1);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 2);

    // --- Epoch 1, Step 2: After some time, deposit first lock ---
    clock.increment_for_testing(one_week_ms / 4); // 1/4 through epoch

    let deposit1 = 3000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit1, 3);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 4);

    // Still no earned rewards within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 5);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 6);

    // --- Epoch 1, Step 3: After another time, deposit second lock within same epoch ---
    clock.increment_for_testing(one_week_ms / 4); // Now 1/2 through epoch

    let deposit2 = 7000;
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let total_deposits = deposit1 + deposit2;
    assert!(reward_obj.total_supply(&clock) == total_deposits, 7);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 8);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 9);

    // Still no earned rewards within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 10);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 11);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms / 2); // Complete the epoch

    // Still no earned rewards because balance updates are required when balance_update_enabled = true
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 12);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 13);

    // --- Update balances for previous epoch (Epoch 1) ---
    // Set custom balances that will determine reward distribution
    let updated_balance1 = 4000; // 40% of total (4000 / 10000)
    let updated_balance2 = 6000; // 60% of total (6000 / 10000)
    let updated_total = updated_balance1 + updated_balance2;

    let lock_ids = vector[lock_id1, lock_id2];
    let balances = vector[updated_balance1, updated_balance2];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // Verify balances were updated for epoch 1
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 14);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 15);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_total, 16);

    // --- Now get rewards for all locks ---
    // Calculate expected rewards based on updated balances
    let expected_reward1 = 4000; // 40% of 10000 = 4000
    let expected_reward2 = 6000; // 60% of 10000 = 6000

    // Check earned amounts
    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    
    assert!(earned1 == expected_reward1, 17);
    assert!(earned2 == expected_reward2, 18);
    assert!(earned1 + earned2 == notify_amount, 19);

    // --- Claim rewards for both locks ---
    let balance_opt1 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt1), 21);
    let balance1 = option::destroy_some(balance_opt1);
    assert!(balance1.value() == earned1, 22);
    sui::balance::destroy_for_testing(balance1);

    let balance_opt2 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id2, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt2), 23);
    let balance2 = option::destroy_some(balance_opt2);
    assert!(balance2.value() == earned2, 24);
    sui::balance::destroy_for_testing(balance2);

    // Verify earned is now 0 after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 25);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 26);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_only_finalized_epochs_claimable() {
    let admin = @0xF8;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let notify_amount1 = 5000; // USD1 reward amount for epoch 1
    let notify_amount2 = 8000; // USD1 reward amount for epoch 2

    // --- Epoch 1, Step 1: Notify reward amount for epoch 1 ---
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 1, Step 2: Deposit a lock ---
    let lock_id1: ID = object::id_from_address(@0xF06);
    let initial_deposit = 4000;

    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 2);

    // No earned rewards within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 2, Step 1: Notify reward amount again for epoch 2 ---
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );

    clock.increment_for_testing(one_week_ms / 10);

    // Still no earned rewards because balance updates are required
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);

    // --- Epoch 2, Step 2: Make a partial withdraw ---
    let withdraw_amount = 1000;
    reward_obj.withdraw(&reward_cap, withdraw_amount, lock_id1, &clock, scenario.ctx());
    let remaining_balance = initial_deposit - withdraw_amount; // 3000
    assert!(reward_obj.total_supply(&clock) == remaining_balance, 5);
    assert!(reward_obj.balance_of(lock_id1, &clock) == remaining_balance, 6);

    // Still no earned rewards
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 7);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

    // Still no earned rewards because neither epoch has been finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 8);

    // --- Update balances for the FIRST epoch ONLY (final=true) ---
    let updated_balance_epoch1 = 6000; // Custom balance for epoch 1
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch1];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1 ONLY
        true, // final = true (finalize epoch 1)
        &clock,
        scenario.ctx()
    );

    // Verify epoch 1 balance was updated
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance_epoch1, 9);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance_epoch1, 10);

    // --- Get reward - should ONLY be claimable for first epoch ---
    // Expected reward for epoch 1: 100% of notify_amount1 since only one lock
    let expected_reward_epoch1 = notify_amount1; // 5000
    
    let earned_total = reward_obj.earned<USD1>(lock_id1, &clock);
    
    // Should only get rewards from epoch 1, NOT epoch 2 (epoch 2 not finalized)
    assert!(earned_total == expected_reward_epoch1, 11);

    // Verify epoch 2 is NOT contributing to earned rewards
    // If epoch 2 was contributing, earned would be notify_amount1 + notify_amount2 = 13000
    // But since epoch 2 is not finalized, we only get epoch 1 rewards
    assert!(earned_total != notify_amount1 + notify_amount2, 12);
    assert!(earned_total == notify_amount1, 13); // Only epoch 1

    // --- Claim rewards (should only get epoch 1 rewards) ---
    let balance_opt = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt), 14);
    let claimed_balance = option::destroy_some(balance_opt);
    assert!(claimed_balance.value() == expected_reward_epoch1, 15);
    sui::balance::destroy_for_testing(claimed_balance);

    // Verify earned is now 0 after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 16);

    // --- Verify that epoch 2 rewards are still not available ---
    // Even after claiming epoch 1, epoch 2 should still not be claimable
    // because it hasn't been finalized with update_balances
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 17);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_only_second_epoch_finalized_no_rewards() {
    let admin = @0xFA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let notify_amount1 = 5000; // USD1 reward amount for epoch 1
    let notify_amount2 = 8000; // USD1 reward amount for epoch 2

    // --- Epoch 1, Step 1: Notify reward amount for epoch 1 ---
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 1, Step 2: Deposit a lock ---
    let lock_id1: ID = object::id_from_address(@0xF07);
    let initial_deposit = 4000;

    reward_obj.deposit(&reward_cap, initial_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == initial_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == initial_deposit, 2);

    // No earned rewards within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 2, Step 1: Notify reward amount again for epoch 2 ---
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );

    clock.increment_for_testing(one_week_ms / 10);

    // Still no earned rewards because balance updates are required
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);

    // --- Epoch 2, Step 2: Make a partial withdraw ---
    let withdraw_amount = 1000;
    reward_obj.withdraw(&reward_cap, withdraw_amount, lock_id1, &clock, scenario.ctx());
    let remaining_balance = initial_deposit - withdraw_amount; // 3000
    assert!(reward_obj.total_supply(&clock) == remaining_balance, 5);
    assert!(reward_obj.balance_of(lock_id1, &clock) == remaining_balance, 6);

    // Still no earned rewards
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 7);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

    // Still no earned rewards because neither epoch has been finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 8);

    // --- Update balances for the SECOND epoch ONLY (final=true) ---
    // This is the key difference: we finalize epoch 2 instead of epoch 1
    let updated_balance_epoch2 = 7000; // Custom balance for epoch 2
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch2];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch2_start, // Update balances for Epoch 2 ONLY (not epoch 1)
        true, // final = true (finalize epoch 2)
        &clock,
        scenario.ctx()
    );

    // Verify epoch 2 balance was updated
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance_epoch2, 9);
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance_epoch2, 10);

    // Verify epoch 1 balance remains unchanged (not finalized)
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == initial_deposit, 11);
    assert!(reward_obj.total_supply_at(epoch1_start) == initial_deposit, 12);

    // --- Get reward - should be ZERO because epoch 1 was never finalized ---
    // Even though epoch 2 is finalized, epoch 1 (which comes first) was not finalized
    // The earned() function will stop at epoch 1 since it's not finalized
    let earned_total = reward_obj.earned<USD1>(lock_id1, &clock);
    
    // Should be zero because epoch 1 was never finalized, blocking access to all subsequent rewards
    assert!(earned_total == 0, 13);

    // --- Attempt to claim rewards (should get nothing) ---
    let balance_opt = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    
    // Should get None (no rewards available)
    assert!(option::is_none(&balance_opt), 14);
    option::destroy_none(balance_opt);

    // --- Verify earned is still 0 after attempted claim ---
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 15);

    // --- Verify that both epoch rewards are inaccessible ---
    // Epoch 1: Not finalized, so rewards not available
    // Epoch 2: Finalized, but blocked by epoch 1 not being finalized
    // Total available rewards should be 0, not 5000 (epoch 1) or 8000 (epoch 2) or 13000 (both)
    assert!(earned_total == 0, 16);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_double_claim_impossible() {
    let admin = @0xFC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let notify_amount1 = 3000; // USD1 reward amount for epoch 1
    let notify_amount2 = 7000; // USD1 reward amount for epoch 2

    // --- Epoch 1: Notify reward amount ---
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 1: Deposit a lock ---
    let lock_id1: ID = object::id_from_address(@0xF08);
    let deposit_amount = 5000;

    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit_amount, 2);

    // No earned rewards within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Epoch 2: Update balances for Epoch 1 ---
    let updated_balance_epoch1 = 6000; // Custom balance for epoch 1
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance_epoch1];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1
        true, // final = true (finalize epoch 1)
        &clock,
        scenario.ctx()
    );

    // --- Epoch 2: Notify reward amount for epoch 2 ---
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Try claim in wrong token, should be zero
    let earned_wrong_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    assert!(earned_wrong_token == 0, 5);

    let balance_opt_wrong_token = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_wrong_token), 6);
    option::destroy_none(balance_opt_wrong_token);

    // --- First claim: Get reward for epoch 1 ---
    let earned_before_first_claim = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_before_first_claim == notify_amount1, 4); // Should equal first epoch notify amount

    let balance_opt1 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt1), 7);
    let claimed_balance1 = option::destroy_some(balance_opt1);
    assert!(claimed_balance1.value() == notify_amount1, 8); // Should equal first epoch rewards
    sui::balance::destroy_for_testing(claimed_balance1);

    // Verify earned is now 0 after first claim
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 9);

    // --- Double claim attempt 1: Try to claim reward again instantly ---
    let balance_opt1_double = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    // Should get None (no rewards available)
    assert!(option::is_none(&balance_opt1_double), 10);
    option::destroy_none(balance_opt1_double);

    // Verify earned is still 0 after double claim attempt
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 11);

    // Try again claim in wrong token, should be zero
    let earned_wrong_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    assert!(earned_wrong_token == 0, 12);

    let balance_opt_wrong_token = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_wrong_token), 13);
    option::destroy_none(balance_opt_wrong_token);

    // --- Advance to Epoch 3 ---
    clock.increment_for_testing(one_week_ms);

    // --- Epoch 3: Update balances for Epoch 2 ---
    let updated_balance_epoch2 = 8000; // Custom balance for epoch 2
    let balances2 = vector[updated_balance_epoch2];
    
    reward_obj.update_balances(
        &reward_cap,
        balances2,
        lock_ids,
        epoch2_start, // Update balances for Epoch 2
        true, // final = true (finalize epoch 2)
        &clock,
        scenario.ctx()
    );

    // Try again claim in wrong token, should be zero
    let earned_wrong_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    assert!(earned_wrong_token == 0, 14);

    let balance_opt_wrong_token = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_wrong_token), 15);
    option::destroy_none(balance_opt_wrong_token);

    // --- Second claim: Get reward for epoch 2 ---
    let earned_before_second_claim = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_before_second_claim == notify_amount2, 16); // Should equal second epoch notify amount

    let balance_opt2 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt2), 17);
    let claimed_balance2 = option::destroy_some(balance_opt2);
    assert!(claimed_balance2.value() == notify_amount2, 18); // Should equal second epoch rewards
    sui::balance::destroy_for_testing(claimed_balance2);

    // Verify earned is now 0 after second claim
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 19);

    // --- Double claim attempt 2: Try to claim reward again instantly ---
    let balance_opt2_double = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    // Should get None (no rewards available)
    assert!(option::is_none(&balance_opt2_double), 20);
    option::destroy_none(balance_opt2_double);

        // Try again claim in wrong token, should be zero
    let earned_wrong_token = reward_obj.earned<OTHER>(lock_id1, &clock);
    assert!(earned_wrong_token == 0, 21);

    let balance_opt_wrong_token = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_wrong_token), 22);
    option::destroy_none(balance_opt_wrong_token);

    // Verify earned is still 0 after second double claim attempt
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 23);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_multi_token_notify_and_claim() {
    let admin = @0xFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true and support for multiple tokens
    let reward_types = vector[
        type_name::get<USD1>(),
        type_name::get<OTHER>()
    ];
    let (mut reward_obj, reward_cap) = reward::create(
        object::id_from_address(@0x0),
        reward_types,
        true, // balance_update_enabled = true
        scenario.ctx()
    );

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let notify_amount_usd1 = 5000; // USD1 reward amount
    let notify_amount_other = 3000; // OTHER reward amount

    // --- Notify reward with USD1 ---
    let reward_coin_usd1 = coin::mint_for_testing<USD1>(notify_amount_usd1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin_usd1.into_balance(),
        &clock,
        scenario.ctx()
    );

    // --- Notify reward with OTHER ---
    let reward_coin_other = coin::mint_for_testing<OTHER>(notify_amount_other, scenario.ctx());
    reward::notify_reward_amount_internal<OTHER>(
        &mut reward_obj,
        &reward_cap,
        reward_coin_other.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Verify both tokens are supported
    assert!(reward_obj.rewards_contains(type_name::get<USD1>()), 1);
    assert!(reward_obj.rewards_contains(type_name::get<OTHER>()), 2);

    // --- Deposit a lock ---
    let lock_id1: ID = object::id_from_address(@0xF09);
    let deposit_amount = 8000;

    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 3);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit_amount, 4);

    // No earned rewards within the same epoch for either token
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 5);
    assert!(reward_obj.earned<OTHER>(lock_id1, &clock) == 0, 6);

    // --- Advance to the next epoch ---
    clock.increment_for_testing(one_week_ms);

    // Still no earned rewards because balance updates are required
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 7);
    assert!(reward_obj.earned<OTHER>(lock_id1, &clock) == 0, 8);

    // --- Update balances for the previous epoch ---
    let updated_balance = 10000; // Custom balance for the lock
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance];
    
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch1_start, // Update balances for Epoch 1
        true, // final = true (finalize epoch 1)
        &clock,
        scenario.ctx()
    );

    // Verify balance was updated
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance, 9);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance, 10);

    // --- Get rewards for both token types ---
    
    // Expected rewards: 100% of each notify amount since only one lock exists
    let expected_reward_usd1 = notify_amount_usd1; // 5000
    let expected_reward_other = notify_amount_other; // 3000

    // Check earned amounts for both tokens
    let earned_usd1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned_other = reward_obj.earned<OTHER>(lock_id1, &clock);
    
    assert!(earned_usd1 == expected_reward_usd1, 11);
    assert!(earned_other == expected_reward_other, 12);

    // --- Claim USD1 rewards ---
    let balance_opt_usd1 = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt_usd1), 13);
    let claimed_balance_usd1 = option::destroy_some(balance_opt_usd1);
    assert!(claimed_balance_usd1.value() == expected_reward_usd1, 14);
    sui::balance::destroy_for_testing(claimed_balance_usd1);

    // Verify USD1 earned is now 0 after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 15);

    // --- Claim OTHER rewards ---
    let balance_opt_other = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin, // Recipient address
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt_other), 16);
    let claimed_balance_other = option::destroy_some(balance_opt_other);
    assert!(claimed_balance_other.value() == expected_reward_other, 17);
    sui::balance::destroy_for_testing(claimed_balance_other);

    // Verify OTHER earned is now 0 after claiming
    assert!(reward_obj.earned<OTHER>(lock_id1, &clock) == 0, 18);

    // --- Verify both tokens are completely claimed ---
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 19);
    assert!(reward_obj.earned<OTHER>(lock_id1, &clock) == 0, 20);

    // --- Verify double claim protection for both tokens ---
    let balance_opt_usd1_double = reward::get_reward_internal<USD1>(
        &mut reward_obj, 
        &reward_cap,
        admin,
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_usd1_double), 21);
    option::destroy_none(balance_opt_usd1_double);

    let balance_opt_other_double = reward::get_reward_internal<OTHER>(
        &mut reward_obj, 
        &reward_cap,
        admin,
        lock_id1, 
        &clock, 
        scenario.ctx()
    );
    assert!(option::is_none(&balance_opt_other_double), 22);
    option::destroy_none(balance_opt_other_double);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_reward_update_balances_empty_vectors_should_succeed() {
    let admin = @0xEA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // --- Epoch 1: Set up initial deposits ---
    let lock_id1: ID = object::id_from_address(@0xE01);
    let lock_id2: ID = object::id_from_address(@0xE02);
    let deposit1 = 4000;
    let deposit2 = 6000;
    let total_deposit = deposit1 + deposit2;

    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    
    assert!(reward_obj.total_supply(&clock) == total_deposit, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 2);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 3);

    // Add a reward for the epoch
    let reward_coin = coin::mint_for_testing<USD1>(1000, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Store epoch start for reference
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // --- Advance to Epoch 2 ---
    clock.increment_for_testing(one_week_ms);

    // Verify current state before empty update
    assert!(reward_obj.total_supply(&clock) == total_deposit, 4);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 5);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 6);

    // Verify balances at epoch 1 (should be the original deposits)
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 7);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 8);
    assert!(reward_obj.total_supply_at(epoch1_start) == total_deposit, 9);

    // --- Call update_balances with empty vectors (both balances and lock_ids empty) ---
    let empty_lock_ids = vector<ID>[];
    let empty_balances = vector<u64>[];
    
    reward_obj.update_balances(
        &reward_cap,
        empty_balances, // Empty vector (0 elements)
        empty_lock_ids, // Empty vector (0 elements)
        epoch1_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // --- Verify that balances remain unchanged after empty update ---
    
    // Current balances should remain the same
    assert!(reward_obj.total_supply(&clock) == total_deposit, 10);
    assert!(reward_obj.balance_of(lock_id1, &clock) == deposit1, 11);
    assert!(reward_obj.balance_of(lock_id2, &clock) == deposit2, 12);

    // Historical balances at epoch 1 should remain the same
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 13);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 14);
    assert!(reward_obj.total_supply_at(epoch1_start) == total_deposit, 15);

    // Advance to next epoch to make rewards claimable
    clock.increment_for_testing(one_week_ms);

    // Verify that rewards can be claimed (indicating the epoch was properly finalized)
    let earned1 = reward_obj.earned<USD1>(lock_id1, &clock);
    let earned2 = reward_obj.earned<USD1>(lock_id2, &clock);
    
    // Should have earned rewards proportional to their deposits
    // lock_id1: 4000/10000 = 40% of 1000 = 400
    // lock_id2: 6000/10000 = 60% of 1000 = 600
    let expected_earned1 = 400;
    let expected_earned2 = 600;
    
    assert!(earned1 == expected_earned1, 16);
    assert!(earned2 == expected_earned2, 17);
    assert!(earned1 + earned2 == 1000, 18);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);

    scenario.end();
}

#[test]
fun test_claim_rewards_sequentially_with_balance_updates() {
    let admin = @0xEE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = object::id_from_address(@0xF0B);
    let deposit_amount = 5000;
    let notify_amount1 = 4000;
    let notify_amount2 = 6000;

    // In Epoch 1
    // 2. Deposit a lock
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // 3. Notify reward for Epoch 1
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );

    // 4. Advance time to Epoch 2
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // In Epoch 2
    // 5. Notify reward again for Epoch 2
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Earned should be 0 as epoch 1 is not finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 1);

    // 6. Update balances for the first epoch with final=true
    let updated_balance1 = 8000;
    let lock_ids = vector[lock_id1];
    let balances1 = vector[updated_balance1];
    reward_obj.update_balances(
        &reward_cap,
        balances1,
        lock_ids,
        epoch1_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // 7. Claim rewards for the lock (for epoch 1)
    let earned_epoch1 = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_epoch1 == notify_amount1, 2);

    let balance_opt1 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id1, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt1), 3);
    let claimed_balance1 = option::destroy_some(balance_opt1);
    assert!(claimed_balance1.value() == notify_amount1, 4);
    sui::balance::destroy_for_testing(claimed_balance1);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 5);

    // Earned should still be 0 for epoch 2 because it's not finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 6);


    // Advance to Epoch 3
    clock.increment_for_testing(one_week_ms);

    // 8. Update balances for the second epoch with final=true
    let updated_balance2 = 12000;
    let balances2 = vector[updated_balance2];
    reward_obj.update_balances(
        &reward_cap,
        balances2,
        lock_ids,
        epoch2_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // Now earned for epoch 2 should be available.
    let earned_epoch2 = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_epoch2 == notify_amount2, 7);

    // 10. and claims rewards for the lock.
    let earned_epoch2_after_advance = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_epoch2_after_advance == notify_amount2, 8);
    let balance_opt2 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id1, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt2), 9);
    let claimed_balance2 = option::destroy_some(balance_opt2);
    assert!(claimed_balance2.value() == notify_amount2, 10);
    sui::balance::destroy_for_testing(claimed_balance2);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 11);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
fun test_claim_rewards_epoch_by_epoch_with_balance_updates() {
    let admin = @0xEC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Step 1: Create Reward with balance updates enabled
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = object::id_from_address(@0xF0A);
    let deposit_amount = 5000;
    let notify_amount1 = 3000; // Reward for epoch 1
    let notify_amount2 = 7000; // Reward for epoch 2

    // Step 2: Deposit a lock in Epoch 1
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == deposit_amount, 1);

    // Step 3: Notify reward for Epoch 1
    let reward_coin1 = coin::mint_for_testing<USD1>(notify_amount1, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin1.into_balance(),
        &clock,
        scenario.ctx()
    );
    let epoch1_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Earned is 0 within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 2);

    // Step 4: Advance to Epoch 2
    clock.increment_for_testing(one_week_ms);
    let epoch2_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // Step 5: Notify reward for Epoch 2
    let reward_coin2 = coin::mint_for_testing<USD1>(notify_amount2, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin2.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Earned is still 0 because epoch 1 is not finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 3);

    // Step 6: Advance to Epoch 3
    clock.increment_for_testing(one_week_ms);

    // Earned is still 0 because no epochs are finalized
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 4);

    // Step 7: Update balances for Epoch 1
    let updated_balance_epoch1 = 6000; // custom balance
    let lock_ids = vector[lock_id1];
    let balances1 = vector[updated_balance_epoch1];
    
    reward_obj.update_balances(
        &reward_cap,
        balances1,
        lock_ids,
        epoch1_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // Step 8: Claim reward for Epoch 1
    // Now earned should reflect epoch 1 rewards
    let earned_after_e1_finalize = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_after_e1_finalize == notify_amount1, 5);

    let balance_opt1 = reward::get_reward_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        admin,
        lock_id1,
        &clock,
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt1), 6);
    let claimed_balance1 = option::destroy_some(balance_opt1);
    assert!(claimed_balance1.value() == notify_amount1, 7);
    sui::balance::destroy_for_testing(claimed_balance1);

    // Earned should be 0 again after claiming
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 8);

    // Step 9: Update balances for Epoch 2
    let updated_balance_epoch2 = 8000; // custom balance
    let balances2 = vector[updated_balance_epoch2];

    reward_obj.update_balances(
        &reward_cap,
        balances2,
        lock_ids,
        epoch2_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // Step 10: Claim reward for Epoch 2
    // Now earned should reflect epoch 2 rewards
    let earned_after_e2_finalize = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_after_e2_finalize == notify_amount2, 9);

    let balance_opt2 = reward::get_reward_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        admin,
        lock_id1,
        &clock,
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt2), 10);
    let claimed_balance2 = option::destroy_some(balance_opt2);
    assert!(claimed_balance2.value() == notify_amount2, 11);
    sui::balance::destroy_for_testing(claimed_balance2);

    // Earned should be 0 again
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 12);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_double_claim_with_balance_updates_is_zero() {
    let admin = @0xEE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create reward with balance_update_enabled = true
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = object::id_from_address(@0xF0C);
    let deposit_amount = 10000;
    let notify_amount = 5000;

    // 2. Deposit a lock
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id1, &clock, scenario.ctx());
    let epoch_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(&clock));

    // 3. Notify reward
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Advance to next epoch to be able to update balances for the previous one
    clock.increment_for_testing(one_week_ms);

    // 4. Update balances with final=true
    let lock_ids = vector[lock_id1];
    let balances = vector[deposit_amount];
    reward_obj.update_balances(
        &reward_cap,
        balances,
        lock_ids,
        epoch_start,
        true, // final = true
        &clock,
        scenario.ctx()
    );

    // 5. Claim rewards for the lock (first time)
    let earned_before_claim = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_before_claim == notify_amount, 1);

    let balance_opt1 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id1, &clock, scenario.ctx());
    assert!(option::is_some(&balance_opt1), 2);
    let claimed_balance1 = option::destroy_some(balance_opt1);
    assert!(claimed_balance1.value() == notify_amount, 3);
    sui::balance::destroy_for_testing(claimed_balance1);

    // Verify earned is zero after first claim
    let earned_after_claim = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_after_claim == 0, 4);

    // 6. Tries again to claim rewards for the same lock
    let balance_opt2 = reward::get_reward_internal<USD1>(&mut reward_obj, &reward_cap, admin, lock_id1, &clock, scenario.ctx());
    
    // 7. Second time claimed rewards should be zero
    assert!(option::is_none(&balance_opt2), 5); // Should get None as there are no rewards to claim
    option::destroy_none(balance_opt2);

    let earned_after_second_try = reward_obj.earned<USD1>(lock_id1, &clock);
    assert!(earned_after_second_try == 0, 6);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_rewards_after_100_epochs() {
    let admin = @0xFAFA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id: ID = object::id_from_address(@0xDADA);
    let deposit_amount = 10000;
    let notify_amount_per_epoch = 100;
    let num_epochs = 100;
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // Deposit lock
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.balance_of(lock_id, &clock) == deposit_amount, 0);

    // Loop 100 times: notify reward and advance epoch
    let mut i = 0;
    while (i < num_epochs) {
        // Notify reward
        let reward_coin = coin::mint_for_testing<USD1>(notify_amount_per_epoch, scenario.ctx());
        reward::notify_reward_amount_internal<USD1>(
            &mut reward_obj,
            &reward_cap,
            reward_coin.into_balance(),
            &clock,
            scenario.ctx()
        );

        // Advance to next epoch
        clock.increment_for_testing(one_week_ms);
        i = i + 1;
    };

    // Verify earned rewards
    // Since there's only one lock, it should get 100% of the rewards.
    let total_notified_reward = notify_amount_per_epoch * num_epochs;
    let earned_amount = reward_obj.earned<USD1>(lock_id, &clock);
    assert!(earned_amount == total_notified_reward, 1);

    // Claim rewards
    let balance_opt = reward::get_reward_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        admin,
        lock_id,
        &clock,
        scenario.ctx()
    );
    assert!(option::is_some(&balance_opt), 2);
    let claimed_balance = option::destroy_some(balance_opt);
    assert!(claimed_balance.value() == total_notified_reward, 3);
    sui::balance::destroy_for_testing(claimed_balance);

    // Verify earned is 0 after claim
    assert!(reward_obj.earned<USD1>(lock_id, &clock) == 0, 4);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_rewards_after_200_epochs() {
    let admin = @0xFAFA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id: ID = object::id_from_address(@0xDADA);
    let deposit_amount = 10000;
    let notify_amount_per_epoch = 100;
    let num_epochs = 200;
    let one_week_ms = 7 * 24 * 60 * 60 * 1000;

    // Deposit lock
    reward_obj.deposit(&reward_cap, deposit_amount, lock_id, &clock, scenario.ctx());
    assert!(reward_obj.balance_of(lock_id, &clock) == deposit_amount, 0);

    // Loop 100 times: notify reward and advance epoch
    let mut i = 0;
    while (i < num_epochs) {
        // Notify reward
        let reward_coin = coin::mint_for_testing<USD1>(notify_amount_per_epoch, scenario.ctx());
        reward::notify_reward_amount_internal<USD1>(
            &mut reward_obj,
            &reward_cap,
            reward_coin.into_balance(),
            &clock,
            scenario.ctx()
        );

        // Advance to next epoch
        clock.increment_for_testing(one_week_ms);
        i = i + 1;
    };

    // Verify earned rewards
    // Since there's only one lock, it should get 100% of the rewards.
    // we do 2 iterations cos we have a limit of 100 epochs per claim.
    let mut i = 0;
    while (i < 2) {
        // claim method only claims 100 epochs at a time.
        let expected_claimed_amount = notify_amount_per_epoch * 100;
        let earned_amount = reward_obj.earned<USD1>(lock_id, &clock);
        assert!(earned_amount == expected_claimed_amount, 1);

        // Claim rewards
        let balance_opt = reward::get_reward_internal<USD1>(
            &mut reward_obj,
            &reward_cap,
            admin,
            lock_id,
            &clock,
            scenario.ctx()
        );
        assert!(option::is_some(&balance_opt), 2);
        let claimed_balance = option::destroy_some(balance_opt);
        assert!(claimed_balance.value() == expected_claimed_amount, 3);
        sui::balance::destroy_for_testing(claimed_balance);
        i = i + 1;
    };

    // Verify earned is 0 after claim
    assert!(reward_obj.earned<USD1>(lock_id, &clock) == 0, 4);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_deposit_zero_amount() {
    let admin = @0x1000;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Create Reward object and Cap
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, false);

    // Define details
    let lock_id1: ID = object::id_from_address(@0x201);
    let lock_id2: ID = object::id_from_address(@0x202);
    let zero_deposit = 0;
    let normal_deposit = 5000;

    // --- Test 1: Zero deposit on a new lock ---
    // Initial state checks
    assert!(reward_obj.total_supply(&clock) == 0, 1);
    assert!(reward_obj.balance_of(lock_id1, &clock) == 0, 2);

    // Deposit zero amount
    reward_obj.deposit(&reward_cap, zero_deposit, lock_id1, &clock, scenario.ctx());

    // Verify state after zero deposit - should remain unchanged
    assert!(reward_obj.total_supply(&clock) == 0, 3);
    assert!(reward_obj.balance_of(lock_id1, &clock) == 0, 4);
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 5);

    // --- Test 2: Normal deposit followed by zero deposit ---
    // Make a normal deposit first
    reward_obj.deposit(&reward_cap, normal_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == normal_deposit, 6);
    assert!(reward_obj.balance_of(lock_id1, &clock) == normal_deposit, 7);

    // Now deposit zero amount - should not change the balance
    reward_obj.deposit(&reward_cap, zero_deposit, lock_id1, &clock, scenario.ctx());
    assert!(reward_obj.total_supply(&clock) == normal_deposit, 8);
    assert!(reward_obj.balance_of(lock_id1, &clock) == normal_deposit, 9);

    // --- Test 3: Zero deposit on a different lock while another has balance ---
    reward_obj.deposit(&reward_cap, zero_deposit, lock_id2, &clock, scenario.ctx());
    
    // lock_id1 should still have its balance, lock_id2 should have zero
    assert!(reward_obj.balance_of(lock_id1, &clock) == normal_deposit, 10);
    assert!(reward_obj.balance_of(lock_id2, &clock) == 0, 11);
    assert!(reward_obj.total_supply(&clock) == normal_deposit, 12);

    // --- Test 4: Zero deposit with reward notifications ---
    let notify_amount = 1000;
    let reward_coin = coin::mint_for_testing<USD1>(notify_amount, scenario.ctx());
    reward::notify_reward_amount_internal<USD1>(
        &mut reward_obj,
        &reward_cap,
        reward_coin.into_balance(),
        &clock,
        scenario.ctx()
    );

    // Deposit zero after reward notification
    reward_obj.deposit(&reward_cap, zero_deposit, lock_id1, &clock, scenario.ctx());
    
    // Balances should remain the same
    assert!(reward_obj.balance_of(lock_id1, &clock) == normal_deposit, 13);
    assert!(reward_obj.balance_of(lock_id2, &clock) == 0, 14);
    assert!(reward_obj.total_supply(&clock) == normal_deposit, 15);
    
    // Earned should still be 0 within the same epoch
    assert!(reward_obj.earned<USD1>(lock_id1, &clock) == 0, 16);
    assert!(reward_obj.earned<USD1>(lock_id2, &clock) == 0, 17);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

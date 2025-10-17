#[test_only]
module voting_escrow::reward_total_supply_issue_tests;

use sui::test_scenario::{Self, Scenario};
use std::type_name;

use voting_escrow::reward::{Self, Reward};
use sui::test_utils;
use sui::clock;
use voting_escrow::reward_cap::{RewardCap};
use sui::object::{ID};
use voting_escrow::common;

// Define dummy types for testing
public struct USD1 has drop {}

fun create_default_reward(
    scenario: &mut Scenario,
    balance_update_enabled: bool
): (Reward, RewardCap) {
    let reward_types = vector[type_name::get<USD1>()];

    reward::create(
        sui::object::id_from_address(@0x0),
        reward_types,
        balance_update_enabled,
        scenario.ctx()
    )
}

#[test]
fun test_total_supply_with_out_of_order_update() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // 2. Deposit two locks.
    let deposit1 = 1000;
    let deposit2 = 2000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 1);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 2);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 3);

    // 3. Advance to the next epoch.
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch2_start = common::epoch_start(common::current_timestamp(&clock));

    // 4. Deposit 0 for the first lock. This should not change the balance for the new epoch.
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // Balances at epoch 2 start are carried over from epoch 1's deposits.
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 5);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1 + deposit2, 6);

    // Advance to epoch 3 to be able to update past epochs.
    clock::increment_for_testing(&mut clock, one_week_ms);

    // 5. Update balances for the first epoch.
    let updated_balance1 = 300;
    let updated_balance2 = 400;
    let lock_ids = vector[lock_id1, lock_id2];
    let balances = vector[updated_balance1, updated_balance2];
    reward_obj.update_balances(&reward_cap, balances, lock_ids, epoch1_start, true, &clock, scenario.ctx());

    // 6. Check balances and total supply.
    // Epoch 1 should be updated.
    let expected_supply_e1 = updated_balance1 + updated_balance2; // 700
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 8);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 9);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) + reward_obj.balance_of_at(lock_id2, epoch1_start) == reward_obj.total_supply_at(epoch1_start), 10);
    assert!(reward_obj.total_supply_at(epoch1_start) == expected_supply_e1, 7);
    
    // Epoch 2 should be affected by the update to epoch 1.
    let expected_supply_e2 = deposit1 + updated_balance2; // 1400
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1, 12);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == updated_balance2, 13);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) + reward_obj.balance_of_at(lock_id2, epoch2_start) == reward_obj.total_supply_at(epoch2_start), 14);
    assert!(reward_obj.total_supply_at(epoch2_start) == expected_supply_e2, 11);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_update_supply() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // 2. Deposit two locks.
    let deposit1 = 100;
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 1);

    // 3. Advance to the next epoch to be able to update past epochs.
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch2_start = common::epoch_start(common::current_timestamp(&clock));

    // 4. Update supply for the first epoch.
    let new_supply = 1000;
    reward_obj.update_supply(&reward_cap, epoch1_start, new_supply, &clock, scenario.ctx());

    // 5. Check that supply is updated.
    assert!(reward_obj.total_supply_at(epoch1_start) == new_supply, 2);
    assert!(reward_obj.total_supply_at(epoch2_start) == new_supply, 3);
    assert!(reward_obj.total_supply(&clock) == new_supply, 3);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_update_supply_after_deposit() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // 2. Deposit two locks.
    let deposit1 = 100;
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 1);

    // 3. Advance to the next epoch to be able to update past epochs.
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch2_start = common::epoch_start(common::current_timestamp(&clock));

    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // 4. Update supply for the first epoch.
    let new_supply = 1000;
    let old_supply = deposit1 + deposit2;
    reward_obj.update_supply(&reward_cap, epoch1_start, new_supply, &clock, scenario.ctx());

    // 5. Check that supply is updated.
    assert!(reward_obj.total_supply_at(epoch1_start) == new_supply, 2);
    assert!(reward_obj.total_supply_at(epoch2_start) == old_supply, 3);
    assert!(reward_obj.total_supply(&clock) == old_supply, 3);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_out_of_order_supply_updates() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 100;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 1);

    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch2_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1 + deposit2, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 10);

    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch3_start = common::epoch_start(common::current_timestamp(&clock));

    // --- In Epoch 3: Update supplies for past epochs ---
    // Update epoch 2 first
    let new_supply2 = 2000;
    reward_obj.update_supply(&reward_cap, epoch2_start, new_supply2, &clock, scenario.ctx());

    // Check supplies after updating epoch 2
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 3);
    assert!(reward_obj.total_supply_at(epoch2_start) == new_supply2, 4);
    assert!(reward_obj.total_supply_at(epoch3_start) == new_supply2, 5);
    assert!(reward_obj.total_supply(&clock) == new_supply2, 6);

    // Update epoch 1
    let new_supply1 = 1000;
    reward_obj.update_supply(&reward_cap, epoch1_start, new_supply1, &clock, scenario.ctx());

    // Check supplies after updating epoch 1
    assert!(reward_obj.total_supply_at(epoch1_start) == new_supply1, 7);
    assert!(reward_obj.total_supply_at(epoch2_start) == new_supply2, 8); // Should remain unchanged
    assert!(reward_obj.total_supply_at(epoch3_start) == new_supply2, 9); // Should remain unchanged
    assert!(reward_obj.total_supply(&clock) == new_supply2, 10); // Should remain unchanged

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_complex_update_scenario() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 100;
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 1);

    // --- Advance to Epoch 2 ---
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch2_start = common::epoch_start(common::current_timestamp(&clock));

    // Update balances for Epoch 1 and finalize
    let updated_balance1 = 300;
    let updated_balance2 = 400;
    let lock_ids1 = vector[lock_id1, lock_id2];
    let balances1 = vector[updated_balance1, updated_balance2];
    reward_obj.update_balances(&reward_cap, balances1, lock_ids1, epoch1_start, true, &clock, scenario.ctx());

    // Check state after Epoch 1 update
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 2);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 3);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1 + updated_balance2, 4);

    // Deposit 0 for the second lock in Epoch 2
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());

    // --- Advance to Epoch 3 ---
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch3_start = common::epoch_start(common::current_timestamp(&clock));
    
    // Deposit 0 for the first lock in Epoch 3
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());
    
    // Update balances for Epoch 2
    let updated_balance1_e2 = 0;
    let updated_balance2_e2 = 1000;
    let lock_ids2 = vector[lock_id1, lock_id2];
    let balances2 = vector[updated_balance1_e2, updated_balance2_e2];
    reward_obj.update_balances(&reward_cap, balances2, lock_ids2, epoch2_start, true, &clock, scenario.ctx());

    // Check final supply amounts
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1_e2 + updated_balance2_e2, 5); // 1000
    assert!(reward_obj.total_supply_at(epoch3_start) == updated_balance1 + updated_balance2_e2, 6); // 300 + 1000 = 1300

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_sequential_zeroing_updates() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);

    // --- Epoch 1 ---
    let deposit1 = 1000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));

    // Advance 2 epochs (to Epoch 3)
    clock::increment_for_testing(&mut clock, 2 * one_week_ms);
    let epoch2_start = epoch1_start + (one_week_ms / 1000);
    let epoch3_start = epoch2_start + (one_week_ms / 1000);

    // --- In Epoch 3: Deposit 0 for the lock ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // Advance 1 more epoch (to Epoch 4)
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch4_start = epoch3_start + (one_week_ms / 1000);

    // --- In Epoch 4: Perform sequential updates ---
    let lock_ids = vector[lock_id1];
    let zero_balances = vector[0u64];

    // Update Epoch 1
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch1_start, true, &clock, scenario.ctx());
    assert!(reward_obj.total_supply_at(epoch1_start) == 0, 1);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 0, 11);
    assert!(reward_obj.total_supply_at(epoch2_start) == 0, 2);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == 0, 12);
    assert!(reward_obj.total_supply_at(epoch3_start) == deposit1, 3);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == deposit1, 13);
    assert!(reward_obj.total_supply_at(epoch4_start) == deposit1, 4);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == deposit1, 14);

    // Update Epoch 2
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch2_start, true, &clock, scenario.ctx());
    assert!(reward_obj.total_supply_at(epoch1_start) == 0, 1);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 0, 11);
    assert!(reward_obj.total_supply_at(epoch2_start) == 0, 2);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == 0, 12);
    assert!(reward_obj.total_supply_at(epoch3_start) == deposit1, 3);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == deposit1, 13);
    assert!(reward_obj.total_supply_at(epoch4_start) == deposit1, 4);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == deposit1, 14);

    // Update Epoch 3
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch3_start, true, &clock, scenario.ctx());
    assert!(reward_obj.total_supply_at(epoch1_start) == 0, 1);
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 0, 11);
    assert!(reward_obj.total_supply_at(epoch2_start) == 0, 2);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == 0, 12);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 3);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 13);
    assert!(reward_obj.total_supply_at(epoch4_start) == 0, 4);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == 0, 14);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_reverse_sequential_zeroing_updates() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);

    // --- Epoch 1 ---
    let deposit1 = 1000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));

    // Advance 2 epochs (to Epoch 3)
    clock::increment_for_testing(&mut clock, 2 * one_week_ms);
    let epoch2_start = epoch1_start + (one_week_ms / 1000);
    let epoch3_start = epoch2_start + (one_week_ms / 1000);

    // --- In Epoch 3: Deposit 0 for the lock ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // Advance 1 more epoch (to Epoch 4)
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch4_start = epoch3_start + (one_week_ms / 1000);

    // --- In Epoch 4: Perform sequential updates in reverse order ---
    let lock_ids = vector[lock_id1];
    let zero_balances = vector[0u64];

    // Update Epoch 3
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch3_start, true, &clock, scenario.ctx());
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 2);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1, 3);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1, 4);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 5);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 6);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == 0, 7);
    assert!(reward_obj.total_supply_at(epoch4_start) == 0, 8);

    // Update Epoch 2
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch2_start, true, &clock, scenario.ctx());
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 9);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 10);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == 0, 11);
    assert!(reward_obj.total_supply_at(epoch2_start) == 0, 12);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 13);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 14);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == 0, 15);
    assert!(reward_obj.total_supply_at(epoch4_start) == 0, 16);

    // Update Epoch 1
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch1_start, true, &clock, scenario.ctx());
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == 0, 17);
    assert!(reward_obj.total_supply_at(epoch1_start) == 0, 18);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == 0, 19);
    assert!(reward_obj.total_supply_at(epoch2_start) == 0, 20);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 21);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 22);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == 0, 23);
    assert!(reward_obj.total_supply_at(epoch4_start) == 0, 24);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_multi_epoch_zeroing_and_update() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);

    // --- Epoch 1 ---
    let deposit1 = 1000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));

    // Advance 4 epochs (to Epoch 5)
    clock::increment_for_testing(&mut clock, 4 * one_week_ms);
    let epoch2_start = epoch1_start + one_week_s;
    let epoch3_start = epoch2_start + one_week_s;
    let epoch4_start = epoch3_start + one_week_s;
    let epoch5_start = epoch4_start + one_week_s;

    // --- In Epoch 5: Deposit 0 for the lock ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // Advance 1 more epoch (to Epoch 6)
    clock::increment_for_testing(&mut clock, one_week_ms);
    let epoch6_start = epoch5_start + one_week_s;

    // --- In Epoch 6: Deposit 0 again ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());

    // Advance 1 more epoch (to Epoch 7) to allow updates
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- In Epoch 7: Perform updates ---
    let lock_ids = vector[lock_id1];
    let zero_balances = vector[0u64];

    // Update Epoch 3 to zero
    reward_obj.update_balances(&reward_cap, zero_balances, lock_ids, epoch3_start, true, &clock, scenario.ctx());

    // --- Verification 1 ---
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 2);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1, 3);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1, 4);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 5);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 6);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == 0, 7);
    assert!(reward_obj.total_supply_at(epoch4_start) == 0, 8);
    assert!(reward_obj.balance_of_at(lock_id1, epoch5_start) == deposit1, 9);
    assert!(reward_obj.total_supply_at(epoch5_start) == deposit1, 10);
    assert!(reward_obj.balance_of_at(lock_id1, epoch6_start) == deposit1, 11);
    assert!(reward_obj.total_supply_at(epoch6_start) == deposit1, 12);

    // Update Epoch 4
    let new_balance_e4 = 2000;
    let new_balances_e4 = vector[new_balance_e4];
    reward_obj.update_balances(&reward_cap, new_balances_e4, lock_ids, epoch4_start, true, &clock, scenario.ctx());

    // --- Verification 2 ---
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 13);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 14);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1, 15);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1, 16);
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == 0, 17);
    assert!(reward_obj.total_supply_at(epoch3_start) == 0, 18);
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == new_balance_e4, 19);
    assert!(reward_obj.total_supply_at(epoch4_start) == new_balance_e4, 20);
    assert!(reward_obj.balance_of_at(lock_id1, epoch5_start) == deposit1, 21);
    assert!(reward_obj.total_supply_at(epoch5_start) == deposit1, 22);
    assert!(reward_obj.balance_of_at(lock_id1, epoch6_start) == deposit1, 23);
    assert!(reward_obj.total_supply_at(epoch6_start) == deposit1, 24);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_complex_zero_deposits_and_update() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 1000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let deposit2 = 2000;
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch2_start = epoch1_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3 ---
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch3_start = epoch2_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 4 ---
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch4_start = epoch3_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 5 ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch5_start = epoch4_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);
    // Now in Epoch 6, can update past epochs

    // --- Update Balances for Epoch 2 ---
    let updated_balance1_e2 = 500;
    let lock_ids = vector[lock_id1];
    let balances = vector[updated_balance1_e2];
    reward_obj.update_balances(&reward_cap, balances, lock_ids, epoch2_start, true, &clock, scenario.ctx());

    // --- Verification ---
    // Epoch 1
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == 0, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 3);

    // Epoch 2
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance1_e2, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 5);
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1_e2 + deposit2, 6);

    // Epoch 3
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == updated_balance1_e2, 7);
    assert!(reward_obj.balance_of_at(lock_id2, epoch3_start) == deposit2, 8);
    assert!(reward_obj.total_supply_at(epoch3_start) == updated_balance1_e2 + deposit2, 9);

    // Epoch 4
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == updated_balance1_e2, 10);
    assert!(reward_obj.balance_of_at(lock_id2, epoch4_start) == deposit2, 11);
    assert!(reward_obj.total_supply_at(epoch4_start) == updated_balance1_e2 + deposit2, 12);

    // Epoch 5
    assert!(reward_obj.balance_of_at(lock_id1, epoch5_start) == deposit1, 13);
    assert!(reward_obj.balance_of_at(lock_id2, epoch5_start) == deposit2, 14);
    assert!(reward_obj.total_supply_at(epoch5_start) == deposit1 + deposit2, 15);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_complex_zero_deposits_and_update_two_locks() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 1000;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let deposit2 = 2000;
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch2_start = epoch1_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 3 ---
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch3_start = epoch2_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 4 ---
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch4_start = epoch3_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 5 ---
    reward_obj.deposit(&reward_cap, 0, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());
    let epoch5_start = epoch4_start + one_week_s;
    clock::increment_for_testing(&mut clock, one_week_ms);
    // Now in Epoch 6, can update past epochs

    // --- Update Balances for Epoch 2 ---
    let updated_balance1_e2 = 500;
    let updated_balance2_e2 = 600;
    let lock_ids = vector[lock_id1, lock_id2];
    let balances = vector[updated_balance1_e2, updated_balance2_e2];
    reward_obj.update_balances(&reward_cap, balances, lock_ids, epoch2_start, true, &clock, scenario.ctx());

    // --- Verification ---
    // Epoch 1
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == 0, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1, 3);

    // Epoch 2
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance1_e2, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == updated_balance2_e2, 5);
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1_e2 + updated_balance2_e2, 6);

    // Epoch 3
    assert!(reward_obj.balance_of_at(lock_id1, epoch3_start) == updated_balance1_e2, 7);
    assert!(reward_obj.balance_of_at(lock_id2, epoch3_start) == deposit2, 8);
    assert!(reward_obj.total_supply_at(epoch3_start) == updated_balance1_e2 + deposit2, 9);

    // Epoch 4
    assert!(reward_obj.balance_of_at(lock_id1, epoch4_start) == updated_balance1_e2, 10);
    assert!(reward_obj.balance_of_at(lock_id2, epoch4_start) == deposit2, 11);
    assert!(reward_obj.total_supply_at(epoch4_start) == updated_balance1_e2 + deposit2, 12);

    // Epoch 5
    assert!(reward_obj.balance_of_at(lock_id1, epoch5_start) == deposit1, 13);
    assert!(reward_obj.balance_of_at(lock_id2, epoch5_start) == deposit2, 14);
    assert!(reward_obj.total_supply_at(epoch5_start) == deposit1 + deposit2, 15);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_complex_update_after_zero_deposit() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 100;
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    
    // Check initial state
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 3);
    
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let epoch2_start = epoch1_start + one_week_s;
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());

    clock::increment_for_testing(&mut clock, one_week_ms);
    // Now in Epoch 3, can update past epochs

    // --- Update Balances for Epoch 1 ---
    let updated_balance1 = 300;
    let updated_balance2 = 400;
    let lock_ids = vector[lock_id1, lock_id2];
    let balances = vector[updated_balance1, updated_balance2];
    reward_obj.update_balances(&reward_cap, balances, lock_ids, epoch1_start, true, &clock, scenario.ctx());

    // --- Verification ---
    // Epoch 1 should be updated
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 5);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1 + updated_balance2, 6);

    // Epoch 2 should be partially affected
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance1, 7); // Propagated from epoch 1 update
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 8); // Has its own checkpoint from zero-deposit
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1 + deposit2, 9);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_double_update_after_zero_deposit() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);

    // --- Epoch 1 ---
    let deposit1 = 100;
    let deposit2 = 200;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    
    // Check initial state
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == deposit1, 1);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 2);
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2, 3);
    
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let epoch2_start = epoch1_start + one_week_s;
    reward_obj.deposit(&reward_cap, 0, lock_id2, &clock, scenario.ctx());

    clock::increment_for_testing(&mut clock, one_week_ms);
    // Now in Epoch 3, can update past epochs

    // --- First Update for Epoch 1 (not final) ---
    let updated_balance1_v1 = 300;
    let updated_balance2_v1 = 400;
    let lock_ids = vector[lock_id1, lock_id2];
    let balances_v1 = vector[updated_balance1_v1, updated_balance2_v1];
    reward_obj.update_balances(&reward_cap, balances_v1, lock_ids, epoch1_start, false, &clock, scenario.ctx());

    // --- Verification 1 ---
    // Epoch 1 should be updated
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1_v1, 4);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2_v1, 5);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1_v1 + updated_balance2_v1, 6);

    // Epoch 2 should be partially affected
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance1_v1, 7);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 8); 
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1_v1 + deposit2, 9);

    // --- Second Update for Epoch 1 (final) ---
    let updated_balance1_v2 = 500;
    let updated_balance2_v2 = 600;
    let balances_v2 = vector[updated_balance1_v2, updated_balance2_v2];
    reward_obj.update_balances(&reward_cap, balances_v2, lock_ids, epoch1_start, true, &clock, scenario.ctx());

    // --- Verification 2 ---
    // Epoch 1 should be updated to the latest values
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1_v2, 10);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2_v2, 11);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1_v2 + updated_balance2_v2, 12);

    // Epoch 2 should be partially affected by the latest update
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == updated_balance1_v2, 13); // Propagated from latest epoch 1 update
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 14); // Has its own checkpoint from zero-deposit
    assert!(reward_obj.total_supply_at(epoch2_start) == updated_balance1_v2 + deposit2, 15);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_incremental_updates() {
    let admin = @0xCAFE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Create a Reward object with balance_update_enabled = true.
    let (mut reward_obj, reward_cap) = create_default_reward(&mut scenario, true);

    let one_week_ms = 7 * 24 * 60 * 60 * 1000;
    let one_week_s = one_week_ms / 1000;
    let lock_id1: ID = sui::object::id_from_address(@0x1);
    let lock_id2: ID = sui::object::id_from_address(@0x2);
    let lock_id3: ID = sui::object::id_from_address(@0x3);

    // --- Epoch 1 ---
    let deposit1 = 100;
    let deposit2 = 200;
    let deposit3 = 300;
    reward_obj.deposit(&reward_cap, deposit1, lock_id1, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit2, lock_id2, &clock, scenario.ctx());
    reward_obj.deposit(&reward_cap, deposit3, lock_id3, &clock, scenario.ctx());
    let epoch1_start = common::epoch_start(common::current_timestamp(&clock));
    assert!(reward_obj.total_supply_at(epoch1_start) == deposit1 + deposit2 + deposit3, 1);
    
    clock::increment_for_testing(&mut clock, one_week_ms);

    // --- Epoch 2 ---
    let epoch2_start = epoch1_start + one_week_s;
    let deposit1_e2 = 50;
    reward_obj.deposit(&reward_cap, deposit1_e2, lock_id1, &clock, scenario.ctx());

    clock::increment_for_testing(&mut clock, one_week_ms);
    // Now in Epoch 3, can update past epochs

    // --- First Update (lock 1, not final) ---
    let updated_balance1 = 400;
    reward_obj.update_balances(&reward_cap, vector[updated_balance1], vector[lock_id1], epoch1_start, false, &clock, scenario.ctx());
    
    // Verification 1
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 2);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == deposit2, 3);
    assert!(reward_obj.balance_of_at(lock_id3, epoch1_start) == deposit3, 4);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1 + deposit2 + deposit3, 5);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1 + deposit1_e2, 6);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == deposit2, 7);
    assert!(reward_obj.balance_of_at(lock_id3, epoch2_start) == deposit3, 8);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1 + deposit1_e2 + deposit2 + deposit3, 9);
    
    // --- Second Update (lock 2, not final) ---
    let updated_balance2 = 500;
    reward_obj.update_balances(&reward_cap, vector[updated_balance2], vector[lock_id2], epoch1_start, false, &clock, scenario.ctx());

    // Verification 2
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 10);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 11);
    assert!(reward_obj.balance_of_at(lock_id3, epoch1_start) == deposit3, 12);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1 + updated_balance2 + deposit3, 13);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1 + deposit1_e2, 14);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == updated_balance2, 15);
    assert!(reward_obj.balance_of_at(lock_id3, epoch2_start) == deposit3, 16);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1 + deposit1_e2 + updated_balance2 + deposit3, 17);

    // --- Third Update (lock 3, final) ---
    let updated_balance3 = 600;
    reward_obj.update_balances(&reward_cap, vector[updated_balance3], vector[lock_id3], epoch1_start, true, &clock, scenario.ctx());

    // Verification 3
    assert!(reward_obj.balance_of_at(lock_id1, epoch1_start) == updated_balance1, 18);
    assert!(reward_obj.balance_of_at(lock_id2, epoch1_start) == updated_balance2, 19);
    assert!(reward_obj.balance_of_at(lock_id3, epoch1_start) == updated_balance3, 20);
    assert!(reward_obj.total_supply_at(epoch1_start) == updated_balance1 + updated_balance2 + updated_balance3, 21);
    assert!(reward_obj.balance_of_at(lock_id1, epoch2_start) == deposit1 + deposit1_e2, 22);
    assert!(reward_obj.balance_of_at(lock_id2, epoch2_start) == updated_balance2, 23);
    assert!(reward_obj.balance_of_at(lock_id3, epoch2_start) == updated_balance3, 24);
    assert!(reward_obj.total_supply_at(epoch2_start) == deposit1 + deposit1_e2 + updated_balance2 + updated_balance3, 25);

    // Cleanup
    test_utils::destroy(reward_cap);
    test_utils::destroy(reward_obj);
    clock::destroy_for_testing(clock);
    scenario.end();
}




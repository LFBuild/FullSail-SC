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

// нужно написать тесты на get_prior_supply_index



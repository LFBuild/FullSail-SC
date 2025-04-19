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

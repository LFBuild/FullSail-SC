#[test_only]
module distribution::reward_tests;

use sui::test_scenario::{Self, Scenario};
use sui::object::{Self, ID};
use sui::types;
use std::option::{Self, Option};
use std::type_name::{Self, TypeName};

use distribution::reward::{Self, Reward};
use sui::test_utils;

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

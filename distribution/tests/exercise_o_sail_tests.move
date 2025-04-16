#[test_only]
module distribution::exercise_o_sail_tests;

use sui::test_scenario;
use sui::test_utils;
use sui::package;
use sui::clock::{Self, Clock};
use sui::tx_context::{Self, TxContext};
use sui::transfer;
use sui::event;
use sui::balance;
use move_stl::linked_table;
use std::type_name;
use std::ascii;
use std::string;
use sui::hash;
use sui::bcs;
use integer_mate::i32;
use clmm_pool::rewarder;

use clmm_pool::position;
use clmm_pool::pool::{Self, Pool};
use clmm_pool::factory::{Self, Pools};
use clmm_pool::config::{Self, GlobalConfig};
use distribution::minter::{Self, Minter, MINTER};
use distribution::voter::{Self, Voter, VOTER};
use distribution::notify_reward_cap::{Self, NotifyRewardCap};
use sui::coin::{Self, TreasuryCap};
use std::option::{Self, Option};
use sui::object;
use distribution::distribution_config;

#[test_only]
public struct USD1 has drop {}

#[test_only]
public struct USD2 has drop {}
    
#[test_only]
public struct SAIL has drop {}

// Helper function to compare two TypeNames lexicographically.
// Returns 0 if a < b, 1 if a > b, 2 if a == b.
#[test_only]
fun compare_type_names(type_name_a: &std::type_name::TypeName, type_name_b: &std::type_name::TypeName): u8 {
    let bytes_a = std::ascii::as_bytes(&std::type_name::into_string(*type_name_a));
    let bytes_b = std::ascii::as_bytes(&std::type_name::into_string(*type_name_b));
    let len_a = std::vector::length<u8>(bytes_a);
    let len_b = std::vector::length<u8>(bytes_b);
    let mut i = 0;
    while (i < len_a && i < len_b) {
        let byte_a = *std::vector::borrow<u8>(bytes_a, i);
        let byte_b = *std::vector::borrow<u8>(bytes_b, i);
        if (byte_a < byte_b) return 0; // A < B
        if (byte_a > byte_b) return 1; // A > B
        i = i + 1;
    };
    if (len_a < len_b) return 0; // A < B (A is prefix of B)
    if (len_a > len_b) return 1; // A > B (B is prefix of A)
    2 // A == B (Should not happen for different types)
}

// Creates a pool with a specific sqrt price.
// Assumes factory, config are initialized and fee tier (tick_spacing=1) exists.
// Requires CoinTypeA > CoinTypeB lexicographically.
#[test_only]
public fun create_pool_with_sqrt_price<CoinTypeA: drop, CoinTypeB: drop>(
    pools: &mut Pools,
    global_config: &GlobalConfig, // Immutable borrow is sufficient
    clock: &Clock,
    sqrt_price: u128,
    ctx: &mut TxContext
): Pool<CoinTypeA, CoinTypeB> {
    // Ensure CoinTypeA > CoinTypeB lexicographically as required by factory::create_pool_
    let type_name_a = std::type_name::get<CoinTypeA>();
    let type_name_b = std::type_name::get<CoinTypeB>();
    // Use the numeric error code value (6) because the constant is private
    assert!(compare_type_names(&type_name_a, &type_name_b) == 1, 6 /* clmm_pool::factory::EInvalidCoinOrder */);

    let tick_spacing = 1;
    // Fetch fee rate dynamically based on the assumed existing fee tier for tick_spacing 1
    let fee_rate = config::get_fee_rate(tick_spacing, global_config);

    let url = std::string::utf8(b"test_pool_url");
    let pool_index = factory::index(pools); // Get current index before factory increments it
    let feed_id_a = @0x2; // Placeholder feed ID
    let feed_id_b = @0x3; // Placeholder feed ID
    let auto_calc = true;

    // Use the factory function that returns the pool object directly
    factory::create_pool_<CoinTypeA, CoinTypeB>(
        pools,
        global_config,
        tick_spacing,
        sqrt_price,
        url,
        feed_id_a,
        feed_id_b,
        auto_calc,
        clock,
        ctx
    )
}

// Utility function to initialize CLMM factory, config, and add a fee tier.
#[test_only]
public fun setup_clmm_factory_with_fee_tier(
    scenario: &mut test_scenario::Scenario,
    sender: address,
    tick_spacing: u32,
    fee_rate: u64
) {
    // Tx 1: Init factory & config
    // No next_tx needed here if it's the first action in a block
    {
        factory::test_init(scenario.ctx());
        config::test_init(scenario.ctx());
    };
    
    // Tx 2: Add fee tier
    scenario.next_tx(sender);
    {
        let admin_cap = scenario.take_from_sender<config::AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, tick_spacing, fee_rate, scenario.ctx());
        test_scenario::return_shared(global_config);
        transfer::public_transfer(admin_cap, sender);
    };
}

// Sets up a CLMM pool with a specific sqrt price.
// Assumes factory, config are initialized and the required fee tier exists.
#[test_only]
public fun setup_pool_with_sqrt_price<CoinTypeA: drop, CoinTypeB: drop>(
    scenario: &mut test_scenario::Scenario,
    sqrt_price: u128,
    tick_spacing: u32,
) {

    {
        let mut pools = test_scenario::take_shared<Pools>(scenario);
        let global_config = test_scenario::take_shared<GlobalConfig>(scenario); 
        let clock = clock::create_for_testing(scenario.ctx());

        // Ensure CoinTypeA > CoinTypeB lexicographically
        let type_name_a = std::type_name::get<CoinTypeA>();
        let type_name_b = std::type_name::get<CoinTypeB>();
        assert!(compare_type_names(&type_name_a, &type_name_b) == 1, 6 /* clmm_pool::factory::EInvalidCoinOrder */);

        // Fee rate is fetched inside create_pool_ using the global_config and tick_spacing
        let url = std::string::utf8(b"test_pool_url");
        let feed_id_a = @0x2; // Placeholder
        let feed_id_b = @0x3; // Placeholder
        let auto_calc = true;

        let pool = factory::create_pool_<CoinTypeA, CoinTypeB>(
            &mut pools,
            &global_config,
            tick_spacing,
            sqrt_price,
            url,
            feed_id_a,
            feed_id_b,
            auto_calc,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pools);
        test_scenario::return_shared(global_config);
        transfer::public_share_object(pool);
        clock::destroy_for_testing(clock);
     }
}

// Sets up the Minter and Voter modules for testing.
// Assumes clmm_pool::config is initialized beforehand.
#[test_only]
public fun setup_distribution(
    scenario: &mut test_scenario::Scenario,
    sender: address
) { // No return value

    // --- Initialize Distribution Config ---
    {
        distribution_config::test_init(scenario.ctx());
    };
    
    // --- Minter Setup --- 
    scenario.next_tx(sender);
    {
        let minter_publisher = minter::test_init(scenario.ctx());
        let treasury_cap = coin::create_treasury_cap_for_testing<SAIL>(scenario.ctx());
        let (minter_obj, minter_admin_cap) = minter::create<SAIL>(
            &minter_publisher,
            option::some(treasury_cap),
            scenario.ctx()
        );
        test_utils::destroy(minter_publisher);
        transfer::public_share_object(minter_obj);
        transfer::public_transfer(minter_admin_cap, sender);
    };

    // --- Voter Setup --- 
    scenario.next_tx(sender);
    {
        let voter_publisher = voter::test_init(scenario.ctx()); 
        
        // Get config IDs 
        let global_config_obj = scenario.take_shared<config::GlobalConfig>();
        let global_config_id = object::id(&global_config_obj);
        test_scenario::return_shared(global_config_obj);

        let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();
        let distribution_config_id = object::id(&distribution_config_obj);
        test_scenario::return_shared(distribution_config_obj);

        let (voter_obj, notify_cap) = voter::create(
            &voter_publisher,
            global_config_id,
            distribution_config_id,
            scenario.ctx()
        );
        test_utils::destroy(voter_publisher);
        transfer::public_share_object(voter_obj);
        transfer::public_transfer(notify_cap, sender);
    }
}

#[test]
fun test_distribution_setup_utility() {
    let admin = @0xC1;
    let mut scenario = test_scenario::begin(admin);

    // Tx 1: Use the setup functions
    {
        // Call the factory/fee tier setup first
        setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        
        // Then call the distribution setup (which assumes clmm config exists)
        setup_distribution(&mut scenario, admin);
        // Minter & Voter objects are shared, AdminCaps are now owned by 'admin'
    };

    // Tx 2: Verify objects exist
    scenario.next_tx(admin);
    {
        // Take shared objects
        let minter_obj = scenario.take_shared<Minter<SAIL>>();
        let voter_obj = scenario.take_shared<Voter>();
        let global_config_obj = scenario.take_shared<config::GlobalConfig>();
        let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();

        // Take AdminCaps from sender 
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let notify_cap = scenario.take_from_sender<NotifyRewardCap>();
        let clmm_admin_cap = scenario.take_from_sender<config::AdminCap>(); // Also take the CLMM AdminCap

        // Basic assertions
        assert!(minter::epoch(&minter_obj) == 0, 1);
        assert!(minter::activated_at(&minter_obj) == 0, 2);
        assert!(voter::total_weight(&voter_obj) == 0, 4);

        // Return shared objects
        test_scenario::return_shared(minter_obj);
        test_scenario::return_shared(voter_obj);
        test_scenario::return_shared(global_config_obj);
        test_scenario::return_shared(distribution_config_obj);
        // Return the caps taken
        scenario.return_to_sender(minter_admin_cap);
        scenario.return_to_sender(notify_cap);
        scenario.return_to_sender(clmm_admin_cap); // Return CLMM AdminCap
    };

    scenario.end();
}

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
use clmm_pool::factory::{Self as factory, Pools};
use clmm_pool::config::{Self as config, GlobalConfig, AdminCap};
use distribution::minter::{Self, Minter, MINTER, AdminCap as MinterAdminCap};
use distribution::voter::{Self, Voter, VOTER};
use distribution::notify_reward_cap;
use sui::coin::{Self, TreasuryCap};
use std::option::{Self, Option};
use sui::object;

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

// Utility function to perform the full setup: init factory, config, add fee tier, create pool.
// Returns the created Pool and Clock.
#[test_only]
public fun setup_pool_with_sqrt_price<CoinTypeA: drop, CoinTypeB: drop>(
    scenario: &mut test_scenario::Scenario,
    sender: address,
    sqrt_price: u128,
    tick_spacing: u32,
    fee_rate: u64
): (Pool<CoinTypeA, CoinTypeB>, Clock) {

    // Tx 1: Init factory & config
    scenario.next_tx(sender);
    {
        factory::test_init(scenario.ctx());
        config::test_init(scenario.ctx());
    };

    // Tx 2: Add fee tier
    scenario.next_tx(sender);
    {
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let mut global_config = scenario.take_shared<GlobalConfig>();
        config::add_fee_tier(&mut global_config, tick_spacing, fee_rate, scenario.ctx());
        test_scenario::return_shared(global_config);
        transfer::public_transfer(admin_cap, sender); // Transfer back to sender
    };

    // Tx 3: Create pool
    scenario.next_tx(sender);
    let pool: Pool<CoinTypeA, CoinTypeB>;
    let clock: Clock;
    {
        let mut pools = test_scenario::take_shared<Pools>(scenario);
        let global_config = test_scenario::take_shared<GlobalConfig>(scenario);
        clock = clock::create_for_testing(scenario.ctx());

        // Ensure CoinTypeA > CoinTypeB lexicographically
        let type_name_a = std::type_name::get<CoinTypeA>();
        let type_name_b = std::type_name::get<CoinTypeB>();
        assert!(compare_type_names(&type_name_a, &type_name_b) == 1, 6 /* clmm_pool::factory::EInvalidCoinOrder */);

        let url = std::string::utf8(b"test_pool_url");
        let feed_id_a = @0x2; // Placeholder
        let feed_id_b = @0x3; // Placeholder
        let auto_calc = true;

        pool = factory::create_pool_<CoinTypeA, CoinTypeB>( // Use the internal version that returns the pool
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
        // Keep clock alive, return it
    };

    (pool, clock) // Return the pool and clock
}

#[test]
fun test_pool_creation_utility_example() {
    let admin = @0x1;
    let mut scenario = test_scenario::begin(admin);

    let tick_spacing = 1;
    let fee_rate = 1000;
    let sqrt_price = 2 << 64; // Target sqrt_price = 2 (Q64 format)

    // Use the setup utility function
    // Ensure USD2 > USD1 lexicographically
    let (pool, clock) = setup_pool_with_sqrt_price<USD2, USD1>(
        &mut scenario,
        admin,
        sqrt_price,
        tick_spacing,
        fee_rate
    );

    // Assertions (performed in the next transaction context)
    scenario.next_tx(admin);
    {
        assert!(pool::current_sqrt_price(&pool) == sqrt_price, 1337);
        assert!(pool::tick_spacing(&pool) == tick_spacing, 1338);
        assert!(pool::fee_rate(&pool) == fee_rate, 1339);

        // Cleanup: Transfer pool and destroy clock
        transfer::public_transfer(pool, admin);
        clock::destroy_for_testing(clock);
    };

    test_scenario::end(scenario);
}

// Sets up the Minter module for testing.
// Initializes the minter, creates TreasuryCap and Minter object.
// Shares the Minter object and transfers the AdminCap to the sender.
#[test_only]
public fun setup_distribution<SailCoinType: drop>(
    scenario: &mut test_scenario::Scenario,
    sender: address
) { 
    let minter_publisher = minter::test_init(scenario.ctx());

    // Create a test TreasuryCap
    let treasury_cap = coin::create_treasury_cap_for_testing<SailCoinType>(scenario.ctx());

    // Create Minter - Pass the publisher and test TreasuryCap
    let (minter_obj, minter_admin_cap) = minter::create<SailCoinType>(
        &minter_publisher,
        option::some(treasury_cap),
        scenario.ctx()
    );

    // Destroy the publisher obtained from test_init
    test_utils::destroy(minter_publisher);

    // Share the Minter object
    transfer::public_share_object(minter_obj);

    // Transfer the AdminCap to the sender
    transfer::public_transfer(minter_admin_cap, sender);

    // No need to return the cap, sender owns it after transfer.
}

#[test]
// Rename test to reflect it uses the setup utility
fun test_minter_setup_utility() {
    let admin = @0xC1;
    let mut scenario = test_scenario::begin(admin);

    // Tx 1: Use the setup function
    {
        setup_distribution<SAIL>(&mut scenario, admin);
        // Minter object is shared, AdminCap is now owned by 'admin'
    };

    // Tx 2: Verify objects exist
    scenario.next_tx(admin);
    {
        // Take shared Minter
        let minter_obj = scenario.take_shared<Minter<SAIL>>();
        // Take AdminCap from sender (which received it in the setup function)
        let minter_admin_cap_taken = scenario.take_from_sender<MinterAdminCap>();

        // Basic assertion: Check initial state
        assert!(minter::epoch(&minter_obj) == 0, 1);
        assert!(minter::activated_at(&minter_obj) == 0, 2);

        // Return shared Minter
        test_scenario::return_shared(minter_obj);
        // Return the cap taken
        scenario.return_to_sender(minter_admin_cap_taken);
    };

    test_scenario::end(scenario);
}

#[test_only]
module distribution::setup;

use sui::test_scenario;
use sui::test_utils;
use sui::clock::{Self, Clock};
use clmm_pool::pool::{Self, Pool};
use clmm_pool::factory::{Self, Pools};
use clmm_pool::config::{Self, GlobalConfig};
use distribution::minter::{Self, Minter};
use distribution::voter::{Self, Voter};
use distribution::notify_reward_cap::{NotifyRewardCap};
use sui::coin;
use distribution::distribution_config;
use distribution::voting_escrow::{Self, VotingEscrow};
use distribution::reward_distributor::{Self, RewardDistributor};
use distribution::reward_distributor_cap::{RewardDistributorCap};

#[test_only]
public struct USD1 has drop {}

#[test_only]
public struct USD2 has drop {}
    
#[test_only]
public struct SAIL has drop {}

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
    // we don't check lexical order here because it complicates testing

    let tick_spacing = 1;

    let url = std::string::utf8(b"test_pool_url");
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
    scenario.next_tx(sender);
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

// Sets up the Minter, Voter, VotingEscrow, and RewardDistributor modules for testing.
#[test_only]
public fun setup_distribution<SailCoinType>(
    scenario: &mut test_scenario::Scenario,
    sender: address,
    clock: &Clock
) { // No return value

    // --- Initialize Distribution Config ---
    scenario.next_tx(sender);
    {
        distribution_config::test_init(scenario.ctx());
    };

    // --- Minter Setup --- 
    scenario.next_tx(sender);
    {
        let minter_publisher = minter::test_init(scenario.ctx());
        let treasury_cap = coin::create_treasury_cap_for_testing<SailCoinType>(scenario.ctx());
        let (minter_obj, minter_admin_cap) = minter::create<SailCoinType>(
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

        // --- Set Notify Reward Cap ---
        let mut minter = scenario.take_shared<Minter<SailCoinType>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        minter.set_notify_reward_cap(&minter_admin_cap, notify_cap);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(minter_admin_cap);
    };

    // --- VotingEscrow Setup --- 
    scenario.next_tx(sender);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let voter_obj = scenario.take_shared<Voter>(); 
        let voter_id = object::id(&voter_obj);
        test_scenario::return_shared(voter_obj); 
        let ve_obj = voting_escrow::create<SailCoinType>(
            &ve_publisher,
            voter_id, 
            clock,
            scenario.ctx()
        );
        test_utils::destroy(ve_publisher);
        transfer::public_share_object(ve_obj);
    };

    // --- RewardDistributor Setup --- 
    scenario.next_tx(sender);
    {
        let rd_publisher = reward_distributor::test_init(scenario.ctx());
        let (rd_obj, rd_cap) = reward_distributor::create<SailCoinType>(
            &rd_publisher,
            clock,
            scenario.ctx()
        );
        test_utils::destroy(rd_publisher);
        transfer::public_share_object(rd_obj);
        
        // --- Set Reward Distributor Cap ---
        let mut minter = scenario.take_shared<Minter<SailCoinType>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        minter.set_reward_distributor_cap(&minter_admin_cap, rd_cap);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(minter_admin_cap);
    };
}

#[test]
fun test_distribution_setup_utility() {
    let admin = @0xC1;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Use the setup functions
    {
        // Call the factory/fee tier setup first
        setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        
        // Then call the distribution setup, passing the clock
        setup_distribution<SAIL>(&mut scenario, admin, &clock);
        // Minter, Voter, VE, RD objects are shared, AdminCaps are owned by 'admin'
    };

    // Tx 3: Setup Pool (USD1/SAIL)
    scenario.next_tx(admin);
    // Assuming USD1's type name > SAIL's type name lexicographically
    let pool_sqrt_price: u128 = 2 << 64;
    let pool_tick_spacing = 1;
    let pool_fee_rate = 1000;
    {
        setup_pool_with_sqrt_price<USD1, SAIL>( // Create USD1/SAIL pool
            &mut scenario,
            pool_sqrt_price,
            pool_tick_spacing,
        );
        // Pool<USD1, SAIL> is now shared
    };


    // Tx 4: Connect Minter caps and Verify all objects exist
    scenario.next_tx(admin);
    {
        // Take shared objects
        let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
        let voter_obj = scenario.take_shared<Voter>();
        let ve_obj = scenario.take_shared<VotingEscrow<SAIL>>();
        let rd_obj = scenario.take_shared<RewardDistributor<SAIL>>();
        let global_config_obj = scenario.take_shared<config::GlobalConfig>();
        let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();
        let pool_obj = scenario.take_shared<Pool<USD1, SAIL>>(); // Take the pool

        // Take AdminCaps from sender
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let clmm_admin_cap = scenario.take_from_sender<config::AdminCap>();

        // --- Assertions --- 
        assert!(minter::epoch(&minter_obj) == 0, 1);
        assert!(minter::activated_at(&minter_obj) == 0, 2);
        assert!(voter::total_weight(&voter_obj) == 0, 4);
        assert!(voting_escrow::total_locked(&ve_obj) == 0, 5);
        assert!(reward_distributor::balance(&rd_obj) == 0, 6);
        // Pool
        assert!(pool::current_sqrt_price(&pool_obj) == pool_sqrt_price, 7);
        assert!(pool::tick_spacing(&pool_obj) == pool_tick_spacing, 8);
        assert!(pool::fee_rate(&pool_obj) == pool_fee_rate, 9);


        // Return shared objects
        test_scenario::return_shared(minter_obj);
        test_scenario::return_shared(voter_obj);
        test_scenario::return_shared(ve_obj);
        test_scenario::return_shared(rd_obj);
        test_scenario::return_shared(global_config_obj);
        test_scenario::return_shared(distribution_config_obj);
        test_scenario::return_shared(pool_obj); // Return the pool
        // Return the caps taken
        scenario.return_to_sender(minter_admin_cap);
        scenario.return_to_sender(clmm_admin_cap);
    };

    // Destroy clock at the end of the test
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test_only]
module distribution::setup;

use sui::test_scenario;
use sui::test_utils;
use sui::clock::{Self, Clock};
use clmm_pool::pool::{Self, Pool};
use clmm_pool::factory::{Self, Pools};
use clmm_pool::config::{Self, GlobalConfig};
use clmm_pool::position::{Self, Position};
use clmm_pool::price_provider::{Self, PriceProvider};
use clmm_pool::stats::{Self, Stats};
use distribution::minter::{Self, Minter};
use distribution::voter::{Self, Voter};
use sui::coin::{Self, Coin, CoinMetadata};
use distribution::distribution_config::{Self, DistributionConfig};
use distribution::voting_escrow::{Self, VotingEscrow, Lock};
use distribution::rebase_distributor::{Self, RebaseDistributor};
use clmm_pool::tick_math;
use clmm_pool::rewarder;
use distribution::gauge::{Self, Gauge, StakedPosition};
use switchboard::aggregator::{Self, Aggregator};
use switchboard::decimal;
use price_monitor::price_monitor::{Self, PriceMonitor};
use std::type_name::{Self, TypeName};

use distribution::usd_tests::{Self, USD_TESTS};

const ONE_DEC18: u128 = 1000000000000000000;

// Define dummy types used in setup
public struct OSAIL1 has drop {}

public struct OSAIL2 has drop {}

public struct OSAIL3 has drop {}

public struct OTHER has drop, store {}

// Creates a pool with a specific sqrt price.
// Assumes factory, config are initialized and fee tier (tick_spacing=1) exists.
// Requires CoinTypeA > CoinTypeB lexicographically.
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
        stats::init_test(scenario.ctx());
        price_provider::init_test(scenario.ctx());
        rewarder::test_init(scenario.ctx());
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
public fun setup_distribution<SAIL>(
    scenario: &mut test_scenario::Scenario,
    sender: address,
    clock: &Clock
) { // No return value

    // --- Initialize Distribution Config ---
    scenario.next_tx(sender);
    {
        distribution_config::test_init(scenario.ctx());
        gauge_cap::gauge_cap::init_test(scenario.ctx());
    };

    // --- Minter Setup --- 
    scenario.next_tx(sender);
    {
        let minter_publisher = minter::test_init(scenario.ctx());
        let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let treasury_cap = coin::create_treasury_cap_for_testing<SAIL>(scenario.ctx());
        let (minter_obj, minter_admin_cap) = minter::create_test<SAIL>(
            &minter_publisher,
            option::some(treasury_cap),
            object::id(&distribution_config),
            scenario.ctx()
        );
        minter::grant_distribute_governor(
            &minter_publisher,
            sender,
            scenario.ctx()
        );
        
        transfer::public_share_object(minter_obj);
        transfer::public_transfer(minter_admin_cap, sender);
        test_scenario::return_shared(distribution_config);

        // Create and transfer DistributeGovernorCap using the correct function
        minter::grant_distribute_governor(&minter_publisher, sender, scenario.ctx());
        test_utils::destroy(minter_publisher); // Destroy publisher after use
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
        let (mut voter_obj, distribute_cap) = voter::create(
            &voter_publisher,
            global_config_id,
            distribution_config_id,
            scenario.ctx()
        );

        voter_obj.add_governor(&voter_publisher, sender, scenario.ctx());

        test_utils::destroy(voter_publisher);
        transfer::public_share_object(voter_obj);

        // --- Set Distribute Cap ---
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        minter.set_distribute_cap(&minter_admin_cap, distribute_cap);
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
        let ve_obj = voting_escrow::create<SAIL>(
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
        let rd_publisher = rebase_distributor::test_init(scenario.ctx());
        let (rebase_distributor, rd_cap) = rebase_distributor::create<SAIL>(
            &rd_publisher,
            clock,
            scenario.ctx()
        );
        test_utils::destroy(rd_publisher);
        let rebase_distributor_id = object::id(&rebase_distributor);
        transfer::public_share_object(rebase_distributor);
        
        // --- Set Reward Distributor Cap ---
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        minter.set_reward_distributor_cap(&minter_admin_cap, rebase_distributor_id, rd_cap);
        test_scenario::return_shared(minter);
        scenario.return_to_sender(minter_admin_cap);
    };
}
    
public struct SAIL has drop {}

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

    // Tx 3: Setup Pool (USD_TESTS/SAIL)
    scenario.next_tx(admin);
    // Assuming USD_TESTS's type name > SAIL's type name lexicographically
    let pool_sqrt_price: u128 = 2 << 64;
    let pool_tick_spacing = 1;
    let pool_fee_rate = 1000;
    {
        setup_pool_with_sqrt_price<USD_TESTS, SAIL>( // Create USD_TESTS/SAIL pool
            &mut scenario,
            pool_sqrt_price,
            pool_tick_spacing,
        );
        // Pool<USD_TESTS, SAIL> is now shared
    };


    // Tx 4: Connect Minter caps and Verify all objects exist
    scenario.next_tx(admin);
    {
        // Take shared objects
        let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
        let voter_obj = scenario.take_shared<Voter>();
        let ve_obj = scenario.take_shared<VotingEscrow<SAIL>>();
        let rd_obj = scenario.take_shared<RebaseDistributor<SAIL>>();
        let global_config_obj = scenario.take_shared<config::GlobalConfig>();
        let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();
        let pool_obj = scenario.take_shared<Pool<USD_TESTS, SAIL>>(); // Take the pool

        // Take AdminCaps from sender
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let clmm_admin_cap = scenario.take_from_sender<config::AdminCap>();

        // --- Assertions --- 
        assert!(minter::active_period(&minter_obj) == 0, 1);
        assert!(minter::activated_at(&minter_obj) == 0, 2);
        assert!(voting_escrow::total_locked(&ve_obj) == 0, 5);
        assert!(rebase_distributor::balance(&rd_obj) == 0, 6);
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

// Activates the minter for a specific oSAIL epoch.
// Requires the minter, voter, rd, and admin cap to be set up.
public fun activate_minter<SAIL, OSailCoinType>( // Changed to public
    scenario: &mut test_scenario::Scenario,
    initial_o_sail_supply: u64,
    clock: &mut Clock
): Coin<OSailCoinType> { // Returns the minted oSAIL

    // increment clock to make sure the activated_at field is not 0 and epoch start is not 0
    clock.increment_for_testing(7 * 24 * 60 * 60 * 1000 + 1000);
    let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
    let mut voter = scenario.take_shared<Voter>();
    let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    // Create TreasuryCap for OSAIL2 for the next epoch
    let mut o_sail_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
    let initial_supply = o_sail_cap.mint(initial_o_sail_supply, scenario.ctx());

    minter_obj.activate_test<SAIL, OSailCoinType>(
        &mut voter,
        &minter_admin_cap,
        &mut rebase_distributor,
        o_sail_cap,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(minter_obj);
    test_scenario::return_shared(voter);
    test_scenario::return_shared(rebase_distributor);
    scenario.return_to_sender(minter_admin_cap);

    initial_supply
}

// Whitelists or de-whitelists a token in the Minter for oSAIL exercising.
// Requires the minter and admin cap to be set up.
public fun whitelist_usd<SAIL, UsdCoinType>(
    scenario: &mut test_scenario::Scenario,
    list: bool, 
    clock: &Clock,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    
    minter::whitelist_usd<SAIL, UsdCoinType>(&mut minter, &minter_admin_cap, list);

    if (list) {
        let exercise_fee_distributor = minter::create_exercise_fee_distributor<SAIL, UsdCoinType>(
            &mut minter,
            &minter_admin_cap,
            clock,
            scenario.ctx()
        );
        transfer::public_share_object(exercise_fee_distributor);
    };

    test_scenario::return_shared(minter);
    scenario.return_to_sender(minter_admin_cap);
}

// Mints SAIL and creates a permanent lock in the Voting Escrow for the user.
// Assumes the transaction is run by the user who will own the lock.
public fun mint_and_create_permanent_lock<SAIL>(
    scenario: &mut test_scenario::Scenario,
    _user: address, // User who will own the lock (must be the sender of this tx block)
    amount_to_lock: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SAIL>(amount_to_lock, scenario.ctx());
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

    // create_lock consumes the coin and transfers the lock to ctx.sender()
    voting_escrow::create_lock<SAIL>(
        &mut ve,
        sail_coin,
        182, // Duration doesn't matter for permanent lock
        true, // permanent lock
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(ve);
    // Lock is automatically transferred to the user (sender of this tx block)
}

public fun mint_and_create_perpetual_lock<SAIL>(
    scenario: &mut test_scenario::Scenario,
    _user: address,
    amount_to_lock: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SAIL>(amount_to_lock, scenario.ctx());

    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

    voting_escrow::create_lock_advanced<SAIL>(
        &mut ve,
        sail_coin,
        182, // duration doesn't matter
        true, // permanent
        true, // perpetual
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(ve);
}

public fun mint_and_create_perpetual_lock_for<SAIL>(
    scenario: &mut test_scenario::Scenario,
    owner: address,
    amount_to_lock: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SAIL>(amount_to_lock, scenario.ctx());

    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

    voting_escrow::create_lock_for<SAIL>(
        &mut ve,
        owner,
        sail_coin,
        182, // duration doesn't matter
        true, // permanent
        true, // perpetual
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(ve);
}

#[test]
fun test_mint_and_create_permanent_lock() {
    let admin = @0xA1; // Use a different address
    let user = @0xA2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup Distribution
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx()); 
        setup_distribution<SAIL>(&mut scenario, admin, &clock);
        // Minter, Voter, VE, RD shared; AdminCap owned by admin
    };

    // Tx 2: Mint SAIL and Create Permanent Lock for User
    let amount_to_lock = 500_000;
    scenario.next_tx(user); // User needs to be sender to receive the Lock
    {
        mint_and_create_permanent_lock<SAIL>(&mut scenario, user, amount_to_lock, &clock);
    };

    // Tx 3: Verify Lock Creation
    scenario.next_tx(user); // User owns the Lock
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let user_lock = scenario.take_from_sender<voting_escrow::Lock>(); // Take the Lock from the user

        let (locked_balance, lock_exists) = voting_escrow::locked(&ve, object::id(&user_lock));
        
        // Assertions
        assert!(lock_exists, 1);
        assert!(locked_balance.amount() == amount_to_lock, 2); // Check locked amount
        assert!(locked_balance.is_permanent(), 3); // Check it's permanent
        assert!(voting_escrow::total_locked(&ve) == amount_to_lock, 4); // Check VE total locked

        // Cleanup
        test_scenario::return_shared(ve);
        scenario.return_to_sender(user_lock); // Return lock to user
    };

    // Final cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

// Creates a Gauge for an existing pool.
// Assumes Voter, VE, DistributionConfig are set up, and the sender has the required caps.
public fun setup_gauge_for_pool<CoinTypeA, CoinTypeB, SAIL>(
    scenario: &mut test_scenario::Scenario,
    gauge_base_emissions: u64, // Added gauge_base_emissions parameter
    clock: &Clock,
) {
    let mut minter = scenario.take_shared<Minter<SAIL>>(); // Minter is now responsible
    let mut voter = scenario.take_shared<Voter>();
    let ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let mut dist_config = scenario.take_shared<distribution_config::DistributionConfig>();
    let create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
    let admin_cap = scenario.take_from_sender<minter::AdminCap>(); // Minter uses AdminCap
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();

    // Use minter to create the gauge
    let gauge = minter.create_gauge<CoinTypeA, CoinTypeB, SAIL>(
        // &mut minter, // minter is the receiver, so it's an implicit first argument
        &mut voter,
        &mut dist_config,
        &create_cap,
        &admin_cap,
        &ve,
        &mut pool,
        gauge_base_emissions,
        clock,
        scenario.ctx()
    );

    transfer::public_share_object(gauge);

    // Return shared objects
    test_scenario::return_shared(minter);
    test_scenario::return_shared(voter);
    test_scenario::return_shared(ve);
    test_scenario::return_shared(dist_config);
    test_scenario::return_shared(pool);
    // Return capabilities to sender
    scenario.return_to_sender(create_cap);
    scenario.return_to_sender(admin_cap);
}

// Creates a new position in an existing pool and adds liquidity.
// Assumes GlobalConfig and Pool<CoinTypeA, CoinTypeB> are shared.
// Transfers the new Position object to the specified owner.
public fun create_position_with_liquidity<CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    owner: address,
    tick_lower: u32,
    tick_upper: u32,
    liquidity_delta: u128,
    clock: &Clock,
) {
    let global_config = scenario.take_shared<GlobalConfig>();
    let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
    let mut pool_obj = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>(); // Renamed to avoid conflict

    // Open the position
    let mut position = pool::open_position<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut pool_obj,
        tick_lower,
        tick_upper,
        scenario.ctx()
    );

    // Add liquidity
    let receipt: pool::AddLiquidityReceipt<CoinTypeA, CoinTypeB> = pool::add_liquidity<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut vault,
        &mut pool_obj,
        &mut position,
        liquidity_delta,
        clock
    );

    // Repay liquidity
    let (amount_a, amount_b) = pool::add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
    let coin_a = coin::mint_for_testing<CoinTypeA>(amount_a, scenario.ctx());
    let coin_b = coin::mint_for_testing<CoinTypeB>(amount_b, scenario.ctx());

    pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut pool_obj,
        coin_a.into_balance(),
        coin_b.into_balance(),
        receipt // receipt is consumed here
    );

    // Transfer position to the owner
    transfer::public_transfer(position, owner);

    // Return shared objects
    test_scenario::return_shared(global_config);
    test_scenario::return_shared(pool_obj);
    test_scenario::return_shared(vault);
}

// Adds liquidity to existing position.
// Assumes GlobalConfig and Pool<CoinTypeA, CoinTypeB> are shared, Position is owned by the sender
// Transfers the new Position object to the specified owner.
public fun add_liquidity<CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    liquidity_delta: u128,
    clock: &Clock,
) {
    let global_config = scenario.take_shared<GlobalConfig>();
    let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
    let mut pool_obj = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>(); // Renamed to avoid conflict
    let mut position = scenario.take_from_sender<Position>();

    // Add liquidity
    let receipt: pool::AddLiquidityReceipt<CoinTypeA, CoinTypeB> = pool::add_liquidity<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut vault,
        &mut pool_obj,
        &mut position,
        liquidity_delta,
        clock
    );

    // Repay liquidity
    let (amount_a, amount_b) = pool::add_liquidity_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
    let coin_a = coin::mint_for_testing<CoinTypeA>(amount_a, scenario.ctx());
    let coin_b = coin::mint_for_testing<CoinTypeB>(amount_b, scenario.ctx());

    pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut pool_obj,
        coin_a.into_balance(),
        coin_b.into_balance(),
        receipt // receipt is consumed here
    );

    // Return shared objects
    test_scenario::return_shared(global_config);
    test_scenario::return_shared(pool_obj);
    test_scenario::return_shared(vault);
    scenario.return_to_sender(position);
}

// Removes liquidity from existing position.
// Assumes GlobalConfig and Pool<CoinTypeA, CoinTypeB> are shared, Position is owned by the sender
// Destroys removed liquidity assets.
public fun remove_liquidity<CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    liquidity_delta: u128,
    clock: &Clock,
) {
    let global_config = scenario.take_shared<GlobalConfig>();
    let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
    let mut pool_obj = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>(); // Renamed to avoid conflict
    let mut position = scenario.take_from_sender<Position>();

    // Add liquidity
    let (amount_a, amount_b) = pool::remove_liquidity<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut vault,
        &mut pool_obj,
        &mut position,
        liquidity_delta,
        clock
    );

    test_utils::destroy(amount_a);
    test_utils::destroy(amount_b);

    // Return shared objects
    test_scenario::return_shared(global_config);
    test_scenario::return_shared(pool_obj);
    test_scenario::return_shared(vault);
    scenario.return_to_sender(position);
}

// Define coin types with store for testing repay_add_liquidity
#[test_only]
public struct CoinStoreA has drop, store {}
#[test_only]
public struct CoinStoreB has drop, store {}

#[test]
fun test_create_position_with_liquidity() {
    let admin = @0xAA1;
    let user = @0xBB1;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM Factory & Fee Tier
    {
        setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    };

    // Tx 2: Setup Pool (CoinStoreB/CoinStoreA)
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup_pool_with_sqrt_price<CoinStoreB, CoinStoreA>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: User calls the utility function
    let tick_lower = 0u32;
    let tick_upper = 10u32;
    let liquidity_delta = 500_000_000u128;
    scenario.next_tx(user);
    {
        create_position_with_liquidity<CoinStoreB, CoinStoreA>(
            &mut scenario,
            user, 
            tick_lower,
            tick_upper,
            liquidity_delta,
            &clock
        );
    };

    // Tx 4: Verify position and pool state
    scenario.next_tx(user); // User owns the position
    {
        let pool = scenario.take_shared<Pool<CoinStoreB, CoinStoreA>>();
        let position = scenario.take_from_sender<Position>();
        
        // Verify Position
        assert!(position.pool_id() == object::id(&pool), 1);
        assert!(position.liquidity() == liquidity_delta, 2);
        let (pos_tick_lower, pos_tick_upper) = position::tick_range(&position);
        assert!(pos_tick_lower == integer_mate::i32::from_u32(tick_lower), 3);
        assert!(pos_tick_upper == integer_mate::i32::from_u32(tick_upper), 4);

        // Verify Pool liquidity
        assert!(pool::liquidity(&pool) == liquidity_delta, 5); // Pool was empty before

        // Cleanup
        scenario.return_to_sender(position);
        test_scenario::return_shared(pool);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

    // Error constants
const EExceededLimit: u64 = 765177259852085600;
const EInsufficientOutput: u64 = 7357981668783265000;
const EAmountMismatch: u64 = 698650768773923000;

public fun swap<CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    mut coin_a: sui::coin::Coin<CoinTypeA>,
    mut coin_b: sui::coin::Coin<CoinTypeB>,
    a2b: bool,
    by_amount_in: bool,
    amount: u64,
    amount_limit: u64,
    sqrt_price_limit: u128,
    clock: &sui::clock::Clock,
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
    let global_config = scenario.take_shared<GlobalConfig>();
    let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let price_provider = scenario.take_shared<PriceProvider>();
    let mut stats = scenario.take_shared<Stats>();

    let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut vault,
        &mut pool,
        a2b,
        by_amount_in,
        amount,
        sqrt_price_limit,
        &mut stats,
        &price_provider,
        clock
    );
    let pay_amout = receipt.swap_pay_amount();
    let coin_out_value = if (a2b) {
        coin_b_out.value()
    } else {
        coin_a_out.value()
    };
    if (by_amount_in) {
        assert!(pay_amout == amount, EAmountMismatch);
        assert!(coin_out_value >= amount_limit, EInsufficientOutput);
    } else {
        assert!(coin_out_value == amount, EAmountMismatch);
        assert!(pay_amout <= amount_limit, EExceededLimit);
    };
    let (repay_amount_a, repay_amount_b) = if (a2b) {
        (coin_a.split(pay_amout, scenario.ctx()).into_balance(), sui::balance::zero<CoinTypeB>())
    } else {
        (sui::balance::zero<CoinTypeA>(), coin_b.split(pay_amout, scenario.ctx()).into_balance())
    };
    clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
        &global_config,
        &mut pool,
        repay_amount_a,
        repay_amount_b,
        receipt
    );
    coin_a.join(sui::coin::from_balance<CoinTypeA>(coin_a_out, scenario.ctx()));
    coin_b.join(sui::coin::from_balance<CoinTypeB>(coin_b_out, scenario.ctx()));

    test_scenario::return_shared(global_config);
    test_scenario::return_shared(pool);
    test_scenario::return_shared(price_provider);
    test_scenario::return_shared(stats);
    test_scenario::return_shared(vault);
    (coin_a, coin_b)
}

#[test]
fun test_swap_utility() {
    let admin = @0xCC1;
    let user = @0xDD1;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup CLMM, Pool, Stats, PriceProvider
    {
        setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        stats::init_test(scenario.ctx());       // Init Stats
        price_provider::init_test(scenario.ctx());  // Init PriceProvider
    };

    scenario.next_tx(admin);
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    {
        setup_pool_with_sqrt_price<CoinStoreB, CoinStoreA>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 2: Create Position with Liquidity for the user
    let tick_lower = clmm_pool::tick_math::min_tick().as_u32();
    let tick_upper = clmm_pool::tick_math::max_tick().as_u32();
    let liquidity_delta = 1_000_000_000u128;
    scenario.next_tx(admin); // Admin creates the position for the user
    {
        create_position_with_liquidity<CoinStoreB, CoinStoreA>(
            &mut scenario,
            user, 
            tick_lower,
            tick_upper,
            liquidity_delta,
            &clock
        );
    };
    // Tx 3: User executes swap using the utility
    let swap_amount = 5000; 
    let expected_output_min = 1; // Expect at least 1 unit out
    scenario.next_tx(user);
    {
        let coin_in = coin::mint_for_testing<CoinStoreB>(swap_amount, scenario.ctx()); // User starts with 0 output coin
        let coin_out = coin::zero<CoinStoreA>(scenario.ctx());

        let (remaining_coin_in, received_coin_out) = swap<CoinStoreB, CoinStoreA>(
            &mut scenario,
            coin_in,
            coin_out,
            true,  // a2b = true (CoinStoreA -> CoinStoreB)
            true,  // by_amount_in = true
            swap_amount,
            expected_output_min,
            tick_math::min_sqrt_price(), // price limit - min price for A->B
            &clock,
        );

        // --- Verification --- 
        // User should have received some CoinB
        assert!(received_coin_out.value() >= expected_output_min, 1);
        // User should have less CoinA than they started with
        assert!(remaining_coin_in.value() < swap_amount, 2);

        // Cleanup remaining coins
        remaining_coin_in.burn_for_testing();
        received_coin_out.burn_for_testing();
    };

    // Final Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

// Mints SAIL and creates a non-permanent lock in the Voting Escrow for the sender.
public fun mint_and_create_lock<SAIL>(
    scenario: &mut test_scenario::Scenario,
    amount_to_lock: u64,
    lock_duration_days: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SAIL>(amount_to_lock, scenario.ctx());

    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

    // create_lock consumes the coin and transfers the lock to ctx.sender()
    voting_escrow::create_lock<SAIL>(
        &mut ve,
        sail_coin,
        lock_duration_days,
        false, // permanent lock = false
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(ve);
    // Lock is automatically transferred to the user (sender of this tx block)
}

public fun withdraw_lock<SAIL>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
) {
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let lock = scenario.take_from_sender<Lock>();

    voting_escrow::withdraw<SAIL>(
        &mut ve,
        lock,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(ve);
}

public fun deposit_position<CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
): ID {
 // 2. Stake the Position
    // Take shared objects needed for deposit
    let global_config = scenario.take_shared<GlobalConfig>();
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();
    let dist_config = scenario.take_shared<DistributionConfig>();
    // Take the position back from the user who received it in the previous step
    let position = scenario.take_from_sender<Position>();
    let position_id = object::id(&position);

    let staked_position = gauge::deposit_position<CoinTypeA, CoinTypeB>(
        &global_config,
        &dist_config,
        &mut gauge,
        &mut pool,
        position, // Consumes position object
        clock,
        scenario.ctx()
    );
    transfer::public_transfer(staked_position, scenario.ctx().sender());

    // Return shared objects
    test_scenario::return_shared(global_config);
    test_scenario::return_shared(dist_config);
    test_scenario::return_shared(pool);
    test_scenario::return_shared(gauge);
    // Position object is now held within the gauge
    position_id
}

// also claim last reward coin rewards
public fun withdraw_position<CoinTypeA, CoinTypeB, LastRewardCoin>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
) {
    // 2. Stake the Position
    // Take shared objects needed for deposit
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();
    let staked_position = scenario.take_from_sender<StakedPosition>();

    let position = gauge::withdraw_position<CoinTypeA, CoinTypeB>(
        &mut gauge,
        &mut pool,
        staked_position, // Consumes position object
        clock,
        scenario.ctx()
    );
    transfer::public_transfer(position, scenario.ctx().sender());

    // Return shared objects
    test_scenario::return_shared(pool);
    test_scenario::return_shared(gauge);
}

public fun get_staked_position_reward<CoinTypeA, CoinTypeB, SAIL, RewardCoinType>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
) {
    {
        let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
        let position = scenario.take_from_sender<StakedPosition>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // USD_TESTS is not a valid reward token
        let reward = minter.get_position_reward<CoinTypeA, CoinTypeB, SAIL, RewardCoinType>(
            &voter,
            &distribution_config,
            &mut gauge,
            &mut pool,
            &position,
            clock,
            scenario.ctx()
        );

        sui::transfer::public_transfer(reward, scenario.ctx().sender());

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(gauge);
        test_scenario::return_shared(pool);
        scenario.return_to_sender(position);
    };
}

// Updates the minter period, sets the next period token to OSailCoinTypeNext
public fun update_minter_period<SAIL, OSailCoinType>(
    scenario: &mut test_scenario::Scenario,
    initial_o_sail_supply: u64,
    clock: &Clock,
): Coin<OSailCoinType> {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rebase_distributor = scenario.take_shared<RebaseDistributor<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Correct cap for update_period

        // Create TreasuryCap for OSAIL2 for the next epoch
        let mut o_sail_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
        let initial_supply = o_sail_cap.mint(initial_o_sail_supply, scenario.ctx());

        minter::update_period_test<SAIL, OSailCoinType>(
            &mut minter, // minter is the receiver
            &mut voter,
            &distribution_config,
            &distribute_governor_cap, // Pass the correct DistributeGovernorCap
            &voting_escrow,
            &mut rebase_distributor,
            o_sail_cap, 
            clock,
            scenario.ctx()
        );

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(rebase_distributor);
        scenario.return_to_sender(distribute_governor_cap);    

        initial_supply
}

public fun distribute_gauge_epoch_1<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
    scenario: &mut test_scenario::Scenario,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    aggregator: &mut Aggregator, 
    clock: &Clock,
): u64 {
    // initial epoch is distributed without any historical data
    let prev_epoch_pool_emissions: u64 = 0;
    let prev_epoch_pool_fees_usd: u64 = 0;
    let epoch_pool_emissions_usd: u64 = 0;
    let epoch_pool_fees_usd: u64 = 0;
    let epoch_pool_volume_usd: u64 = 0;
    let epoch_pool_predicted_volume_usd: u64 = 0;

    distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
        scenario,
        prev_epoch_pool_emissions,
        prev_epoch_pool_fees_usd,
        epoch_pool_emissions_usd,
        epoch_pool_fees_usd,
        epoch_pool_volume_usd,
        epoch_pool_predicted_volume_usd,
        usd_metadata,
        aggregator,
        clock
    )
}

public fun distribute_gauge_epoch_2<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
    scenario: &mut test_scenario::Scenario,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    aggregator: &mut Aggregator,
    clock: &Clock,
): u64 {
    // epoch 2 is distributed with historical data from epoch 1
    // this data results into stable emissions, same as epoch 1 emissions
    let prev_epoch_pool_emissions: u64 = 0;
    let prev_epoch_pool_fees_usd: u64 = 0;
    let epoch_pool_emissions_usd: u64 = 1_000_000_000;
    let epoch_pool_fees_usd: u64 = 1_000_000_000;
    let epoch_pool_volume_usd: u64 = 1_000_000_000;
    let epoch_pool_predicted_volume_usd: u64 = 1_000_000_000;

    distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
        scenario,
        prev_epoch_pool_emissions,
        prev_epoch_pool_fees_usd,
        epoch_pool_emissions_usd,
        epoch_pool_fees_usd,
        epoch_pool_volume_usd,
        epoch_pool_predicted_volume_usd,
        usd_metadata,
        aggregator,
        clock
    )
}

public fun distribute_gauge_epoch_3<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
        scenario: &mut test_scenario::Scenario,
        usd_metadata: &CoinMetadata<USD_TESTS>,
        aggregator: &mut Aggregator,
    clock: &Clock,
): u64 {
    // this data results into stable emissions, same as epoch 2 emissions
    let prev_epoch_pool_emissions: u64 = 1_000_000_000;
    let prev_epoch_pool_fees_usd: u64 = 1_000_000_000;
    let epoch_pool_emissions_usd: u64 = 1_000_000_000;
    let epoch_pool_fees_usd: u64 = 1_000_000_000;
    let epoch_pool_volume_usd: u64 = 1_000_000_000;
    let epoch_pool_predicted_volume_usd: u64 = 1_000_000_000;

    distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
        scenario,
        prev_epoch_pool_emissions,
        prev_epoch_pool_fees_usd,
        epoch_pool_emissions_usd,
        epoch_pool_fees_usd,
        epoch_pool_volume_usd,
        epoch_pool_predicted_volume_usd,
        usd_metadata,
        aggregator,
        clock
    )
}

    // CoinTypeA and CoinTypeB - to check that such a pool has already been created
    // in other cases you can pass any types, so that the USD_TESTS/SAIL pool is created
    #[test_only]
    public fun setup_price_monitor_and_aggregator<CoinTypeA, CoinTypeB, USD: drop, SAIL: drop>(
        scenario: &mut test_scenario::Scenario,
        sender: address,
        clock: &Clock,
    ): Aggregator {

        // create pool for USD_TESTS/SAIL
        if (type_name::get<CoinTypeA>() != type_name::get<USD>() || 
            type_name::get<CoinTypeB>() != type_name::get<SAIL>()) {

            // create pool for USD_TESTS/SAIL
            scenario.next_tx(sender);
            {
                let global_config = scenario.take_shared<GlobalConfig>();
                let mut pools = test_scenario::take_shared<Pools>(scenario);
                
                let pool_sqrt_price: u128 = 1 << 64; // Price = 1
                let sail_stablecoin_pool = create_pool_with_sqrt_price<USD, SAIL>(
                    &mut pools,
                    &global_config,
                    clock,
                    pool_sqrt_price,
                    scenario.ctx()
                );

                test_scenario::return_shared(global_config);
                test_scenario::return_shared(pools);
                transfer::public_share_object(sail_stablecoin_pool);
            };
        };

        // --- Initialize Price Monitor --- and aggregator
        scenario.next_tx(sender);
        {
            price_monitor::test_init(scenario.ctx());
        };

        let aggregator = setup_aggregator(scenario, one_dec18(), clock);

        // --- Price Monitor Setup --- 
        scenario.next_tx(sender);
        {
            let mut price_monitor = scenario.take_shared<price_monitor::PriceMonitor>();
            let mut distribution_config = scenario.take_shared<DistributionConfig>();
            let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();
            
            let pool_id = object::id(&sail_stablecoin_pool);

            price_monitor.add_aggregator(
                aggregator.id(),
                vector[pool_id],
                scenario.ctx()
            );

            distribution_config.set_o_sail_price_aggregator(&aggregator);
            distribution_config.set_sail_price_aggregator(&aggregator);

            test_scenario::return_shared(price_monitor);
            test_scenario::return_shared(distribution_config);
            transfer::public_share_object(sail_stablecoin_pool);
        };

        aggregator
    }

    /// You can create new aggregator just prior to the call that requires it.
    /// Then just destroy it after the call.
    /// Aggregators are not shared objects due to missing store capability.
    public fun setup_aggregator(
        scenario: &mut test_scenario::Scenario,
        price: u128, // decimals 18
        clock: &Clock,
    ): Aggregator {
        let owner = scenario.ctx().sender();

        let mut aggregator = aggregator::new_aggregator(
            aggregator::example_queue_id(),
            std::string::utf8(b"test_aggregator"),
            owner,
            vector::empty(),
            1,
            1000000000000000,
            100000000000,
            5,
            1000,
            scenario.ctx(),
        );

        // 1 * 10^18
        let result = decimal::new(price, false);
        let result_timestamp_ms = clock.timestamp_ms();
        let min_result = result;
        let max_result = result;
        let stdev = decimal::new(0, false);
        let range = decimal::new(0, false);
        let mean = result;

        aggregator::set_current_value(
            &mut aggregator,
            result,
            result_timestamp_ms,
            result_timestamp_ms,
            result_timestamp_ms,
            min_result,
            max_result,
            stdev,
            range,
            mean
        );

        // Return aggregator to the calling function
        aggregator
    }

    public fun aggregator_set_current_value(
        aggregator: &mut Aggregator,
        price: u128, // decimals 18
        result_timestamp_ms: u64,
    ) {

        // 1 * 10^18
        let result = decimal::new(price, false);
        let min_result = result;
        let max_result = result;
        let stdev = decimal::new(0, false);
        let range = decimal::new(0, false);
        let mean = result;

        aggregator.set_current_value(
            result,
            result_timestamp_ms,
            result_timestamp_ms,
            result_timestamp_ms,
            min_result,
            max_result,
            stdev,
            range,
            mean
        );

        // Return aggregator to the calling function
        // aggregator
    }

// Utility to call minter.distribute_gauge
// Assumes Voter, Gauge, Pool, DistributionConfig are shared.
public fun distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SAIL, EpochOSail, USD_TESTS>(
    scenario: &mut test_scenario::Scenario,
    prev_epoch_pool_emissions: u64,
    prev_epoch_pool_fees_usd: u64,
    epoch_pool_emissions_usd: u64,
    epoch_pool_fees_usd: u64,
    epoch_pool_volume_usd: u64,
    epoch_pool_predicted_volume_usd: u64,
    usd_metadata: &CoinMetadata<USD_TESTS>,
    aggregator: &mut Aggregator,
    clock: &Clock,
): u64 {
    let mut minter = scenario.take_shared<Minter<SAIL>>(); // Minter is now responsible
    let mut voter = scenario.take_shared<Voter>();
    let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let distribution_config = scenario.take_shared<DistributionConfig>();
    let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Minter uses DistributeGovernorCap
    let mut price_monitor = scenario.take_shared<PriceMonitor>();

    aggregator_set_current_value(aggregator,  one_dec18(), clock.timestamp_ms());

    let mut distributed_amount: u64 = 0;
    if (type_name::get<CoinTypeA>() != type_name::get<USD_TESTS>() || 
            type_name::get<CoinTypeB>() != type_name::get<SAIL>()) {

        let sail_stablecoin_pool = scenario.take_shared<Pool<USD_TESTS, SAIL>>();

        distributed_amount = minter.distribute_gauge<CoinTypeA, CoinTypeB, USD_TESTS, SAIL, SAIL, EpochOSail>(
            &mut voter,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut pool,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            &mut price_monitor,
            &sail_stablecoin_pool,
            aggregator,
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(sail_stablecoin_pool);
    } else {
        distributed_amount = minter.distribute_gauge_for_sail_pool<CoinTypeA, CoinTypeB, SAIL, EpochOSail>(
            &mut voter,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut pool,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            &mut price_monitor,
            aggregator,
            clock,
            scenario.ctx()
        );
    };

    // Return shared objects
    test_scenario::return_shared(minter);
    test_scenario::return_shared(voter);
    test_scenario::return_shared(gauge);
    test_scenario::return_shared(pool);
    test_scenario::return_shared(distribution_config);
    scenario.return_to_sender(distribute_governor_cap);
    test_scenario::return_shared(price_monitor);

    distributed_amount
}

/// Sets up the entire environment: CLMM, Distribution, Pool, Gauge,
/// activates Minter, and creates a lock for the user.
/// Assumes standard tick spacing and price for the pool.
/// The admin address receives MinterAdminCap, GovernorCap, CreateCap.
/// The user address receives the specified oSAIL and the created Lock.
public fun full_setup_with_lock<CoinTypeA: drop, CoinTypeB: drop, SAIL: drop, OSailCoinType, USD: drop>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
    user: address,
    clock: &mut Clock, // Make clock mutable as activate_minter needs it
    lock_amount: u64,
    lock_duration_days: u64,
    gauge_base_emissions: u64,
    initial_o_sail_supply: u64
): Aggregator {
    // Tx 1: Setup CLMM Factory & Fee Tier (using tick_spacing=1)
    {
        setup_clmm_factory_with_fee_tier(scenario, admin, 1, 1000);
    };

    // Tx 2: Setup Distribution (admin gets caps)
    {
        // Needs CLMM config initialized
        setup_distribution<SAIL>(scenario, admin, clock);
    };

    // Tx 3: Setup Pool (CoinTypeA/CoinTypeB, price=1)
    let pool_sqrt_price: u128 = 1 << 64;
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        setup_pool_with_sqrt_price<CoinTypeA, CoinTypeB>(
            scenario,
            pool_sqrt_price,
            pool_tick_spacing
        );
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAILCoinType)
    scenario.next_tx(admin);
    {
        let o_sail_coin = activate_minter<SAIL, OSailCoinType>(scenario, initial_o_sail_supply, clock);
        o_sail_coin.burn_for_testing();
    };

    // Tx 5: Create Gauge for the CoinTypeA/CoinTypeB pool
    scenario.next_tx(admin); // Admin needs caps to create gauge
    {
        setup_gauge_for_pool<CoinTypeA, CoinTypeB, SAIL>(
            scenario,
            gauge_base_emissions,
            clock // Pass immutable clock ref here
        );
    };

    // Tx 6: Create Lock for the user
    scenario.next_tx(user); // User needs to be sender to receive the lock
    {
        mint_and_create_lock<SAIL>(
            scenario,
            lock_amount,
            lock_duration_days,
            clock
        );
        // Lock object is automatically transferred to user
    };

    setup_price_monitor_and_aggregator<CoinTypeA, CoinTypeB, USD, SAIL>(scenario, admin, clock)
}

public fun vote<SAIL>(
    scenario: &mut test_scenario::Scenario,
    pools: vector<ID>,
    weights: vector<u64>,
    volumes: vector<u64>,
    clock: &mut Clock,
) {
    let mut voter = scenario.take_shared<Voter>();
    let distribution_config = scenario.take_shared<DistributionConfig>();
    let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
    let lock = scenario.take_from_sender<Lock>();

    voter.vote(
        &mut ve,
        &distribution_config,
        &lock,
        pools,
        weights,
        volumes, // Added volumes
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(voter);
    test_scenario::return_shared(ve);
    test_scenario::return_shared(distribution_config);
    scenario.return_to_sender(lock);
}

public fun vote_for_pool<CoinTypeA, CoinTypeB, SAIL>(
    scenario: &mut test_scenario::Scenario,
    clock: &mut Clock,
) {
    let pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let pool_id = object::id(&pool);
    vote<SAIL>(
        scenario,
        vector[pool_id],
        vector[10000], // 100% weight
        vector[1_000_000], // Default volume: $1 USD with 6 decimals
        clock,
    );
    test_scenario::return_shared(pool);
}

public fun one_dec18(): u128 {
    ONE_DEC18
}

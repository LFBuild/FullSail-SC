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
use sui::coin::{Self, Coin};
use distribution::distribution_config::{Self, DistributionConfig};
use distribution::voting_escrow::{Self, VotingEscrow, Lock};
use distribution::reward_distributor::{Self, RewardDistributor};
use clmm_pool::tick_math;
use clmm_pool::rewarder;
use distribution::gauge::{Self, Gauge};

public struct USD1 has drop {}

public struct USD2 has drop {}
    
public struct SAIL has drop {}

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
public fun setup_distribution<SailCoinType>(
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
        let (mut voter_obj, notify_cap) = voter::create(
            &voter_publisher,
            global_config_id,
            distribution_config_id,
            scenario.ctx()
        );

        voter_obj.add_governor(&voter_publisher, sender, scenario.ctx());

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

// Activates the minter for a specific oSAIL epoch.
// Requires the minter, voter, rd, and admin cap to be set up.
public fun activate_minter<SailCoinType>( // Changed to public
    scenario: &mut test_scenario::Scenario,
    clock: &mut Clock
) { // Returns the minted oSAIL

    // increment clock to make sure the activated_at field is not and epoch start is not 0
    clock.increment_for_testing(7 * 24 * 60 * 60 * 1000 + 1000);
    let mut minter_obj = scenario.take_shared<Minter<SailCoinType>>();
    let mut rd = scenario.take_shared<RewardDistributor<SailCoinType>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();

    minter_obj.activate<SailCoinType>(
        &minter_admin_cap,
        &mut rd,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(minter_obj);
    test_scenario::return_shared(rd);
    scenario.return_to_sender(minter_admin_cap);
}

// Whitelists or de-whitelists a pool in the Minter for oSAIL exercising.
// Requires the minter and admin cap to be set up.
public fun whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>( // Changed to public
    scenario: &mut test_scenario::Scenario,
    list: bool // Added flag to whitelist/de-whitelist
) {
    let pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut minter = scenario.take_shared<Minter<SailCoinType>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    
    minter::whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>(
        &mut minter, 
        &minter_admin_cap, 
        &pool, 
        list
    );

    test_scenario::return_shared(minter);
    scenario.return_to_sender(minter_admin_cap);
    test_scenario::return_shared(pool);
}

// Mints SAIL and creates a permanent lock in the Voting Escrow for the user.
// Assumes the transaction is run by the user who will own the lock.
public fun mint_and_create_permanent_lock<SailCoinType>(
    scenario: &mut test_scenario::Scenario,
    _user: address, // User who will own the lock (must be the sender of this tx block)
    amount_to_lock: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SailCoinType>(amount_to_lock, scenario.ctx());

    let mut ve = scenario.take_shared<VotingEscrow<SailCoinType>>();

    // create_lock consumes the coin and transfers the lock to ctx.sender()
    voting_escrow::create_lock<SailCoinType>(
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
public fun setup_gauge_for_pool<CoinTypeA, CoinTypeB, SailCoinType>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
) {
    let mut voter = scenario.take_shared<Voter>();
    let ve = scenario.take_shared<VotingEscrow<SailCoinType>>();
    let mut dist_config = scenario.take_shared<distribution_config::DistributionConfig>();
    let create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
    let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();

    // Use the integrate::voter entry function to create the gauge
    let gauge = voter.create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        &mut dist_config,
        &create_cap,
        &governor_cap,
        &ve, // VotingEscrow is borrowed immutably here
        &mut pool,
        clock,
        scenario.ctx()
    );

    transfer::public_share_object(gauge);

    // Return shared objects
    test_scenario::return_shared(voter);
    test_scenario::return_shared(ve);
    test_scenario::return_shared(dist_config);
    test_scenario::return_shared(pool);
    // Return capabilities to sender
    scenario.return_to_sender(create_cap);
    scenario.return_to_sender(governor_cap);
}

// Creates a new position in an existing pool and adds liquidity.
// Assumes GlobalConfig and Pool<CoinTypeA, CoinTypeB> are shared.
// Transfers the new Position object to the specified owner.
public fun create_position_with_liquidity<CoinTypeA: store, CoinTypeB: store>(
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
public fun add_liquidity<CoinTypeA: store, CoinTypeB: store>(
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
public fun remove_liquidity<CoinTypeA: store, CoinTypeB: store>(
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
public fun mint_and_create_lock<SailCoinType>(
    scenario: &mut test_scenario::Scenario,
    amount_to_lock: u64,
    lock_duration_days: u64,
    clock: &Clock,
) {
    let sail_coin = coin::mint_for_testing<SailCoinType>(amount_to_lock, scenario.ctx());

    let mut ve = scenario.take_shared<VotingEscrow<SailCoinType>>();

    // create_lock consumes the coin and transfers the lock to ctx.sender()
    voting_escrow::create_lock<SailCoinType>(
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

    gauge::deposit_position<CoinTypeA, CoinTypeB>(
        &global_config,
        &dist_config,
        &mut gauge,
        &mut pool,
        position, // Consumes position object
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(global_config);
    test_scenario::return_shared(dist_config);
    test_scenario::return_shared(pool);
    test_scenario::return_shared(gauge);
    // Position object is now held within the gauge
    position_id
}

public fun withdraw_position<CoinTypeA, CoinTypeB, LastRewardCoin>(
    scenario: &mut test_scenario::Scenario,
    position_id: ID,
    clock: &Clock,
) {
    // 2. Stake the Position
    // Take shared objects needed for deposit
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();

    gauge::withdraw_position<CoinTypeA, CoinTypeB, LastRewardCoin>(
        &mut gauge,
        &mut pool,
        position_id, // Consumes position object
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(pool);
    test_scenario::return_shared(gauge);
}

// Updates the minter period, sets the next period token to OSailCoinTypeNext
public fun update_minter_period<SailCoinType, OSailCoinType>(
    scenario: &mut test_scenario::Scenario,
    initial_o_sail_supply: u64,
    clock: &Clock,
): Coin<OSailCoinType> {
        let mut minter = scenario.take_shared<Minter<SailCoinType>>();
        let mut voter = scenario.take_shared<Voter>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SailCoinType>>();
        let mut reward_distributor = scenario.take_shared<RewardDistributor<SailCoinType>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();

        // Create TreasuryCap for OSAIL2 for the next epoch
        let mut o_sail_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
        let initial_supply = o_sail_cap.mint(initial_o_sail_supply, scenario.ctx());

        minter::update_period<SailCoinType, OSailCoinType>(
            &minter_admin_cap,
            &mut minter,
            &mut voter,
            &voting_escrow,
            &mut reward_distributor,
            o_sail_cap, 
            clock,
            scenario.ctx()
        );

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(reward_distributor);
        scenario.return_to_sender(minter_admin_cap);    

        initial_supply
}

// Utility to call voter.distribute_gauge
// Assumes Voter, Gauge, Pool, DistributionConfig are shared.
public fun distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType, PrevEpochOSail, EpochOSail>(
    scenario: &mut test_scenario::Scenario,
    clock: &Clock,
) {
    let mut voter = scenario.take_shared<Voter>();
    let mut gauge = scenario.take_shared<Gauge<CoinTypeA, CoinTypeB>>();
    let mut minter = scenario.take_shared<Minter<SailCoinType>>();
    let mut pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let distribution_config = scenario.take_shared<DistributionConfig>();

    minter.distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType, PrevEpochOSail, EpochOSail>(
        &mut voter,
        &distribution_config,
        &mut gauge,
        &mut pool,
        clock,
        scenario.ctx()
    );

    // Return shared objects
    test_scenario::return_shared(voter);
    test_scenario::return_shared(gauge);
    test_scenario::return_shared(pool);
    test_scenario::return_shared(minter);
    test_scenario::return_shared(distribution_config);
}

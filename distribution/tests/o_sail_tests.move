#[test_only]
module distribution::o_sail_tests;

use distribution::setup;
use distribution::minter::{Self, Minter};
use distribution::voter::{Self, Voter};
use distribution::voting_escrow::{Self, VotingEscrow};
use distribution::reward_distributor::{Self, RewardDistributor};
use distribution::notify_reward_cap::{Self, NotifyRewardCap};
use distribution::distribution_config::{Self, DistributionConfig};

use clmm_pool::pool::{Self, Pool};
use clmm_pool::config::{Self, GlobalConfig};

use sui::test_scenario;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::object;

public struct SAIL has drop {}

// Define oSAIL type for testing epoch 1
public struct OSAIL1 has drop {}

public struct USD1 has drop {}

fun activate_minter<OSailCoinType>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
    initial_o_sail_supply: u64,
    clock: &Clock
): Coin<OSailCoinType> {
    let mut minter_obj = scenario.take_shared<Minter<SAIL>>();
    let mut voter = scenario.take_shared<Voter>();
    let mut rd = scenario.take_shared<RewardDistributor<SAIL>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    // Create TreasuryCap for OSAIL1
    let mut o_sail1_cap = coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
    let initial_supply = o_sail1_cap.mint(initial_o_sail_supply, scenario.ctx());

    minter_obj.activate<SAIL, OSailCoinType>(
        &mut voter,
        &minter_admin_cap,
        &mut rd,
        o_sail1_cap,
        clock,
        scenario.ctx()
    );

    test_scenario::return_shared(minter_obj);
    test_scenario::return_shared(voter);
    test_scenario::return_shared(rd);
    scenario.return_to_sender(minter_admin_cap);

    initial_supply
}

fun whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>(
    scenario: &mut test_scenario::Scenario,
    admin: address,
) {
    let pool = scenario.take_shared<Pool<CoinTypeA, CoinTypeB>>();
    let mut minter = scenario.take_shared<Minter<SailCoinType>>();
    let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
    minter.whitelist_pool(&minter_admin_cap, &pool, true);

    test_scenario::return_shared(minter);
    scenario.return_to_sender(minter_admin_cap);
    test_scenario::return_shared(pool);
}

#[test]
fun test_exercise_o_sail() {
    let admin = @0xD1; // Use a different address
    let user = @0xD2;
    let mut scenario = test_scenario::begin(admin);

    // Create Clock before setup
    let clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Setup Pool (USD1/SAIL)
    let pool_sqrt_price: u128 = 1 << 64; // Price = 1
    let pool_tick_spacing = 1;
    scenario.next_tx(admin);
    {
        // Assuming USD1 > SAIL lexicographically
        setup::setup_pool_with_sqrt_price<USD1, SAIL>(
            &mut scenario, 
            pool_sqrt_price, 
            pool_tick_spacing
        );
    };

    // Tx 3: Whitelist pool
    scenario.next_tx(admin);
    {
        whitelist_pool<SAIL, USD1, SAIL>(&mut scenario, admin);
    };

    // Tx 4: Activate Minter for Epoch 1 (OSAIL1)
    scenario.next_tx(admin);
    {
        let o_sail1_initial_supply = activate_minter<OSAIL1>(&mut scenario, admin, 1_000_000, &clock);
        transfer::public_transfer(o_sail1_initial_supply, user);
    };

    // Tx 5: Exercise OSAIL1
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let mut pool = scenario.take_shared<Pool<USD1, SAIL>>();
        let global_config = scenario.take_shared<GlobalConfig>();
        let distribution_config = scenario.take_shared<DistributionConfig>(); // Needed? minter::exercise doesn't list it
        let mut o_sail1_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        // Whitelist the pool for exercising

        // Mint OSAIL1 for the user
        let o_sail_to_exercise = o_sail1_coin.split(100_000, scenario.ctx());

        // Mint USD1 fee for the user
        let usd_fee = coin::mint_for_testing<USD1>(50_000, scenario.ctx()); // Amount should cover ~50% of SAIL value at price 1
        let usd_limit = 50_000;

        // Exercise o_sail_ba because Pool is <USD1, SAIL>
        let (usd_left, sail_received) = minter::exercise_o_sail_ab<SAIL, USD1, OSAIL1>(
            &mut minter,
            &mut voter,
            &global_config,
            &mut pool,
            o_sail_to_exercise,
            usd_fee,
            usd_limit,
            &clock,
            scenario.ctx()
        );

        // --- Assertions --- 
        assert!(sail_received.value() == 100_000, 1); // Should receive full SAIL amount
        // Check USD left - depends on exact price and discount. 
        // For price=1, 50% discount -> should pay 50k USD. If fee was 50k, should have 0 left.
        assert!(usd_left.value() == 0, 2); 

        // Cleanup
        coin::destroy_zero(usd_left);
        transfer::public_transfer(sail_received, user);

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(o_sail1_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

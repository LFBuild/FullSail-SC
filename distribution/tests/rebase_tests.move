#[test_only]
module distribution::rebase_tests;

use distribution::minter;
use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self, Scenario, ctx};
use clmm_pool::tick_math;
use sui::test_utils;

use distribution::rebase_distributor::{RebaseDistributor};
use distribution::minter::{Minter};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use distribution::setup;
use switchboard::aggregator::{Aggregator};

use distribution::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

public struct AUSD has drop, store {}
public struct SAIL has drop, store {}
public struct OSAIL1 has drop, store {}
public struct OSAIL2 has drop, store {}
public struct OSAIL3 has drop, store {}
public struct OSAIL4 has drop, store {}
public struct BUSD has drop, store {}

#[test]
fun test_calculate_rebase_growth() {
    let emissions = 1_000_000;

    // 1. Zero total supply
    let rebase1 = minter::calculate_rebase_growth(emissions, 0, 0);
    assert!(rebase1 == 0, 0);

    // 2. Zero emissions
    let rebase2 = minter::calculate_rebase_growth(0, 1_000_000, 500_000);
    assert!(rebase2 == 0, 1);

    // 3. All tokens locked
    let rebase3 = minter::calculate_rebase_growth(emissions, 1_000_000, 1_000_000);
    assert!(rebase3 == 0, 2);

    // 4. No tokens locked
    let rebase4 = minter::calculate_rebase_growth(emissions, 1_000_000, 0);
    assert!(rebase4 == emissions / 2, 3); // 1_000_000 / 2 = 500_000

    // 5. Half tokens locked
    let rebase5 = minter::calculate_rebase_growth(emissions, 1_000_000, 500_000);
    assert!(rebase5 == emissions / 8, 4); // 1_000_000 * (0.5)^2 / 2 = 125_000

    // 6. 25% tokens locked
    let rebase6 = minter::calculate_rebase_growth(emissions, 1_000_000, 250_000);
    // expected = 1_000_000 * (750_000 / 1_000_000)^2 / 2
    // expected = 1_000_000 * (0.75)^2 / 2
    // expected = 1_000_000 * 0.5625 / 2 = 281_250
    assert!(rebase6 == 281250, 5);

    // 7. 75% tokens locked
    let rebase7 = minter::calculate_rebase_growth(emissions, 1_000_000, 750_000);
    // expected = 1_000_000 * (250_000 / 1_000_000)^2 / 2 = 31_250
    assert!(rebase7 == 31250, 6);

    // 8. Large numbers
    let large_emissions = 1_000_000_000_000_000_000;
    let large_total_supply = 10_000_000_000_000_000_000;
    let large_locked = 4_000_000_000_000_000_000; // 40% locked
    let rebase8 = minter::calculate_rebase_growth(large_emissions, large_total_supply, large_locked);
    // expected = large_emissions * (0.6)^2 / 2
    // expected = 10^18 * 0.36 / 2 = 18 * 10^16
    assert!(rebase8 == 180_000_000_000_000_000, 7);
}

#[test]
fun test_rebase_distribution_and_claim() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        initial_o_sail_supply
    );

    // Create and deposit a position for the user
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 2. Distribute gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    // 3. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // get reward for lock
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // 4. Check RebaseDistributor balance before update (should be 0)
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 5. Update minter period for epoch 2, which triggers rebase
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 5.5 Check RebaseDistributor balance after update.
    // Emissions are based on previous epoch emissions, but there is no previous epoch relative to the first one.
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // distribute the gauge for epoch 2
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    scenario.next_tx(admin);
    {
        // print the total supply
        let minter = scenario.take_shared<Minter<SAIL>>();
        test_scenario::return_shared(minter);
    };

    clock.increment_for_testing(WEEK);

    // get position reward oSAIL2
    scenario.next_tx(user);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };

    // update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 6. Verify rebase amount was distributed to RebaseDistributor
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        // total supply is 2_500_000
        // total locked is 500_000
        // emissions is 1_000_000
        // according to the rebase formula the rebase is 1_000_000 * (1 - 500_000 / 2_500_000)^2 / 2 = 320_000
        assert!(320_000 - rd.balance() <= 1, 1);
        test_scenario::return_shared(rd);
    };

    // 7. User claims rewards
    scenario.next_tx(user);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(320_000 - claimed_amount <= 10, 2);

        // The reward should be added to the lock amount since it's still active
        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!(lock_amount + 320_000 - locked_balance.amount() <= 10, 3);
        assert!(rd.balance() <= 10, 4);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };


    // distribute gague
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // update to epoch 4
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // expected total supply is 1_000_000 + 1_000_000 + 500_000 + 320_000;
    // locked supply is 500_000 + 320_000
    // expected rebase is 251496

    // 8. Verify rebase amount was distributed to RebaseDistributor
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() - 251496 <= 10, 1);
        test_scenario::return_shared(rd);
    };

    // 9. User claims rewards
    scenario.next_tx(user);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(251496 - claimed_amount <= 10, 2);

        // The reward should be added to the lock amount since it's still active
        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!(lock_amount + 320_000 + 251496 - locked_balance.amount() <= 20, 3);
        assert!(rd.balance() <= 20, 4);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };


    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_rebase_distribution_with_two_pools() {
    let admin = @0xA;
    let user1 = @0xB;
    let user2 = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Setup
    scenario.next_tx(admin);
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    };

    scenario.next_tx(admin);
    {
        setup::setup_distribution_with_initial_supply<SAIL>(&mut scenario, admin, lock_amount, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, initial_o_sail_supply, &mut clock);
        o_sail_coin.burn_for_testing();
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        transfer::public_transfer(sail_coin, user1);
    };
    scenario.next_tx(user1);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        setup::create_lock<SAIL>(&mut scenario, sail_coin, 182, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<USD_TESTS, SAIL>(&mut scenario, admin, true, &clock);

    // 2. Create and deposit positions
    scenario.next_tx(user1);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user1);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };
    
    scenario.next_tx(user2);
    {
        setup::create_position_with_liquidity<USD_TESTS, BUSD>(
            &mut scenario,
            user2,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user2);
    {
        setup::deposit_position<USD_TESTS, BUSD>(&mut scenario, &clock);
    };
    
    // 3. Distribute gauges for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // 4. Claim staking rewards for epoch 1
    scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // 5. Update to epoch 2, rebase should be 0
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 6. Distribute gauges for epoch 2
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
     scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // 7. Claim staking rewards for epoch 2
     scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    
    // 8. Update to epoch 3, trigger rebase
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 9. Verify and claim first rebase
    let expected_rebase1 = 790123;
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(expected_rebase1 - rd.balance() <= 1, 1);
        test_scenario::return_shared(rd);
    };

    scenario.next_tx(user1);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(expected_rebase1 - claimed_amount <= 10, 2);

        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!((lock_amount + expected_rebase1) - locked_balance.amount() <= 10, 3);
        assert!(rd.balance() <= 10, 4);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    // 10. Distribute gauges for epoch 3
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // 11. Update to epoch 4, trigger second rebase
    scenario.next_tx(admin);
    {
        let o_sail_coin_4 = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        o_sail_coin_4.burn_for_testing();
    };

    // 12. Verify and claim second rebase
    let expected_rebase2 = 571726;
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() - expected_rebase2 <= 10, 5);
        test_scenario::return_shared(rd);
    };

    scenario.next_tx(user1);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(expected_rebase2 - claimed_amount <= 10, 6);

        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!((lock_amount + expected_rebase1 + expected_rebase2) - locked_balance.amount() <= 20, 7);
        assert!(rd.balance() <= 20, 8);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    // Cleanup
    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
fun test_rebase_distribution_with_two_pools_one_gauge_first_epoch_skipped() {
    let admin = @0xA;
    let user1 = @0xB;
    let user2 = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Setup
    scenario.next_tx(admin);
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    };

    scenario.next_tx(admin);
    {
        setup::setup_distribution_with_initial_supply<SAIL>(&mut scenario, admin, lock_amount, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, initial_o_sail_supply, &mut clock);
        o_sail_coin.burn_for_testing();
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        transfer::public_transfer(sail_coin, user1);
    };
    scenario.next_tx(user1);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        setup::create_lock<SAIL>(&mut scenario, sail_coin, 182, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<USD_TESTS, SAIL>(&mut scenario, admin, true, &clock);

    // 2. Create and deposit positions
    scenario.next_tx(user1);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user1);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };
    
    scenario.next_tx(user2);
    {
        setup::create_position_with_liquidity<USD_TESTS, BUSD>(
            &mut scenario,
            user2,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user2);
    {
        setup::deposit_position<USD_TESTS, BUSD>(&mut scenario, &clock);
    };
    
    // 3. Distribute gauges for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
    // skip the second gauge distribution

    clock.increment_for_testing(WEEK);

    // 4. Claim staking rewards for epoch 1
    scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // 5. Update to epoch 2, rebase should be 0
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 6. Distribute gauges for epoch 2
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
     scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // 7. Claim staking rewards for epoch 2
     scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    
    // 8. Update to epoch 3, trigger rebase
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 9. Verify and claim first rebase
    //  1_000_000 * (1 - 500_000/3_500_000)**2 * 0.5
    // 1m of base because we only distributed 1 gauge during the first epoch
    let expected_rebase1 = 367347;
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(expected_rebase1 - rd.balance() <= 1, 1);
        test_scenario::return_shared(rd);
    };

    scenario.next_tx(user1);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(expected_rebase1 - claimed_amount <= 10, 2);

        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!((lock_amount + expected_rebase1) - locked_balance.amount() <= 10, 3);
        assert!(rd.balance() <= 10, 4);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    // Cleanup
    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_rebase_distribution_with_two_pools_one_gauge_second_epoch_skipped() {
    let admin = @0xA;
    let user1 = @0xB;
    let user2 = @0xC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Setup
    scenario.next_tx(admin);
    {
        setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    };

    scenario.next_tx(admin);
    {
        setup::setup_distribution_with_initial_supply<SAIL>(&mut scenario, admin, lock_amount, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, AUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, 1 << 64, 1);
    };
    
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, initial_o_sail_supply, &mut clock);
        o_sail_coin.burn_for_testing();
    };
    
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    scenario.next_tx(admin);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        transfer::public_transfer(sail_coin, user1);
    };
    scenario.next_tx(user1);
    {
        let sail_coin = scenario.take_from_sender<Coin<SAIL>>();
        setup::create_lock<SAIL>(&mut scenario, sail_coin, 182, &clock);
    };

    let mut aggregator = setup::setup_price_monitor_and_aggregator<USD_TESTS, SAIL>(&mut scenario, admin, true, &clock);

    // 2. Create and deposit positions
    scenario.next_tx(user1);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user1,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user1);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };
    
    scenario.next_tx(user2);
    {
        setup::create_position_with_liquidity<USD_TESTS, BUSD>(
            &mut scenario,
            user2,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user2);
    {
        setup::deposit_position<USD_TESTS, BUSD>(&mut scenario, &clock);
    };
    
    // 3. Distribute gauges for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };

    clock.increment_for_testing(WEEK);

    // 4. Claim staking rewards for epoch 1
    scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL1>(&mut scenario, &clock);
    };

    // 5. Update to epoch 2, rebase should be 0
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 6. Distribute gauges for epoch 2
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock); 
    };
    // skip the second gauge distribution

    clock.increment_for_testing(WEEK);

    // 7. Claim staking rewards for epoch 2
     scenario.next_tx(user1);
    {
        setup::get_staked_position_reward<USD_TESTS, AUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
     scenario.next_tx(user2);
    {
        setup::get_staked_position_reward<USD_TESTS, BUSD, SAIL, OSAIL2>(&mut scenario, &clock);
    };
    
    // 8. Update to epoch 3, trigger rebase
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 9. Verify and claim first rebase
    //  1_000_000 * (1 - 500_000/3_500_000)**2 * 0.5
    // 1m of base because the gauge was not distributed and we don't have information about it's emissions
    let expected_rebase1 = 367347;
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        std::debug::print(&b"rd.balance()".to_string());
        std::debug::print(&rd.balance());
        assert!(expected_rebase1 - rd.balance() <= 1, 1);
        test_scenario::return_shared(rd);
    };

    scenario.next_tx(user1);
    {
        let mut rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        let claimed_amount = rd.claim(&mut ve, &mut lock, &clock, scenario.ctx());
        assert!(expected_rebase1 - claimed_amount <= 10, 2);

        let (locked_balance, _) = voting_escrow::locked(&ve, object::id(&lock));
        assert!((lock_amount + expected_rebase1) - locked_balance.amount() <= 10, 3);
        assert!(rd.balance() <= 10, 4);

        test_scenario::return_shared(rd);
        test_scenario::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    // Cleanup
    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_rebase_with_unclaimed_rewards() {
    let admin = @0xD;
    let user = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_tests_cap, usd_tests_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000; // Set emissions to zero
    let lock_amount = 500_000;
    let initial_o_sail_supply = 0;

    // 1. Full setup. This will create a lock for `user` with `lock_amount`.
    // The total supply of SAIL will be `lock_amount`. All of it is locked.
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        lock_amount,
        182, // lock_duration_days
        gauge_base_emissions,
        initial_o_sail_supply
    );

    // 2. Create and deposit a position for the user
    scenario.next_tx(user);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario,
            user,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000,
            &clock
        );
    };
    scenario.next_tx(user);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 3. Distribute gauge for epoch 1. Since base emissions are 0, no new SAIL should be minted.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock);
    };

    // 4. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 5. Update minter period for epoch 2. This triggers the first rebase calculation.
    // Since no new SAIL was minted, total supply should equal locked supply.
    // Therefore, rebase amount should be 0.
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // 6. Check RebaseDistributor balance. It should be 0.
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 0);
        test_scenario::return_shared(rd);
    };

    // 7. Distribute the gauge for epoch 2. Again, no new SAIL should be minted.
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_tests_metadata, &mut aggregator, &clock);
    };

    // 8. Advance to the next epoch
    clock.increment_for_testing(WEEK);

    // 9. Update minter period for epoch 3. Rebase should be 0 again.
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // 10. Verify rebase amount is still 0.
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<RebaseDistributor<SAIL>>();
        assert!(rd.balance() == 0, 1);
        test_scenario::return_shared(rd);
    };

    // Cleanup
    test_utils::destroy(usd_tests_cap);
    test_utils::destroy(usd_tests_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}
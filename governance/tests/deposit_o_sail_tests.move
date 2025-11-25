#[test_only]
module governance::deposit_o_sail_tests;

use governance::setup;
use governance::minter::{Self, Minter};
use voting_escrow::voting_escrow::{Self, VotingEscrow, Lock};
use governance::distribution_config::{Self, DistributionConfig};
use clmm_pool::config;
use sui::test_scenario;
use sui::test_utils;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::object::{Self, ID};
use governance::voter::{Self, Voter};
use sui::transfer;

public struct SAIL has drop {}
public struct OSAIL1 has drop {}

#[test]
fun test_deposit_o_sail_into_permanent_lock() {
    let admin = @0x301;
    let user = @0x302;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        // Initialize clmm_pool::config as it's needed by setup_distribution
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a permanent lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // Tx 4: Check initial lock state
    let initial_balance_of;
    scenario.next_tx(user);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (locked_balance, _) = voting_escrow::locked(&ve, lock_id);
        assert!(locked_balance.amount() == initial_lock_amount, 1);
        assert!(locked_balance.is_permanent(), 101);
        
        // Advance time a bit to check voting power
        clock::increment_for_testing(&mut clock, 1000);
        initial_balance_of = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Tx 5: Deposit oSAIL into the lock
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    // Tx 6: Check final lock state
    scenario.next_tx(user);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (locked_balance, _) = voting_escrow::locked(&ve, lock_id);
        let expected_final_amount = initial_lock_amount + o_sail_to_deposit;
        assert!(locked_balance.amount() == expected_final_amount, 2);
        assert!(locked_balance.is_permanent(), 102);

        let final_balance_of = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(final_balance_of == initial_balance_of + o_sail_to_deposit, 3);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDepositOSailLockNotPermanent)]
fun test_deposit_o_sail_into_non_permanent_lock_fail() {
    let admin = @0x401;
    let user = @0x402;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a 6-month lock for the user
    let initial_lock_amount = 100_000;
    let lock_duration_days = 26 * 7; // 6 months
    scenario.next_tx(user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(initial_lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, lock_duration_days, &clock);
    };

    // Tx 4: Attempt to deposit oSAIL into the non-permanent lock (this should fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDepositOSailLockNotPermanent)]
fun test_deposit_o_sail_into_2_year_lock_fail() {
    let admin = @0x501;
    let user = @0x502;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a 2-year lock for the user
    let initial_lock_amount = 100_000;
    let lock_duration_days = 2 * 52 * 7; // 2 years
    scenario.next_tx(user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(initial_lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, lock_duration_days, &clock);
    };

    // Tx 4: Attempt to deposit oSAIL into the non-permanent lock (this should fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::EDepositForNulledLock)]
fun test_deposit_o_sail_into_split_lock_fails() {
    let admin = @0x601;
    let user = @0x602;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Allow splitting for everyone
    scenario.next_tx(admin);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = voting_escrow::create_team_cap<SAIL>(&mut ve, &ve_publisher, scenario.ctx());

        voting_escrow::toggle_split<SAIL>(
            &mut ve,
            &team_cap,
            @0x0, // for everyone
            true
        );

        test_scenario::return_shared(ve);
        transfer::public_transfer(team_cap, admin);
        test_utils::destroy(ve_publisher);
    };

    // Tx 2: Activate Minter for oSAIL
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        // send it to the user so he could later deposit
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a 4-year lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // Tx 4: Split the lock
    let original_lock_id: ID;
    scenario.next_tx(user);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut original_lock = scenario.take_from_sender<Lock>();
        original_lock_id = object::id(&original_lock);

        let (lock_a, lock_b) = voting_escrow::split(
            &mut ve,
            &mut original_lock,
            initial_lock_amount / 2,
            &clock,
            scenario.ctx()
        );

        // Return the two new locks to the user
        transfer::public_transfer(lock_a, user);
        transfer::public_transfer(lock_b, user);
        // The original lock object is now nulled but must be returned to be destroyed
        scenario.return_to_sender(original_lock); 
        test_scenario::return_shared(ve);
    };

    let o_sail_to_deposit = 1_000_000;
    // Tx 5: Attempt to deposit oSAIL into the non-permanent lock (this should fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(original_lock_id);
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDepositOSailLockNotPermanent)]
fun test_deposit_o_sail_into_4_year_lock_fail() {
    let admin = @0x601;
    let user = @0x602;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a 4-year lock for the user
    let initial_lock_amount = 100_000;
    let lock_duration_days = 4 * 52 * 7; // 4 years
    scenario.next_tx(user);
    {
        let sail_to_lock = coin::mint_for_testing<SAIL>(initial_lock_amount, scenario.ctx());
        setup::create_lock<SAIL>(&mut scenario, sail_to_lock, lock_duration_days, &clock);
    };

    // Tx 4: Attempt to deposit oSAIL into the non-permanent lock (this should fail)
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_deposit_expired_o_sail_into_permanent_lock_succeeds() {
    let admin = @0x701;
    let user = @0x702;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL from Epoch 1
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a permanent lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // Advance time by 5 weeks to make OSAIL1 expire
    let five_weeks_ms = 5 * 7 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, five_weeks_ms);

    // Tx 4: Deposit expired oSAIL into the permanent lock
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    // Tx 5: Check final lock state
    scenario.next_tx(user);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (locked_balance, _) = voting_escrow::locked(&ve, lock_id);
        let expected_final_amount = initial_lock_amount + o_sail_to_deposit;
        assert!(locked_balance.amount() == expected_final_amount, 1);
        assert!(locked_balance.is_permanent(), 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDepositOSailLockNotPermanent)]
fun test_deposit_o_sail_into_toggled_permanent_lock_fail() {
    let admin = @0x801;
    let user = @0x802;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a permanent lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // advance time a little bit, cos unlocking just after the lock is created is not allowed
    clock::increment_for_testing(&mut clock, 10000);

    // Tx 4: Unlock the permanent lock
    scenario.next_tx(user);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::unlock_permanent<SAIL>(
            &mut ve,
            &mut lock,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Tx 5: Attempt to deposit oSAIL into the now non-permanent lock
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}


#[test]
#[expected_failure(abort_code = minter::EDepositOSailZeroAmount)]
fun test_deposit_zero_o_sail_into_permanent_lock_succeeds() {
    let admin = @0x901;
    let user = @0x902;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a permanent lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // Tx 4: Deposit zero oSAIL into the lock
    let o_sail_to_deposit = 0;
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();

        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut ve,
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    // Tx 5: Check final lock state
    scenario.next_tx(user);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (locked_balance, _) = voting_escrow::locked(&ve, lock_id);
        assert!(locked_balance.amount() == initial_lock_amount, 1);
        assert!(locked_balance.is_permanent(), 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = minter::EDepositOSailBalanceNotExist)]
fun test_deposit_o_sail_into_permanent_lock_with_wrong_ve_fails() {
    let admin = @0xA01;
    let user = @0xA02;
    let mut scenario = test_scenario::begin(admin);

    let mut clock = clock::create_for_testing(scenario.ctx());

    // Tx 1: Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);
    };

    // Tx 2: Activate Minter and give user some oSAIL
    let o_sail_to_deposit = 50_000;
    scenario.next_tx(admin);
    {
        let o_sail_coin = setup::activate_minter<SAIL, OSAIL1>(&mut scenario, 1_000_000, &mut clock);
        transfer::public_transfer(o_sail_coin, user);
    };

    // Tx 3: Create a permanent lock for the user
    let initial_lock_amount = 100_000;
    scenario.next_tx(user);
    {
        setup::mint_and_create_permanent_lock<SAIL>(&mut scenario, user, initial_lock_amount, &clock);
    };

    // Tx 4: Attempt to deposit oSAIL using a wrong VE instance
    scenario.next_tx(user);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut lock = scenario.take_from_sender<Lock>();
        let mut o_sail_coin = scenario.take_from_sender<Coin<OSAIL1>>();
        let o_sail_to_deposit_coin = o_sail_coin.split(o_sail_to_deposit, scenario.ctx());

        // Create a new, "wrong" VE instance for this test
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let voter = scenario.take_shared<Voter>(); // need this to get voter_id
        let (mut wrong_ve, ve_cap) = voting_escrow::create<SAIL>(
            &ve_publisher,
            object::id(&voter),
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(voter);
        test_utils::destroy(ve_publisher);
        test_utils::destroy(ve_cap);

        // This call is expected to fail because the lock does not belong to `wrong_ve`
        minter::deposit_o_sail_into_lock<SAIL, OSAIL1>(
            &mut minter,
            &mut wrong_ve, // Using the wrong VE instance
            &distribution_config,
            &mut lock,
            o_sail_to_deposit_coin,
            &clock,
            scenario.ctx()
        );

        // Cleanup (will not be reached)
        test_utils::destroy(wrong_ve);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(o_sail_coin);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}


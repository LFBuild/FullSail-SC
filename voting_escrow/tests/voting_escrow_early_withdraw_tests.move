#[test_only]
module voting_escrow::voting_escrow_early_withdraw_tests;

use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use voting_escrow::voting_escrow::{Self, VotingEscrow, Lock, TimeLockedWithdraw};
use sui::coin::{Self};
use voting_escrow::setup::{Self, SAIL};
use sui::test_utils;
use sui::object::{Self};

const ADMIN: address = @0xAD;
const USER: address = @0x0F;

// Dummy struct to create an invalid publisher
public struct VOTING_ESCROW_EARLY_WITHDRAW_TESTS has drop {}

#[test]
#[expected_failure(abort_code = 287647463522008100)]
fun test_schedule_early_withdraw_with_invalid_publisher_fails() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // 2. Create a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // 3. Attempt to schedule early withdraw with invalid publisher
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let invalid_publisher = sui::package::claim<VOTING_ESCROW_EARLY_WITHDRAW_TESTS>(
            VOTING_ESCROW_EARLY_WITHDRAW_TESTS {},
            scenario.ctx()
        );

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &invalid_publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );

        // This part is not reached, but needed for compilation
        test_utils::destroy(withdraw_obj);

        // Cleanup
        test_utils::destroy(invalid_publisher);
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // 4. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code = 696051782678871300)]
fun test_execute_early_withdraw_too_soon_fails() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // 2. Create a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let withdraw_obj: TimeLockedWithdraw;
    let lock_id: object::ID;

    // 3. Schedule early withdraw with a valid publisher
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        let publisher = voting_escrow::test_init(scenario.ctx());

        withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );

        // Cleanup
        test_utils::destroy(publisher);
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // 4. Advance time, but not enough for withdrawal
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms - 1000); // 1 second less

    // 5. Attempt to execute early withdraw
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 6. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_execute_early_withdraw_succeeds() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let lock_amount = 1_000_000;

    // 2. Create a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let withdraw_obj: TimeLockedWithdraw;
    let lock_id: object::ID;

    // 3. Schedule early withdraw with a valid publisher
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        let publisher = voting_escrow::test_init(scenario.ctx());

        withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        
        // Cleanup
        test_utils::destroy(publisher);
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // 4. Advance time by exactly 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 5. Execute early withdraw
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 6. Verify withdrawal
    scenario.next_tx(USER);
    {
        // Check user has the coin back
        let coin = scenario.take_from_sender<sui::coin::Coin<SAIL>>();
        assert!(coin.value() == lock_amount, 0);
        test_utils::destroy(coin);

        // Check lock is gone from voting escrow
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (_, exists) = ve.locked(lock_id);
        assert!(!exists, 1);
        ts::return_shared(ve);
    };

    // 7. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_admin_schedules_and_user_executes_early_withdraw() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let lock_amount = 1_000_000;

    // 2. User creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: object::ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 3. Admin schedules early withdraw and sends object to user
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        
        transfer::public_transfer(withdraw_obj, USER);

        // Cleanup
        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 4. Advance time by exactly 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 5. User executes early withdraw
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 6. Verify withdrawal
    scenario.next_tx(USER);
    {
        // Check user has the coin back
        let coin = scenario.take_from_sender<sui::coin::Coin<SAIL>>();
        assert!(coin.value() == lock_amount, 0);
        test_utils::destroy(coin);

        // Check lock is gone from voting escrow
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (_, exists) = ve.locked(lock_id);
        assert!(!exists, 1);
        ts::return_shared(ve);
    };

    // 7. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code = 6035137208728614)]
fun test_execute_early_withdraw_with_changed_amount_fails() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let initial_lock_amount = 1_000_000;
    let deposit_amount = 500_000;

    // 2. User creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(initial_lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: object::ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 3. Admin schedules early withdraw and sends object to user
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        
        transfer::public_transfer(withdraw_obj, USER);

        // Cleanup
        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 4. User deposits more SAIL into the lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let sail = coin::mint_for_testing<SAIL>(deposit_amount, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            sail,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // 5. Advance time by 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 6. User attempts to execute early withdraw (should fail)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 7. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code = 922337640483821980)] // EWithdrawPositionVoted
fun test_execute_early_withdraw_for_voted_lock_fails() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let lock_amount = 1_000_000;

    // 2. User creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365, // 1 year
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: object::ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };
        
    // 3. Admin sets voting status for the lock
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());
        let cap = voting_escrow::create_voting_escrow_cap(
            &publisher,
            object::id(&ve),
            scenario.ctx()
        );
        
        voting_escrow::voting<SAIL>(
            &mut ve,
            &cap,
            lock_id,
            true
        );

        test_utils::destroy(publisher);
        test_utils::destroy(cap);
        ts::return_shared(ve);
    };

    // 4. Admin schedules early withdraw
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        transfer::public_transfer(withdraw_obj, USER);

        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };


    // 5. Advance time by 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 6. User attempts to execute early withdraw (should fail)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 7. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code = 922337642201861328)] // EWithdrawPermanentPosition
fun test_execute_early_withdraw_for_permanent_lock() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let lock_amount = 1_000_000;

    // 2. User creates a permanent lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            0, // duration is ignored for permanent lock
            true, // permanent lock
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: object::ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };
        
    // 3. Admin schedules early withdraw
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        
        transfer::public_transfer(withdraw_obj, USER);

        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 4. Advance time by 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 5. User executes early withdraw
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 6. Verify withdrawal
    scenario.next_tx(USER);
    {
        let coin = scenario.take_from_sender<sui::coin::Coin<SAIL>>();
        assert!(coin.value() == lock_amount, 0);
        test_utils::destroy(coin);

        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (_, exists) = ve.locked(lock_id);
        assert!(!exists, 1);
        ts::return_shared(ve);
    };

    // 7. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code = 896364354150284800)] // EWithdrawPerpetualPosition
fun test_execute_early_withdraw_for_perpetual_lock_fails() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let lock_amount = 1_000_000;

    // 2. User creates a perpetual lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock_advanced<SAIL>(
            &mut ve,
            sail,
            0, // duration is ignored
            true, // permanent
            true, // perpetual
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: object::ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };
        
    // 3. Admin schedules early withdraw
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());

        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(
            &mut ve,
            &publisher,
            lock_id,
            &clock,
            scenario.ctx()
        );
        
        transfer::public_transfer(withdraw_obj, USER);

        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 4. Advance time by 24 hours
    let withdraw_lock_time_ms: u64 = 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, withdraw_lock_time_ms);

    // 5. User attempts to execute early withdraw (should fail)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();

        voting_escrow::execute_early_withdraw<SAIL>(
            &mut ve,
            withdraw_obj,
            lock,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // 6. End scenario
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_early_withdraw_impact_on_total_supply() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // 2. Admin creates multiple locks
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        // Permanent lock
        let p_sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, p_sail, 0, true, &clock, scenario.ctx());
        // 4-year lock
        let y4_sail = coin::mint_for_testing<SAIL>(4_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, y4_sail, 4 * 52 * 7, false, &clock, scenario.ctx());
        // 2-year lock
        let y2_sail = coin::mint_for_testing<SAIL>(2_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, y2_sail, 2 * 52 * 7, false, &clock, scenario.ctx());

        ts::return_shared(ve);
    };

    // 3. User creates a 1-year lock
    let user_lock_amount = 500_000;
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(user_lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(&mut ve, sail, 365, false, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    let user_lock_id: object::ID;
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        user_lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 4. Advance time by 6 months
    clock::increment_for_testing(&mut clock, 26 * 7 * 24 * 60 * 60 * 1000);

    // 5. Check total supply before withdrawal
    let total_supply_before: u64;
    let user_lock_power_before: u64;
    let expected_total_supply_after_6m = 1_000_000 + 4_000_000 * 7/8 + 2_000_000 * 3/8 + 500_000 * 1/8;
    scenario.next_tx(ADMIN);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        total_supply_before = voting_escrow::total_supply_at<SAIL>(&ve, current_time);
        assert!(total_supply_before - expected_total_supply_after_6m <= 30, 1);
        user_lock_power_before = voting_escrow::balance_of_nft_at<SAIL>(&ve, user_lock_id, current_time);
        ts::return_shared(ve);
    };

    // 6. Admin schedules early withdraw for user's lock
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());
        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(&mut ve, &publisher, user_lock_id, &clock, scenario.ctx());
        transfer::public_transfer(withdraw_obj, USER);
        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 7. Advance time by 24 hours and execute withdrawal
    clock::increment_for_testing(&mut clock, 24 * 60 * 60 * 1000);
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(user_lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();
        voting_escrow::execute_early_withdraw<SAIL>(&mut ve, withdraw_obj, lock, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    // 8. Verify total supply after withdrawal
    scenario.next_tx(ADMIN);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        let total_supply_after = voting_escrow::total_supply_at<SAIL>(&ve, current_time);

        // Total supply should decrease by the voting power of the withdrawn lock
        assert!(total_supply_after < total_supply_before, 0);
        
        let expected_supply_after = expected_total_supply_after_6m - user_lock_power_before - 4_000_000 / (4 * 52 * 7) - 2_000_000 / (4 * 52 * 7);
        assert!(total_supply_after - expected_supply_after <= 50, 1); 

        let (_, exists) = ve.locked(user_lock_id);
        assert!(!exists, 2);

        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_early_withdraw_permanent_lock_impact_on_total_supply() {
    // 1. Setup
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // 2. Admin creates multiple locks
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        // Permanent lock
        let p_sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, p_sail, 0, true, &clock, scenario.ctx());
        // 4-year lock
        let y4_sail = coin::mint_for_testing<SAIL>(4_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, y4_sail, 4 * 52 * 7, false, &clock, scenario.ctx());
        // 2-year lock
        let y2_sail = coin::mint_for_testing<SAIL>(2_000_000, scenario.ctx());
        voting_escrow::create_lock<SAIL>(&mut ve, y2_sail, 2 * 52 * 7, false, &clock, scenario.ctx());

        ts::return_shared(ve);
    };

    // 3. User creates a permanent lock
    let user_lock_amount = 500_000;
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(user_lock_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(&mut ve, sail, 0, true, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    let user_lock_id: object::ID;
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        user_lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // 4. Advance time by 6 months
    clock::increment_for_testing(&mut clock, 26 * 7 * 24 * 60 * 60 * 1000);

    // 5. Check total supply before withdrawal
    let total_supply_before: u64;
    let user_lock_power_before: u64;
    let expected_total_supply_after_6m = 1_000_000 + 4_000_000 * 7/8 + 2_000_000 * 3/8 + 500_000;
    scenario.next_tx(ADMIN);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        total_supply_before = voting_escrow::total_supply_at<SAIL>(&ve, current_time);
        assert!(total_supply_before - expected_total_supply_after_6m <= 30, 1);
        user_lock_power_before = voting_escrow::balance_of_nft_at<SAIL>(&ve, user_lock_id, current_time);
        assert!(user_lock_power_before == user_lock_amount, 0);
        ts::return_shared(ve);
    };

    // 6. Admin schedules early withdraw for user's lock
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let publisher = voting_escrow::test_init(scenario.ctx());
        let withdraw_obj = voting_escrow::schedule_early_withdraw<SAIL>(&mut ve, &publisher, user_lock_id, &clock, scenario.ctx());
        transfer::public_transfer(withdraw_obj, USER);
        test_utils::destroy(publisher);
        ts::return_shared(ve);
    };

    // 7. Advance time by 24 hours and execute withdrawal
    clock::increment_for_testing(&mut clock, 24 * 60 * 60 * 1000);
    // unlock permanent, cos withdrawing permanent lock is not allowed
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(user_lock_id);
        voting_escrow::unlock_permanent<SAIL>(&mut ve, &mut lock, &clock, scenario.ctx());
        ts::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(user_lock_id);
        let withdraw_obj = scenario.take_from_sender<TimeLockedWithdraw>();
        voting_escrow::execute_early_withdraw<SAIL>(&mut ve, withdraw_obj, lock, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    // 8. Verify total supply after withdrawal
    scenario.next_tx(ADMIN);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        let total_supply_after = voting_escrow::total_supply_at<SAIL>(&ve, current_time);

        assert!(total_supply_after < total_supply_before, 0);
        
        let expected_supply_after = expected_total_supply_after_6m - user_lock_power_before - (4_000_000 + 2_000_000) / (4 * 52 * 7);
        assert!(total_supply_after - expected_supply_after <= 50, 1); 

        let (_, exists) = ve.locked(user_lock_id);
        assert!(!exists, 2);

        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

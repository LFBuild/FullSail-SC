module ve::voting_escrow_tests;

use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use sui::coin::{Self};
use ve::setup::{Self, SAIL};
use sui::test_utils;

const ADMIN: address = @0xAD;
const USER: address = @0x0F;

#[test]
fun test_voting_escrow_balance_and_supply_at_6m_lock() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            false,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    let start_time = clock.timestamp_ms() / 1000;
    let day = 7 * 24 * 60 * 60;

    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let mut i = 0;
        while (i < 15) {
            let total_supply = ve.total_supply_at(start_time + i * day);
            let balance_at = ve.balance_of_nft_at(lock_id, start_time + i * day);
            assert!(total_supply - balance_at <= 10, i);
            i = i + 1;
        };

        ts::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_voting_escrow_balance_and_supply_large_lock() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1000000000000000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            4 * 52 * 7,
            false,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    let start_time = clock.timestamp_ms() / 1000;
    let month = 30 * 24 * 60 * 60;

    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let mut i = 0;
        while (i < 12) {
            let total_supply = ve.total_supply_at(start_time + 2 * i * month);
            let balance_at = ve.balance_of_nft_at(lock_id, start_time + 2 * i * month);
            assert!(total_supply - balance_at <= 30, i);
            i = i + 1;
        };

        ts::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_increase_large_lock_and_check_future_supply() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // 1. Create a large lock for 4 years
    scenario.next_tx(USER);
    {
        // 1T sail
        let sail = coin::mint_for_testing<SAIL>(1000000000000000000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        // Lock for 4 years
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            4 * 52 * 7,
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // 2. Wait for 10 months
    let month_ms: u64 = 10 * 30 * 24 * 60 * 60 * 1000;
    clock::increment_for_testing(&mut clock, month_ms);

    // 3. Increase the lock amount
    scenario.next_tx(USER);
    {
        // 0.5T sail
        let sail = coin::mint_for_testing<SAIL>(500000000000000000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            sail,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    // 4. Check total supply and balance of nft at 2 years in the future
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let current_time_sec = clock.timestamp_ms() / 1000;
        let two_years_sec = 2 * 365 * 24 * 60 * 60;
        let future_time_sec = current_time_sec + two_years_sec;

        let total_supply = ve.total_supply_at(future_time_sec);
        let balance_at = ve.balance_of_nft_at(lock_id, future_time_sec);

        // With only one lock, total supply should equal the balance of that lock.
        assert!(total_supply - balance_at <= 100, 1);

        ts::return_shared(ve);
        scenario.return_to_sender(lock);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_merge_two_locks_and_check_voting_power() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, lock_b_id) = create_two_locks(
        &mut scenario, &clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Store voting powers before merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        let lock_a_power_before = ve.balance_of_nft_at(lock_a_id, current_time);
        let lock_b_power_before = ve.balance_of_nft_at(lock_b_id, current_time);
        let total_supply_before = ve.total_supply_at(current_time);
        
        // Verify total supply equals sum of individual powers
        assert!(total_supply_before == lock_a_power_before + lock_b_power_before, 0);
        
        ts::return_shared(ve);
    };

    // Merge the locks (lock_a will be consumed, lock_b will be updated)
    merge_locks(&mut scenario, &clock, lock_a_id, lock_b_id);

    // Check voting power after merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        let lock_a_power_after = ve.balance_of_nft_at(lock_a_id, current_time);
        let lock_b_power_after = ve.balance_of_nft_at(lock_b_id, current_time);
        let total_supply_after = ve.total_supply_at(current_time);
        
        // lock_a should have 0 voting power after being consumed in merge
        assert!(lock_a_power_after == 0, 1);
        
        // lock_b should have the combined voting power
        // Total supply should equal lock_b's voting power (since lock_a is nulled)
        assert!(total_supply_after == lock_b_power_after, 2);

        // locked for 1 of 4 years, so voting power is 1/4 of 3M
        let expected_total_supply_after = 3_000_000 / 4;

        assert!(expected_total_supply_after - total_supply_after <= 2, 2);
        
        // The merged lock should have more voting power than 0
        assert!(lock_b_power_after > 0, 3);

        let (balance_a, _) = ve.locked(lock_a_id);
        let balance_a_amount = balance_a.amount();
        let (balance_b, _) = ve.locked(lock_b_id);
        let balance_b_amount = balance_b.amount();
        assert!(balance_a_amount == 0, 4);
        assert!(balance_b_amount == 3_000_000, 5);
        
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_merge_two_locks_after_6m_and_check_voting_power() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, lock_b_id) = create_two_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Store voting powers before merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        // Check individual voting powers before merge
        let lock_a_power_before = ve.balance_of_nft_at(lock_a_id, current_time);
        let lock_b_power_before = ve.balance_of_nft_at(lock_b_id, current_time);
        let total_supply_before = ve.total_supply_at(current_time);
        
        // Verify total supply equals sum of individual powers
        assert!(total_supply_before == lock_a_power_before + lock_b_power_before, 0);
        
        ts::return_shared(ve);
    };

    clock.increment_for_testing(6 * 30 * 24 * 60 * 60 * 1000);

    // Merge the locks (lock_a will be consumed, lock_b will be updated)
    merge_locks(&mut scenario, &clock, lock_a_id, lock_b_id);

    // Check voting power after merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        // Check voting powers after merge
        let lock_a_power_after = ve.balance_of_nft_at(lock_a_id, current_time);
        let lock_b_power_after = ve.balance_of_nft_at(lock_b_id, current_time);
        let total_supply_after = ve.total_supply_at(current_time);
        
        // lock_a should have 0 voting power after being consumed in merge
        assert!(lock_a_power_after == 0, 1);
        
        // lock_b should have the combined voting power
        // Total supply should equal lock_b's voting power (since lock_a is nulled)
        assert!(total_supply_after - lock_b_power_after <= 2, 2);
        
        // The merged lock should have more voting power than 0
        assert!(lock_b_power_after > 0, 3);

        let (balance_a, _) = ve.locked(lock_a_id);
        let balance_a_amount = balance_a.amount();
        let (balance_b, _) = ve.locked(lock_b_id);
        let balance_b_amount = balance_b.amount();
        assert!(balance_a_amount == 0, 4);
        assert!(balance_b_amount == 3_000_000, 5);
        
        ts::return_shared(ve);
    };

    clock.increment_for_testing(7 * 24 * 60 * 60 * 1000);

    // Check voting power after 1 week
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let current_time = clock.timestamp_ms() / 1000;
        // Check voting powers after merge
        let lock_a_power_after = ve.balance_of_nft_at(lock_a_id, current_time);
        let lock_b_power_after = ve.balance_of_nft_at(lock_b_id, current_time);
        let total_supply_after = ve.total_supply_at(current_time);
        
        // lock_a should have 0 voting power after being consumed in merge
        assert!(lock_a_power_after == 0, 1);
        
        // lock_b should have the combined voting power
        // Total supply should equal lock_b's voting power (since lock_a is nulled)
        assert!(total_supply_after - lock_b_power_after <= 2, 2);
        
        // The merged lock should have more voting power than 0
        assert!(lock_b_power_after > 0, 3);

        let (balance_a, _) = ve.locked(lock_a_id);
        let balance_a_amount = balance_a.amount();
        let (balance_b, _) = ve.locked(lock_b_id);
        let balance_b_amount = balance_b.amount();
        assert!(balance_a_amount == 0, 4);
        assert!(balance_b_amount == 3_000_000, 5);
        
        ts::return_shared(ve);
    };

    
    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_complex_lock_lifecycle_and_merge() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let initial_amount1 = 1_000_000;
    let deposit_amount = 500_000;
    let initial_amount2 = 2_000_000;

    // 1. Create the first lock for 1 year
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(initial_amount1, scenario.ctx());
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

    // 2. Wait for 1 month
    clock.increment_for_testing(30 * 24 * 60 * 60 * 1000);

    // 3. Increase lock duration to 2 years
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        voting_escrow::increase_unlock_time<SAIL>(
            &mut ve,
            &mut lock,
            730, // 2 years
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // 4. Wait for 6 more months
    clock.increment_for_testing(6 * 30 * 24 * 60 * 60 * 1000);

    let lock_a_id: ID;
    let lock_b_id: ID;

    // 5. Deposit more SAIL
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(deposit_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        lock_a_id = object::id(&lock);
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

    // 6. Wait for 1 more month
    clock.increment_for_testing(30 * 24 * 60 * 60 * 1000);

    // 7. Create a second lock (freshly created)
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(initial_amount2, scenario.ctx());
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

    // 8. Merge lock_a into lock_b
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock1 = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        let lock2 = scenario.take_from_sender<Lock>();
        
        let mut lock_a;
        let mut lock_b;

        // Distinguish locks by amount
        if (voting_escrow::get_amount(&lock1) == initial_amount1 + deposit_amount) {
            lock_a = lock1;
            lock_b = lock2;
        } else {
            lock_a = lock2;
            lock_b = lock1;
        };

        lock_b_id = object::id(&lock_b);

        voting_escrow::merge<SAIL>(
            &mut ve,
            &mut lock_a,
            &mut lock_b,
            &clock,
            scenario.ctx()
        );
        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        ts::return_shared(ve);
    };

    // 9. Check locked balances after merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (balance_a, exists_a) = ve.locked(lock_a_id);
        let (balance_b, exists_b) = ve.locked(lock_b_id);

        assert!(exists_a, 0);
        assert!(exists_b, 1);

        // lock_a was merged, so its amount should be 0
        assert!(balance_a.amount() == 0, 2);

        // lock_b should have the combined amount
        assert!(balance_b.amount() == initial_amount1 + deposit_amount + initial_amount2, 3);
        
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=473735693153592300)]
fun test_merge_already_merged_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, lock_b_id) = setup_and_merge_locks(
        &mut scenario, &clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Attempt to merge again (this should fail)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_b = scenario.take_from_sender_by_id<Lock>(lock_b_id);
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::merge<SAIL>(
            &mut ve,
            &mut lock_a,
            &mut lock_b,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        ts::return_shared(ve);
    };

    test_utils::destroy(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code=285443173276424000)]
fun test_split_merged_source_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // ADMIN enables splitting for USER
    scenario.next_tx(ADMIN);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = voting_escrow::create_team_cap(&ve, &ve_publisher, scenario.ctx());

        voting_escrow::toggle_split<SAIL>(
            &mut ve,
            &team_cap,
            USER,
            true
        );

        ts::return_shared(ve);
        transfer::public_transfer(team_cap, ADMIN);
        test_utils::destroy(ve_publisher);
    };

    // Attempt to split the merged source lock (lock_a), this should fail
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        let (_, _) = voting_escrow::split<SAIL>(
            &mut ve,
            &mut lock_a,
            500_000, // split amount
            &clock,
            scenario.ctx()
        );
        
        scenario.return_to_sender(lock_a);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=5602953801720378)]
fun test_deposit_into_merged_source_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Attempt to deposit into the merged source lock (lock_a), this should fail
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        let sail = coin::mint_for_testing<SAIL>(100_000, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock_a,
            sail,
            &clock,
            scenario.ctx()
        );
        
        scenario.return_to_sender(lock_a);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_destroy_merged_source_lock() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Verify lock_a still exists
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (_, exists) = ve.locked(lock_a_id);
        assert!(exists, 0);
        ts::return_shared(ve);
    };

    // Destroy the nulled source lock (lock_a)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::destroy_nulled<SAIL>(
            &mut ve,
            lock_a,
            &clock,
            scenario.ctx()
        );
        
        ts::return_shared(ve);
    };

    // Verify lock_a is destroyed
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (_, exists) = ve.locked(lock_a_id);
        assert!(!exists, 0);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337438190718157)]
fun test_create_lock_with_zero_amount_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // Attempt to create a lock with zero amount
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(0, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=328022942696051000)]
fun test_destroy_non_nulled_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // Create a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // Attempt to destroy the non-nulled lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();

        voting_escrow::destroy_nulled<SAIL>(
            &mut ve,
            lock,
            &clock,
            scenario.ctx()
        );
        
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_four_year_lock_power_after_three_years() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    // Create a 4-year lock with 1 SAIL
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(1, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            4 * 52 * 7, // 4 years
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // Wait for 3 years
    clock.increment_for_testing(3 * 365 * 24 * 60 * 60 * 1000);

    // Check lock status
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Check if nulled (should be false)
        assert!(!voting_escrow::is_nulled<SAIL>(&ve, lock_id), 0);

        // Check balance (should be 0 due to integer truncation)
        let balance = voting_escrow::balance_of_nft_at<SAIL>(
            &ve,
            lock_id,
            clock.timestamp_ms() / 1000
        );
        assert!(balance == 0, 1);

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337603547116342)]
fun test_split_full_amount_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let initial_amount = 1000;

    // ADMIN enables splitting for USER
    scenario.next_tx(ADMIN);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = voting_escrow::create_team_cap(&ve, &ve_publisher, scenario.ctx());

        voting_escrow::toggle_split<SAIL>(
            &mut ve,
            &team_cap,
            USER,
            true
        );

        ts::return_shared(ve);
        transfer::public_transfer(team_cap, ADMIN);
        test_utils::destroy(ve_publisher);
    };

    // USER creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(initial_amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            365,
            false,
            &clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // USER attempts to split the lock with the full amount
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::split<SAIL>(
            &mut ve,
            &mut lock,
            initial_amount,
            &clock,
            scenario.ctx()
        );
        
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337611707593526)]
fun test_merge_permanent_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (permanent_lock_id, four_year_lock_id) = create_two_locks(
        &mut scenario, &clock,
        1_000_000, 100, true, // permanent lock is source 'a'
        2_000_000, 4 * 52 * 7, false // 4-year lock is target 'b'
    );

    // Attempt to merge the permanent lock into the 4-year lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut permanent_lock = scenario.take_from_sender_by_id<Lock>(permanent_lock_id);
        let mut four_year_lock = scenario.take_from_sender_by_id<Lock>(four_year_lock_id);

        voting_escrow::merge<SAIL>(
            &mut ve,
            &mut permanent_lock, // Source lock cannot be permanent
            &mut four_year_lock, // Target lock
            &clock,
            scenario.ctx()
        );
        
        scenario.return_to_sender(permanent_lock);
        scenario.return_to_sender(four_year_lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_merge_into_permanent_lock() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let four_year_amount = 2_000_000;
    let permanent_amount = 1_000_000;

    let (four_year_lock_id, permanent_lock_id) = setup_and_merge_locks(
        &mut scenario, &clock,
        four_year_amount, 4 * 52 * 7, false, // 4-year lock is source 'a'
        permanent_amount, 100, true // permanent lock is target 'b'
    );

    // Verify the state after merge
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        
        let (source_balance, _) = ve.locked(four_year_lock_id);
        assert!(source_balance.amount() == 0, 0);

        let (target_balance, _) = ve.locked(permanent_lock_id);
        assert!(target_balance.amount() == permanent_amount + four_year_amount, 1);
        assert!(target_balance.is_permanent(), 2);

        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=251507383857110900)]
fun test_withdraw_nulled_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Verify lock_a is nulled
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow::is_nulled<SAIL>(&ve, lock_a_id), 0);
        ts::return_shared(ve);
    };

    // Wait for the original lock duration to expire
    clock.increment_for_testing(200 * 24 * 60 * 60 * 1000);

    // Attempt to withdraw the nulled lock (should fail)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::withdraw<SAIL>(
            &mut ve,
            lock_a,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=887642997355636700)]
fun test_lock_permanent_on_nulled_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Attempt to make the nulled lock permanent
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::lock_permanent<SAIL>(
            &mut ve,
            &mut lock_a,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock_a);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=766708045064883300)]
fun test_increase_unlock_time_on_nulled_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Attempt to increase unlock time on the nulled lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::increase_unlock_time<SAIL>(
            &mut ve,
            &mut lock_a,
            730, // new duration doesn't matter
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock_a);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=5602953801720378)]
fun test_increase_amount_on_nulled_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    // Attempt to increase amount on the nulled lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        let sail = coin::mint_for_testing<SAIL>(100_000, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock_a,
            sail,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock_a);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

fun create_two_locks(
    scenario: &mut ts::Scenario,
    clock: &Clock,
    amount_a: u64,
    duration_a: u64,
    permanent_a: bool,
    amount_b: u64,
    duration_b: u64,
    permanent_b: bool
): (ID, ID) {
    // Create first lock (lock_a)
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(amount_a, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            duration_a,
            permanent_a,
            clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    // Create second lock (lock_b)
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(amount_b, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            duration_b,
            permanent_b,
            clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_a_id: ID;
    let lock_b_id: ID;

    // Get lock IDs. The second lock created (lock_b) is taken first due to LIFO
    scenario.next_tx(USER);
    {
        let lock_b = scenario.take_from_sender<Lock>();
        let lock_a = scenario.take_from_sender<Lock>();
        lock_a_id = object::id(&lock_a);
        lock_b_id = object::id(&lock_b);
        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
    };

    (lock_a_id, lock_b_id)
}

fun merge_locks(scenario: &mut ts::Scenario, clock: &Clock, lock_a_id: ID, lock_b_id: ID) {
    // Merge lock_a into lock_b
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        let mut lock_b = scenario.take_from_sender_by_id<Lock>(lock_b_id);

        voting_escrow::merge<SAIL>(
            &mut ve,
            &mut lock_a,
            &mut lock_b,
            clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        ts::return_shared(ve);
    };
}

fun setup_and_merge_locks(
    scenario: &mut ts::Scenario,
    clock: &Clock,
    amount_a: u64,
    duration_a: u64,
    permanent_a: bool,
    amount_b: u64,
    duration_b: u64,
    permanent_b: bool
): (ID, ID) {
    let (lock_a_id, lock_b_id) = create_two_locks(
        scenario,
        clock,
        amount_a,
        duration_a,
        permanent_a,
        amount_b,
        duration_b,
        permanent_b
    );
    merge_locks(scenario, clock, lock_a_id, lock_b_id);
    (lock_a_id, lock_b_id)
}

const USER2: address = @0x10;

#[test]
fun test_transfer_nulled_lock_updates_ownership() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let (lock_a_id, _) = setup_and_merge_locks(
        &mut scenario, &mut clock, 1_000_000, 182, false, 2_000_000, 365, false
    );

    clock.increment_for_testing(24 * 60 * 60 * 1000);

    // Verify lock_a is nulled
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow::is_nulled<SAIL>(&ve, lock_a_id), 0);
        ts::return_shared(ve);
    };

    let initial_ownership_change_at: u64;

    // Get initial ownership change timestamp
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        initial_ownership_change_at = voting_escrow::ownership_change_at(&ve, lock_a_id);
        ts::return_shared(ve);
    };

    // Transfer the nulled lock from USER to USER2
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);

        voting_escrow::transfer<SAIL>(
            lock_a,
            &mut ve,
            USER2,
            &clock,
            scenario.ctx()
        );

        ts::return_shared(ve);
    };

    // Verify ownership has changed
    scenario.next_tx(ADMIN);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        
        let new_owner = voting_escrow::owner_of(&ve, lock_a_id);
        assert!(new_owner == USER2, 1);

        let new_ownership_change_at = voting_escrow::ownership_change_at(&ve, lock_a_id);
        assert!(new_ownership_change_at > initial_ownership_change_at, 2);
        assert!(new_ownership_change_at == clock.timestamp_ms(), 3);
        
        ts::return_shared(ve);
    };

    // USER2 now has the lock object
    scenario.next_tx(USER2);
    {
        let lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        scenario.return_to_sender(lock_a);
    };

    scenario.end();
    test_utils::destroy(clock);
}

fun create_lock_and_set_voting_status(
    scenario: &mut ts::Scenario,
    clock: &Clock,
    amount: u64,
    duration: u64,
    permanent: bool,
    is_voting: bool
): ID {
    // USER creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(amount, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(
            &mut ve,
            sail,
            duration,
            permanent,
            clock,
            scenario.ctx()
        );
        ts::return_shared(ve);
    };

    let lock_id: ID;

    // Get lock ID
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // ADMIN sets voting status for the lock
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let cap = scenario.take_from_sender<ve::voting_escrow_cap::VotingEscrowCap>();
        
        voting_escrow::voting<SAIL>(
            &mut ve,
            &cap,
            lock_id,
            is_voting
        );

        scenario.return_to_sender(cap);
        ts::return_shared(ve);
    };

    lock_id
}

#[test]
fun test_set_voting_status() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 365, false, true
    );

    // Verify status
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow::lock_has_voted<SAIL>(&mut ve, lock_id), 0);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337640483821980)]
fun test_withdraw_voted_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &mut clock, 1_000_000, 182, false, true
    );

    // Wait for the lock to expire
    clock.increment_for_testing(200 * 24 * 60 * 60 * 1000);

    // Attempt to withdraw
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        voting_escrow::withdraw<SAIL>(&mut ve, lock, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337600970122857)]
fun test_split_voted_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 365, false, true
    );

    // ADMIN enables splitting for USER
    scenario.next_tx(ADMIN);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = voting_escrow::create_team_cap(&ve, &ve_publisher, scenario.ctx());

        voting_escrow::toggle_split<SAIL>(
            &mut ve,
            &team_cap,
            USER,
            true
        );

        ts::return_shared(ve);
        transfer::public_transfer(team_cap, ADMIN);
        test_utils::destroy(ve_publisher);
    };

    // Attempt to split
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        voting_escrow::split<SAIL>(&mut ve, &mut lock, 500_000, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337607412573801)]
fun test_merge_voted_source_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_a_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 182, false, true
    );

    // Create target lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(2_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        voting_escrow::create_lock<SAIL>(&mut ve, sail, 365, false, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    let lock_b_id: ID;
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_b_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // Attempt to merge
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_a_id);
        let mut lock_b = scenario.take_from_sender_by_id<Lock>(lock_b_id);
        voting_escrow::merge<SAIL>(&mut ve, &mut lock_a, &mut lock_b, &clock, scenario.ctx());
        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_deposit_for_voted_lock_succeeds() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let initial_amount = 1_000_000;
    let deposit_amount = 100_000;

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, initial_amount, 365, false, true
    );

    // Attempt to deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::deposit_for<SAIL>(&mut ve, &mut lock, coin::mint_for_testing<SAIL>(deposit_amount, scenario.ctx()), &clock, scenario.ctx());

        // Verify amount increased
        let (locked_balance, _) = ve.locked(lock_id);
        assert!(locked_balance.amount() == initial_amount + deposit_amount, 0);

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_increase_amount_voted_lock_succeeds() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let initial_amount = 1_000_000;
    let increase_amount = 100_000;

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, initial_amount, 365, false, true
    );

    // Attempt to increase amount
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::increase_amount<SAIL>(&mut ve, &mut lock, coin::mint_for_testing<SAIL>(increase_amount, scenario.ctx()), &clock, scenario.ctx());

        // Verify amount increased
        let (locked_balance, _) = ve.locked(lock_id);
        assert!(locked_balance.amount() == initial_amount + increase_amount, 0);

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_increase_unlock_time_voted_lock_succeeds() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 182, false, true
    );

    let initial_end_time;
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = ve.locked(lock_id);
        initial_end_time = locked_balance.end();
        ts::return_shared(ve);
    };

    // Attempt to increase unlock time
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::increase_unlock_time<SAIL>(&mut ve, &mut lock, 365, &clock, scenario.ctx());

        let (new_locked_balance, _) = ve.locked(lock_id);
        assert!(new_locked_balance.end() > initial_end_time, 0);

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_lock_permanent_voted_lock_succeeds() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 365, false, true
    );

    // Attempt to make lock permanent
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);

        voting_escrow::lock_permanent<SAIL>(&mut ve, &mut lock, &clock, scenario.ctx());

        let (locked_balance, _) = ve.locked(lock_id);
        assert!(locked_balance.is_permanent(), 0);

        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
#[expected_failure(abort_code=922337667112619215)]
fun test_unlock_permanent_voted_lock_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &clock, 1_000_000, 100, true, true
    );

    // Attempt to unlock permanent lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        voting_escrow::unlock_permanent<SAIL>(&mut ve, &mut lock, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_transfer_voted_lock() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let lock_id = create_lock_and_set_voting_status(
        &mut scenario, &mut clock, 1_000_000, 365, false, true
    );

    // Transfer the lock from USER to USER2
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender_by_id<Lock>(lock_id);
        voting_escrow::transfer<SAIL>(lock, &mut ve, USER2, &clock, scenario.ctx());
        ts::return_shared(ve);
    };

    // Verify the new owner and voting status
    scenario.next_tx(ADMIN);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow::owner_of(&ve, lock_id) == USER2, 1);
        assert!(voting_escrow::lock_has_voted<SAIL>(&mut ve, lock_id), 2);
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}

#[test]
fun test_split_lock_verification() {
    let mut scenario = ts::begin(ADMIN);
    let mut clock = setup::setup<SAIL>(&mut scenario, ADMIN);

    let initial_amount = 1_000_000;
    let split_amount = 400_000;

    // ADMIN enables splitting for USER
    scenario.next_tx(ADMIN);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = voting_escrow::create_team_cap(&ve, &ve_publisher, scenario.ctx());

        voting_escrow::toggle_split<SAIL>(
            &mut ve,
            &team_cap,
            USER,
            true
        );

        ts::return_shared(ve);
        transfer::public_transfer(team_cap, ADMIN);
        test_utils::destroy(ve_publisher);
    };

    // USER creates a lock
    scenario.next_tx(USER);
    {
        let sail = coin::mint_for_testing<SAIL>(initial_amount, scenario.ctx());
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

    let original_lock_id: ID;
    let new_lock_id1: ID;
    let new_lock_id2: ID;
    let power_before_split: u64;

    // Get original lock ID and its voting power before split
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        original_lock_id = object::id(&lock);
        power_before_split = voting_escrow::balance_of_nft_at(&ve, original_lock_id, clock.timestamp_ms() / 1000);
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // USER splits the lock
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(original_lock_id);

        let (id1, id2) = voting_escrow::split<SAIL>(
            &mut ve,
            &mut lock,
            split_amount,
            &clock,
            scenario.ctx()
        );
        new_lock_id1 = id1;
        new_lock_id2 = id2;
        
        scenario.return_to_sender(lock);
        ts::return_shared(ve);
    };

    // Verify the state after split
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        // 1. Check original lock is nulled and has no power
        assert!(voting_escrow::is_nulled<SAIL>(&ve, original_lock_id), 0);
        let power_after_split_original = voting_escrow::balance_of_nft_at(&ve, original_lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after_split_original == 0, 1);

        // 2. Check new locks' amounts
        let (balance1, exists1) = ve.locked(new_lock_id1);
        let (balance2, exists2) = ve.locked(new_lock_id2);
        
        assert!(exists1, 2);
        assert!(exists2, 3);
        
        let amount1 = balance1.amount();
        let amount2 = balance2.amount();

        assert!(
            amount2 == split_amount && amount1 == initial_amount - split_amount,
            4
        );

        // 3. Check new locks' voting power
        let power1 = voting_escrow::balance_of_nft_at(&ve, new_lock_id1, clock.timestamp_ms() / 1000);
        let power2 = voting_escrow::balance_of_nft_at(&ve, new_lock_id2, clock.timestamp_ms() / 1000);

        let total_new_power = power1 + power2;
        assert!(power_before_split - total_new_power <= 1, 5);
        
        ts::return_shared(ve);
    };

    scenario.end();
    test_utils::destroy(clock);
}
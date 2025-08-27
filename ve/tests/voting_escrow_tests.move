module ve::voting_escrow_tests;

use sui::test_scenario::{Self as ts};
use sui::clock::{Self};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use sui::coin::{Self};
use sui::object::{Self, ID};
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

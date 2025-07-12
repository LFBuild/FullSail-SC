#[test_only]
module distribution::voting_escrow_tests;

use sui::test_scenario::{Self};
use sui::clock::{Self, Clock};
use distribution::setup::{Self, SAIL};
use distribution::voting_escrow::{Self, VotingEscrow, Lock};
use sui::coin::{Self, Coin};
use clmm_pool::config;

const USER: address = @0x42;
const ADMIN: address = @0x43;
const ONE_YEAR_MS: u64 = 365 * 24 * 60 * 60 * 1000;
const TWO_YEARS_IN_DAYS: u64 = 730;
const TWO_YEARS_IN_MS: u64 = 2 * ONE_YEAR_MS;

#[test]
fun test_create_lock_and_withdraw_after_2_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;

    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let current_timestamp = clock.timestamp_ms();

        let voting_power = voting_escrow::balance_of_nft_at(&ve, lock_id, current_timestamp);
        
        let expected_voting_power = amount_to_lock / 2;

        assert!(expected_voting_power - voting_power <= 1, 1);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    clock.increment_for_testing(TWO_YEARS_IN_MS + 1);

    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let current_timestamp = clock.timestamp_ms();

        let voting_power = voting_escrow::balance_of_nft_at(&ve, lock_id, current_timestamp);
        let expected_voting_power = 0;

        assert!(expected_voting_power == voting_power, 1);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(USER);
    {
       setup::withdraw_lock<SAIL>(&mut scenario, &clock);
    };

    scenario.next_tx(USER);
    {
        let withdrawn_coin = scenario.take_from_sender<Coin<SAIL>>();
        assert!(withdrawn_coin.value() == amount_to_lock, 4);
        withdrawn_coin.burn_for_testing();
    };
    
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_permanent_lock_toggle_and_withdraw() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let four_years_in_ms: u64 = 4 * ONE_YEAR_MS;
    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a permanent lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_permanent_lock<SAIL>(
            &mut scenario,
            USER,
            amount_to_lock,
            &clock
        );
    };

    // 3. Check initial voting power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        
        let voting_power_initial = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_initial == amount_to_lock, 1);

        // 4. Wait 1 year and check voting power again
        clock.increment_for_testing(ONE_YEAR_MS);
        let voting_power_after_1_year = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_after_1_year == amount_to_lock, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Toggle permanent off
    scenario.next_tx(USER);
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

    // 6. Wait 4 years
    clock.increment_for_testing(four_years_in_ms + 1);

    // 7. Withdraw the lock
    scenario.next_tx(USER);
    {
        setup::withdraw_lock<SAIL>(&mut scenario, &clock);
    };
    
    // 8. Check withdrawn coin
    scenario.next_tx(USER);
    {
        let withdrawn_coin = scenario.take_from_sender<Coin<SAIL>>();
        assert!(withdrawn_coin.value() == amount_to_lock, 3);
        withdrawn_coin.burn_for_testing();
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::EWithdrawPermanentPosition)]
fun test_permanent_lock_cannot_be_withdrawn() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let five_years_in_ms: u64 = 5 * ONE_YEAR_MS;
    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a permanent lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_permanent_lock<SAIL>(
            &mut scenario,
            USER,
            amount_to_lock,
            &clock
        );
    };

    // 3. Wait 5 years
    clock.increment_for_testing(five_years_in_ms);

    // 4. Try to withdraw the lock - this must fail
    scenario.next_tx(USER);
    {
        setup::withdraw_lock<SAIL>(&mut scenario, &clock);
    };
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::EWithdrawPermanentPosition)]
fun test_perpetual_lock_cannot_be_withdrawn() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let five_years_in_ms: u64 = 5 * ONE_YEAR_MS;
    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a perpetual lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_perpetual_lock<SAIL>(
            &mut scenario,
            USER,
            amount_to_lock,
            &clock
        );
    };

    // 3. Check voting power after 5 years
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        
        let voting_power_initial = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_initial == amount_to_lock, 1);

        clock.increment_for_testing(five_years_in_ms);

        let voting_power_after_5_years = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_after_5_years == amount_to_lock, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 4. Try to withdraw the lock - this must fail
    scenario.next_tx(USER);
    {
        setup::withdraw_lock<SAIL>(&mut scenario, &clock);
    };
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::EUnlockPermanentIsPerpetual)]
fun test_cannot_unlock_perpetual_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a perpetual lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_perpetual_lock<SAIL>(
            &mut scenario,
            USER,
            amount_to_lock,
            &clock
        );
    };

    // 3. Try to unlock permanent - this must fail
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::unlock_permanent<SAIL>(
            &mut ve,
            &mut lock,
            &clock,
            scenario.ctx()
        );

        // This code is unreachable
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_perpetual_lock_for_power_does_not_decay() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let recipient = @0x1337;
    let five_years_in_ms: u64 = 5 * ONE_YEAR_MS;
    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a perpetual lock for another user
    scenario.next_tx(ADMIN); // Admin creates the lock
    {
        setup::mint_and_create_perpetual_lock_for<SAIL>(
            &mut scenario,
            recipient,
            amount_to_lock,
            &clock
        );
    };

    // 3. Check voting power after 5 years
    scenario.next_tx(recipient); // Recipient checks their lock
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        
        let voting_power_initial = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_initial == amount_to_lock, 1);

        clock.increment_for_testing(five_years_in_ms);

        let voting_power_after_5_years = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(voting_power_after_5_years == amount_to_lock, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::ELockPermanentAlreadyPermanent)]
fun test_cannot_toggle_permanent_on_perpetual_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let amount_to_lock = 1_000_000_000;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    // 2. Create a perpetual lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_perpetual_lock<SAIL>(
            &mut scenario,
            USER,
            amount_to_lock,
            &clock
        );
    };

    // 3. Try to toggle permanent on - this must fail
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::lock_permanent<SAIL>(
            &mut ve,
            &mut lock,
            &clock,
            scenario.ctx()
        );

        // This code is unreachable
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

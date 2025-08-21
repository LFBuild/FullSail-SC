#[test_only]
module ve::voting_escrow_tests;

use sui::test_scenario::{Self};
use sui::clock::{Self, Clock};
use distribution::setup::{Self, SAIL};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use ve::common;
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

#[test]
fun test_simulate_deposit_on_permanent_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 3. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 4. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_permanent_lock_after_2_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 2 years
    clock.increment_for_testing(TWO_YEARS_IN_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_permanent_lock_after_4_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 4 years
    clock.increment_for_testing(4 * ONE_YEAR_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_permanent_lock_after_5_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 5 years
    clock.increment_for_testing(5 * ONE_YEAR_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_perpetual_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 3. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 4. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_perpetual_lock_after_2_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 2 years
    clock.increment_for_testing(TWO_YEARS_IN_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_perpetual_lock_after_4_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 4 years
    clock.increment_for_testing(4 * ONE_YEAR_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);
        
        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);
        
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_perpetual_lock_after_5_years() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

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

    // 3. Wait for 5 years
    clock.increment_for_testing(5 * ONE_YEAR_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_before == amount_to_lock, 1);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);
        assert!(simulated_delta == amount_to_deposit, 3);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);
        assert!(power_after == amount_to_lock + amount_to_deposit, 5);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_2_year_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 3. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 4. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms());
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_2_year_lock_after_1_year() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 1 year
    clock.increment_for_testing(ONE_YEAR_MS);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_after_deposit_and_wait() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let six_months_ms = ONE_YEAR_MS / 2;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let initial_amount_to_lock = 1_000_000_000;
    let first_deposit_amount = 1_000_000_000;
    let second_deposit_amount = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            initial_amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 6 months
    clock.increment_for_testing(six_months_ms);

    // 4. First Deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(first_deposit_amount, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Wait for another 6 months
    clock.increment_for_testing(six_months_ms);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 6. Get power and simulate second deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, second_deposit_amount, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 7. Actually perform second deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(second_deposit_amount, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 8. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_nearly_expired_2_year_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 2 years rounded to periods minus 1 second for lock to not be expired yet
    clock.increment_for_testing(common::to_period(TWO_YEARS_IN_MS / 1000) * 1000 - 1);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_on_expired_2_year_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 2 years rounded to periods minus 1 second for lock to not be expired yet
    clock.increment_for_testing(common::to_period(TWO_YEARS_IN_MS / 1000) * 1000);

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 4. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(delta == 0, 2);
        assert!(cannot_deposit == amount_to_deposit, 3);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // cannot deposit anything
    
    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_after_extending_lock() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let amount_to_lock = 1_000_000_000;
    let amount_to_deposit = 1_000_000;
    let one_year_in_days = 365;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 1 year
    clock.increment_for_testing(ONE_YEAR_MS);

    // 4. Extend lock for 1 more year
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::increase_unlock_time<SAIL>(
            &mut ve,
            &mut lock,
            TWO_YEARS_IN_DAYS, // the remaining time is 1 year, we are making it 2 years
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 5. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, amount_to_deposit, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 6. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(amount_to_deposit, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 7. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_simulate_deposit_after_deposit_and_extend() {
    let mut scenario = test_scenario::begin(ADMIN);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let six_months_ms = ONE_YEAR_MS / 2;

    // 1. Setup
    {
        config::test_init(scenario.ctx());
        setup::setup_distribution<SAIL>(&mut scenario, ADMIN, &clock);
    };

    let initial_amount_to_lock = 1_000_000_000;
    let first_deposit_amount = 1_000_000_000;
    let second_deposit_amount = 1_000_000;

    // 2. Create a 2-year lock
    scenario.next_tx(USER);
    {
        setup::mint_and_create_lock<SAIL>(
            &mut scenario,
            initial_amount_to_lock,
            TWO_YEARS_IN_DAYS,
            &clock
        );
    };

    // 3. Wait for 6 months
    clock.increment_for_testing(six_months_ms);

    // 4. Increase lock amount
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(first_deposit_amount, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 5. Wait for another 6 months
    clock.increment_for_testing(six_months_ms);

    // 6. Extend lock for 1 more year (total becomes 2 years from now)
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();

        voting_escrow::increase_unlock_time<SAIL>(
            &mut ve,
            &mut lock,
            TWO_YEARS_IN_DAYS,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    let mut power_before = 0;
    let mut simulated_delta = 0;

    // 7. Get initial power and simulate deposit
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        power_before = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);

        let (delta, cannot_deposit) = voting_escrow::simulate_depoist(&ve, lock_id, second_deposit_amount, &clock);
        simulated_delta = delta;
        assert!(cannot_deposit == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 8. Actually deposit
    scenario.next_tx(USER);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        let coin_to_deposit = coin::mint_for_testing<SAIL>(second_deposit_amount, scenario.ctx());

        voting_escrow::increase_amount<SAIL>(
            &mut ve,
            &mut lock,
            coin_to_deposit,
            &clock,
            scenario.ctx()
        );

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // 9. Check final power
    scenario.next_tx(USER);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = sui::object::id(&lock);

        let power_after = voting_escrow::balance_of_nft_at(&ve, lock_id, clock.timestamp_ms() / 1000);
        assert!(power_after == power_before + simulated_delta, 4);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Cleanup
    clock::destroy_for_testing(clock);
    scenario.end();
}

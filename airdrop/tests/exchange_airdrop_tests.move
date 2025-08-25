#[test_only]
module airdrop::exchange_airdrop_tests;
use airdrop::exchange_airdrop::{Self, ExchangeAirdrop};
use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use sui::coin::{Self};
use sui::object::{Self, ID};
use airdrop::setup::{Self, SAIL, PRE_SAIL};

const ADMIN: address = @0xAD;

const USER: address = @0x123;

#[test]
fun test_exchange_airdrop_successful_flow() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = 1_000_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, 0, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    let airdrop_amount = 100_000;

    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(airdrop_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    // Verify the airdrop is claimed by user and claimed amount
    scenario.next_tx(USER);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == airdrop_amount, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == airdrop_amount, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == airdrop_amount, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == airdrop_amount, 3);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
    };

    // Verify the exchange airdrop collected amount
    scenario.next_tx(ADMIN);
    {
        let exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        assert!(exchange_airdrop.collected() == airdrop_amount, 0);
        assert!(exchange_airdrop.reserves() == total_airdrop_amount - airdrop_amount, 1);
        assert!(exchange_airdrop.distributed() == airdrop_amount, 2);
        ts::return_shared(exchange_airdrop);
    };

    // Verify the voting escrow total supply
    scenario.next_tx(ADMIN);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow.total_locked() == airdrop_amount, 0);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000) == airdrop_amount, 1);
        ts::return_shared(voting_escrow);
    };

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
fun test_exchange_airdrop_multiple_claims() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = 1_000_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, 0, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    let airdrop_amount1 = 100_000;
    let airdrop_amount2 = 200_000;
    let airdrop_amount3 = 50_000;

    // Claim 1
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(airdrop_amount1, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    // Claim 2
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(airdrop_amount2, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    // Claim 3
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(airdrop_amount3, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    let total_claimed = airdrop_amount1 + airdrop_amount2 + airdrop_amount3;

    // Verify locks
    scenario.next_tx(USER);
    {
        let lock1 = scenario.take_from_sender<Lock>();
        let lock2 = scenario.take_from_sender<Lock>();
        let lock3 = scenario.take_from_sender<Lock>();
        
        let mut amounts = vector[lock1.get_amount(), lock2.get_amount(), lock3.get_amount()];
        
        let mut expected_amounts = vector[airdrop_amount1, airdrop_amount2, airdrop_amount3];
        
        let mut total_amount = 0;
        while (vector::length(&mut amounts) > 0) {
            let amount = vector::pop_back(&mut amounts);
            total_amount = total_amount + amount;
            let mut found = false;
            let mut i = 0;
            while (i < vector::length(&mut expected_amounts)) {
                if (vector::borrow(&expected_amounts, i) == &amount) {
                    vector::remove(&mut expected_amounts, i);
                    found = true;
                    break
                };
                i = i + 1;
            };
            assert!(found, 0);
        };

        assert!(total_amount == total_claimed, 1);

        scenario.return_to_sender(lock1);
        scenario.return_to_sender(lock2);
        scenario.return_to_sender(lock3);
    };

    // Verify the exchange airdrop collected amount
    scenario.next_tx(ADMIN);
    {
        let exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        assert!(exchange_airdrop.collected() == total_claimed, 0);
        assert!(exchange_airdrop.reserves() == total_airdrop_amount - total_claimed, 1);
        assert!(exchange_airdrop.distributed() == total_claimed, 2);
        ts::return_shared(exchange_airdrop);
    };

    // Verify the voting escrow total supply
    scenario.next_tx(ADMIN);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow.total_locked() == total_claimed, 0);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000) == total_claimed, 1);
        ts::return_shared(voting_escrow);
    };

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
fun test_exchange_airdrop_deposit_reserves_flow() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let initial_airdrop_amount = 100_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(initial_airdrop_amount, scenario.ctx());

    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, 0, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    // First claim (claim the whole initial airdrop)
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(initial_airdrop_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };
    
    // Deposit more reserves
    let additional_airdrop_amount = 500_000;
    scenario.next_tx(ADMIN);
    {
        let additional_coin = coin::mint_for_testing<SAIL>(additional_airdrop_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.deposit_reserves(additional_coin);
        ts::return_shared(exchange_airdrop);
    };

    // Second claim
    let second_claim_amount = 200_000;
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(second_claim_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };
    
    let total_claimed = initial_airdrop_amount + second_claim_amount;
    let total_reserves = initial_airdrop_amount + additional_airdrop_amount;
    
    // Verify locks
    scenario.next_tx(USER);
    {
        let lock1 = scenario.take_from_sender<Lock>();
        let lock2 = scenario.take_from_sender<Lock>();

        let mut amounts = vector[lock1.get_amount(), lock2.get_amount()];
        let mut expected_amounts = vector[initial_airdrop_amount, second_claim_amount];
        
        let mut total_amount = 0;
        while (vector::length(&mut amounts) > 0) {
            let amount = vector::pop_back(&mut amounts);
            total_amount = total_amount + amount;
            let mut found = false;
            let mut i = 0;
            while (i < vector::length(&mut expected_amounts)) {
                if (vector::borrow(&expected_amounts, i) == &amount) {
                    vector::remove(&mut expected_amounts, i);
                    found = true;
                    break
                };
                i = i + 1;
            };
            assert!(found, 0);
        };
        assert!(total_amount == total_claimed, 1);

        scenario.return_to_sender(lock1);
        scenario.return_to_sender(lock2);
    };

    // Verify the exchange airdrop collected amount
    scenario.next_tx(ADMIN);
    {
        let exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        assert!(exchange_airdrop.collected() == total_claimed, 0);
        assert!(exchange_airdrop.reserves() == total_reserves - total_claimed, 1);
        assert!(exchange_airdrop.distributed() == total_claimed, 2);
        ts::return_shared(exchange_airdrop);
    };

    // Verify the voting escrow total supply
    scenario.next_tx(ADMIN);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow.total_locked() == total_claimed, 0);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000) == total_claimed, 1);
        ts::return_shared(voting_escrow);
    };

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = 653209817586432800)]
fun test_claim_more_than_reserves_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = 100_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, 0, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    let claim_amount = total_airdrop_amount + 1;

    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(claim_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = 830914020413490200)]
fun test_claim_before_start_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = 100_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let future_start_time = clock::timestamp_ms(&clock) + 1000;
    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, future_start_time, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    let claim_amount = 10_000;

    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(claim_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    scenario.end();
    clock.destroy_for_testing();
}

#[test]
fun test_withdraw_collected_flow() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = 1_000_000;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let (exchange_airdrop, withdraw_cap) = exchange_airdrop::new<PRE_SAIL, SAIL>(airdrop_coin, 0, scenario.ctx());
    transfer::public_share_object(exchange_airdrop);
    transfer::public_transfer(withdraw_cap, ADMIN);

    let claim_amount = 100_000;

    // User claims airdrop
    scenario.next_tx(USER);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let coin_in = coin::mint_for_testing<PRE_SAIL>(claim_amount, scenario.ctx());
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        exchange_airdrop.get_airdrop(&mut voting_escrow, coin_in, &clock, scenario.ctx());
        ts::return_shared(exchange_airdrop);
        ts::return_shared(voting_escrow);
    };

    // Admin withdraws collected amount
    scenario.next_tx(ADMIN);
    {
        let mut exchange_airdrop = scenario.take_shared<ExchangeAirdrop<PRE_SAIL, SAIL>>();
        let cap = scenario.take_from_sender<exchange_airdrop::WithdrawCap>();
        let withdrawn_coin: coin::Coin<PRE_SAIL> = exchange_airdrop.withdraw_collected(&cap, claim_amount, scenario.ctx());
        
        assert!(coin::value(&withdrawn_coin) == claim_amount, 0);
        assert!(exchange_airdrop.collected() == 0, 1);

        transfer::public_transfer(withdrawn_coin, ADMIN);
        scenario.return_to_sender(cap);
        ts::return_shared(exchange_airdrop);
    };

    scenario.end();
    clock.destroy_for_testing();
}

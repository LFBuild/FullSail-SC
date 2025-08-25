#[test_only]
module airdrop::ve_airdrop_tests;
use airdrop::ve_airdrop::{Self, VeAirdrop};
use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use sui::coin::{Self};
use sui::object::{Self, ID};

use airdrop::setup::{Self, SAIL};

// These constants are generated using packages/playground/scripts/airdrop/merkle_tree_test.ts script
const ROOT: vector<u8> = x"b29b111a4e30864a5e1e63dfcf695d0170283efd3a00fc7cbcf628d73c9bc6b3";

const ADDRESS1: address = @0x432266954fd8b3b79b7fec2b7dc745c13b6a3984653581650ce3177762acc914;
const AMOUNT1: u64 = 1_337;
const PROOF1: vector<vector<u8>> = vector[x"40290573a9cd1141eee8614303d135c77d71d8267a951d12af39b429bb289cbb"];

const ADDRESS2: address = @0x55cd6ded9237cfc051a0eff5461f380c27b517fc8567af32907a09debb4f870f;
const AMOUNT2: u64 = 2_000;
const PROOF2: vector<vector<u8>> = vector[x"a21f455974990eae569c63f3d1b40e0aba2717df1ec1b5b484978f072a1369be"];

const TREE_2_ROOT: vector<u8> = x"e96a3736c79d61081240630b1cfec8e7cc700edaa66647cb620627863445ddbd";

const TREE_2_ADDRESS_1: address =
    @0x585b4574795226445728def2daf419bd56d264f440db34d4e79e84e4dc25b7f5;
const TREE_2_AMOUNT_1: u64 = 1_000_000_000_000;
const TREE_2_PROOF_1: vector<vector<u8>> = vector[
    x"da77b2059c272556a16b7989aefdbd72599b3cb67b796bbcb268b47570e161e4",
    x"91d6a29193e3d89f47d3c9f51e4aa8cc20ccff0c017e6a3fa7ec8a4f1b88b6c0",
];

const TREE_2_ADDRESS_2: address =
    @0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340;
const TREE_2_AMOUNT_2: u64 = 2_000_000_000_000;
const TREE_2_PROOF_2: vector<vector<u8>> = vector[
    x"5b22539248a67a8f83faad7c4b389a7b9232257cddd93c6b6a63461ef47f2bc3",
    x"91d6a29193e3d89f47d3c9f51e4aa8cc20ccff0c017e6a3fa7ec8a4f1b88b6c0",
];

const TREE_2_ADDRESS_3: address =
    @0xbc96556276d1fc405c77e0dfa68dbf5d83ec091fd354602bd17fd9d1a30ec258;
const TREE_2_AMOUNT_3: u64 = 3_000_000_000_000;
const TREE_2_PROOF_3: vector<vector<u8>> = vector[
    x"821a11d00540e3427b6ed48bd1d6ced7f15a57eef2083877017d50267f2f1b69",
];

const ADMIN: address = @0xAD;

fun claim_airdrop<SailCoinType>(scenario: &mut ts::Scenario, sender: address, proof: vector<vector<u8>>, amount: u64, clock: &Clock) {
    scenario.next_tx(sender);
    {
        let mut ve_airdrop = scenario.take_shared<VeAirdrop<SailCoinType>>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SailCoinType>>();
        ve_airdrop.get_airdrop(&mut voting_escrow, proof, amount, clock, scenario.ctx());
        ts::return_shared(ve_airdrop);
        ts::return_shared(voting_escrow);
    }
}

#[test]
fun test_ve_airdrop_successful_flow() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1 + AMOUNT2, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Claim the airdrop
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1, &clock);
    };

    // Verify the airdrop is claimed by address1 and claimed amount
    scenario.next_tx(ADDRESS1);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == AMOUNT1, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == AMOUNT1, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == AMOUNT1, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == AMOUNT1, 3);

        let ve_airdrop = scenario.take_shared<VeAirdrop<SAIL>>();
        assert!(ve_airdrop.has_account_claimed(PROOF1, AMOUNT1, ADDRESS1), 4);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
        ts::return_shared(ve_airdrop);
    };

    // Claim the airdrop
    scenario.next_tx(ADDRESS2);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS2, PROOF2, AMOUNT2, &clock);
    };

    // Verify the airdrop is claimed by address2 and claimed amount
    scenario.next_tx(ADDRESS2);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == AMOUNT2, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == AMOUNT2, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == AMOUNT2, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == AMOUNT2, 3);

        let ve_airdrop = scenario.take_shared<VeAirdrop<SAIL>>();
        assert!(ve_airdrop.has_account_claimed(PROOF2, AMOUNT2, ADDRESS2), 4);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
        ts::return_shared(ve_airdrop);
    };


    // verify the voting_escrow total supply
    scenario.next_tx(ADDRESS1);
    {
        let expected_total_supply = AMOUNT1 + AMOUNT2;
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow.total_locked() == expected_total_supply, 0);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000) == expected_total_supply, 1);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000 + 1_000_000_000) == expected_total_supply, 1);
        ts::return_shared(voting_escrow);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
fun test_ve_airdrop_successful_flow_tree_2() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let total_airdrop_amount = TREE_2_AMOUNT_1 + TREE_2_AMOUNT_2 + TREE_2_AMOUNT_3;
    let airdrop_coin = coin::mint_for_testing<SAIL>(total_airdrop_amount, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, TREE_2_ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Claim the airdrop for TREE_2_ADDRESS_1
    scenario.next_tx(TREE_2_ADDRESS_1);
    {
        claim_airdrop<SAIL>(&mut scenario, TREE_2_ADDRESS_1, TREE_2_PROOF_1, TREE_2_AMOUNT_1, &clock);
    };

    // Verify the airdrop is claimed by TREE_2_ADDRESS_1 and claimed amount
    scenario.next_tx(TREE_2_ADDRESS_1);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == TREE_2_AMOUNT_1, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == TREE_2_AMOUNT_1, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == TREE_2_AMOUNT_1, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == TREE_2_AMOUNT_1, 3);

        let ve_airdrop = scenario.take_shared<VeAirdrop<SAIL>>();
        assert!(ve_airdrop.has_account_claimed(TREE_2_PROOF_1, TREE_2_AMOUNT_1, TREE_2_ADDRESS_1), 4);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
        ts::return_shared(ve_airdrop);
    };

    // Claim the airdrop for TREE_2_ADDRESS_2
    scenario.next_tx(TREE_2_ADDRESS_2);
    {
        claim_airdrop<SAIL>(&mut scenario, TREE_2_ADDRESS_2, TREE_2_PROOF_2, TREE_2_AMOUNT_2, &clock);
    };

    // Verify the airdrop is claimed by TREE_2_ADDRESS_2 and claimed amount
    scenario.next_tx(TREE_2_ADDRESS_2);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == TREE_2_AMOUNT_2, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == TREE_2_AMOUNT_2, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == TREE_2_AMOUNT_2, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == TREE_2_AMOUNT_2, 3);

        let ve_airdrop = scenario.take_shared<VeAirdrop<SAIL>>();
        assert!(ve_airdrop.has_account_claimed(TREE_2_PROOF_2, TREE_2_AMOUNT_2, TREE_2_ADDRESS_2), 4);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
        ts::return_shared(ve_airdrop);
    };

    // Claim the airdrop for TREE_2_ADDRESS_3
    scenario.next_tx(TREE_2_ADDRESS_3);
    {
        claim_airdrop<SAIL>(&mut scenario, TREE_2_ADDRESS_3, TREE_2_PROOF_3, TREE_2_AMOUNT_3, &clock);
    };

    // Verify the airdrop is claimed by TREE_2_ADDRESS_3 and claimed amount
    scenario.next_tx(TREE_2_ADDRESS_3);
    {
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let (locked_balance, _) = voting_escrow.locked(lock_id);

        assert!(lock.get_amount() == TREE_2_AMOUNT_3, 0);
        assert!(locked_balance.is_permanent(), 1);
        assert!(locked_balance.amount() == TREE_2_AMOUNT_3, 2);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000) == TREE_2_AMOUNT_3, 3);
        assert!(voting_escrow.balance_of_nft_at(lock_id, clock.timestamp_ms()/1000 + 1_000_000_000) == TREE_2_AMOUNT_3, 3);

        let ve_airdrop = scenario.take_shared<VeAirdrop<SAIL>>();
        assert!(ve_airdrop.has_account_claimed(TREE_2_PROOF_3, TREE_2_AMOUNT_3, TREE_2_ADDRESS_3), 4);

        scenario.return_to_sender(lock);
        ts::return_shared(voting_escrow);
        ts::return_shared(ve_airdrop);
    };

    // verify the voting_escrow total supply
    scenario.next_tx(ADMIN);
    {
        let expected_total_supply = total_airdrop_amount;
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        assert!(voting_escrow.total_locked() == expected_total_supply, 0);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000) == expected_total_supply, 1);
        assert!(voting_escrow.total_supply_at(clock.timestamp_ms() / 1000 + 1_000_000_000) == expected_total_supply, 1);
        ts::return_shared(voting_escrow);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = suitears::airdrop::EAlreadyClaimed)]
fun test_ve_airdrop_double_claim_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Claim the airdrop for the first time
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1, &clock);
    };

    // Claim the airdrop for the second time - this should fail
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 0)]
fun test_claim_with_wrong_amount_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1 + 1, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Claim the airdrop with a wrong amount - this should fail
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1 + 1, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 0)]
fun test_claim_with_lower_amount_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Claim the airdrop with a lower amount - this should fail
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1 - 1, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 0)]
fun test_claim_with_other_users_proof_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT2, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // ADDRESS1 tries to claim the airdrop with proof from ADDRESS2 - this should fail
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF2, AMOUNT2, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 0)]
fun test_claim_with_wrong_root_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1, scenario.ctx());

    let ve_airdrop = ve_airdrop::new(airdrop_coin, TREE_2_ROOT, 0, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // ADDRESS1 tries to claim the airdrop from a ve_airdrop with a different root - this should fail
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}

#[test]
#[expected_failure(abort_code = suitears::airdrop::EHasNotStarted)]
fun test_claim_airdrop_not_started_fails() {
    let mut scenario = ts::begin(ADMIN);
    let clock = setup::setup<SAIL>(&mut scenario, ADMIN);
    let airdrop_coin = coin::mint_for_testing<SAIL>(AMOUNT1, scenario.ctx());

    // Create an airdrop that starts in the future.
    let future_start_time = clock::timestamp_ms(&clock) + 1000;
    let ve_airdrop = ve_airdrop::new(airdrop_coin, ROOT, future_start_time, &clock, scenario.ctx());
    transfer::public_share_object(ve_airdrop);

    // Try to claim the airdrop before it starts. This should fail.
    scenario.next_tx(ADDRESS1);
    {
        claim_airdrop<SAIL>(&mut scenario, ADDRESS1, PROOF1, AMOUNT1, &clock);
    };

    clock.destroy_for_testing();
    scenario.end();
}
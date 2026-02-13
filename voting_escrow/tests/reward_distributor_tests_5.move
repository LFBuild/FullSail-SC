#[test_only]
module voting_escrow::reward_distributor_tests_5;

use sui::test_scenario;
use sui::clock;
use sui::coin;
use std::unit_test;
use sui::test_utils;

use voting_escrow::reward_distributor;
use voting_escrow::common;
use voting_escrow::setup::{Self, SAIL};
use voting_escrow::voting_escrow::{Self as ve_module, VotingEscrow, Lock};
use voting_escrow::reward_distributor_cap::RewardDistributorCap;

public struct REWARD_COIN has drop {}

// ========= 50. test_rounding_does_not_create_tokens =========
// Multiple users with non-round small voting power shares. Verify
// sum(all claims) <= total tokens distributed (no over-distribution).

#[test]
fun test_rounding_does_not_create_tokens() {
    let admin = @0xAD;
    let user1 = @0x1001;
    let user2 = @0x1002;
    let user3 = @0x1003;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create 3 permanent locks with non-round amounts
    // Total: 666
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(333, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(222, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user3);
    {
        let sail = coin::mint_for_testing<SAIL>(111, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_1 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user2);
    let lock_id_2 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user3);
    let lock_id_3 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 777 at epoch 1 -> period 0 = 777
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(777, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 333 at epoch 2 -> period epoch = 333
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(333, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    let total_deposited = 777 + 333;

    // Claim all
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        let c3 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_3, scenario.ctx()
        );

        let sum = c1.value() + c2.value() + c3.value();
        // Floor rounding: sum of claims must be <= total deposited
        assert!(sum <= total_deposited, 1);
        assert!(total_deposited - sum <= 6, 2);
        // Verify remaining balance equals the rounding dust
        assert!(reward_distributor::balance(&rd) == total_deposited - sum, 2);
        // Each user gets a non-zero share
        assert!(c1.value() > 0, 3);
        assert!(c2.value() > 0, 4);
        assert!(c3.value() > 0, 5);

        unit_test::destroy(c1);
        unit_test::destroy(c2);
        unit_test::destroy(c3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 51. test_checkpoint_then_claim_same_epoch =========
// Checkpoint tokens multiple timesand claim in the same epoch

#[test]
fun test_checkpoint_then_claim_same_epoch() {
    let admin = @0xAD;
    let user1 = @0x1004;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create permanent lock
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K mid-epoch 0 (at 0.33*epoch)
    clock::increment_for_testing(&mut clock, common::epoch() / 3 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };


    // Checkpoint 100K mid-epoch 0 (at 0.5*epoch)
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Claim in the same epoch -> should get 0
    // last_token_time = 0.5*epoch, max_period = to_period(0.5*epoch) = 0
    // epoch_end = 0 (lock created at time 0), epoch_end >= max_period -> stop
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);
        assert!(claimable == 0, 1);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 0, 2);
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 52. test_claimable_idempotent =========
// Calling claimable multiple times without any state changes should
// return the same value each time (it's a read-only view).

#[test]
fun test_claimable_idempotent() {
    let admin = @0xAD;
    let user1 = @0x1005;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create permanent lock
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Call claimable 3 times -- all should return the same value
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();

        let c1 = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);
        let c2 = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);
        let c3 = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);

        assert!(c1 == c2, 1);
        assert!(c2 == c3, 2);
        assert!(c1 == 100_000, 3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 54. test_first_claim_uses_lock_creation_period =========
// When time_cursor_of is empty for a lock, the code initializes epoch_end
// from user_point_history[1].ts rounded to period. Verify the user doesn't
// get rewards before their first eligible epoch.

#[test]
fun test_first_claim_uses_lock_creation_period() {
    let admin = @0xAD;
    let user1 = @0x1007;
    let user2 = @0x1008;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // User 1: permanent lock created at time 0 (exists for all epochs)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_1 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD at time 0
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 200K at 2*epoch -> period 0 = 100K, period epoch = 100K
    clock::increment_for_testing(&mut clock, common::epoch() * 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(200_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // User 2 creates lock at 2.5*epoch (mid-epoch 2)
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user2);
    let lock_id_2 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Checkpoint 100K at 3*epoch -> period 2*epoch = 100K
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Verify claims
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        // User 1 (created at time 0): initial_period = 0.
        // Periods 0 and epoch: sole lock -> 100K + 100K = 200K.
        // Period 2*epoch: user1 1M + user2 1M = 2M -> 50K each.
        // Total user 1: 250K.
        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        assert!(c1.value() == 250_000, 1);

        // User 2 (created at 2.5*epoch): initial_period = to_period(2.5*epoch) = 2*epoch.
        // Skips periods 0 and epoch entirely (before lock creation).
        // Period 2*epoch: 50K.
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        assert!(c2.value() == 50_000, 2);

        // Total claimed = total deposited
        assert!(c1.value() + c2.value() == 300_000, 3);

        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 56. test_last_token_time_accessor =========
// Verify last_token_time returns the timestamp of the most recent
// checkpoint_token call.

#[test]
fun test_last_token_time_accessor() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create RD at time 0
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        // Initial last_token_time = 0 (creation time)
        assert!(reward_distributor::last_token_time(&rd) == 0, 1);
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint at epoch boundary
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(50_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        assert!(reward_distributor::last_token_time(&rd) == common::epoch(), 2);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint at 2.5*epoch (mid-epoch)
    clock::increment_for_testing(&mut clock, common::epoch() * 3 / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(25_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        assert!(reward_distributor::last_token_time(&rd) == common::epoch() * 5 / 2, 3);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 0 at 3*epoch
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        assert!(reward_distributor::last_token_time(&rd) == common::epoch() * 3, 4);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 57. test_distributor_with_multiple_checkpoint_token_across_many_epochs =========
// Simulate a realistic scenario: checkpoint different amounts every epoch
// for 10 epochs, with 3 users of varying lock sizes. Verify each user's
// final claim totals match expected proportional shares.

#[test]
fun test_distributor_with_multiple_checkpoint_token_across_many_epochs() {
    let admin = @0xAD;
    let user1 = @0x1009;
    let user2 = @0x100A;
    let user3 = @0x100B;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // 3 permanent locks: 100K, 300K, 600K (total 1M)
    // Shares: 10%, 30%, 60%
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(100_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(300_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user3);
    {
        let sail = coin::mint_for_testing<SAIL>(600_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_1 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user2);
    let lock_id_2 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user3);
    let lock_id_3 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // tokens are checkpointed 5 hours after epoch start, cos that's the realistic scenario
    clock::increment_for_testing(&mut clock, 5 * 60 * 60 * 1000);

    // Checkpoint 10 epochs with increasing amounts: 10K, 20K, ..., 100K
    // Total: 550K
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let mut i = 0u64;
        let mut amount = 10_000u64;
        while (i < 10) {
            clock::increment_for_testing(&mut clock, common::epoch() * 1000);
            // VE checkpoint every 5 epochs to keep total_supply_at iterations low
            if (i % 5 == 0) {
                ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
            };
            let coin = coin::mint_for_testing<REWARD_COIN>(amount, scenario.ctx());
            reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
            amount = amount + 10_000;
            i = i + 1;
        };

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };
    // last epoch has only partial rewards cos some are distributed in the next epoch in the next 5 hours. That's a realistic scenario.
    let expected_total = 10_000 + 20_000 + 30_000 + 40_000 + 50_000 + 60_000 + 70_000 + 80_000 + 90_000 + 97023;

    // Claim for all 3 users
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        let c3 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_3, scenario.ctx()
        );

        let expected_share_1 = expected_total / 10;
        let expected_share_2 = expected_total * 3 / 10;
        let expected_share_3 = expected_total * 6 / 10;

        assert!(expected_share_1 - c1.value() <= 10, 1);
        assert!(expected_share_2 - c2.value() <= 10, 2);
        assert!(expected_share_3 - c3.value() <= 10, 3);

        assert!(expected_total - (c1.value() + c2.value() + c3.value()) <= 20, 4);
        assert!(reward_distributor::balance(&rd) - 2977 <= 20, 5);

        unit_test::destroy(c1);
        unit_test::destroy(c2);
        unit_test::destroy(c3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 58. test_claiming_with_wrong_voting_escrow_object =========
// Claiming with a wrong VotingEscrow object should fail — after the first
// claim locks in the correct VE, using a different VE aborts with
// EVotingEscrowMismatch.

#[test]
#[expected_failure(abort_code = voting_escrow::reward_distributor::EVotingEscrowMismatch)]
fun test_claiming_with_wrong_voting_escrow_object() {
    let admin = @0xAD;
    let user1 = @0x100C;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create lock in the main VE (VE1, shared by setup)
    scenario.next_tx(user1);
    let ve1_id = {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let id = object::id(&ve);
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
        id
    };

    scenario.next_tx(user1);
    let lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create a second VotingEscrow (VE2) with a lock from the beginning
    scenario.next_tx(admin);
    let ve2_id = {
        let ve_publisher = ve_module::test_init(scenario.ctx());
        let (ve2, ve_cap2) = ve_module::create<SAIL>(
            &ve_publisher,
            object::id_from_address(@0xBEEF),
            &clock,
            scenario.ctx()
        );
        let id = object::id(&ve2);
        sui::transfer::public_share_object(ve2);
        sui::transfer::public_transfer(ve_cap2, admin);
        test_utils::destroy(ve_publisher);
        id
    };

    scenario.next_tx(user1);
    {
        let sail2 = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve2 = scenario.take_shared_by_id<VotingEscrow<SAIL>>(ve2_id);
        ve_module::create_lock<SAIL>(&mut ve2, sail2, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve2);
    };

    scenario.next_tx(user1);
    let ve2_lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD with VE1 identity, checkpoint tokens
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1), ve1_id, &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Verify correct VE1 gives 100K claimable
    scenario.next_tx(admin);
    {
        let ve1 = scenario.take_shared_by_id<VotingEscrow<SAIL>>(ve1_id);
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();

        let correct_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve1, lock_id
        );
        assert!(correct_claimable == 100_000, 1);

        test_scenario::return_shared(ve1);
        test_scenario::return_shared(rd);
    };

    // Try claimable with wrong VE2 — should abort because RD is bound to VE1
    scenario.next_tx(admin);
    {
        let ve2 = scenario.take_shared_by_id<VotingEscrow<SAIL>>(ve2_id);
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();

        // This should abort with EVotingEscrowMismatch
        let _wrong_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve2, ve2_lock_id
        );

        test_scenario::return_shared(ve2);
        test_scenario::return_shared(rd);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

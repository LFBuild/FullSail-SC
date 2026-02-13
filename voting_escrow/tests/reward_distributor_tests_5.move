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
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create 3 permanent locks with non-round amounts
    // Total: 333_333 + 222_222 + 111_111 = 666_666
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(333_333, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(222_222, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user3);
    {
        let sail = coin::mint_for_testing<SAIL>(111_111, scenario.ctx());
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
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 77_777 at epoch 1 -> period 0 = 77_777
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(77_777, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 33_333 at epoch 2 -> period epoch = 33_333
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(33_333, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    let total_deposited = 77_777 + 33_333;

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
// Checkpoint tokens and claim in the same epoch. The current epoch
// (incomplete) should NOT be claimable since max_period is the
// current period and the loop condition is epoch_end >= max_period.

#[test]
fun test_checkpoint_then_claim_same_epoch() {
    let admin = @0xAD;
    let user1 = @0x1004;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

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
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
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

    // Advance to epoch boundary, checkpoint 0 to finalize epoch 0
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Now epoch 0 is finalized -> claim should get 100K
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);
        assert!(claimable == 100_000, 3);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 100_000, 4);
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
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

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
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
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

// ========= 53. test_claim_after_start_resets_distribution =========
// Call start to reset timestamps. Verify that the lock doesn't earn
// rewards for periods before start_time, and only post-start rewards
// are distributed.

#[test]
fun test_claim_after_start_resets_distribution() {
    let admin = @0xAD;
    let user1 = @0x1006;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create permanent lock at time 0
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

    // Create RD at time 0 (start_time = 0)
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Verify initial start_time = 0
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        assert!(reward_distributor::start_time(&rd) == 0, 1);
        test_scenario::return_shared(rd);
    };

    // Advance to 3*epoch and call start -> resets start_time and last_token_time
    clock::increment_for_testing(&mut clock, common::epoch() * 3 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        reward_distributor::start(&mut rd, &cap, &clock);
        assert!(reward_distributor::start_time(&rd) == common::epoch() * 3, 2);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 100K at 4*epoch -> period 3*epoch = 100K
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

    // Claim: lock created at time 0, but start_time = 3*epoch.
    // epoch_end initialized to 0 (from lock creation), then bumped to
    // to_period(start_time) = 3*epoch. Only period 3*epoch is processed.
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id);
        assert!(claimable == 100_000, 3);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 100_000, 4);
        unit_test::destroy(claimed);

        // time_cursor should be 4*epoch (started from 3*epoch, processed one period)
        let cursor = reward_distributor::test_time_cursor_of(&rd, lock_id);
        assert!(cursor == common::epoch() * 4, 5);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
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
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

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
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
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
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create RD at time 0
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
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
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

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
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

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

        // Shares: 100K/1M=10%, 300K/1M=30%, 600K/1M=60%
        // All epoch amounts are multiples of 10K -> exact division, no rounding
        // user1: sum(1K, 2K, ..., 10K) = 55K
        // user2: sum(3K, 6K, ..., 30K) = 165K
        // user3: sum(6K, 12K, ..., 60K) = 330K
        assert!(c1.value() == 55_000, 1);
        assert!(c2.value() == 165_000, 2);
        assert!(c3.value() == 330_000, 3);

        // Total claimed = 550K, nothing left
        assert!(c1.value() + c2.value() + c3.value() == 550_000, 4);
        assert!(reward_distributor::balance(&rd) == 0, 5);

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
// Claiming with a wrong VotingEscrow object should fail — the lock_id
// doesn't exist in the wrong VE, so user_point_epoch returns 0 and the
// claim produces 0 rewards.

#[test]
fun test_claiming_with_wrong_voting_escrow_object() {
    let admin = @0xAD;
    let user1 = @0x100C;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create lock in the main VE (VE1, shared by setup)
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

    // Create RD, checkpoint tokens
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1), &clock, scenario.ctx()
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
        let ve1 = scenario.take_shared<VotingEscrow<SAIL>>();
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();

        let correct_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve1, lock_id
        );
        assert!(correct_claimable == 100_000, 1);

        test_scenario::return_shared(ve1);
        test_scenario::return_shared(rd);
    };

    // Create a second VotingEscrow (VE2) and try claiming with it
    scenario.next_tx(admin);
    {
        let ve_publisher = ve_module::test_init(scenario.ctx());
        let (ve2, ve_cap2) = ve_module::create<SAIL>(
            &ve_publisher,
            object::id_from_address(@0xBEEF),
            &clock,
            scenario.ctx()
        );

        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        // Using wrong VE2: claimable should be 0
        let wrong_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve2, lock_id
        );
        assert!(wrong_claimable == 0, 2);

        // Claiming with wrong VE2 should return 0
        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve2, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 0, 3);
        unit_test::destroy(claimed);

        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
        test_utils::destroy(ve2);
        test_utils::destroy(ve_cap2);
        test_utils::destroy(ve_publisher);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

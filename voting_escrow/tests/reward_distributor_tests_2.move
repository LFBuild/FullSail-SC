#[test_only]
module voting_escrow::reward_distributor_tests_2;

use sui::test_scenario;
use sui::clock;
use sui::coin;
use std::unit_test;

use voting_escrow::reward_distributor;
use voting_escrow::common;
use voting_escrow::setup::{Self, SAIL};
use voting_escrow::voting_escrow::{Self as ve_module, VotingEscrow, Lock};
use voting_escrow::reward_distributor_cap::RewardDistributorCap;

public struct REWARD_COIN has drop {}

// ========= 27. test_claimable_after_lock_expires =========

#[test]
fun test_claimable_after_lock_expires() {
    let admin = @0xAD;
    let user1 = @0xF1;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a 14-day non-permanent lock (expires at 2*epoch)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 14, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // Checkpoint 300K at 3*epoch -> 100K per period (0, epoch, 2*epoch)
        clock::increment_for_testing(&mut clock, common::epoch() * 3 * 1000);
        let coin = coin::mint_for_testing<REWARD_COIN>(300_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Period 0 (eval at epoch-1): lock has power -> earns 100K (sole lock gets 100%)
        // Period epoch (eval at 2*epoch-1): power ~ 0 (1 sec before expiry) -> earns 0
        // Period 2*epoch (eval at 3*epoch-1): lock expired -> earns 0
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 100_000, 1);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 28. test_claimable_permanent_lock_constant_power =========

#[test]
fun test_claimable_permanent_lock_constant_power_non_permanent_decay() {
    let admin = @0xAD;
    let user1 = @0xF2;
    let user2 = @0xF3;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // User 1: permanent lock of 1M (constant voting power)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: non-permanent lock of 1M, max duration (1456 days = max_lock_time)
    // Starts with ~equal power but decays each epoch
    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 1456, false, &clock, scenario.ctx());
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

    // Create RD at time 0, share it for multi-tx claim pattern
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 (all in period 0)
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

    // Claim epoch 0 for both
    scenario.next_tx(admin);
    let (perm_0, decay_0) = {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        let v1 = c1.value();
        let v2 = c2.value();
        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
        (v1, v2)
    };

    // Checkpoint 100K at epoch 2 (all in period epoch)
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

    // Claim epoch 1 for both
    scenario.next_tx(admin);
    let (perm_1, decay_1) = {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        let v1 = c1.value();
        let v2 = c2.value();
        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
        (v1, v2)
    };

    // Checkpoint 100K at epoch 3 (all in period 2*epoch)
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

    // Claim epoch 2 for both
    scenario.next_tx(admin);
    let (perm_2, decay_2) = {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        let v1 = c1.value();
        let v2 = c2.value();
        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
        (v1, v2)
    };

    // Voting power at eval time (epoch_end + epoch - 1):
    //   Decaying lock: epoch 0 → 995,192 | epoch 1 → 990,384 | epoch 2 → 985,576
    //   Permanent lock: 1,000,000 (constant)
    // Total supply:    epoch 0 → 1,995,192 | epoch 1 → 1,990,384 | epoch 2 → 1,985,576
    // Claim = floor(user_power * 100,000 / total_supply)

    // Epoch 0: perm = floor(1M * 100K / 1,995,192) = 50,120
    //          decay = floor(995,192 * 100K / 1,995,192) = 49,879
    assert!(perm_0 == 50_120, 1);
    assert!(decay_0 == 49_879, 2);

    // Epoch 1: perm = floor(1M * 100K / 1,990,384) = 50,241
    //          decay = floor(990,384 * 100K / 1,990,384) = 49,758
    assert!(perm_1 == 50_241, 3);
    assert!(decay_1 == 49_758, 4);

    // Epoch 2: perm = floor(1M * 100K / 1,985,576) = 50,363
    //          decay = floor(985,576 * 100K / 1,985,576) = 49,636
    assert!(perm_2 == 50_363, 5);
    assert!(decay_2 == 49_636, 6);

    // Permanent lock share grows as decaying lock weakens
    assert!(perm_0 < perm_1 && perm_1 < perm_2, 7);
    // Decaying lock share shrinks each epoch
    assert!(decay_0 > decay_1 && decay_1 > decay_2, 8);
    // Floor rounding loses 1 token per epoch (sum = 99,999 not 100,000)
    assert!(perm_0 + decay_0 == 99_999, 9);
    assert!(perm_1 + decay_1 == 99_999, 10);
    assert!(perm_2 + decay_2 == 99_999, 11);

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 29. test_claimable_respects_start_time =========

#[test]
fun test_claimable_respects_start_time() {
    let admin = @0xAD;
    let user1 = @0xF3;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

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

    // Create RD at time 0, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Advance to 2*epoch and call start -> start_time = 2.5*epoch
    clock::increment_for_testing(&mut clock, common::epoch() * 5/2 * 1000);

    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        reward_distributor::start(&mut rd, &cap, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Advance to 5*epoch and checkpoint 300K -> 100K per period (2*epoch, 3*epoch, 4*epoch)
    clock::increment_for_testing(&mut clock, common::epoch() * 5/2 * 1000);

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let coin = coin::mint_for_testing<REWARD_COIN>(300_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Lock created at time 0 but start_time = 2.5*epoch
        // checkpoint skips epoch before start time as well as claimable.
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 300_000, 1);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 30. test_claimable_with_no_tokens_distributed =========

#[test]
fun test_claimable_with_no_tokens_distributed() {
    let admin = @0xAD;
    let user1 = @0xF4;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

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

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // No checkpoint_token called -- claimable should be 0
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 0, 1);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 31. test_claimable_zero_total_supply_epoch =========

#[test]
fun test_claimable_zero_total_supply_epoch() {
    let admin = @0xAD;
    let user1 = @0xF5;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a 7-day non-permanent lock (expires at epoch)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 7, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Advance past lock expiry, create RD, checkpoint tokens
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // Checkpoint 100K at 2*epoch -> tokens land in period epoch
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let deposit = 100_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Lock expired -- total_supply = 0 in period epoch
        // non_zero_total_supply fallback (1) prevents division by zero
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 0, 1);
        assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == deposit, 2);

        // Rewards stay in the distributor
        assert!(reward_distributor::balance(&rd) == deposit, 2);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 32. test_claimable_partial_period_tokens =========

#[test]
fun test_claimable_partial_period_tokens() {
    let admin = @0xAD;
    let user1 = @0xF6;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock (sole lock)
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

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // Checkpoint 150K at 1.5*epoch -- tokens split proportionally
        // Period 0: 100K (2/3), Period epoch: 50K (1/3)
        clock::increment_for_testing(&mut clock, (common::epoch() + common::epoch() / 2) * 1000);
        let deposit = 150_000u64;
        let coin1 = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        // Checkpoint 0 at 2*epoch to finalize
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
        let coin2 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Sole permanent lock earns 100% -- claimable reflects partial period amounts
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == deposit, 1);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 33. test_claimable_50_epoch_iteration_limit =========

#[test]
fun test_claimable_50_epoch_iteration_limit() {
    let admin = @0xAD;
    let user1 = @0xF7;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock (sole lock)
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

    // Create RD at time 0, share it (need claim to advance cursor)
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint rewards in batches of 17 epochs = 51 periods total, 10K each.
    // Also call ve_module::checkpoint periodically to create global checkpoints,
    // reducing total_supply_at iteration cost.
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

        clock::increment_for_testing(&mut clock, common::epoch() * 17 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c1 = coin::mint_for_testing<REWARD_COIN>(170_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c1, &clock);

        clock::increment_for_testing(&mut clock, common::epoch() * 17 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c2 = coin::mint_for_testing<REWARD_COIN>(170_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c2, &clock);

        clock::increment_for_testing(&mut clock, common::epoch() * 17 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c3 = coin::mint_for_testing<REWARD_COIN>(170_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c3, &clock);

        // Checkpoint 0 at 52*epoch to finalize
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let c4 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c4, &clock);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Check claimable, claim, then check remaining
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        // First claimable: loop capped at 50 iterations -> 50 epochs * 10K = 500K
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable1 == 500_000, 1);

        // Claim to advance cursor past the first 50 epochs
        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 500_000, 2);
        unit_test::destroy(claimed);

        // Second claimable: remaining 1 epoch * 10K = 10K
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable2 == 10_000, 3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 34. test_claimable_reads_voting_power_at_epoch_end =========

#[test]
fun test_claimable_reads_voting_power_at_epoch_end() {
    let admin = @0xAD;
    let user1 = @0xF8;
    let user2 = @0xF9;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // User 1: 7-day non-permanent lock (expires exactly at epoch boundary)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 7, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock (constant power)
    scenario.next_tx(user2);
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

    scenario.next_tx(user2);
    let lock_id_2 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // Checkpoint 100K at 2*epoch -> 50K in period 0, 50K in period epoch
        clock::increment_for_testing(&mut clock, common::epoch() * 2 * 1000);
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Period 0: eval at epoch-1 (last second of epoch 0).
        // Non-permanent lock expires at epoch, so at epoch-1 it has 1_000_000_000_000 / 125798400 = 7949 voting power (125798400 is max lock duration).
        // 50k is divided at the epoch 0 across two locks. At epoch 1 it all is redirected to the second lock as it is the only lock that has voting power.
        let expected_claimable1 = 50_000 * 7949u64 / 1_007_949;
        let expected_claimable2 = 50_000 * 1_000_000u64 / 1_007_949 + 50_000;

        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );

        // Non-permanent lock earns 0 (power rounds to 0 at eval time)
        assert!(claimable1 == expected_claimable1, 1);
        // Permanent lock earns everything
        assert!(claimable2 == expected_claimable2, 2);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claim_returns_correct_coin() {
    let admin = @0xAD;
    let user1 = @0xC1;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock (sole lock, 100% voting power)
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

    // Create RD, share it for multi-tx claim
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 200K at epoch boundary
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(200_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Verify claimable, then claim and check returned coin matches
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 200_000, 1);

        let claimed_coin = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed_coin.value() == claimable, 2);
        unit_test::destroy(claimed_coin);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 37. test_claim_updates_time_cursor =========

#[test]
fun test_claim_updates_time_cursor() {
    let admin = @0xAD;
    let user1 = @0xC2;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 boundary (covers period 0)
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

    // Before any claim, time_cursor_of should be 0 (not set)
    scenario.next_tx(admin);
    {
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        assert!(reward_distributor::test_time_cursor_of(&rd, lock_id) == 0, 1);
        test_scenario::return_shared(rd);
    };

    // Claim epoch 0
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 100_000, 2);
        unit_test::destroy(claimed);

        // After claiming epoch 0, cursor should advance to epoch (start of next epoch)
        let cursor_after_first = reward_distributor::test_time_cursor_of(&rd, lock_id);
        assert!(cursor_after_first == common::epoch(), 3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 50K at epoch 2 boundary (covers period epoch)
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(50_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Claim epoch 1 and verify cursor advances again
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 50_000, 4);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 50_000, 5);
        unit_test::destroy(claimed);

        // After claiming epoch 1, cursor should advance to 2*epoch
        let cursor_after_second = reward_distributor::test_time_cursor_of(&rd, lock_id);
        assert!(cursor_after_second == common::epoch() * 2, 6);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 38. test_claim_twice_no_double_counting =========

#[test]
fun test_claim_twice_no_double_counting() {
    let admin = @0xAD;
    let user1 = @0xC3;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 300K at epoch boundary
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(300_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // First claim: should get 300K
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimed1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed1.value() == 300_000, 1);
        unit_test::destroy(claimed1);

        // Second claim immediately: should get 0
        let claimed2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed2.value() == 0, 2);
        unit_test::destroy(claimed2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 39. test_claim_twice_with_new_rewards_between =========

#[test]
fun test_claim_twice_with_new_rewards_between() {
    let admin = @0xAD;
    let user1 = @0xC4;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 boundary
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

    // First claim: 100K (epoch 0)
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimed1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed1.value() == 100_000, 1);
        unit_test::destroy(claimed1);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Checkpoint 250K at epoch 2 boundary (new rewards for epoch 1)
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(250_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Second claim: should only get 250K (epoch 1 rewards only)
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimed2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed2.value() == 250_000, 2);
        unit_test::destroy(claimed2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 40. test_claim_reduces_balance =========

#[test]
fun test_claim_reduces_balance() {
    let admin = @0xAD;
    let user1 = @0xC5;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 500K at epoch boundary
    let deposit = 500_000u64;
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Balance before claim equals the deposited amount
        assert!(reward_distributor::balance(&rd) == deposit, 1);

        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Claim and verify balance decreases
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let balance_before = reward_distributor::balance(&rd);
        assert!(balance_before == deposit, 2);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        let claimed_amount = claimed.value();
        assert!(claimed_amount == deposit, 3);
        unit_test::destroy(claimed);

        let balance_after = reward_distributor::balance(&rd);
        assert!(balance_after == balance_before - claimed_amount, 4);
        assert!(balance_after == 0, 5);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 41. test_claim_with_wrong_cap_aborts =========

#[test]
#[expected_failure(abort_code = 159517009221984420)] // ERewardDistributorInvalid
fun test_claim_with_wrong_cap_aborts() {
    let admin = @0xAD;
    let user1 = @0xC6;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        // Create two separate reward distributors -> two separate caps
        let (mut rd1, _cap1) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        let (_rd2, cap2) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x2),
            ve_id,
            &clock,
            scenario.ctx()
        );

        // Checkpoint tokens into rd1
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd1, &_cap1, coin, &clock);

        // Attempt to claim from rd1 using cap2 -> should abort
        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd1, &cap2, &ve, lock_id, scenario.ctx()
        );
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd1);
        unit_test::destroy(_cap1);
        unit_test::destroy(_rd2);
        unit_test::destroy(cap2);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 42. test_claim_zero_reward_no_event =========

#[test]
fun test_claim_zero_reward() {
    let admin = @0xAD;
    let user1 = @0xC7;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD with no tokens checkpointed — claimable is 0
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let (mut rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 0, 1);

        // Claim should succeed but return a zero-value coin
        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 0, 2);
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 43. test_claim_multiple_users_sequentially =========

#[test]
fun test_claim_multiple_users_sequentially() {
    let admin = @0xAD;
    let user1 = @0xD1;
    let user2 = @0xD2;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // User 1: permanent lock of 1M
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock of 1M (equal power)
    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // Get lock IDs
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 1M at epoch boundary
    let deposit = 1_000_000u64;
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // User 1 claims first
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let balance_before = reward_distributor::balance(&rd);
        assert!(balance_before == deposit, 1);

        let claimed1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        // Equal power -> 50% each
        assert!(claimed1.value() == deposit / 2, 2);
        let balance_after_1 = reward_distributor::balance(&rd);
        assert!(balance_after_1 == deposit - claimed1.value(), 3);
        unit_test::destroy(claimed1);

        // User 2 claims next
        let claimed2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );
        assert!(claimed2.value() == deposit / 2, 4);
        let balance_after_2 = reward_distributor::balance(&rd);
        assert!(balance_after_2 == balance_after_1 - claimed2.value(), 5);
        assert!(balance_after_2 == 0, 6);
        unit_test::destroy(claimed2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 44. test_claim_after_50_epochs_then_claim_remaining =========

#[test]
fun test_claim_after_50_epochs_then_claim_remaining() {
    let admin = @0xAD;
    let user1 = @0xC8;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Distribute 10K per epoch across 70 epochs.
    // Checkpoint in batches of ~17-18 epochs with ve checkpoints to keep
    // total_supply_at iteration cost low.
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();

        // Batch 1: epochs 0-17 (18 epochs, 180K)
        clock::increment_for_testing(&mut clock, common::epoch() * 18 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c1 = coin::mint_for_testing<REWARD_COIN>(180_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c1, &clock);

        // Batch 2: epochs 18-35 (18 epochs, 180K)
        clock::increment_for_testing(&mut clock, common::epoch() * 18 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c2 = coin::mint_for_testing<REWARD_COIN>(180_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c2, &clock);

        // Batch 3: epochs 36-53 (18 epochs, 180K)
        clock::increment_for_testing(&mut clock, common::epoch() * 18 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c3 = coin::mint_for_testing<REWARD_COIN>(180_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c3, &clock);

        // Batch 4: epochs 54-69 (16 epochs, 160K)
        clock::increment_for_testing(&mut clock, common::epoch() * 16 * 1000);
        ve_module::checkpoint<SAIL>(&mut ve, &clock, scenario.ctx());
        let c4 = coin::mint_for_testing<REWARD_COIN>(160_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c4, &clock);

        // Finalize: checkpoint 0 at epoch 71
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let c5 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, c5, &clock);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // First claim: capped at 50 epochs -> 500K
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable1 == 500_000, 1);

        let claimed1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed1.value() == 500_000, 2);
        unit_test::destroy(claimed1);

        // Second claim: remaining 20 epochs -> 200K
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable2 == 200_000, 3);

        let claimed2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed2.value() == 200_000, 4);
        unit_test::destroy(claimed2);

        // Third claim: nothing left
        let claimable3 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable3 == 0, 5);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 45. test_claim_not_finalized_epoch =========

#[test]
fun test_claim_not_finalized_epoch() {
    let admin = @0xAD;
    let user1 = @0xC9;
    let mut scenario = test_scenario::begin(admin);
    let (mut clock, ve_id) = setup::setup_v2<SAIL>(&mut scenario, admin);

    // Create a permanent lock
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create_v2<REWARD_COIN>(
            object::id_from_address(@0x1),
            ve_id,
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Notify 100K mid-epoch 0 (epoch 0 not finalized yet)
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

    // Try to claim mid-epoch: should get 0 (epoch not finalized —
    // last_token_time = 0.5*epoch, max_period = to_period(0.5*epoch) = 0)
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 0, 1);
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Advance to epoch 1 boundary and checkpoint 0 to finalize epoch 0.
    // This advances last_token_time to the epoch boundary, locking period 0 = 100K.
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

    // Notify a significant amount (500K) mid-epoch 1.
    // All 500K lands in period 1 since last_token_time is at the epoch boundary.
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(500_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Claim now: last_token_time = 1.5*epoch, max_period = to_period(1.5*epoch) = epoch.
    // Only epoch 0 is claimable (period 0 finalized with 100K).
    // Epoch 1 is NOT claimable — last_token_time hasn't passed the epoch 1 boundary.
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 100_000, 2);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 100_000, 3);
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Advance to epoch 2 boundary, checkpoint 0 to finalize epoch 1
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

    // Now epoch 1 is finalized — claim the remaining 500K
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 500_000, 4);

        let claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id, scenario.ctx()
        );
        assert!(claimed.value() == 500_000, 5);
        unit_test::destroy(claimed);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

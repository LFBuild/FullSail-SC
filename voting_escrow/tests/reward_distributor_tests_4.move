#[test_only]
module voting_escrow::reward_distributor_tests_4;

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

// ========= 45. test_claim_after_lock_split =========
// User splits their lock into two new locks. The old (nulled) lock should still
// be claimable for the epochs before the split epoch (excluding the epoch of
// the split). New locks start fresh — claimable for old epochs should be zero.
// The new locks should start claim from the epoch the split happened and
// continue in the next epochs.

#[test]
fun test_claim_after_lock_split() {
    let admin = @0xAD;
    let user1 = @0xE1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Enable split for user1
    scenario.next_tx(admin);
    {
        let ve_publisher = ve_module::test_init(scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let team_cap = ve_module::create_team_cap(&ve, &ve_publisher, scenario.ctx());
        ve_module::toggle_split<SAIL>(&mut ve, &team_cap, user1, true);
        test_scenario::return_shared(ve);
        test_utils::destroy(team_cap);
        test_utils::destroy(ve_publisher);
    };

    // Create a permanent lock of 1M (sole lock)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_old = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 boundary → period 0 = 100K
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

    // Checkpoint 100K at epoch 2 boundary → period epoch = 100K
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

    // Split lock mid-epoch 2 (at 2.5*epoch): 600K + 400K
    // old lock gets nulled, two new locks created
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(user1);
    let (lock_id_a, lock_id_b) = {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id_old);
        let (lock_a, lock_b) = ve_module::split<SAIL>(
            &mut ve,
            &mut lock,
            400_000, // split amount for lock_b
            &clock,
            scenario.ctx()
        );
        let id_a = object::id(&lock_a);
        let id_b = object::id(&lock_b);
        sui::transfer::public_transfer(lock_a, user1);
        sui::transfer::public_transfer(lock_b, user1);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
        (id_a, id_b)
    };

    // Checkpoint 100K at epoch 3 → period 2*epoch = 100K
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

    // Checkpoint 100K at epoch 4 → period 3*epoch = 100K
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

    // Checkpoint 0 at epoch 5 to finalize epoch 4
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
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

        // Old lock (nulled mid-epoch 2 at 2.5*epoch): claimable for epochs 0, 1 only.
        // Period 0 eval (epoch-1): 1M power, sole lock → 100K
        // Period epoch eval (2*epoch-1): 1M power (not yet nulled) → 100K
        // Period 2*epoch eval (3*epoch-1): nulled at 2.5*epoch → 0
        let old_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_old
        );
        assert!(old_claimable == 200_000, 1);

        let old_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_old, scenario.ctx()
        );
        assert!(old_claimed.value() == 200_000, 2);
        unit_test::destroy(old_claimed);

        // New lock A (600K permanent, created at 2.5*epoch):
        // initial_period = to_period(2.5*epoch) = 2*epoch, old epochs skipped.
        // Period 2*epoch eval (3*epoch-1): 600K / 1M * 100K = 60K
        // Period 3*epoch eval (4*epoch-1): 600K / 1M * 100K = 60K
        let a_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_a
        );
        assert!(a_claimable == 120_000, 3);

        let a_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_a, scenario.ctx()
        );
        assert!(a_claimed.value() == 120_000, 4);
        unit_test::destroy(a_claimed);

        // New lock B (400K permanent, created at 2.5*epoch):
        // Period 2*epoch: 400K / 1M * 100K = 40K
        // Period 3*epoch: 400K / 1M * 100K = 40K
        let b_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_b
        );
        assert!(b_claimable == 80_000, 5);

        let b_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_b, scenario.ctx()
        );
        assert!(b_claimed.value() == 80_000, 6);
        unit_test::destroy(b_claimed);

        // Total claimed: 200K + 120K + 80K = 400K (total deposited)
        assert!(reward_distributor::balance(&rd) == 0, 7);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 46.1 test_claim_after_deposit_for_increases_future_rewards =========
// User deposits more tokens into their lock mid-epoch. Future epochs, starting
// from the epoch the deposit happened in, should reflect higher voting power and
// thus higher rewards. All rewards are claimed in one go at the end.

#[test]
fun test_claim_after_deposit_for_increases_future_rewards() {
    let admin = @0xAD;
    let user1 = @0xE2;
    let user2 = @0xE3;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1: permanent lock of 1M
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock of 1M (equal power to user 1)
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 → period 0 = 100K
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

    // User 1 deposits 1M more mid-epoch 1 (at 1.5*epoch).
    // Now user 1 has 2M, user 2 has 1M.
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id_1);
        let extra_sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        ve_module::deposit_for<SAIL>(&mut ve, &mut lock, extra_sail, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Checkpoint 100K at epoch 2 → period epoch = 100K
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

    // Claim all rewards in one go
    // Epoch 0 (period 0): user1 1M, user2 1M, total 2M → 50K each
    // Epoch 1 (period epoch): user1 2M, user2 1M, total 3M
    //   user1 = floor(2M/3M * 100K) = 66_666
    //   user2 = floor(1M/3M * 100K) = 33_333
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

        // User 1: 50K (epoch 0) + 66_666 (epoch 1) = 116_666
        assert!(c1.value() == 116_666, 1);
        // User 2: 50K (epoch 0) + 33_333 (epoch 1) = 83_333
        assert!(c2.value() == 83_333, 2);

        // User 1 earned more overall thanks to the mid-epoch deposit
        assert!(c1.value() > c2.value(), 3);

        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 46.2 test_claim_after_extend_lock_duration =========
// User increases locking duration mid-epoch. Future rewards, starting from the
// epoch the extension happened in, should reflect higher voting power.
// All rewards claimed in one go at the end.

#[test]
fun test_claim_after_extend_lock_duration() {
    let admin = @0xAD;
    let user1 = @0xE4;
    let user2 = @0xE5;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1: non-permanent lock of 1M, 182 days (= 26 weeks = 1/8 of max_lock_time)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock of 1M (constant power reference)
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 → period 0 = 100K
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

    // Snapshot epoch 0 claimable before extension to verify the pre-extension share
    scenario.next_tx(admin);
    let (claimable_1_e0, claimable_2_e0) = {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();

        let c1 = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id_1);
        let c2 = reward_distributor::claimable<SAIL, REWARD_COIN>(&rd, &ve, lock_id_2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        (c1, c2)
    };

    // User 1 with 182-day lock has ~1/8 of max voting power → much less than user 2
    assert!(claimable_1_e0 < claimable_2_e0, 1);

    // User 1 extends lock duration to 1456 days (max) mid-epoch 1
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id_1);
        ve_module::increase_unlock_time<SAIL>(
            &mut ve, &mut lock, 1456, &clock, scenario.ctx()
        );
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Checkpoint 100K at epoch 2 → period epoch = 100K
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

    // Claim all rewards in one go (epoch 0 + epoch 1)
    //
    // Epoch 0 (period 0): user1 has 120192 of voting power, user2 has 1M permanent.
    //   user1 gets claimable_1_e0, user2 gets claimable_2_e0.
    //
    // Epoch 1 (period epoch): after extension to max duration, user1 power ≈ 995K
    //   (same as test_28's max-duration lock). Nearly equal to user2's 1M.
    //   user1 gets 49_879, user2 gets 50_120 (matches test_28 epoch 0 values).
    scenario.next_tx(admin);
    {

        let expected_c1_e0 = 10729;
        let expected_c2_e0 = 89270;
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let c1 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_1, scenario.ctx()
        );
        let c2 = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_2, scenario.ctx()
        );

        assert!(claimable_1_e0 == expected_c1_e0, 1);
        assert!(claimable_2_e0 == expected_c2_e0, 2);

        // Verify totals = epoch 0 share + epoch 1 share
        assert!(c1.value() == 10729 + 49_879, 2);
        assert!(c2.value() == 89270 + 50_120, 3);

        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 47.1 test_claim_after_lock_permanent_toggle =========
// User toggles on permanent lock. Verify voting power stops decaying and rewards
// reflect constant power going forward.

#[test]
fun test_claim_after_lock_permanent_toggle() {
    let admin = @0xAD;
    let user1 = @0xE6;
    let user2 = @0xE7;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1: non-permanent lock of 1M, max duration (1456 days)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 1456, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock of 1M (constant power reference)
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 → period 0 = 100K
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

    // Claim epoch 0 for both — user 1 decaying, user 2 permanent
    scenario.next_tx(admin);
    let (decay_e0, perm_e0) = {
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

    // Before toggle: user 1 has slightly less power than user 2 due to decay
    assert!(decay_e0 < perm_e0, 1);
    assert!(decay_e0 == 49879, 2);
    assert!(perm_e0 == 50120, 3);

    // User 1 toggles permanent ON at epoch 1 boundary
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id_1);
        ve_module::lock_permanent<SAIL>(&mut ve, &mut lock, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Checkpoint 100K at epoch 2 → period epoch = 100K
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

    // Claim epoch 1 for both — now both are permanent with equal power
    scenario.next_tx(admin);
    let (perm_1_e1, perm_2_e1) = {
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

    // After toggle: both locks are permanent with 1M each → equal 50/50
    assert!(perm_1_e1 == 50_000, 2);
    assert!(perm_2_e1 == 50_000, 3);

    // User 1's share went up from < 50K to exactly 50K (no more decay)
    assert!(perm_1_e1 > decay_e0, 4);

    // Checkpoint 100K at epoch 3 → period 2*epoch = 100K
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

    // Claim epoch 2 — still equal since both permanent
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

        // Power is constant — same split as epoch 1
        assert!(c1.value() == 50_000, 5);
        assert!(c2.value() == 50_000, 6);

        unit_test::destroy(c1);
        unit_test::destroy(c2);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 47.2 test_claim_after_lock_permanent_off =========
// User starts with permanent:true lock and then toggles permanent off. The
// voting power should start decaying therefore reward share should decay too.

#[test]
fun test_claim_after_lock_permanent_off() {
    let admin = @0xAD;
    let user1 = @0xE8;
    let user2 = @0xE9;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1: permanent lock of 1M
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2: permanent lock of 1M (constant power reference)
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

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 → period 0 = 100K
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

    // Claim epoch 0 — both permanent, equal 50/50
    scenario.next_tx(admin);
    let (perm_e0_1, perm_e0_2) = {
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

    assert!(perm_e0_1 == 50_000, 1);
    assert!(perm_e0_2 == 50_000, 2);

    // User 1 toggles permanent OFF at epoch 1 boundary
    // unlock_permanent sets end = to_period(current_time + max_lock_time)
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender_by_id<Lock>(lock_id_1);
        ve_module::unlock_permanent<SAIL>(&mut ve, &mut lock, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
    };

    // Checkpoint 100K at epoch 2 → period epoch = 100K
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

    // Claim epoch 1 — user 1 now decaying, user 2 still permanent
    scenario.next_tx(admin);
    let (decay_e1, perm_e1) = {
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

    // After toggling off: user 1 is now decaying, so gets less than 50K
    assert!(decay_e1 < perm_e0_1, 3);
    // User 2 (still permanent) gets more than 50K now
    assert!(perm_e1 > perm_e0_2, 4);
    assert!(decay_e1 == 49879, 5);
    assert!(perm_e1 == 50120, 6);

    // Checkpoint 100K at epoch 3 → period 2*epoch = 100K
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

    // Claim epoch 2 — user 1 decayed more, user 2 gains more
    scenario.next_tx(admin);
    let (decay_e2, perm_e2) = {
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

    // User 1's share continues to decay each epoch
    assert!(decay_e2 < decay_e1, 5);
    // User 2's share continues to grow
    assert!(perm_e2 > perm_e1, 6);
    assert!(decay_e2 == 49758, 7);
    assert!(perm_e2 == 50241, 8);

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 48. test_claim_with_merge =========
// User merges lock A into lock B. Lock A gets nulled, lock B is updated
// with combined amount. Lock A (nulled) should still be claimable for old
// rewards before the epoch of the merge (excluding the epoch of the merge).
// Lock B's increased power should earn more in future epochs starting from
// the epoch the merge happened in.

#[test]
fun test_claim_with_merge() {
    let admin = @0xAD;
    let user1 = @0xEA;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create two permanent locks: A = 400K (non-permanent, source for merge),
    // B = 600K (permanent, target for merge)
    // Note: merge requires lock_a (source) is NOT permanent
    scenario.next_tx(user1);
    {
        let sail_a = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail_a, 1456, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_a = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user1);
    {
        let sail_b = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail_b, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_b = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Checkpoint 100K at epoch 1 → period 0 = 100K
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

    // Checkpoint 100K at epoch 2 → period epoch = 100K
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

    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);

    // Merge lock_a into lock_b
    // lock_a gets nulled, lock_b gets updated with combined 1M
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_id_a);
        let mut lock_b = scenario.take_from_sender_by_id<Lock>(lock_id_b);
        ve_module::merge<SAIL>(&mut ve, &mut lock_a, &mut lock_b, &clock, scenario.ctx());
        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        test_scenario::return_shared(ve);
    };

    // Checkpoint 100K at epoch 3 → period 2*epoch = 100K
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

    // Checkpoint 0 at epoch 4 to finalize
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
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

        let a_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_a
        );
        assert!(a_claimable == 49879 + 49758, 1);

        let a_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_a, scenario.ctx()
        );
        let a_claimed_val = a_claimed.value();
        assert!(a_claimed_val == a_claimable, 2);
        unit_test::destroy(a_claimed);

        // Lock B: claimable for ALL epochs (0, 1 with old 600K power, 2 with merged 1M power).
        // Since lock B is permanent (target), it keeps its ID and gains more power.
        // Period 2*epoch: lock B (now 1M permanent) is the SOLE lock → gets 100% of 100K
        let b_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_b
        );
        assert!(50120 + 50241 + 100_000 - b_claimable <= 2, 3);

        let b_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_b, scenario.ctx()
        );
        let b_claimed_val = b_claimed.value();
        assert!(b_claimable == b_claimed_val, 4);
        unit_test::destroy(b_claimed);

        // Lock B gets 100% of epoch 2 rewards (sole lock after merge) = 100K
        // plus its share of epochs 0 and 1
        // Total for both locks should equal total deposited (300K) minus rounding
        let total_claimed = a_claimed_val + b_claimed_val;
        // With floor rounding, total may be slightly less than 300K
        assert!(total_claimed >= 299_997 && total_claimed <= 300_000, 4);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= 49. test_merge_one_second_before_epoch_change =========
// User merges lock B into lock A producing lock C one second before the epoch
// change. Lock A and Lock B (nulled) should NOT be able to claim from the epoch
// that is about to end. Lock C should be able — it has full voting power right
// at the end of the epoch.

#[test]
fun test_merge_one_second_before_epoch_change() {
    let admin = @0xAD;
    let user1 = @0xEB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create two locks:
    // lock_a: 500K non-permanent (source for merge)
    // lock_b: 500K permanent (target for merge)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(500_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 1456, false, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_a = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(500_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(user1);
    let lock_id_b = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Create RD, share it
    scenario.next_tx(admin);
    {
        let (rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        sui::transfer::public_share_object(rd);
        sui::transfer::public_transfer(cap, admin);
    };

    // Advance to 1 second before epoch 1 boundary and merge
    // time = epoch - 1
    clock::increment_for_testing(&mut clock, (common::epoch() - 1) * 1000);
    scenario.next_tx(user1);
    {
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock_a = scenario.take_from_sender_by_id<Lock>(lock_id_a);
        let mut lock_b = scenario.take_from_sender_by_id<Lock>(lock_id_b);
        ve_module::merge<SAIL>(&mut ve, &mut lock_a, &mut lock_b, &clock, scenario.ctx());
        scenario.return_to_sender(lock_a);
        scenario.return_to_sender(lock_b);
        test_scenario::return_shared(ve);
    };

    // Advance 1 more second to epoch boundary
    clock::increment_for_testing(&mut clock, 1 * 1000);

    // Checkpoint 100K at epoch 1 boundary → period 0 = 100K
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Verify claims for epoch 0
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        // Lock A (nulled at epoch-1):
        // Period 0 eval at (epoch - 1): lock_a was nulled at epoch-1.
        // At the eval time (epoch-1) the null checkpoint happens at epoch-1.
        // balance_of_nft_at(lock_a, epoch-1) should be 0 since it was nulled
        // at that exact moment (the null creates a 0-power point at that timestamp).
        let a_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_a
        );
        assert!(a_claimable == 0, 1);

        // Lock B (merged at epoch-1, now 1M permanent):
        // Period 0 eval at (epoch - 1): lock_b has been updated to 1M at epoch-1.
        // It has full voting power right at the end of the epoch.
        // total_supply at epoch-1: just lock_b with 1M (lock_a is nulled)
        // lock_b gets 100% = 100K
        let b_claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_b
        );
        assert!(b_claimable == 100_000, 2);

        let b_claimed = reward_distributor::claim<SAIL, REWARD_COIN>(
            &mut rd, &cap, &ve, lock_id_b, scenario.ctx()
        );
        assert!(b_claimed.value() == 100_000, 3);
        unit_test::destroy(b_claimed);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

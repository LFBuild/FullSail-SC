#[test_only]
module voting_escrow::reward_distributor_tests;

use sui::test_scenario;
use sui::clock;
use sui::coin;
use std::unit_test;

use voting_escrow::reward_distributor;
use voting_escrow::common;
use integer_mate::full_math_u64;
use voting_escrow::setup::{Self, SAIL};
use voting_escrow::voting_escrow::{Self as ve_module, VotingEscrow, Lock};
use voting_escrow::reward_distributor_cap::RewardDistributorCap;

public struct REWARD_COIN has drop {}

// ========= Group 1 — create =========

#[test]
fun test_create_initializes_fields() {
    let admin = @0xAA;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());
    let current_time = common::current_timestamp(&clock);

    let wrapper_id = object::id_from_address(@0x1);
    let (rd, cap) = reward_distributor::create<REWARD_COIN>(
        wrapper_id,
        &clock,
        scenario.ctx()
    );

    // balance == 0
    assert!(reward_distributor::balance(&rd) == 0, 1);
    // last_token_time == current_time
    assert!(reward_distributor::last_token_time(&rd) == current_time, 2);
    // start_time == current_time
    assert!(rd.start_time() == current_time, 3);
    // cap validates against this distributor (would abort if mismatched)
    cap.validate(object::id(&rd));

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward_distributor_cap::ERewardDistributorInvalid)]
fun test_create_cap_validates_only_its_distributor() {
    let admin = @0xBB;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (rd_a, cap_a) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );
    let (rd_b, cap_b) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x2),
        &clock,
        scenario.ctx()
    );

    // cap_a should reject distributor B — this aborts
    cap_a.validate(object::id(&rd_b));

    // Cleanup (unreachable due to expected failure)
    unit_test::destroy(rd_a);
    unit_test::destroy(rd_b);
    unit_test::destroy(cap_a);
    unit_test::destroy(cap_b);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= Group 2 — start =========

#[test]
fun test_start_resets_timestamps() {
    let admin = @0xCC;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    let creation_time = common::current_timestamp(&clock);
    assert!(rd.start_time() == creation_time, 1);
    assert!(reward_distributor::last_token_time(&rd) == creation_time, 2);

    // Advance time by 5 000 seconds
    clock::increment_for_testing(&mut clock, 5_000_000);
    let new_time = common::current_timestamp(&clock);
    assert!(new_time != creation_time, 3);

    // Call start — both timestamps should reset to now
    reward_distributor::start(&mut rd, &cap, &clock);

    assert!(rd.start_time() == new_time, 4);
    assert!(reward_distributor::last_token_time(&rd) == new_time, 5);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward_distributor_cap::ERewardDistributorInvalid)]
fun test_start_with_wrong_cap_aborts() {
    let admin = @0xDD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd_a, cap_a) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );
    let (rd_b, cap_b) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x2),
        &clock,
        scenario.ctx()
    );

    // Use cap_b on rd_a — should abort
    reward_distributor::start(&mut rd_a, &cap_b, &clock);

    // Cleanup (unreachable due to expected failure)
    unit_test::destroy(rd_a);
    unit_test::destroy(rd_b);
    unit_test::destroy(cap_a);
    unit_test::destroy(cap_b);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward_distributor::ETokensAlreadyCheckpointed)]
fun test_start_after_checkpoint_aborts() {
    let admin = @0xD1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Checkpoint some tokens
    let coin = coin::mint_for_testing<REWARD_COIN>(1_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Advance time and try to start — should abort
    clock::increment_for_testing(&mut clock, 5_000_000);
    reward_distributor::start(&mut rd, &cap, &clock);

    // Cleanup (unreachable due to expected failure)
    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= Group 3 — checkpoint_token (basic) =========

#[test]
fun test_checkpoint_token_single_deposit_within_epoch() {
    let admin = @0xEE;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    let deposit_amount = 10_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit_amount, scenario.ctx());

    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // All tokens land in the current period
    let current_period = common::to_period(common::current_timestamp(&clock));
    assert!(reward_distributor::tokens_per_period(&rd, current_period) == deposit_amount, 1);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_token_updates_balance() {
    let admin = @0xFF;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    assert!(reward_distributor::balance(&rd) == 0, 1);

    let deposit_amount = 5_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit_amount, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    assert!(reward_distributor::balance(&rd) == deposit_amount, 2);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = voting_escrow::reward_distributor_cap::ERewardDistributorInvalid)]
fun test_checkpoint_token_with_wrong_cap_aborts() {
    let admin = @0x11;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd_a, cap_a) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );
    let (rd_b, cap_b) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x2),
        &clock,
        scenario.ctx()
    );

    let coin = coin::mint_for_testing<REWARD_COIN>(1_000, scenario.ctx());
    // Use cap_b on rd_a — should abort
    reward_distributor::checkpoint_token(&mut rd_a, &cap_b, coin, &clock);

    // Cleanup (unreachable due to expected failure)
    unit_test::destroy(rd_a);
    unit_test::destroy(rd_b);
    unit_test::destroy(cap_a);
    unit_test::destroy(cap_b);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_token_zero_value_coin() {
    let admin = @0x22;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    let coin = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Balance unchanged
    assert!(reward_distributor::balance(&rd) == 0, 1);
    // Period entry is written but with 0 tokens
    let current_period = common::to_period(common::current_timestamp(&clock));
    assert!(reward_distributor::tokens_per_period(&rd, current_period) == 0, 2);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_tokens_per_period_returns_zero_for_empty_periods() {
    let admin = @0x23;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Before any checkpoint, all periods return 0
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 0, 1);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == 0, 2);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch() * 100) == 0, 3);

    // Checkpoint tokens in period 0
    let coin = coin::mint_for_testing<REWARD_COIN>(5_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Period 0 has tokens, neighboring periods still return 0
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 5_000, 4);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == 0, 5);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch() * 2) == 0, 6);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= Group 4 — checkpoint_token_internal (time distribution logic) =========

#[test]
fun test_checkpoint_at_exact_epoch_boundary() {
    let admin = @0x33;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance exactly 1 epoch
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);

    // Start resets last_token_time to current time (epoch boundary)
    reward_distributor::start(&mut rd, &cap, &clock);

    let deposit = 10_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
    let current_period = common::current_period(&clock);

    // token_time_delta == 0, so all tokens land in the current period
    assert!(reward_distributor::tokens_per_period(&rd, current_period) == deposit, 1);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_at_epoch_boundary_lands_in_previous_epoch() {
    let admin = @0x34;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    // RD created at time 0 — last_token_time = 0
    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance exactly to the epoch boundary
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);

    let deposit = 10_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // All tokens land in period 0 (the previous epoch), not the new period
    assert!(reward_distributor::tokens_per_period(&rd, 0) == deposit, 1);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == 0, 2);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_mid_epoch_then_at_boundary() {
    let admin = @0x34;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Start at time 0
    reward_distributor::start(&mut rd, &cap, &clock);

    // Advance to mid-epoch and checkpoint first deposit
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    let coin1 = coin::mint_for_testing<REWARD_COIN>(5_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

    let first_period = common::current_period(&clock); // period 0

    // Advance to exact epoch boundary and checkpoint second deposit
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
    let coin2 = coin::mint_for_testing<REWARD_COIN>(3_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

    let second_period = common::current_period(&clock); // period 604800

    // Time span 302400→604800 falls entirely within period 0,
    // so all second-checkpoint tokens go to the old period
    assert!(reward_distributor::tokens_per_period(&rd, first_period) == 5_000 + 3_000, 1);
    // New period is written but gets 0
    assert!(reward_distributor::tokens_per_period(&rd, second_period) == 0, 2);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_start_mid_epoch_checkpoint_next_epoch() {
    let admin = @0x35;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Start at 1/4 of epoch (151200s)
    let start_offset = common::epoch() / 4;
    clock::increment_for_testing(&mut clock, start_offset * 1000);
    reward_distributor::start(&mut rd, &cap, &clock);

    // Advance to 1/4 of the next epoch (756000s)
    let end_offset = common::epoch() + common::epoch() / 4;
    clock::increment_for_testing(&mut clock, (end_offset - start_offset) * 1000);

    let deposit = 12_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    let time_delta = end_offset - start_offset; // 604800
    // Period 0 gets 3/4 (time from 151200 to 604800)
    let expected_p0 = full_math_u64::mul_div_floor(
        deposit, common::epoch() - start_offset, time_delta
    );
    // Period 604800 gets 1/4 (time from 604800 to 756000)
    let expected_p1 = full_math_u64::mul_div_floor(
        deposit, common::epoch() / 4, time_delta
    );
    assert!(expected_p0 == 9_000, 1);
    assert!(expected_p1 == 3_000, 2);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == expected_p0, 3);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == expected_p1, 4);
    assert!(expected_p0 + expected_p1 == deposit, 5);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_spanning_two_epochs() {
    let admin = @0x44;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance 1.5 epochs = 907200 seconds
    let advance = common::epoch() + common::epoch() / 2;
    clock::increment_for_testing(&mut clock, advance * 1000);

    let deposit = 900_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Period 0 gets 2/3 of tokens
    let expected_p0 = full_math_u64::mul_div_floor(deposit, common::epoch(), advance);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == expected_p0, 1);
    // Period 604800 gets 1/3 of tokens
    let expected_p1 = full_math_u64::mul_div_floor(deposit, common::epoch() / 2, advance);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == expected_p1, 2);
    // Verify sum
    assert!(expected_p0 + expected_p1 == deposit, 3);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_spanning_many_epochs() {
    let admin = @0x55;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance exactly 10 epochs
    let num_epochs = 10u64;
    clock::increment_for_testing(&mut clock, common::epoch() * num_epochs * 1000);

    let deposit = 10_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Each of 10 periods gets equal share
    let per_period = deposit / num_epochs;
    let mut total = 0u64;
    let mut i = 0u64;
    while (i < num_epochs) {
        let period = common::epoch() * i;
        let tokens = reward_distributor::tokens_per_period(&rd, period);
        assert!(tokens == per_period, i + 1);
        total = total + tokens;
        i = i + 1;
    };
    assert!(total == deposit, 100);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_spanning_20_plus_epochs_capped() {
    let admin = @0x66;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    let num_epochs = 25u64;
    clock::increment_for_testing(&mut clock, common::epoch() * num_epochs * 1000);

    let deposit = 25_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Only first 20 periods get tokens (loop capped at 20 iterations)
    let per_period = full_math_u64::mul_div_floor(
        deposit, common::epoch(), common::epoch() * num_epochs
    );
    let mut total = 0u64;
    let mut i = 0u64;
    // iterate over all epochs to make sure there are no side effects on neighboring periods
    while (i < 30) {
        let period = common::epoch() * i;
        let tokens = reward_distributor::tokens_per_period(&rd, period);
        if (i < 20) {
            assert!(tokens == per_period, i + 1);
        } else {
            assert!(tokens == 0, i + 1);
        };
        total = total + tokens;
        i = i + 1;
    };
    // only 20/25 epochs are distributed, so only 20/25 of the tokens are distributed
    assert!(total == 20000, 100);
    // Balance still holds all deposited tokens
    assert!(reward_distributor::balance(&rd) == deposit, 101);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_right_before_epoch_boundary() {
    let admin = @0x77;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance to 1 second before epoch boundary
    clock::increment_for_testing(&mut clock, (common::epoch() - 1) * 1000);

    let deposit = 10_000u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // All tokens stay in period 0
    assert!(reward_distributor::tokens_per_period(&rd, 0) == deposit, 1);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_right_after_epoch_boundary() {
    let admin = @0x88;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance to 1 second after epoch boundary
    let advance = common::epoch() + 1;
    clock::increment_for_testing(&mut clock, advance * 1000);

    let deposit = 604_801u64;
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Almost all tokens in period 0
    let expected_p0 = 604_800;
    assert!(reward_distributor::tokens_per_period(&rd, 0) == expected_p0, 1);
    // Tiny fraction in next period
    let expected_p1 = 1;
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == expected_p1, 2);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_two_checkpoints_same_timestamp() {
    let admin = @0x99;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // First deposit
    let coin1 = coin::mint_for_testing<REWARD_COIN>(5_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 5_000, 1);

    // Second deposit at same time — accumulates
    let coin2 = coin::mint_for_testing<REWARD_COIN>(3_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 8_000, 2);

    // next period should be 0
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == 0, 3);

    // Balance reflects total
    assert!(reward_distributor::balance(&rd) == 8_000, 3);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_two_checkpoints_same_epoch_different_times() {
    let admin = @0xAB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // First deposit at time 0
    let coin1 = coin::mint_for_testing<REWARD_COIN>(6_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 6_000, 1);

    // Advance half an epoch
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);

    // Second deposit — still within epoch 0
    let coin2 = coin::mint_for_testing<REWARD_COIN>(4_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

    // All tokens remain in period 0
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 10_000, 2);
    assert!(reward_distributor::balance(&rd) == 10_000, 3);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_multiple_small_checkpoints_vs_one_large() {
    let admin = @0xBC;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    // Distributor A: 5 deposits of 2000 at same time
    let (mut rd_a, cap_a) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );
    let mut i = 0;
    while (i < 5) {
        let coin = coin::mint_for_testing<REWARD_COIN>(2_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd_a, &cap_a, coin, &clock);
        i = i + 1;
    };

    // Distributor B: 1 deposit of 10000 at same time
    let (mut rd_b, cap_b) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x2),
        &clock,
        scenario.ctx()
    );
    let coin = coin::mint_for_testing<REWARD_COIN>(10_000, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd_b, &cap_b, coin, &clock);

    // Both should have identical tokens_per_period
    assert!(
        reward_distributor::tokens_per_period(&rd_a, 0) ==
        reward_distributor::tokens_per_period(&rd_b, 0),
        1
    );
    assert!(reward_distributor::tokens_per_period(&rd_a, 0) == 10_000, 2);

    unit_test::destroy(rd_a);
    unit_test::destroy(rd_b);
    unit_test::destroy(cap_a);
    unit_test::destroy(cap_b);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_large_token_amount() {
    let admin = @0xCD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance 1.5 epochs to force proportional math with large values
    let advance = common::epoch() + common::epoch() / 2;
    clock::increment_for_testing(&mut clock, advance * 1000);

    let deposit = 9223372036854775808u64; // u64::MAX / 2
    let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Verify proportional split doesn't overflow (mul_div_floor uses u128 internally)
    let expected_p0 = full_math_u64::mul_div_floor(deposit, common::epoch(), advance);
    let expected_p1 = full_math_u64::mul_div_floor(deposit, common::epoch() / 2, advance);
    assert!(reward_distributor::tokens_per_period(&rd, 0) == expected_p0, 1);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == expected_p1, 2);
    // Sum may be less than deposit due to floor rounding
    assert!(expected_p0 + expected_p1 <= deposit, 3);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_checkpoint_dust_amount() {
    let admin = @0xDE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
        object::id_from_address(@0x1),
        &clock,
        scenario.ctx()
    );

    // Advance 1.5 epochs
    let advance = common::epoch() + common::epoch() / 2;
    clock::increment_for_testing(&mut clock, advance * 1000);

    let coin = coin::mint_for_testing<REWARD_COIN>(1, scenario.ctx());
    reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

    // Both periods get 0 due to floor rounding: 1 * 604800 / 907200 = 0
    assert!(reward_distributor::tokens_per_period(&rd, 0) == 0, 1);
    assert!(reward_distributor::tokens_per_period(&rd, common::epoch()) == 0, 2);
    // Balance still holds the token
    assert!(reward_distributor::balance(&rd) == 1, 3);

    unit_test::destroy(rd);
    unit_test::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ========= Group 5 — claimable =========

#[test]
fun test_claimable_before_epoch_fully_checkpointed() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create a permanent lock (voting power = locked amount, no decay)
    scenario.next_tx(admin);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            true, // permanent
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Create and start reward distributor
        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );
        reward_distributor::start(&mut rd, &cap, &clock);

        // Advance to mid-epoch and checkpoint first deposit
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
        let first_deposit = 1_000_000u64;
        let coin1 = coin::mint_for_testing<REWARD_COIN>(first_deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        // Claimable should be 0 — epoch not fully checkpointed
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable1 == 0, 1);

        // Advance to next epoch
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);

        // Claimable still 0 — last_token_time hasn't advanced past the epoch
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable2 == 0, 2);

        // Checkpoint again to advance last_token_time past the epoch boundary
        let coin2 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Now claimable equals the first deposit
        // (permanent lock: user_balance == total_supply, so full share)
        let claimable3 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable3 == first_deposit, 3);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_after_epoch_end_checkpoint() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create a permanent lock
    scenario.next_tx(admin);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            true,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Advance to the epoch boundary — epoch [0, 604800) just ended
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);

        // Checkpoint tokens at the boundary
        let deposit = 500_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == deposit, 1);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_no_locks_returns_zero() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let fake_lock_id = object::id_from_address(@0xDEAD);

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Claimable for a non-existent lock should be 0
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, fake_lock_id
        );
        assert!(claimable1 == 0, 1);

        // Checkpoint tokens, advance epoch, checkpoint again
        let coin1 = coin::mint_for_testing<REWARD_COIN>(10_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        clock::increment_for_testing(&mut clock, common::epoch() * 1000);

        let coin2 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Still 0 — lock was never created
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, fake_lock_id
        );
        assert!(claimable2 == 0, 2);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_lock_with_zero_voting_power() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create a 1-week lock (minimum duration, non-permanent)
    scenario.next_tx(admin);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(
            &mut ve,
            sail,
            7, // 7 days = 1 week = 1 epoch
            false,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Advance 1 week — lock expires, voting power drops to 0
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);

        // Start RD at the epoch boundary
        reward_distributor::start(&mut rd, &cap, &clock);

        // Checkpoint first deposit
        let coin1 = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        // Claimable should be 0 — lock has zero voting power
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable1 == 0, 1);

        // Advance 1 more week
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);

        // Checkpoint second deposit
        let coin2 = coin::mint_for_testing<REWARD_COIN>(100_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Still 0 — expired lock has no voting power
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable2 == 0, 2);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_single_user_gets_all_rewards() {
    let admin = @0xAD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Create a permanent lock — 100% of voting power
    scenario.next_tx(admin);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(
            &mut ve,
            sail,
            182,
            true,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(ve);
    };

    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Checkpoint tokens mid-epoch
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
        let deposit = 750_000u64;
        let coin1 = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        // Advance to next epoch and checkpoint to finalize
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
        let coin2 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Single lock with 100% voting power gets 100% of rewards
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == deposit, 1);

        scenario.return_to_sender(lock);
        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_two_users_equal_power() {
    let admin = @0xAD;
    let user1 = @0xA1;
    let user2 = @0xA2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1 creates a permanent lock of 1M
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2 creates a permanent lock of 1M
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

    // Checkpoint and verify claimable
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Advance to epoch boundary and checkpoint
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let deposit = 1_000_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Each user has 50% of voting power → 50% of rewards
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );
        assert!(claimable1 == deposit / 2, 1);
        assert!(claimable2 == deposit / 2, 2);
        assert!(claimable1 + claimable2 == deposit, 3);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_two_users_unequal_power() {
    let admin = @0xAD;
    let user1 = @0xB1;
    let user2 = @0xB2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1 creates a permanent lock of 3M (75% of voting power)
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(3_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // User 2 creates a permanent lock of 1M (25% of voting power)
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

    // Checkpoint and verify proportional distribution
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Advance to epoch boundary and checkpoint
        clock::increment_for_testing(&mut clock, common::epoch() * 1000);
        let deposit = 1_000_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // User 1 (3M / 4M = 75%) gets 750_000
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        // User 2 (1M / 4M = 25%) gets 250_000
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );
        assert!(claimable1 == 750_000, 1);
        assert!(claimable2 == 250_000, 2);
        assert!(claimable1 + claimable2 == deposit, 3);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_user_created_lock_mid_epoch() {
    let admin = @0xAD;
    let user1 = @0xC1;
    let user2 = @0xC2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1 creates a permanent lock of 1M at time 0
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // Advance to mid-epoch
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);

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

    // Admin creates RD at mid-epoch, checkpoints, and verifies claimable
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        let (mut rd, cap) = reward_distributor::create<REWARD_COIN>(
            object::id_from_address(@0x1),
            &clock,
            scenario.ctx()
        );

        // Checkpoint deposit at mid-epoch — all tokens land in period 0
        let deposit = 1_000_000u64;
        let coin1 = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin1, &clock);

        // Advance to next epoch and checkpoint 0 to finalize
        clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);
        let coin2 = coin::mint_for_testing<REWARD_COIN>(0, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin2, &clock);

        // Lock A (permanent): full voting power at epoch end → gets 50%
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        // Lock B (permanent): full voting power at epoch end → gets 50%
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );
        assert!(claimable1 == deposit / 2, 1);
        assert!(claimable2 == deposit / 2, 2);
        assert!(claimable1 + claimable2 == deposit, 3);

        test_scenario::return_shared(ve);
        unit_test::destroy(rd);
        unit_test::destroy(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_user_created_lock_mid_distribution() {
    let admin = @0xAD;
    let user1 = @0xC1;
    let user2 = @0xC2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1 creates a permanent lock of 1M at time 0
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // Get lock_id_1
    scenario.next_tx(user1);
    let lock_id_1 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Admin creates RD at time 0, shares it and transfers cap
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

    // Advance to 3 epochs
    clock::increment_for_testing(&mut clock, common::epoch() * 3 * 1000);

    // Admin checkpoints 300K (100K per period for epochs 0, 1, 2)
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(300_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Advance to the middle of the epoch 3
    clock::increment_for_testing(&mut clock, common::epoch() / 2 * 1000);

    // User 2 creates a permanent lock of 1M at the middle of the epoch 3
    scenario.next_tx(user2);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // Get lock_id_2
    scenario.next_tx(user2);
    let lock_id_2 = {
        let lock = scenario.take_from_sender<Lock>();
        let id = object::id(&lock);
        scenario.return_to_sender(lock);
        id
    };

    // Advance to 5 epochs
    clock::increment_for_testing(&mut clock, common::epoch() * 3 / 2 * 1000);

    // Admin checkpoints 200K (100K per period for epochs 3, 4)
    scenario.next_tx(admin);
    {
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();
        let coin = coin::mint_for_testing<REWARD_COIN>(200_000, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    // Advance to 6 epochs
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);

    scenario.next_tx(admin);
    {
        // no need to checkpoint 0 cos last tokens were notified at the epoch boundary
        let rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();

        // Lock A: epochs 0-2 at 100% (300K) + epochs 3-4 at 50% (100K) = 400K
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        // Lock B: epochs 3-4 at 50% (100K) = 100K
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );
        assert!(claimable1 == 400_000, 1);
        assert!(claimable2 == 100_000, 2);
        assert!(claimable1 + claimable2 == 500_000, 3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_lock_created_at_checkpoint_epoch_boundary() {
    let admin = @0xAD;
    let user1 = @0xD1;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // Admin creates RD at time 0, shares it and transfers cap
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

    // Advance to the epoch boundary
    clock::increment_for_testing(&mut clock, common::epoch() * 1000);

    // Create a permanent lock exactly at the epoch boundary
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

    // Admin checkpoints tokens at the same epoch boundary
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let deposit = 500_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Claimable is 0: lock was created at the epoch boundary so its initial_period
        // equals max_period — the lock missed period 0 and the current epoch isn't finalized
        let claimable = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id
        );
        assert!(claimable == 0, 1);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_claimable_lock_created_one_second_before_epoch_end() {
    let admin = @0xAD;
    let user1 = @0xE1;
    let user2 = @0xE2;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = setup::setup<SAIL>(&mut scenario, admin);

    // User 1 creates a permanent lock of 1M at time 0
    scenario.next_tx(user1);
    {
        let sail = coin::mint_for_testing<SAIL>(1_000_000, scenario.ctx());
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        ve_module::create_lock<SAIL>(&mut ve, sail, 182, true, &clock, scenario.ctx());
        test_scenario::return_shared(ve);
    };

    // Admin creates RD at time 0, shares it and transfers cap
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

    // Advance to 1 second before epoch end
    clock::increment_for_testing(&mut clock, (common::epoch() - 1) * 1000);

    // User 2 creates a permanent lock of 1M at epoch - 1
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

    // Advance 1 more second to the epoch boundary
    clock::increment_for_testing(&mut clock, 1000);

    // Admin checkpoints deposit at the epoch boundary — tokens land in period 0
    scenario.next_tx(admin);
    {
        let ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<REWARD_COIN>>();
        let cap = scenario.take_from_sender<RewardDistributorCap>();

        let deposit = 1_000_000u64;
        let coin = coin::mint_for_testing<REWARD_COIN>(deposit, scenario.ctx());
        reward_distributor::checkpoint_token(&mut rd, &cap, coin, &clock);

        // Both permanent locks have equal voting power at evaluation time (epoch - 1)
        // Lock B was created 1 second before epoch end — has full permanent power
        let claimable1 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_1
        );
        let claimable2 = reward_distributor::claimable<SAIL, REWARD_COIN>(
            &rd, &ve, lock_id_2
        );
        assert!(claimable1 == deposit / 2, 1);
        assert!(claimable2 == deposit / 2, 2);
        assert!(claimable1 + claimable2 == deposit, 3);

        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(cap);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

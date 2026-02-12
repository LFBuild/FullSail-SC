#[test_only]
module voting_escrow::reward_distributor_tests;

use sui::test_scenario;
use sui::clock;
use sui::coin;
use sui::test_utils;

use voting_escrow::reward_distributor;
use voting_escrow::common;

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

    test_utils::destroy(rd);
    test_utils::destroy(cap);
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
    test_utils::destroy(rd_a);
    test_utils::destroy(rd_b);
    test_utils::destroy(cap_a);
    test_utils::destroy(cap_b);
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

    test_utils::destroy(rd);
    test_utils::destroy(cap);
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
    test_utils::destroy(rd_a);
    test_utils::destroy(rd_b);
    test_utils::destroy(cap_a);
    test_utils::destroy(cap_b);
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

    test_utils::destroy(rd);
    test_utils::destroy(cap);
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

    test_utils::destroy(rd);
    test_utils::destroy(cap);
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
    test_utils::destroy(rd_a);
    test_utils::destroy(rd_b);
    test_utils::destroy(cap_a);
    test_utils::destroy(cap_b);
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

    test_utils::destroy(rd);
    test_utils::destroy(cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

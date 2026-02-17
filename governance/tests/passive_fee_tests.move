#[test_only]
module governance::passive_fee_tests;

use governance::minter::{Self, Minter, AdminCap};
use sui::coin;
use sui::clock;
use sui::test_scenario;
use sui::test_utils;
use voting_escrow::voting_escrow::VotingEscrow;
use governance::setup;
use governance::distribution_config::DistributionConfig;
use governance::usd_tests::{Self, USD_TESTS};
use governance::voter::{Self, Voter};
use clmm_pool::pool::{Self, Pool};
use clmm_pool::tick_math;
use clmm_pool::clmm_math;
use integer_mate::full_math_u64;

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;
const RATE_DENOM: u64 = 10000;

public struct SAIL has drop, store {}
public struct AUSD has drop, store {}
public struct OSAIL1 has drop, store {}
public struct OSAIL2 has drop, store {}
public struct OSAIL3 has drop, store {}
public struct OSAIL4 has drop, store {}
public struct OSAIL5 has drop, store {}
public struct OSAIL6 has drop, store {}

// ──────────────────────────────────────────────────────────
// A1. Create & start passive fee distributor
// ──────────────────────────────────────────────────────────

#[test]
fun test_create_and_start_passive_fee_distributor() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Advance clock so last_token_time is meaningful
    clock.increment_for_testing(WEEK + 1000);

    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let distributor = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter,
            &admin_cap,
            &voting_escrow,
            &distribution_config,
            &clock,
            scenario.ctx(),
        );

        // Balance should be 0 initially
        assert!(distributor.balance() == 0, 0);
        // clock = WEEK + 1000 ms => current_timestamp = 604801 seconds
        // start() sets last_token_time = current_timestamp (no period rounding)
        assert!(distributor.last_token_time() == (WEEK + 1000) / 1000, 1);

        test_utils::destroy(distributor);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A2.1 Create passive fee distributor — minter paused
// ──────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = minter::ECreatePassiveFeeDistributorMinterPaused)]
fun test_create_passive_fee_distributor_minter_paused() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Pause the minter
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        minter::pause(&mut minter, &distribution_config, &admin_cap);

        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // Attempt to create passive fee distributor — should abort
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let distributor = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter,
            &admin_cap,
            &voting_escrow,
            &distribution_config,
            &clock,
            scenario.ctx(),
        );

        test_utils::destroy(distributor);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A2.2 Create passive fee distributor — admin cap revoked
// ──────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_create_passive_fee_distributor_admin_revoked() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Revoke the admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());

        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));

        test_utils::destroy(publisher);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
    };

    // Attempt to create passive fee distributor with revoked cap — should abort
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let distributor = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter,
            &admin_cap,
            &voting_escrow,
            &distribution_config,
            &clock,
            scenario.ctx(),
        );

        test_utils::destroy(distributor);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A3. Set passive voter fee rate — happy path
// ──────────────────────────────────────────────────────────

#[test]
fun test_set_passive_voter_fee_rate() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // 20%
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 2000);
        assert!(minter.passive_voter_fee_rate() == 2000, 0);

        // 50%
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 5000);
        assert!(minter.passive_voter_fee_rate() == 5000, 1);

        // 0%
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 0);
        assert!(minter.passive_voter_fee_rate() == 0, 2);

        // 100% (RATE_DENOM = 10000)
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 10000);
        assert!(minter.passive_voter_fee_rate() == 10000, 3);

        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A4. Set passive voter fee rate — too big
// ──────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = minter::ESetPassiveVoterFeeRateTooBig)]
fun test_set_passive_voter_fee_rate_too_big() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        // RATE_DENOM + 1 = 10001 — should abort
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 10001);

        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A5. Set passive voter fee rate — minter paused
// ──────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = minter::ESetPassiveVoterFeeRateMinterPaused)]
fun test_set_passive_voter_fee_rate_minter_paused() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        minter::pause(&mut minter, &distribution_config, &admin_cap);
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 2000);

        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// A6. Set passive voter fee rate — admin cap revoked
// ──────────────────────────────────────────────────────────

#[test]
#[expected_failure(abort_code = minter::ECheckAdminRevoked)]
fun test_set_passive_voter_fee_rate_admin_revoked() {
    let admin = @0xD;
    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());

    setup::setup_clmm_factory_with_fee_tier(&mut scenario, admin, 1, 1000);
    setup::setup_distribution<SAIL>(&mut scenario, admin, &clock);

    // Revoke the admin cap
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let publisher = minter::test_init(scenario.ctx());

        minter::revoke_admin(&mut minter, &publisher, object::id(&admin_cap));

        test_utils::destroy(publisher);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
    };

    // Try to set rate with revoked cap — should abort
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, 2000);

        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// Utility: compute total fee per token for N wash-trade rounds
// ──────────────────────────────────────────────────────────

fun compute_total_fee_per_token<CoinA, CoinB>(
    scenario: &mut test_scenario::Scenario,
    caller: address,
    swap_amount: u64,
    trade_rounds: u64,
): u64 {
    let fee_rate_denominator = clmm_math::fee_rate_denominator();
    let pool_fee_rate = {
        scenario.next_tx(caller);
        let pool = scenario.take_shared<Pool<CoinA, CoinB>>();
        let r = pool::fee_rate(&pool);
        test_scenario::return_shared(pool);
        r
    };
    let protocol_fee_rate = {
        scenario.next_tx(caller);
        let gc = scenario.take_shared<clmm_pool::config::GlobalConfig>();
        let r = gc.protocol_fee_rate();
        test_scenario::return_shared(gc);
        r
    };
    let protocol_fee_rate_denominator = clmm_pool::config::protocol_fee_rate_denom();
    let full_fee_per_swap = full_math_u64::mul_div_floor(swap_amount, pool_fee_rate, fee_rate_denominator);
    let protocol_fee_per_swap = full_math_u64::mul_div_floor(full_fee_per_swap, protocol_fee_rate, protocol_fee_rate_denominator);
    (full_fee_per_swap - protocol_fee_per_swap) * trade_rounds
}

// ──────────────────────────────────────────────────────────
// Utility: perform wash trades (A->B then B->A) for N rounds
// ──────────────────────────────────────────────────────────

fun wash_trade<CoinA, CoinB>(
    scenario: &mut test_scenario::Scenario,
    clock: &mut clock::Clock,
    swapper: address,
    swap_amount: u64,
    trade_rounds: u64,
    wash_interval: u64,
) {
    let mut i = 0;
    while (i < trade_rounds) {
        clock.increment_for_testing(wash_interval);
        scenario.next_tx(swapper);
        {
            let cin = coin::mint_for_testing<CoinA>(swap_amount, scenario.ctx());
            let cout = coin::zero<CoinB>(scenario.ctx());
            let (ra, rb) = setup::swap<CoinA, CoinB>(
                scenario, cin, cout, true, true,
                swap_amount, 1, tick_math::min_sqrt_price(), clock,
            );
            coin::burn_for_testing(ra);
            coin::burn_for_testing(rb);
        };
        scenario.next_tx(swapper);
        {
            let cin = coin::mint_for_testing<CoinB>(swap_amount, scenario.ctx());
            let cout = coin::zero<CoinA>(scenario.ctx());
            let (ra, rb) = setup::swap<CoinA, CoinB>(
                scenario, cout, cin, false, true,
                swap_amount, 1, tick_math::max_sqrt_price(), clock,
            );
            coin::burn_for_testing(ra);
            coin::burn_for_testing(rb);
        };
        i = i + 1;
    };
}

// ──────────────────────────────────────────────────────────
// B1. Default passive fee (0%) — all fees go to voting rewards
// ──────────────────────────────────────────────────────────

#[test]
fun test_passive_fee_zero_by_default() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );

    // 2. LP creates position with liquidity and deposits
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario, lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128, &clock,
        );
    };
    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 3. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 4. Compute expected fees & wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let expected_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 10;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 5. Advance to epoch 2
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 7. Distribute gauge epoch 2 — collects fees
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 8. Verify: passive_voter_fee_rate defaults to 0, so all fees go to voting rewards
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let gauge_id = voter::pool_to_gauge(&voter, object::id(&pool));

        assert!(minter.passive_voter_fee_rate() == 0, 0);
        assert!(minter::passive_fee_balance<SAIL, USD_TESTS>(&minter) == 0, 1);
        assert!(minter::passive_fee_balance<SAIL, AUSD>(&minter) == 0, 2);

        let voting_fee_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        let voting_fee_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);
        assert!(voting_fee_a == expected_fee_per_token, 3);
        assert!(voting_fee_b == expected_fee_per_token, 4);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// B2. Passive fee at 80% — 80% passive, 20% voting
// ──────────────────────────────────────────────────────────

#[test]
fun test_passive_fee_eighty_percent() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;
    let passive_rate: u64 = 8000; // 80%

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );

    // 2. Set passive fee rate to 80%
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, passive_rate);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 3. LP creates position with liquidity and deposits
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario, lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128, &clock,
        );
    };
    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 5. Compute expected fees & wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let expected_passive_per_token = total_fee_per_token * 8 / 10;
    let expected_voting_per_token = total_fee_per_token - expected_passive_per_token;
    let wash_interval = WEEK / 10;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 6. Advance to epoch 2
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 8. Distribute gauge epoch 2 — collects fees and splits 80/20
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL4, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 9. Verify the 80/20 split
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let gauge_id = voter::pool_to_gauge(&voter, object::id(&pool));

        let passive_a = minter::passive_fee_balance<SAIL, USD_TESTS>(&minter);
        let passive_b = minter::passive_fee_balance<SAIL, AUSD>(&minter);
        let voting_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        let voting_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);

        assert!(passive_a == expected_passive_per_token, 1);
        assert!(passive_b == expected_passive_per_token, 2);
        assert!(voting_a == expected_voting_per_token, 3);
        assert!(voting_b == expected_voting_per_token, 4);

        // Verify totals add up
        assert!(passive_a + voting_a == total_fee_per_token, 5);
        assert!(passive_b + voting_b == total_fee_per_token, 6);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// B3. Passive fee at 100% — voting rewards are zero
// ──────────────────────────────────────────────────────────

#[test]
fun test_passive_fee_hundred_percent() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL5, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );

    // 2. Set passive fee rate to 100%
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        minter::set_passive_voter_fee_rate(&mut minter, &admin_cap, &distribution_config, RATE_DENOM);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 3. LP creates position with liquidity and deposits
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<USD_TESTS, AUSD>(
            &mut scenario, lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128, &clock,
        );
    };
    scenario.next_tx(lp);
    {
        setup::deposit_position<USD_TESTS, AUSD>(&mut scenario, &clock);
    };

    // 4. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL5, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 5. Compute expected fees & wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 10;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 6. Advance to epoch 2
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL6>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 8. Distribute gauge epoch 2 — collects fees, all go to passive
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL6, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 9. Verify: voting rewards are zero, all fees in passive
    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let voter = scenario.take_shared<Voter>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let gauge_id = voter::pool_to_gauge(&voter, object::id(&pool));

        let passive_a = minter::passive_fee_balance<SAIL, USD_TESTS>(&minter);
        let passive_b = minter::passive_fee_balance<SAIL, AUSD>(&minter);
        let voting_a = voter::fee_voting_reward_balance<USD_TESTS>(&voter, gauge_id);
        let voting_b = voter::fee_voting_reward_balance<AUSD>(&voter, gauge_id);

        // 100% passive: voting rewards should be zero
        assert!(voting_a == 0, 1);
        assert!(voting_b == 0, 2);

        // All fees should be in passive
        assert!(passive_a == total_fee_per_token, 3);
        assert!(passive_b == total_fee_per_token, 4);

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(pool);
    };

    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

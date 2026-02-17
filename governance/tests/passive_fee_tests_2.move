#[test_only]
module governance::passive_fee_tests_2;

use governance::minter::{Self, Minter, AdminCap, DistributeGovernorCap};
use governance::passive_fee_distributor;
use sui::coin;
use sui::clock;
use sui::test_scenario;
use sui::test_utils;
use voting_escrow::voting_escrow::{Self, VotingEscrow, Lock};
use governance::setup;
use governance::distribution_config::DistributionConfig;
use governance::usd_tests::{Self, USD_TESTS};
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
public struct OSAIL7 has drop, store {}
public struct OSAIL8 has drop, store {}
public struct OSAIL9 has drop, store {}
public struct OSAIL10 has drop, store {}
public struct OSAIL12 has drop, store {}

// ── Utility functions ───────────────────────────────────

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
// F1. Notify at epoch boundary, claim full reward with single lock
// ──────────────────────────────────────────────────────────

#[test]
fun test_claim_passive_fee_full_reward() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (epoch 1, clock = WEEK + 1000 ms)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
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

    // 3. Create distributor (at WEEK + 1000 ms, start_time = 604801)
    scenario.next_tx(admin);
    let mut distributor = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 4. LP creates position and deposits
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

    // 5. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 6. Compute expected fees & wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 10;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 7. Advance to epoch 2 (clock = 2*WEEK + 1000 ms)
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);

    // 8. Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 9. Distribute gauge epoch 2 (collects fees)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 10. Withdraw & notify passive fees
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_coin = minter::withdraw_passive_fee<SAIL, USD_TESTS>(
            &mut minter, &distribute_governor_cap, &distribution_config, scenario.ctx(),
        );

        minter::notify_passive_fee<SAIL, USD_TESTS>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor, fee_coin, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 11. Check claimable and claim with user's lock
    // Distributor started at 604801, notify at 1209601
    // Epoch 1 period (604800) gets total_fee * 604799 / 604800
    let expected_epoch_1_fee = total_fee_per_token * 604799 / 604800;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Check claimable
        let claimable = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor, &voting_escrow, lock_id,
        );
        assert!(expected_epoch_1_fee - claimable <= 1, 1);

        // Claim
        let reward_coin = passive_fee_distributor::claim<SAIL, USD_TESTS>(
            &mut distributor, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        assert!(expected_epoch_1_fee - reward_coin.value() <= 1, 2);

        coin::burn_for_testing(reward_coin);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// F2. Notify mid-epoch, claim portion for first epoch
// ──────────────────────────────────────────────────────────

#[test]
fun test_claim_passive_fee_mid_epoch_portion() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (epoch 1, clock = WEEK + 1000 ms)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );
    /// toggle permanent for the lock
    scenario.next_tx(user);
    {
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let mut lock = scenario.take_from_sender<Lock>();
        voting_escrow::lock_permanent<SAIL>(&mut voting_escrow, &mut lock, &clock, scenario.ctx());
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
    };

    // 2. Advance past epoch 2 boundary (clock = 2*WEEK + 1000 ms)
    clock.increment_for_testing(WEEK);

    // 3. Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 4. Advance to mid-epoch 2 (clock = 2.5*WEEK ms)
    clock.increment_for_testing(WEEK / 2 - 1000);

    // 5. Create distributor at mid-epoch 2 (start_time = 1512000)
    scenario.next_tx(admin);
    let mut distributor = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 6. Set passive fee rate to 100%
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

    // 7. LP creates position and deposits
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

    // 8. Distribute gauge epoch 2 (initial, at mid-epoch 2)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL4, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 9. Wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 20;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 10. Advance past epoch 3 boundary (clock = 3*WEEK + 1000 ms)
    let remaining_to_epoch_3 = WEEK / 2 - trade_rounds * wash_interval + 1000;
    clock.increment_for_testing(remaining_to_epoch_3);

    // 11. Update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL5>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 12. Advance to mid-epoch 3 (clock = 3.5*WEEK ms)
    clock.increment_for_testing(WEEK / 2 - 1000);

    // 13. Distribute gauge epoch 3 (collects fees)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL5, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 14. Withdraw & notify at mid-epoch 3
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_coin = minter::withdraw_passive_fee<SAIL, USD_TESTS>(
            &mut minter, &distribute_governor_cap, &distribution_config, scenario.ctx(),
        );
        std::debug::print(&fee_coin.value());

        minter::notify_passive_fee<SAIL, USD_TESTS>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor, fee_coin, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 15. Claim — only epoch 2's portion (50%) is claimable
    //     Distributor started at 1512000 (mid-epoch 2), notify at 2116800 (mid-epoch 3).
    //     50/50 split. max_period = to_period(2116800) = 1814400 (epoch 3 start).
    //     Only epoch 2 period (1209600) is claimable.
    let expected_per_epoch = total_fee_per_token / 2;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);


        let claimable = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor, &voting_escrow, lock_id,
        );
        let diff_claimable = if (claimable >= expected_per_epoch) {
            claimable - expected_per_epoch
        } else {
            expected_per_epoch - claimable
        };
        std::debug::print(&diff_claimable);
        std::debug::print(&claimable);
        std::debug::print(&expected_per_epoch);
        assert!(diff_claimable <= 10, 1);

        // Claim
        let reward_coin = passive_fee_distributor::claim<SAIL, USD_TESTS>(
            &mut distributor, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        let diff_claimed = if (reward_coin.value() >= expected_per_epoch) {
            reward_coin.value() - expected_per_epoch
        } else {
            expected_per_epoch - reward_coin.value()
        };
        assert!(diff_claimed <= 10, 2);

        coin::burn_for_testing(reward_coin);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// F3. Vote and claim passive fee with the same lock
// ──────────────────────────────────────────────────────────

#[test]
fun test_vote_and_claim_passive_fee_same_lock() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (epoch 1, clock = WEEK + 1000 ms)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL6, USD_TESTS>(
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

    // 3. Create distributor
    scenario.next_tx(admin);
    let mut distributor = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 4. LP creates position and deposits
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

    // 5. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL6, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 6. Advance 1 hour for voting window, then vote with the user's lock
    let one_hour = 60 * 60 * 1000;
    clock.increment_for_testing(one_hour);
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, &mut clock);
    };

    // 7. Wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<USD_TESTS, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 10;
    wash_trade<USD_TESTS, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 8. Advance to epoch 2 (clock = 2*WEEK + 1000 ms)
    let remaining_time = WEEK - one_hour - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);

    // 9. Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL7>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 10. Distribute gauge epoch 2 (collects fees)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL7, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 11. Withdraw & notify passive fees
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_coin = minter::withdraw_passive_fee<SAIL, USD_TESTS>(
            &mut minter, &distribute_governor_cap, &distribution_config, scenario.ctx(),
        );

        minter::notify_passive_fee<SAIL, USD_TESTS>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor, fee_coin, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 12. User claims passive fee — should succeed despite having voted
    let expected_epoch_1_fee = total_fee_per_token * 604799 / 604800;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Check claimable
        let claimable = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor, &voting_escrow, lock_id,
        );
        assert!(expected_epoch_1_fee - claimable <= 1, 1);

        // Claim passive fee with the same lock used for voting
        let reward_coin = passive_fee_distributor::claim<SAIL, USD_TESTS>(
            &mut distributor, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        assert!(expected_epoch_1_fee - reward_coin.value() <= 1, 2);

        coin::burn_for_testing(reward_coin);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// F4. Passive fee distributor in SAIL token — claim liquid SAIL
// ──────────────────────────────────────────────────────────

#[test]
fun test_claim_passive_fee_sail_token_liquid() {
    let admin = @0xA;
    let user = @0xB;
    let lp = @0xC;
    let swapper = @0xE;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup with SAIL/AUSD pool (SAIL is both VE type and pool token A)
    let mut aggregator = setup::full_setup_with_lock<SAIL, AUSD, SAIL, OSAIL8, USD_TESTS>(
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

    // 3. Create PassiveFeeDistributor<SAIL> (FeeCoinType = SAIL)
    scenario.next_tx(admin);
    let mut distributor = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, SAIL>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 4. LP creates position and deposits in SAIL/AUSD pool
    scenario.next_tx(lp);
    {
        setup::create_position_with_liquidity<SAIL, AUSD>(
            &mut scenario, lp,
            tick_math::min_tick().as_u32(),
            tick_math::max_tick().as_u32(),
            100_000_000_000u128, &clock,
        );
    };
    scenario.next_tx(lp);
    {
        setup::deposit_position<SAIL, AUSD>(&mut scenario, &clock);
    };

    // 5. Distribute gauge epoch 1 (initial)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<SAIL, AUSD, SAIL, OSAIL8, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 6. Compute expected SAIL fees & wash trade
    let swap_amount: u64 = 1_000_000_000;
    let trade_rounds: u64 = 5;
    let total_fee_per_token = compute_total_fee_per_token<SAIL, AUSD>(
        &mut scenario, admin, swap_amount, trade_rounds,
    );
    let wash_interval = WEEK / 10;
    wash_trade<SAIL, AUSD>(
        &mut scenario, &mut clock, swapper, swap_amount, trade_rounds, wash_interval,
    );

    // 7. Advance to epoch 2 (clock = 2*WEEK + 1000 ms)
    let remaining_time = WEEK - wash_interval * trade_rounds;
    clock.increment_for_testing(remaining_time);

    // 8. Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o = setup::update_minter_period<SAIL, OSAIL9>(&mut scenario, 0, &clock);
        o.burn_for_testing();
    };

    // 9. Distribute gauge epoch 2 (collects SAIL fees from swaps)
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<SAIL, AUSD, SAIL, OSAIL9, USD_TESTS>(
            &mut scenario, &usd_metadata, &mut aggregator, &clock,
        );
    };

    // 10. Withdraw SAIL passive fees & notify
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_coin = minter::withdraw_passive_fee<SAIL, SAIL>(
            &mut minter, &distribute_governor_cap, &distribution_config, scenario.ctx(),
        );

        minter::notify_passive_fee<SAIL, SAIL>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor, fee_coin, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 11. Claim SAIL passive fee — verify it's liquid (not deposited into VE)
    let expected_epoch_1_fee = total_fee_per_token * 604799 / 604800;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Record lock balance before claim
        let (locked_bal_before, _) = voting_escrow::locked(&voting_escrow, lock_id);
        let amount_before = voting_escrow::amount(&locked_bal_before);

        // Claim SAIL passive fee
        let reward_coin = passive_fee_distributor::claim<SAIL, SAIL>(
            &mut distributor, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );

        // Lock balance should be unchanged (SAIL reward is liquid, not re-locked)
        let (locked_bal_after, _) = voting_escrow::locked(&voting_escrow, lock_id);
        let amount_after = voting_escrow::amount(&locked_bal_after);
        assert!(amount_before == amount_after, 1);

        // Reward should match expected amount
        assert!(expected_epoch_1_fee - reward_coin.value() <= 1, 2);
        assert!(reward_coin.value() > 0, 3);

        coin::burn_for_testing(reward_coin);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// F5. Multiple fee coin types — USD_TESTS and AUSD distributors
// ──────────────────────────────────────────────────────────

#[test]
fun test_multiple_fee_coin_types() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (epoch 1, clock = WEEK + 1000 ms)
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL10, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );

    // 2. Create PassiveFeeDistributor<USD_TESTS>
    scenario.next_tx(admin);
    let mut distributor_usd = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 3. Create PassiveFeeDistributor<AUSD>
    scenario.next_tx(admin);
    let mut distributor_ausd = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, AUSD>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 4. Advance to epoch 2 (clock = 2*WEEK + 1000 ms)
    clock.increment_for_testing(WEEK);

    // 5. Mint fee coins and notify each distributor
    let fee_amount: u64 = 4_000_000;

    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_usd = coin::mint_for_testing<USD_TESTS>(fee_amount, scenario.ctx());
        minter::notify_passive_fee<SAIL, USD_TESTS>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor_usd, fee_usd, &clock,
        );

        let fee_ausd = coin::mint_for_testing<AUSD>(fee_amount, scenario.ctx());
        minter::notify_passive_fee<SAIL, AUSD>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor_ausd, fee_ausd, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 6. User claims from both distributors
    // Distributors started at 604801, notified at 1209601
    // Epoch 1 period (604800) gets fee_amount * 604799 / 604800
    let expected_fee = fee_amount * 604799 / 604800;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // Check and claim USD_TESTS
        let claimable_usd = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor_usd, &voting_escrow, lock_id,
        );
        assert!(expected_fee - claimable_usd <= 1, 1);

        let reward_usd = passive_fee_distributor::claim<SAIL, USD_TESTS>(
            &mut distributor_usd, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        assert!(expected_fee - reward_usd.value() <= 1, 2);

        // Check and claim AUSD
        let claimable_ausd = passive_fee_distributor::claimable<SAIL, AUSD>(
            &distributor_ausd, &voting_escrow, lock_id,
        );
        assert!(expected_fee - claimable_ausd <= 1, 3);

        let reward_ausd = passive_fee_distributor::claim<SAIL, AUSD>(
            &mut distributor_ausd, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        assert!(expected_fee - reward_ausd.value() <= 1, 4);

        coin::burn_for_testing(reward_usd);
        coin::burn_for_testing(reward_ausd);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor_usd);
    test_utils::destroy(distributor_ausd);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

// ──────────────────────────────────────────────────────────
// F6. Independent distributor accounting — two same-type distributors
// ──────────────────────────────────────────────────────────

#[test]
fun test_independent_distributor_accounting() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;
    let lock_amount = 1_000_000;

    // 1. Full setup (epoch 1, clock = WEEK + 1000 ms)
    let aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL12, USD_TESTS>(
        &mut scenario, admin, user, &mut clock,
        lock_amount, 182, gauge_base_emissions, 0,
    );

    // 2. Create distributor_1 at epoch 1
    scenario.next_tx(admin);
    let mut distributor_1 = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 3. Advance to epoch 2 (clock = 2*WEEK + 1000 ms)
    clock.increment_for_testing(WEEK);

    // 4. Create distributor_2 at epoch 2 (different time than distributor_1)
    scenario.next_tx(admin);
    let distributor_2 = {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let d = minter::create_and_start_passive_fee_distributor<SAIL, USD_TESTS>(
            &minter, &admin_cap, &voting_escrow, &distribution_config, &clock, scenario.ctx(),
        );
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        d
    };

    // 5. Mint fee coins and notify ONLY distributor_1
    let fee_amount: u64 = 4_000_000;

    scenario.next_tx(admin);
    {
        let minter = scenario.take_shared<Minter<SAIL>>();
        let distribute_governor_cap = scenario.take_from_sender<DistributeGovernorCap>();
        let distribution_config = scenario.take_shared<DistributionConfig>();

        let fee_coin = coin::mint_for_testing<USD_TESTS>(fee_amount, scenario.ctx());
        minter::notify_passive_fee<SAIL, USD_TESTS>(
            &minter, &distribute_governor_cap, &distribution_config,
            &mut distributor_1, fee_coin, &clock,
        );

        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(distribution_config);
    };

    // 6. Verify distributor_1 has balance, distributor_2 is empty
    assert!(passive_fee_distributor::balance<USD_TESTS>(&distributor_1) > 0, 1);
    assert!(passive_fee_distributor::balance<USD_TESTS>(&distributor_2) == 0, 2);

    // 7. Verify user can claim from distributor_1 but not from distributor_2
    let expected_fee = fee_amount * 604799 / 604800;

    scenario.next_tx(user);
    {
        let voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let lock_id = object::id(&lock);

        // distributor_1: claimable > 0
        let claimable_1 = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor_1, &voting_escrow, lock_id,
        );
        assert!(expected_fee - claimable_1 <= 1, 3);

        // distributor_2: claimable == 0
        let claimable_2 = passive_fee_distributor::claimable<SAIL, USD_TESTS>(
            &distributor_2, &voting_escrow, lock_id,
        );
        assert!(claimable_2 == 0, 4);

        // Claim from distributor_1 to confirm
        let reward_coin = passive_fee_distributor::claim<SAIL, USD_TESTS>(
            &mut distributor_1, &voting_escrow, &distribution_config, &lock, scenario.ctx(),
        );
        assert!(expected_fee - reward_coin.value() <= 1, 5);

        coin::burn_for_testing(reward_coin);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
    };

    test_utils::destroy(distributor_1);
    test_utils::destroy(distributor_2);
    test_utils::destroy(usd_treasury_cap);
    test_utils::destroy(usd_metadata);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

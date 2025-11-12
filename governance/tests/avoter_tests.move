#[test_only]
module governance::avoter_tests;
// the name of the module is choosen to be so the SAIL coin is < USD_TESTS coin

use sui::coin::{Coin};
use sui::clock::{Self};
use sui::test_scenario::{Self};
use sui::test_utils;

use clmm_pool::pool::{Pool};

use voting_escrow::common;
use voting_escrow::voting_escrow::{VotingEscrow, Lock};
use governance::distribution_config::{DistributionConfig};
use governance::voter::{Self, Voter};
use governance::minter::{Self, Minter};
use governance::gauge::{Self, Gauge};
use governance::setup;

use governance::usd_tests::{Self, USD_TESTS};

const WEEK: u64 = 7 * 24 * 60 * 60 * 1000;

public struct AUSD has drop, store {}
public struct BUSD has drop, store {}
public struct USD has drop, store {}
public struct SAIL has drop, store {}
public struct OSAIL1 has drop, store {}
public struct OSAIL2 has drop, store {}
public struct OSAIL3 has drop, store {}
public struct OSAIL4 has drop, store {}
public struct OSAIL5 has drop, store {}

#[test]
fun test_normal_vote_and_claim_rewards() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // Distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Inject voting fee into the gauge
    let fee_amount = 500_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount, &clock);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);

    // Vote for the pool with the user's lock
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, &mut clock);
    };

    // Store the epoch when the vote was cast
    let vote_epoch: u64;
    scenario.next_tx(user);
    {
        vote_epoch = common::current_period(&clock);
    };

    // Advance by 2 epochs
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // Get the lock ID for updating weights
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // Update and finalize voted weights for the epoch the vote was cast in
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch,
        admin,
        &clock,
    );


    // Claim voting fee rewards with the user's lock
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool);
    };

    // Verify the user received the rewards
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        // The user should have received some rewards
        assert!(reward_coin.value() > 0, 0);
        // The reward should be close to the fee_amount injected
        assert!(fee_amount - reward_coin.value() <= 1, 1);
        reward_coin.burn_for_testing();
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_vote_and_claim_rewards_after_one_epoch() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // Distribute the gauge for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Inject voting fee into the gauge
    let fee_amount = 500_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount, &clock);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);

    // Vote for the pool with the user's lock
    scenario.next_tx(user);
    {
        setup::vote_for_pool<USD_TESTS, AUSD, SAIL>(&mut scenario, &mut clock);
    };

    // Store the epoch when the vote was cast
    let vote_epoch: u64;
    scenario.next_tx(user);
    {
        vote_epoch = common::current_period(&clock);
    };

    // Advance by only 1 epoch
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Get the lock ID for updating weights
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // Update and finalize voted weights for the epoch the vote was cast in
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch,
        admin,
        &clock,
    );

    // Claim voting fee rewards with the user's lock
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool);
    };

    // Verify the user received the rewards
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        // The user should have received some rewards
        assert!(reward_coin.value() > 0, 0);
        // The reward should be close to the fee_amount injected
        assert!(fee_amount - reward_coin.value() <= 1, 1);
        reward_coin.burn_for_testing();
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_vote_for_two_pools_and_claim_rewards() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    // Full setup with first pool (USD_TESTS/AUSD)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // Create second pool (USD_TESTS/BUSD)
    scenario.next_tx(admin);
    {
        let pool_sqrt_price: u128 = 1 << 64; // Price = 1
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, pool_sqrt_price, 1);
    };

    // Create gauge for second pool
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    // Distribute both gauges for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Inject voting fee into both gauges
    let fee_amount_pool1 = 300_000;
    let fee_amount_pool2 = 200_000;
    
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_pool1, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_pool2, &clock);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);

    // Vote for both pools with the user's lock
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        
        let pool1_id = object::id(&pool1);
        let pool2_id = object::id(&pool2);

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool1_id, pool2_id],
            vector[6000, 4000], // 60% to pool1, 40% to pool2
            vector[600_000, 400_000], // volumes in USD (6 decimals)
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
        test_scenario::return_shared(pool2);
    };

    // Store the epoch when the vote was cast
    let vote_epoch: u64;
    scenario.next_tx(user);
    {
        vote_epoch = common::current_period(&clock);
    };

    // Advance by 1 epoch
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Get the lock ID for updating weights
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // Update and finalize voted weights for pool 1
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch,
        admin,
        &clock,
    );

    // Update and finalize voted weights for pool 2
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch,
        admin,
        &clock,
    );

    // Claim voting fee rewards from pool 1
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool1,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
    };

    // Claim voting fee rewards from pool 2
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, BUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool2,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };

    // Verify the user received rewards from pool 1
    let pool1_rewards: u64;
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        pool1_rewards = reward_coin.value();
        // The user should have received some rewards
        assert!(pool1_rewards > 0, 0);
        reward_coin.burn_for_testing();
    };

    // Verify the user received rewards from pool 2
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        let pool2_rewards = reward_coin.value();
        // The user should have received some rewards
        assert!(pool2_rewards > 0, 1);
        
        // Total rewards should be close to total injected fees
        let total_rewards = pool1_rewards + pool2_rewards;
        let total_fees = fee_amount_pool1 + fee_amount_pool2;
        assert!(total_fees - total_rewards <= 2, 2);
        
        reward_coin.burn_for_testing();
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_vote_two_pools_then_revote_in_new_epoch() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());

    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);

    let gauge_base_emissions = 1_000_000;

    // Full setup with first pool (USD_TESTS/AUSD)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );

    // Create second pool (USD_TESTS/BUSD)
    scenario.next_tx(admin);
    {
        let pool_sqrt_price: u128 = 1 << 64; // Price = 1
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, pool_sqrt_price, 1);
    };

    // Create gauge for second pool
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };

    // Distribute both gauges for epoch 1
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Inject voting fee into both gauges for epoch 1
    let fee_amount_epoch1_pool1 = 300_000;
    let fee_amount_epoch1_pool2 = 200_000;
    
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch1_pool1, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch1_pool2, &clock);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);

    // Vote for both pools with the user's lock in epoch 1
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        
        let pool1_id = object::id(&pool1);
        let pool2_id = object::id(&pool2);

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool1_id, pool2_id],
            vector[6000, 4000], // 60% to pool1, 40% to pool2
            vector[600_000, 400_000], // volumes in USD (6 decimals)
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
        test_scenario::return_shared(pool2);
    };

    // Store the epoch when the vote was cast
    let vote_epoch_1: u64;
    scenario.next_tx(user);
    {
        vote_epoch_1 = common::current_period(&clock);
    };

    // Advance by 1 epoch
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 2
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };

    // Distribute both gauges for epoch 2
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };

    // Inject voting fee into both gauges for epoch 2
    let fee_amount_epoch2_pool1 = 150_000;
    let fee_amount_epoch2_pool2 = 250_000;
    
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch2_pool1, &clock);
    };

    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch2_pool2, &clock);
    };

    // Get the lock ID for updating weights
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };

    // Update and finalize voted weights for epoch 1 - pool 1
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch_1,
        admin,
        &clock,
    );

    // Update and finalize voted weights for epoch 1 - pool 2
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch_1,
        admin,
        &clock,
    );

    // Claim voting fee rewards from epoch 1 - pool 1
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool1,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
    };

    // Claim voting fee rewards from epoch 1 - pool 2
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, BUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool2,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };

    // Verify the user received rewards from pool 1
    let pool1_rewards: u64;
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        pool1_rewards = reward_coin.value();
        // The user should have received some rewards
        assert!(pool1_rewards > 0, 0);
        reward_coin.burn_for_testing();
    };

    // Verify the user received rewards from pool 2
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        let pool2_rewards = reward_coin.value();
        // The user should have received some rewards
        assert!(pool2_rewards > 0, 1);
        
        // Total rewards should be close to total injected fees
        let total_rewards = pool1_rewards + pool2_rewards;
        let total_fees = fee_amount_epoch1_pool1 + fee_amount_epoch1_pool2;
        assert!(total_fees - total_rewards <= 2, 2);
        
        reward_coin.burn_for_testing();
    };

    // Vote for pool 1 only in epoch 2
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        
        let pool1_id = object::id(&pool1);

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool1_id],
            vector[10000], // 100% to pool1
            vector[1_000_000], // volume in USD (6 decimals)
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
    };

    // Vote for pool 2 only in same epoch 2
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let mut ve = scenario.take_shared<VotingEscrow<SAIL>>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        
        let pool2_id = object::id(&pool2);

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool2_id],
            vector[10000], // 100% to pool2
            vector[1_000_000], // volume in USD (6 decimals)
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };

    // Store the epoch when the vote was cast
    let vote_epoch_2: u64;
    scenario.next_tx(user);
    {
        vote_epoch_2 = common::current_period(&clock);
    };

    // Advance by 1 epoch
    clock.increment_for_testing(WEEK);

    // Update minter period for epoch 3
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };

    // finalize the voted weights for the pool 1 (without updating the weight of the lock)
    scenario.next_tx(admin);
    {
        let mut minter = scenario.take_shared<Minter<SAIL>>();
        let mut voter = scenario.take_shared<Voter>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>();
        let gauge = scenario.take_shared<Gauge<USD_TESTS, AUSD>>();
        let gauge_id = object::id(&gauge);

        minter::finalize_voted_weights<SAIL>(
            &mut minter,
            &mut voter,
            &distribution_config,
            &distribute_governor_cap,
            gauge_id,
            vote_epoch_2,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(gauge);
    };

    // Update and finalize voted weights for epoch 2 - pool 2 only
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(
        &mut scenario,
        vector[lock_id],
        vector[10000], // 100% voting power
        vote_epoch_2,
        admin,
        &clock,
    );

    // Claim voting fee rewards from epoch 2 - pool 1
    scenario.next_tx(user);
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool2,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };

    // Verify the user has not received rewards from epoch 2 - pool 1
    scenario.next_tx(user);
    {
        assert!(!scenario.has_most_recent_for_sender<Coin<USD_TESTS>>(), 111);
    };

    // Claim voting fee rewards from epoch 2 - pool 2
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();

        voter::claim_voting_fee_by_pool<USD_TESTS, BUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool2,
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };

    // Verify the user received rewards from epoch 2 - pool 2
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        // The user should have received some rewards from pool 2
        assert!(reward_coin.value() > 0, 0);
        // The reward should be close to the fee_amount injected for pool 2 in epoch 2
        assert!(fee_amount_epoch2_pool2 - reward_coin.value() <= 1, 1);
        reward_coin.burn_for_testing();
    };

    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

/// This test is supposed to emulate real-world scenario where backend pushes weights after a week delay after the epoch ends.
/// This means that it is a 2 week delay after the epoch start. So suppose the user votes right at the begining of the epoch.
/// Then the backend finalizes the weight of the vote 2 weeks after the vote.
/// 
/// This produces a weird behaviour when user submits a new vote before the checkpoints for the previous week are finalized.
/// 
/// This test is to simulate this. It emulates 4 epoch course of the voting:
/// Epoch 1: User submits votes for the pool A
/// Epoch 2: User submits a new vote for the pool B
/// Epoch 3: At the begining, the backend updates & finalizes the weight of the vote for the epoch 1. It pushes a new 
/// weight in the gauge for the pool A and finalizes the gauges A and B.
/// After that, the user submits a new vote for the pool A. After that he changes his mind and revotes for the pool B.
/// Epoch 4: At the begining, the backend updates & finalizes the weight of the vote for the epoch 2. It pushes zero
/// weight in the gauge for the pool A as user has not voter for the pool A and finalizes the gauge A.
/// And pushes a new weight for the pool B as user has voted for the pool B and finalizes the gauge B.
/// Epoch 5: At the begining, the backend updates & finalizes the weight of the vote for the epoch 3. It just pushes the weight
/// for the pool B and finalizes the gauge B. There is no need to push any other weight as user has not voted for the pool A,
/// he changed his mind. Also user has not voted for the pool A in the epoch 2, so there is no need to push zero weight.
/// After that the user claims his rewards. He should receive rewards from the epoch 1 from the pool A, and from the epochs 2 and 3 from the pool B.
#[test]
fun test_vote_two_pools_then_revote_with_week_delay_finalization() {
    let admin = @0xA;
    let user = @0xB;
    let mut scenario = test_scenario::begin(admin);
    let mut clock = clock::create_for_testing(scenario.ctx());
    let (usd_treasury_cap, usd_metadata) = usd_tests::create_usd_tests(&mut scenario, 6);
    let gauge_base_emissions = 1_000_000;
    // Full setup with first pool (USD_TESTS/AUSD)
    let mut aggregator = setup::full_setup_with_lock<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(
        &mut scenario,
        admin,
        user,
        &mut clock,
        1_000_000,
        182,
        gauge_base_emissions,
        0
    );
    // Create second pool (USD_TESTS/BUSD)
    scenario.next_tx(admin);
    {
        let pool_sqrt_price: u128 = 1 << 64; // Price = 1
        setup::setup_pool_with_sqrt_price<USD_TESTS, BUSD>(&mut scenario, pool_sqrt_price, 1);
    };
    // Create gauge for second pool
    scenario.next_tx(admin);
    {
        setup::setup_gauge_for_pool<USD_TESTS, BUSD, SAIL>(&mut scenario, gauge_base_emissions, &clock);
    };
    // Epoch 1: Distribute gauges and inject fees
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL1, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    let fee_amount_epoch1_pool1 = 300_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch1_pool1, &clock);
    };

    let fee_amount_epoch1_pool2 = 200_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch1_pool2, &clock);
    };

    // advance 1 hour so the voting starts
    clock.increment_for_testing(1 * 60 * 60 * 1000);
    // Epoch 1: User votes for pool A
    scenario.next_tx(user);
    {
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool1_id = object::id(&pool1);
        setup::vote<SAIL>(&mut scenario, vector[pool1_id], vector[10000], vector[600_000], &mut clock);
        test_scenario::return_shared(pool1);
    };
    let vote_epoch_1 = common::current_period(&clock);
    // Advance to Epoch 2
    clock.increment_for_testing(WEEK);
    // Epoch 2: Update minter, distribute gauges, and inject fees
    scenario.next_tx(admin);
    {
        let o_sail_coin_2 = setup::update_minter_period<SAIL, OSAIL2>(&mut scenario, 0, &clock);
        o_sail_coin_2.burn_for_testing();
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL2, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    let fee_amount_epoch2_pool2 = 250_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch2_pool2, &clock);
    };

    let fee_amount_epoch2_pool1 = 150_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch2_pool1, &clock);
    };

    // Epoch 2: User votes for pool B
    scenario.next_tx(user);
    {
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        let pool2_id = object::id(&pool2);
        setup::vote<SAIL>(&mut scenario, vector[pool2_id], vector[10000], vector[1_000_000], &mut clock);
        test_scenario::return_shared(pool2);
    };
    let vote_epoch_2 = common::current_period(&clock);
    // Advance to Epoch 3
    clock.increment_for_testing(WEEK);
    // Epoch 3: Update minter and finalize epoch 1 weights
    scenario.next_tx(admin);
    {
        let o_sail_coin_3 = setup::update_minter_period<SAIL, OSAIL3>(&mut scenario, 0, &clock);
        o_sail_coin_3.burn_for_testing();
    };
    let lock_id: ID;
    scenario.next_tx(user);
    {
        let lock = scenario.take_from_sender<Lock>();
        lock_id = object::id(&lock);
        scenario.return_to_sender(lock);
    };
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(&mut scenario, vector[lock_id], vector[10000], vote_epoch_1, admin, &clock);
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(&mut scenario, vector[], vector[], vote_epoch_1, admin, &clock);
    // Epoch 3: Distribute gauges and inject fees
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, AUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    scenario.next_tx(admin);
    {
        setup::distribute_gauge<USD_TESTS, BUSD, SAIL, OSAIL3, USD_TESTS>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
    };
    let fee_amount_epoch3_pool2 = 50_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, BUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch3_pool2, &clock);
    };

    let fee_amount_epoch3_pool1 = 100_000;
    scenario.next_tx(admin);
    {
        setup::inject_voting_fee_reward<USD_TESTS, AUSD, SAIL, USD_TESTS>(&mut scenario, fee_amount_epoch3_pool1, &clock);
    };

    // Epoch 3: User votes for pool A, then revotes for pool B
    scenario.next_tx(user);
    {
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        let pool1_id = object::id(&pool1);
        setup::vote<SAIL>(&mut scenario, vector[pool1_id], vector[10000], vector[1_000_000], &mut clock);
        test_scenario::return_shared(pool1);
    };
    scenario.next_tx(user);
    {
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        let pool2_id = object::id(&pool2);
        setup::vote<SAIL>(&mut scenario, vector[pool2_id], vector[10000], vector[1_000_000], &mut clock);
        test_scenario::return_shared(pool2);
    };
    let vote_epoch_3 = common::current_period(&clock);
    // Advance to Epoch 4
    clock.increment_for_testing(WEEK);
    // Epoch 4: Update minter and finalize epoch 2 weights
    scenario.next_tx(admin);
    {
        let o_sail_coin_4 = setup::update_minter_period<SAIL, OSAIL4>(&mut scenario, 0, &clock);
        o_sail_coin_4.burn_for_testing();
    };
    // null pool A weight, cos lock voted in epoch 1 for pool A and not voted for pool A in epoch 2.
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(&mut scenario, vector[lock_id], vector[0], vote_epoch_2, admin, &clock);
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(&mut scenario, vector[lock_id], vector[10000], vote_epoch_2, admin, &clock);
    // Advance to Epoch 5
    clock.increment_for_testing(WEEK);
    // Epoch 5: Update minter and finalize epoch 3 weights
    scenario.next_tx(admin);
    {
        let o_sail_coin_5 = setup::update_minter_period<SAIL, OSAIL5>(&mut scenario, 0, &clock);
        o_sail_coin_5.burn_for_testing();
    };

    // no need to null pool A weight in epoch 3, cos lock didn't vote in epoch 2 for pool A
    setup::update_and_finalize_voted_weights<USD_TESTS, AUSD, SAIL>(&mut scenario, vector[], vector[], vote_epoch_3, admin, &clock);
    setup::update_and_finalize_voted_weights<USD_TESTS, BUSD, SAIL>(&mut scenario, vector[lock_id], vector[10000], vote_epoch_3, admin, &clock);
    // User claims rewards from pool A
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool1 = scenario.take_shared<Pool<USD_TESTS, AUSD>>();
        voter::claim_voting_fee_by_pool<USD_TESTS, AUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool1,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool1);
    };
    // Verify rewards from pool A (only from epoch 1)
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        assert!(reward_coin.value() > 0, 0);
        assert!(fee_amount_epoch1_pool1 - reward_coin.value() <= 1, 1);
        reward_coin.burn_for_testing();
    };
    // User claims rewards from pool B
    scenario.next_tx(user);
    {
        let mut voter = scenario.take_shared<Voter>();
        let mut voting_escrow = scenario.take_shared<VotingEscrow<SAIL>>();
        let distribution_config = scenario.take_shared<DistributionConfig>();
        let lock = scenario.take_from_sender<Lock>();
        let pool2 = scenario.take_shared<Pool<USD_TESTS, BUSD>>();
        voter::claim_voting_fee_by_pool<USD_TESTS, BUSD, SAIL>(
            &mut voter,
            &mut voting_escrow,
            &distribution_config,
            &lock,
            &pool2,
            &clock,
            scenario.ctx()
        );
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(lock);
        test_scenario::return_shared(pool2);
    };
    // Verify rewards from pool B (from epochs 2 and 3)
    scenario.next_tx(user);
    {
        let reward_coin = scenario.take_from_sender<Coin<USD_TESTS>>();
        let expected_rewards = fee_amount_epoch2_pool2 + fee_amount_epoch3_pool2;
        assert!(reward_coin.value() > 0, 2);
        assert!(expected_rewards - reward_coin.value() <= 2, 3);
        reward_coin.burn_for_testing();
    };
    // Cleanup
    transfer::public_transfer(usd_treasury_cap, admin);
    transfer::public_transfer(usd_metadata, admin);
    test_utils::destroy(aggregator);
    clock::destroy_for_testing(clock);
    scenario.end();
}

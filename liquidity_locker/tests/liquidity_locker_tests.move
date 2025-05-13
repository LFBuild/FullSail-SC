#[test_only]
module liquidity_locker::liquidity_locker_tests {
    use sui::test_scenario;
    use sui::test_utils;

    use liquidity_locker::liquidity_locker;
    use liquidity_locker::pool_tranche;
    use locker_cap::locker_cap;
    use clmm_pool::position;
    use clmm_pool::pool;
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config, GlobalConfig, AdminCap};
    use clmm_pool::stats;
    use clmm_pool::tick_math;
    use clmm_pool::partner;
    use clmm_pool::acl;
    use clmm_pool::rewarder;
    use price_provider::price_provider;
    use distribution::distribution_config;
    use distribution::voter;
    use distribution::voting_escrow;
    use distribution::minter;
    use distribution::gauge;
    use distribution::common;
    use distribution::reward_distributor;
    use sui::clock;
    use distribution::common::epoch_to_seconds;


    #[test_only]
    public struct TestCoinA has drop {}
    #[test_only]
    public struct TestCoinB has drop {}
    #[test_only]
    public struct SailCoinType has drop {}
    #[test_only]
    public struct RewardCoinType1 has drop {}
    #[test_only]
    public struct RewardCoinType2 has drop {}
    #[test_only]
    public struct RewardCoinType3 has drop {}
    #[test_only]
    public struct OSAIL1 has drop {}
    #[test_only]
    public struct OSAIL2 has drop {}
    #[test_only]
    public struct OSAIL3 has drop {}
    #[test_only]
    public struct OSAIL4 has drop {}
        

    #[test]
    fun test_init() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Post init
        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            // let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            // transfer::public_transfer(tranche_manager, admin);
            test_scenario::return_shared(locker);
        };

        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_lock_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time, full_unlocking_time) = liquidity_locker::get_unlock_time(&locked_position);
            assert!(expiration_time == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253242);
            assert!(full_unlocking_time == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 9234326345);
            assert!(liquidity_locker::get_profitability(&locked_position) == 10000, 923463477);
            assert!(locked_position.get_locked_position_id() == position_id, 9234325235);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockManagerPaused)]
    fun test_lock_position_lock_manager_paused() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            liquidity_locker::locker_pause(&admin_cap, &mut locker, true);

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_lock_position_invalid_gauge_pool() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut pool_2 = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                2, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool_2,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(pools);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EPositionNotStaked)]
    fun test_lock_position_position_not_staked() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            gauge.withdraw_position<TestCoinB, TestCoinA, SailCoinType>(
                &mut pool,
                position_id,
                &clock,
                scenario.ctx()
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = gauge::EWithdrawPositionPositionIsLocked)]
    fun test_unstaked_failed_after_lock_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            gauge.withdraw_position<TestCoinB, TestCoinA, SailCoinType>(
                &mut pool,
                position_id,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EPositionAlreadyLocked)]
    fun test_lock_position_position_already_locked() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let mut locked_positions2 = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions2.destroy_empty();

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidBlockPeriodIndex)]
    fun test_lock_position_invalid_block_period_index() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                4,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_lock_position_no_tranches() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidProfitabilitiesLength)]
    fun test_lock_position_invalid_profitabilities_length_in_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_with_split() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                1000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let ( position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            // позиция не влезает в первый транш с объемом 4000000000000000000, делится на две 
            // 4000000000000000000 и 7984584197103522

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253242);
            assert!(full_unlocking_time_1 == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253252);
            assert!(full_unlocking_time_2 == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 165688655270059192614, 923412491398739);
            assert!(liquidity2 == 332041393326771866, 9234124983278);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);
            assert!(pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).is_staked(), 9235939696);
            assert!(pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).is_staked(), 9235939697);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_with_split_2() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                50000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                33<<64,
                &clock
            );

            // let total_liquidity = pool.position_manager().borrow_position_info(position_id).info_liquidity();
            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7), 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 92343253252);
            assert!(full_unlocking_time_2 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7), 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            // assert!((liquidity1 + liquidity2) == total_liquidity, 92873453487);
            assert!(liquidity1 == 165687548465414770041, 923412491398739);
            assert!(liquidity2 == 443055005967000433161, 9234124983278);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);
            assert!(pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).is_staked(), 9235939696);
            assert!(pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).is_staked(), 9235939697);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_split_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 36893488147419103232, 923412491398739);

            let position_id_1 = &locked_position_1.get_locked_position_id();

            let (locked_position_11, locked_position_12) = liquidity_locker::split_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            let position_id_11 = &locked_position_11.get_locked_position_id();
            assert!(position_id_11 == position_id_1, 923503059333);

            let liquidity11 = pool.position_manager().borrow_position_info(locked_position_11.get_locked_position_id()).info_liquidity();
            assert!(liquidity11 == 36893488147419103232/2, 9325035242342);

            let liquidity12 = pool.position_manager().borrow_position_info(locked_position_12.get_locked_position_id()).info_liquidity();
            assert!(liquidity12 == (36893488147419103232/2)-27, 9325035242343);

            let (locked_position_111, locked_position_112) = liquidity_locker::split_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_11,
                23000, // 23%
                &clock,
                scenario.ctx()
            );
            let position_id_111 = &locked_position_111.get_locked_position_id();
            assert!(position_id_111 == position_id_1, 923503059336);

            let liquidity111 = pool.position_manager().borrow_position_info(locked_position_111.get_locked_position_id()).info_liquidity();
            assert!(liquidity111 == 36893488147419103232*23/200, 9325035242344);

            let liquidity112 = pool.position_manager().borrow_position_info(locked_position_112.get_locked_position_id()).info_liquidity();
            assert!(liquidity112 == (36893488147419103232*77/200-69), 9325035242345);

            transfer::public_transfer(locked_position_111, admin);
            transfer::public_transfer(locked_position_112, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // TODO посмотреть на награду после сплита

    // ELockManagerPaused при сплите
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockManagerPaused)]
    fun test_split_position_pause(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_locker::locker_pause(&admin_cap, &mut locker, true);

            let (locked_position_11, locked_position_12) = liquidity_locker::split_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockPeriodEnded при сплите
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockPeriodEnded)]
    fun test_split_position_period_ended(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(6)*1000);

            let (locked_position_11, locked_position_12) = liquidity_locker::split_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EInvalidGaugePool при сплите
    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_split_position_invalid_gauge_pool(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();
            let mut periods_blocking = std::vector::empty();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());


            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let mut pool_2 = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                2, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );

            let (locked_position_11, locked_position_12) = liquidity_locker::split_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut gauge,
                &mut pool_2,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_remove_lock_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 2);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4320664223000003333 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 3*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 4*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219369787329198410390, 923412491398739); // 66%
            assert!(liquidity2 == 112671605997573518490, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType3>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 это первый лок из первого транша
            let mut locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            // 66% от тотал реварда за 1 эпоху
            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );
            assert!(reward1.value() == 6606699, 9234129832754);

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            // клейм награды за вторую эпоху лока
            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            // 66% от тотал реварда за 3 эпоху
            let reward3 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(4)),
                &clock
            );
            assert!(reward3.value() == 7009048, 9234129832754); // +3% for epoch 2 and +3% for epoch 3

            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

            // Склеймить все награды
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 3794126173307114777, 92348768657674);
            assert!(remove_balance_b.value() == 534405474921791512, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let position = scenario.take_from_sender<position::Position>();
            assert!(position.liquidity() == 0, 9234887456443);

            transfer::public_transfer(position, admin);

            // награда второй эпохи была в SAIL
            // который автоматически залочился в VOTING_ESCROW
            let lock = scenario.take_from_sender<voting_escrow::Lock>();
            assert!(lock.get_amount() == 6804900, 926223626362);
            let voting_power = ve.get_voting_power(&lock, &clock);
            assert!(voting_power == 6804900, 9745754745543);

            transfer::public_transfer(lock, admin);
            test_scenario::return_shared(ve);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // вывод ликвидности по эпохам
    #[test]
    fun test_remove_lock_liquidity_by_epoch(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                (101<<64)/100, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 3);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4320664223000003333 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 2*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219575652993061008986, 9234124913987);
            assert!(liquidity2 == 112465740333710919911, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType3>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 это первый лок из первого транша
            let mut locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );
            assert!(reward1.value() == 6612899, 9234129832754);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            // Склеймить все награды
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
                &mut pool,
                locked_position_2.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );

            // прошла одна эпоха с даты экспирации
            // можно забрать 1/3
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 1082352715785369270, 92348768657674);
            assert!(remove_balance_b.value() == 365061384823952775, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 это первый лок из первого транша
            let locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            // прошло две эпохи с даты экспирации
            // можно забрать 2/3
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 1082352715785369270, 92348768657674);
            assert!(remove_balance_b.value() == 365061384823952775, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        scenario.next_tx(admin);
        {
            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (6)

            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 это первый лок из первого транша
            let locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 1082352715785369270, 92348768657674);
            assert!(remove_balance_b.value() == 365061384823952775, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        scenario.next_tx(admin);
        {
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let position = scenario.take_from_sender<position::Position>();
            assert!(position.liquidity() == 0, 9234887456443);

            transfer::public_transfer(position, admin);
            test_scenario::return_shared(ve);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // разлок позиции, без вывода ликвидки
    #[test]
    fun test_unlock_position_without_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1050000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            // Склеймить все награды
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

            let position_id = locked_position_1.get_locked_position_id();
            assert!(locker.is_position_locked(position_id), 9234887456443);

            // full unlock
            liquidity_locker::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );

            assert!(!locker.is_position_locked(position_id), 9234887456444);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::ERewardsNotCollected)]
    fun test_remove_lock_liquidity_not_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                1234567899876543210 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                21,
                433,
                7<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 60736273797570172886, 9234732473242);
            assert!(liquidity2 == 68390934718396688319, 9234732473243);
            
            clock.increment_for_testing(common::epoch_to_seconds(6)*1000);

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                21,
                433,
                7<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            let mut locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let mut pool_2 = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                2, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );
            
            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool_2,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );
                
            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // NotClaimedRewards при клейме наград
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ENotClaimedRewards)]
    fun test_not_claimed_rewards_when_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1050000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            // Склеймить все награды
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

            let reward3 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );
            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ClaimEpochIncorrect при клейме наград
    #[test]
    #[expected_failure(abort_code = liquidity_locker::EClaimEpochIncorrect)]
    fun test_claim_epoch_incorrect_when_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                21,
                433,
                7<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            let mut locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();
            
            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                clock.timestamp_ms()/1000,
                &clock
            );
                
            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_collect_rewards_sail(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                21,
                433,
                7<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            let mut locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let mut pool_2 = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                2, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );
            
            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL1, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool_2,
                &mut locked_position_1,
                clock.timestamp_ms()/1000,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::ENotClaimedRewards)]
    fun test_not_claimed_rewards_when_collect_rewards_sail(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1050000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            // Склеймить все награды
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );
            gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
                &mut pool,
                locked_position_1.get_locked_position_id(),
                &clock,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused при разлоке
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockManagerPaused)]
    fun test_pause_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            liquidity_locker::locker_pause(&admin_cap, &mut locker, true);

            liquidity_locker::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EFullLockPeriodNotEnded при разлоке
    #[test]
    #[expected_failure(abort_code = liquidity_locker::EFullLockPeriodNotEnded)]
    fun test_full_lock_period_not_ended_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            liquidity_locker::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ERewardsNotCollected при разлоке
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ERewardsNotCollected)]
    fun test_rewards_not_collected_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(4)*1000);

            liquidity_locker::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused при выводе ликвидности
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockManagerPaused)]
    fun test_pause_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            liquidity_locker::locker_pause(&admin_cap, &mut locker, true);

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockPeriodNotEnded при выводе ликвидности
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockPeriodNotEnded)]
    fun test_lock_period_not_ended_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EInvalidGaugePool при выводе ликвидности
    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let  pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut pool_2 = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                2, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(5)*1000);

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool_2,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ERewardsNotCollected при выводе ликвидности
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ERewardsNotCollected)]
    fun test_rewards_not_collected_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 2);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4320664223000003333 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 3*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 4*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219369787329198410390, 923412491398739); // 66%
            assert!(liquidity2 == 112671605997573518490, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType3>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            let mut locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ENoLiquidityToRemove при выводе ликвидности
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ENoLiquidityToRemove)]
    fun test_no_liquidity_to_remove_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 2);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 1000);
            std::vector::push_back(&mut duration_profitabilities, 2000);
            std::vector::push_back(&mut duration_profitabilities, 3000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                4320664223000003333 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 3*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (distribution::common::epoch_start(clock.timestamp_ms()/1000) + 4*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219369787329198410390, 923412491398739); // 66%
            assert!(liquidity2 == 112671605997573518490, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // добавление награды в 1 транш
        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        scenario.next_tx(admin);
        {
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_tranche::add_reward<RewardCoinType3>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                1000000000000
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();
            let mut locked_position_2 = scenario.take_from_sender<liquidity_locker::LockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL1, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(2)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            liquidity_locker::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(3)),
                &clock,
                scenario.ctx()
            );

            let reward3 = liquidity_locker::collect_reward<TestCoinB, TestCoinA, OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                common::epoch_start(common::epoch_to_seconds(4)),
                &clock
            );

            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);

            // clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

            // gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL1>(
            //     &mut pool,
            //     locked_position_2.get_locked_position_id(),
            //     &clock,
            //     scenario.ctx()
            // );
            // gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL2>(
            //     &mut pool,
            //     locked_position_2.get_locked_position_id(),
            //     &clock,
            //     scenario.ctx()
            // );
            // gauge.get_position_reward<TestCoinB, TestCoinA, OSAIL3>(
            //     &mut pool,
            //     locked_position_2.get_locked_position_id(),
            //     &clock,
            //     scenario.ctx()
            // );

            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity<TestCoinB, TestCoinA, OSAIL4>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(reward_distributor);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_with_swap_a2b() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // обеспечим ликвидность в пуле
            let position_admin = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                500,
                9<<64,
                &clock
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(liquidity == 36893488147419103232, 923412491398739);

            let position_id = &locked_position.get_locked_position_id();

            liquidity_locker::change_tick_range<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(100),
                integer_mate::i32::from_u32(200),
                &clock,
                scenario.ctx()
            );

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(new_liquidity == 179538079592236621463, 923412491398739); // ликвидность должна быть пропорционально увеличена ~ в 4.87 раза

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(100)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(200)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_with_swap_b2a() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, // 148 current tick
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_locker::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut duration_profitabilities = std::vector::empty();
            std::vector::push_back(&mut duration_profitabilities, 10000);
            std::vector::push_back(&mut duration_profitabilities, 20000);
            std::vector::push_back(&mut duration_profitabilities, 30000);

            create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                &mut tranche_manager,
                &tranche_admin_cap,
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // обеспечим ликвидность в пуле
            let position_admin = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                500,
                9<<64,
                &clock
            );

            let (position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                200,
                1<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            std::debug::print(&std::string::utf8(b"liquidity"));
            std::debug::print(&liquidity);
            assert!(liquidity == 18446744073709551616, 923412491398739);

            let position_id = &locked_position.get_locked_position_id();

            liquidity_locker::change_tick_range<TestCoinB, TestCoinA, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(13),
                integer_mate::i32::from_u32(417),
                &clock,
                scenario.ctx()
            );

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            std::debug::print(&std::string::utf8(b"new_liquidity"));
            std::debug::print(&new_liquidity);
            assert!(new_liquidity == 4584779504003109389, 923412491398739); // ликвидность должна быть пропорционально уменьшена ~ в 4 раза

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(13)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(417)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    // TODO разные интервалы потестить

    
    #[test_only]
    fun create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType>(
        scenario: &mut test_scenario::Scenario,
        tranche_manager: &mut pool_tranche::PoolTrancheManager,
        tranche_admin_cap: &pool_tranche::AdminCap,
        pool: &pool::Pool<TestCoinB, TestCoinA>,
        volume_in_coin_a: bool,
        total_volume: u128, // Q64.64
        duration_profitabilities: vector<u64>,
        minimum_remaining_volume: u64,
        reward_value: u64,
        total_income: u64,
        epoch: u64
    ) {
            pool_tranche::new(
                tranche_admin_cap,
                tranche_manager,
                pool,
                volume_in_coin_a,
                total_volume,  // total_volume
                duration_profitabilities, // duration_profitabilities
                minimum_remaining_volume, // minimum_remaining_volume
                scenario.ctx()
            );
            let tranches = pool_tranche::get_tranches(
                tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(pool)
            );
            let new_tranche = tranches.borrow(tranches.length() - 1);
            // add reward
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(new_tranche);
            let reward = sui::coin::mint_for_testing<RewardCoinType>(reward_value, scenario.ctx());

            pool_tranche::add_reward<RewardCoinType>(
                tranche_admin_cap,
                tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(pool),
                tranche_id,
                epoch,
                reward.into_balance(),
                total_income
            );
    }

    #[test_only]
    fun get_tranche_by_index(
        tranche_manager: &mut pool_tranche::PoolTrancheManager,
        pool_id: sui::object::ID,
        index: u64
    ): &mut pool_tranche::PoolTranche {
        let tranches = pool_tranche::get_tranches(
            tranche_manager, 
            pool_id
        );
        tranches.borrow_mut(index)
    }

    #[test_only]
    fun create_position_with_liquidity<CoinTypeB, CoinTypeA>(
        scenario: &mut test_scenario::Scenario,
        global_config: &GlobalConfig,
        vault: &mut rewarder::RewarderGlobalVault,
        pool: &mut pool::Pool<CoinTypeB, CoinTypeA>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_delta: u128,
        clock: &sui::clock::Clock,
    ): position::Position {

        // Open the position
        let mut position = pool::open_position<CoinTypeB, CoinTypeA>(
            global_config,
            pool,
            tick_lower,
            tick_upper,
            scenario.ctx()
        );

        // Add liquidity
        let receipt = pool::add_liquidity<CoinTypeB, CoinTypeA>(
            global_config,
            vault,
            pool,
            &mut position,
            liquidity_delta,
            clock
        );

        // Repay liquidity
        let (amount_a, amount_b) = pool::add_liquidity_pay_amount<CoinTypeB, CoinTypeA>(&receipt);
        let coin_a = sui::coin::mint_for_testing<CoinTypeB>(amount_a, scenario.ctx());
        let coin_b = sui::coin::mint_for_testing<CoinTypeA>(amount_b, scenario.ctx());

        std::debug::print(&std::string::utf8(b"coin_a CREATE_POSITION"));
        std::debug::print(&coin_a.value());
        std::debug::print(&std::string::utf8(b"coin_b CREATE_POSITION"));
        std::debug::print(&coin_b.value());

        pool::repay_add_liquidity<CoinTypeB, CoinTypeA>(
            global_config,
            pool,
            coin_a.into_balance(),
            coin_b.into_balance(),
            receipt // receipt is consumed here
        );

        position
    }

    #[test_only]
    fun create_and_deposit_position<TestCoinB, TestCoinA>(
        scenario: &mut test_scenario::Scenario,
        global_config: &GlobalConfig,
        distribution_config: &mut distribution_config::DistributionConfig,
        gauge: &mut gauge::Gauge<TestCoinB, TestCoinA>,
        vault: &mut rewarder::RewarderGlobalVault,
        pool: &mut pool::Pool<TestCoinB, TestCoinA>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_delta: u128,
        clock: &sui::clock::Clock,
    ):  (sui::object::ID) {
        let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
            scenario,
            global_config,
            vault,
            pool,
            tick_lower,
            tick_upper,
            liquidity_delta,
            clock
        );
        let position_id = sui::object::id<position::Position>(&position);

        distribution::gauge::deposit_position<TestCoinB, TestCoinA>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            scenario.ctx(),
        );

        (position_id)
    }

    #[test_only]
    fun full_setup_with_osail(
        scenario: &mut sui::test_scenario::Scenario,
        admin: address,
        amount_to_lock: u64,
        lock_duration_days: u64,
        current_sqrt_price: u128,
        clock: &mut clock::Clock
    ){
        scenario.next_tx(admin);
        {
            setup_distribution<SailCoinType>(scenario, admin);
        };

        scenario.next_tx(admin);
        {
            activate_minter<SailCoinType>(scenario, amount_to_lock, lock_duration_days);
        };

        clock::increment_for_testing(clock, 3601000); // + 1 hour 1 sec
        scenario.next_tx(admin);
        {
            create_pool_and_gauge<TestCoinB, TestCoinA, SailCoinType>(
                scenario, 
                admin,
                current_sqrt_price,
                clock
            );
        };

        clock::increment_for_testing(clock, common::epoch_start(common::epoch_to_seconds(2))*1000); // Advance clock by 1 epoch

        // Update Minter Period to OSAIL1
        scenario.next_tx(admin);
        {
            let initial_o_sail1_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL1>(
                scenario,
                1_000_000, // Arbitrary supply for OSAIL1
                admin,
                clock
            );
            sui::coin::burn_for_testing(initial_o_sail1_supply); // Burn OSAIL1
        };
    }

    #[test_only]
    public fun setup_distribution<SailCoinType>(
        scenario: &mut test_scenario::Scenario,
        sender: address
    ) { // No return value

        // --- Initialize Distribution Config ---
        scenario.next_tx(sender);
        {
            distribution_config::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
        };

        // --- Minter Setup --- 
        scenario.next_tx(sender);
        {
            let minter_publisher = minter::test_init(scenario.ctx());
            let treasury_cap = sui::coin::create_treasury_cap_for_testing<SailCoinType>(scenario.ctx());
            let (minter_obj, minter_admin_cap) = minter::create<SailCoinType>(
                &minter_publisher,
                option::some(treasury_cap),
                scenario.ctx()
            );
            test_utils::destroy(minter_publisher);
            transfer::public_share_object(minter_obj);
            transfer::public_transfer(minter_admin_cap, sender);
        };

        // --- Voter Setup --- 
        scenario.next_tx(sender);
        {
            let voter_publisher = voter::test_init(scenario.ctx()); 
            let global_config_obj = scenario.take_shared<config::GlobalConfig>();
            let global_config_id = object::id(&global_config_obj);
            test_scenario::return_shared(global_config_obj);
            let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();
            let distribution_config_id = object::id(&distribution_config_obj);
            test_scenario::return_shared(distribution_config_obj);
            let (mut voter_obj, notify_cap) = voter::create(
                &voter_publisher,
                global_config_id,
                distribution_config_id,
                scenario.ctx()
            );

            voter_obj.add_governor(&voter_publisher, sender, scenario.ctx());

            test_utils::destroy(voter_publisher);
            transfer::public_share_object(voter_obj);

            // --- Set Notify Reward Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_notify_reward_cap(&minter_admin_cap, notify_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };

        // --- VotingEscrow Setup --- 
        scenario.next_tx(sender);
        {
            let clock = clock::create_for_testing(scenario.ctx());
            let ve_publisher = voting_escrow::test_init(scenario.ctx());
            let voter_obj = scenario.take_shared<voter::Voter>(); 
            let voter_id = object::id(&voter_obj);
            test_scenario::return_shared(voter_obj); 
            let ve_obj = voting_escrow::create<SailCoinType>(
                &ve_publisher,
                voter_id, 
                &clock,
                scenario.ctx()
            );
            test_utils::destroy(ve_publisher);
            transfer::public_share_object(ve_obj);
            clock::destroy_for_testing(clock);
        };

        // --- RewardDistributor Setup --- 
        scenario.next_tx(sender);
        {
            let clock = clock::create_for_testing(scenario.ctx());
            let rd_publisher = reward_distributor::test_init(scenario.ctx());
            let (rd_obj, rd_cap) = reward_distributor::create<SailCoinType>(
                &rd_publisher,
                &clock,
                scenario.ctx()
            );
            test_utils::destroy(rd_publisher);
            transfer::public_share_object(rd_obj);
            clock::destroy_for_testing(clock);
            // --- Set Reward Distributor Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_reward_distributor_cap(&minter_admin_cap, rd_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };
    }


    #[test_only]
    // Updates the minter period, sets the next period token to OSailCoinTypeNext
    public fun update_minter_period_and_distribute_gauge<SailCoinType, OSailCoinType>(
        scenario: &mut test_scenario::Scenario,
        initial_o_sail_supply: u64,
        admin: address,
        clock: &sui::clock::Clock,
    ): sui::coin::Coin<OSailCoinType> {
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut voter = scenario.take_shared<voter::Voter>();
            let voting_escrow = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            // Create TreasuryCap for OSAIL for the next epoch
            let mut o_sail_cap = sui::coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
            let initial_supply = o_sail_cap.mint(initial_o_sail_supply, scenario.ctx());

            minter::update_period<SailCoinType, OSailCoinType>(
                &minter_admin_cap,
                &mut minter,
                &mut voter,
                &voting_escrow,
                &mut reward_distributor,
                o_sail_cap, 
                clock,
                scenario.ctx()
            );

            voter.distribute_gauge<TestCoinB, TestCoinA, OSailCoinType>(
                &distribution_config,
                &mut gauge,
                &mut pool,
                clock,
                scenario.ctx()
            );

            // Return shared objects & caps
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(voting_escrow);
            test_scenario::return_shared(reward_distributor);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);

            initial_supply
    }

    #[test_only]
    // Activates the minter for a specific oSAIL epoch.
    // Requires the minter, voter, rd, and admin cap to be set up.
    public fun activate_minter<SailCoinType>( // Changed to public
        scenario: &mut test_scenario::Scenario,
        amount_to_lock: u64,
        lock_duration_days: u64
    ) { // Returns the minted oSAIL

        // increment clock to make sure the activated_at field is not and epoch start is not 0
        let mut minter_obj = scenario.take_shared<minter::Minter<SailCoinType>>();
        let mut rd = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        let mut clock = clock::create_for_testing(scenario.ctx());

        clock.increment_for_testing(1000);
        minter_obj.activate<SailCoinType>(
            &minter_admin_cap,
            &mut rd,
            &clock,
            scenario.ctx()
        );

        let sail_coin = sui::coin::mint_for_testing<SailCoinType>(amount_to_lock, scenario.ctx());
        // create_lock consumes the coin and transfers the lock to ctx.sender()
        ve.create_lock<SailCoinType>(
            sail_coin,
            lock_duration_days,
            false, // permanent lock = false
            &clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter_obj);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(rd);
        scenario.return_to_sender(minter_admin_cap);
        clock::destroy_for_testing(clock);
    }

    #[test_only]
    fun create_pool_and_gauge<TestCoinB, TestCoinA, SailCoinType>(
        scenario: &mut test_scenario::Scenario,
        admin: address,
        current_sqrt_price: u128,
        clock: &clock::Clock,
    ){
        let mut global_config = scenario.take_shared<config::GlobalConfig>();
        let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
        let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
        let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut pools = scenario.take_shared<Pools>();
        let lock = scenario.take_from_sender<voting_escrow::Lock>();

        config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

        let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
            &mut pools,
            &global_config,
            1, // tick_spacing
            current_sqrt_price,
            std::string::utf8(b""), // url
            @0x2, // feed_id_coin_a
            @0x3, // feed_id_coin_b
            true, // auto_calculation_volumes
            clock,
            scenario.ctx()
        );
        let pool_id = sui::object::id<pool::Pool<TestCoinB, TestCoinA>>(&pool);

        let gauge = voter.create_gauge<TestCoinB, TestCoinA, SailCoinType>(
            &mut distribution_config,
            &gauge_create_cap,
            &governor_cap,
            &ve, // VotingEscrow is borrowed immutably here
            &mut pool,
            clock,
            scenario.ctx()
        );

        voter.vote(
            &mut ve,
            &distribution_config,
            &lock,
            vector[pool_id],
            vector[10000], // 100% weight
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pools);
        transfer::public_transfer(pool, admin);
        transfer::public_transfer(gauge, admin);
        scenario.return_to_sender(lock);
        transfer::public_transfer(gauge_create_cap, admin);
        scenario.return_to_sender(governor_cap);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
    }
    
}
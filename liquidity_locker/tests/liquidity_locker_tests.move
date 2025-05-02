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
    use distribution::reward_distributor;
    use sui::clock;


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
    public struct OSAIL has drop {}

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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            assert!(expiration_time == distribution::common::epoch_next(4*86400*7), 9234325235);
            assert!(full_unlocking_time == distribution::common::epoch_next(5*86400*7), 9234326345);
            assert!(liquidity_locker::get_profitability(&locked_position) == 10000, 923463477);
            assert!(locked_position.get_locked_position_id() == position_id, 9234325235);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::ELockManagerPaused)]
    fun test_lock_position_lock_manager_paused() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            liquidity_locker::locker_pause(&admin_cap, &mut locker, true);

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidGaugePool)]
    fun test_lock_position_invalid_gauge_pool() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());
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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
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

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EPositionNotStaked)]
    fun test_lock_position_position_not_staked() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
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

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
/*
    #[test]
    // TODO паникует
    #[expected_failure(abort_code = gauge::EWithdrawPositionPositionIsLocked)]
    fun test_unstaked_failed_after_lock_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
    */

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EPositionAlreadyLocked)]
    fun test_lock_position_position_already_locked() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions2 = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidBlockPeriodIndex)]
    fun test_lock_position_invalid_block_period_index() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_lock_position_no_tranches() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
                scenario.ctx()
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_locker::EInvalidProfitabilitiesLength)]
    fun test_lock_position_invalid_profitabilities_length_in_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                position_id,
                1,
                &clock,
                scenario.ctx()
            );

            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_with_split() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                &clock
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            // позиция не влезает в первый транш с объемом 4000000000000000000, делится на две 
            // 4000000000000000000 и 7984584197103522

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            let locked_position_1 = locked_positions.pop_back();
            let locked_position_2 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == distribution::common::epoch_next(4*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == distribution::common::epoch_next(5*86400*7), 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == distribution::common::epoch_next(4*86400*7), 92343253252);
            assert!(full_unlocking_time_2 == distribution::common::epoch_next(5*86400*7), 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 332041393326771866, 9234124983278);
            assert!(liquidity2 == 165688655270059192614, 923412491398739);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);
            assert!(pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).is_staked(), 9235939696);
            assert!(pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).is_staked(), 9235939697);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_with_split_2() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                4812066422300000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                &clock
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                10,
                500,
                33<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            let locked_position_1 = locked_positions.pop_back();
            let locked_position_2 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == distribution::common::epoch_next(4*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == distribution::common::epoch_next(5*86400*7), 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == distribution::common::epoch_next(4*86400*7), 92343253252);
            assert!(full_unlocking_time_2 == distribution::common::epoch_next(5*86400*7), 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 207111217492973797080, 9234124983278);
            assert!(liquidity2 == 199326662023350034177, 923412491398739);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);
            assert!(pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).is_staked(), 9235939696);
            assert!(pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).is_staked(), 9235939697);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
/*
    #[test]
    fun test_remove_lock_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                512066422300000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                &clock
            );

            create_trance_and_add_reward<TestCoinB, TestCoinA, SailCoinType>(
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            let mut locked_position_1 = locked_positions.pop_back();
            let locked_position_2 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == distribution::common::epoch_next(4*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == distribution::common::epoch_next(5*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            std::debug::print(&std::string::utf8(b"liquidity1"));
            std::debug::print(&liquidity1);
            std::debug::print(&std::string::utf8(b"liquidity2: "));
            std::debug::print(&liquidity2);
            assert!(liquidity1 == 253858930440097258382, 9234124983278);
            assert!(liquidity2 == 25995520683552974328, 923412491398739);

            clock.increment_for_testing(expiration_time_1*1000 + distribution::common::epoch_to_seconds(1)*1000);

            let reward = liquidity_locker::collect_reward<TestCoinB, TestCoinA, SailCoinType, RewardCoinType1>(
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                0,
                &clock
            );

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity(
                &global_config,
                &mut vault,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(sui::coin::from_balance(reward, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);


            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
*/
    #[test]
    #[expected_failure(abort_code = liquidity_locker::ERewardsNotCollected)]
    fun test_remove_lock_liquidity_not_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
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

        // Tx 2: Setup Distribution (admin gets caps)
        setup_distribution<SailCoinType>(&mut scenario, admin);

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
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut clock = clock::create_for_testing(scenario.ctx());

            config::add_fee_tier(&mut global_config, 1, 1000, scenario.ctx());

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

            let mut pools = scenario.take_shared<Pools>();

            let mut pool = factory::create_pool_<TestCoinB, TestCoinA>(
                &mut pools,
                &global_config,
                1, // tick_spacing
                18584142135623730951, // current_sqrt_price (1.0)
                std::string::utf8(b""), // url
                @0x2, // feed_id_coin_a
                @0x3, // feed_id_coin_b
                true, // auto_calculation_volumes
                &clock,
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
                512066422300000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                &clock
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
                &clock
            );

            let (mut gauge, position_id) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut voter,
                &mut distribution_config,
                &gauge_create_cap,
                &governor_cap,
                &ve,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_locker::lock_position<TestCoinB, TestCoinA>(
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
            let locked_position_1 = locked_positions.pop_back();
            let locked_position_2 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == distribution::common::epoch_next(4*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == distribution::common::epoch_next(5*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            std::debug::print(&std::string::utf8(b"liquidity1"));
            std::debug::print(&liquidity1);
            std::debug::print(&std::string::utf8(b"liquidity2: "));
            std::debug::print(&liquidity2);
            assert!(liquidity1 == 253858930440097258382, 9234124983278);
            assert!(liquidity2 == 25995520683552974328, 923412491398739);

            clock.increment_for_testing(expiration_time_1*1000 + distribution::common::epoch_to_seconds(1)*1000);

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_locker::remove_lock_liquidity(
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
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
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
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

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
        clock: &sui::clock::Clock
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
                clock.timestamp_ms()/1000,
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
        voter: &mut voter::Voter,
        distribution_config: &mut distribution_config::DistributionConfig,
        gauge_create_cap: &gauge_cap::gauge_cap::CreateCap,
        governor_cap: &distribution::voter_cap::GovernorCap,
        ve: &voting_escrow::VotingEscrow<SailCoinType>,
        vault: &mut rewarder::RewarderGlobalVault,
        pool: &mut pool::Pool<TestCoinB, TestCoinA>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_delta: u128,
        clock: &sui::clock::Clock,
    ):  (gauge::Gauge<TestCoinB, TestCoinA>, sui::object::ID) {
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


        let mut gauge = voter.create_gauge<TestCoinB, TestCoinA, SailCoinType>(
            distribution_config,
            gauge_create_cap,
            governor_cap,
            ve, // VotingEscrow is borrowed immutably here
            pool,
            clock,
            scenario.ctx()
        );

        distribution::gauge::deposit_position<TestCoinB, TestCoinA>(
            global_config,
            distribution_config,
            &mut gauge,
            pool,
            position,
            clock,
            scenario.ctx(),
        );

        (gauge, position_id)
    }

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
        // scenario.next_tx(sender);
        // {
        //     let clock = clock::create_for_testing(scenario.ctx());
        //     let rd_publisher = reward_distributor::test_init(scenario.ctx());
        //     let (rd_obj, rd_cap) = reward_distributor::create<SailCoinType>(
        //         &rd_publisher,
        //         &clock,
        //         scenario.ctx()
        //     );
        //     test_utils::destroy(rd_publisher);
        //     transfer::public_share_object(rd_obj);
        //     clock::destroy_for_testing(clock);
        //     // --- Set Reward Distributor Cap ---
        //     let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
        //     let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        //     minter.set_reward_distributor_cap(&minter_admin_cap, rd_cap);
        //     test_scenario::return_shared(minter);
        //     scenario.return_to_sender(minter_admin_cap);
        // };
    }
    
}
#[test_only]
module liquidity_soft_locker::liquidity_soft_lock_v2_tests {
    use sui::test_scenario;
    use sui::test_utils;

    use liquidity_soft_locker::liquidity_soft_lock_v2;
    use liquidity_soft_locker::pool_soft_tranche;
    use locker_cap::locker_cap;
    use clmm_pool::position;
    use clmm_pool::pool;
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config, GlobalConfig};
    use clmm_pool::stats;
    use clmm_pool::rewarder;
    use price_provider::price_provider;
    use distribution::distribution_config;
    use distribution::voter;
    use distribution::voting_escrow;
    use distribution::minter;
    use distribution::gauge;
    use distribution::common;
    use distribution::rebase_distributor;
    use sui::clock;
    use switchboard::aggregator;
    use switchboard::decimal;

    const ONE_DEC18: u128 = 1000000000000000000;

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
    public struct RewardCoinType4 has drop {}
    #[test_only]
    public struct OSAIL1 has drop {}
    #[test_only]
    public struct OSAIL2 has drop {}
    #[test_only]
    public struct OSAIL3 has drop {}
    #[test_only]
    public struct OSAIL4 has drop {}
    #[test_only]
    public struct OSAIL5 has drop {}
    #[test_only]
    public struct OSAIL6 has drop {}
        
    #[test]
    fun test_init() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            // let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v2::init_locker(
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let position_id = staked_position.position_id();

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time, full_unlocking_time) = liquidity_soft_lock_v2::get_unlock_time(&locked_position);
            assert!(expiration_time == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253242);
            assert!(full_unlocking_time == distribution::common::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 9234326345);
            assert!(liquidity_soft_lock_v2::get_profitability(&locked_position) == 10000, 923463477);
            assert!(locked_position.get_locked_position_id() == position_id, 9234325235);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockManagerPaused)]
    fun test_lock_position_lock_manager_paused() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            liquidity_soft_lock_v2::locker_pause(&mut locker, true, scenario.ctx());

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_lock_position_invalid_gauge_pool() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool_2,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidBlockPeriodIndex)]
    fun test_lock_position_invalid_block_period_index() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                4,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
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
            liquidity_soft_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidProfitabilitiesLength)]
    fun test_lock_position_invalid_profitabilities_length_in_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                1000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let ( staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            // position doesn't fit in the first tranche with volume 4000000000000000000, splits into two
            // 4000000000000000000 and 7984584197103522

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                50000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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
            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 36893488147419103232, 923412491398739);

            let position_id_1 = &locked_position_1.get_locked_position_id();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let (locked_position_11, locked_position_12, staking_reward_1) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_1, scenario.sender());

            let position_id_11 = &locked_position_11.get_locked_position_id();
            assert!(position_id_11 == position_id_1, 923503059333);

            let liquidity11 = pool.position_manager().borrow_position_info(locked_position_11.get_locked_position_id()).info_liquidity();
            assert!(liquidity11 == 36893488147419103232/2, 9325035242342);

            let liquidity12 = pool.position_manager().borrow_position_info(locked_position_12.get_locked_position_id()).info_liquidity();
            assert!(liquidity12 == (36893488147419103232/2)-27, 9325035242343);

            let (locked_position_111, locked_position_112, staking_reward_2) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_11,
                23000, // 23%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_2, scenario.sender());

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
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_split_position_above_current_tick() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                251,
                688,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 2<<64, 923412491398739);

            assert!(pool.current_tick_index().lt(integer_mate::i32::from_u32(251)), 9234124935740);

            let position_id_1 = &locked_position_1.get_locked_position_id();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let (locked_position_11, locked_position_12, staking_reward_1) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_1, scenario.sender());

            let position_id_11 = &locked_position_11.get_locked_position_id();
            assert!(position_id_11 == position_id_1, 923503059333);

            let liquidity11 = pool.position_manager().borrow_position_info(locked_position_11.get_locked_position_id()).info_liquidity();
            assert!(liquidity11 == 36893488147419103232/2, 9325035242342);

            let liquidity12 = pool.position_manager().borrow_position_info(locked_position_12.get_locked_position_id()).info_liquidity();
            assert!(liquidity12 == (36893488147419103232/2)-17, 9325035242343);

            assert!(pool.current_tick_index().lt(integer_mate::i32::from_u32(251)), 9234124935741);

            let (locked_position_111, locked_position_112, staking_reward_2) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_11,
                23000, // 23%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_2, scenario.sender());

            let position_id_111 = &locked_position_111.get_locked_position_id();
            assert!(position_id_111 == position_id_1, 923503059336);

            let liquidity111 = pool.position_manager().borrow_position_info(locked_position_111.get_locked_position_id()).info_liquidity();
            assert!(liquidity111 == 36893488147419103232*23/200, 9325035242344);

            let liquidity112 = pool.position_manager().borrow_position_info(locked_position_112.get_locked_position_id()).info_liquidity();
            assert!(liquidity112 == (36893488147419103232*77/200-3), 9325035242345);

            transfer::public_transfer(locked_position_111, admin);
            transfer::public_transfer(locked_position_112, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_split_position_below_current_tick() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                4294967295-222,
                4294967295-13,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 2<<64, 923412491398739);

            assert!(pool.current_tick_index().gt(integer_mate::i32::from_u32(4294967295-13)), 9234124935740);

            let position_id_1 = &locked_position_1.get_locked_position_id();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let (locked_position_11, locked_position_12, staking_reward_1) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_1, scenario.sender());

            let position_id_11 = &locked_position_11.get_locked_position_id();
            assert!(position_id_11 == position_id_1, 923503059333);

            let liquidity11 = pool.position_manager().borrow_position_info(locked_position_11.get_locked_position_id()).info_liquidity();
            assert!(liquidity11 == 36893488147419103232/2, 9325035242342);

            let liquidity12 = pool.position_manager().borrow_position_info(locked_position_12.get_locked_position_id()).info_liquidity();
            assert!(liquidity12 == (36893488147419103232/2), 9325035242343);

            assert!(pool.current_tick_index().gt(integer_mate::i32::from_u32(4294967295-13)), 9234124935740);

            let (locked_position_111, locked_position_112, staking_reward_2) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_11,
                23000, // 23%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_2, scenario.sender());

            let position_id_111 = &locked_position_111.get_locked_position_id();
            assert!(position_id_111 == position_id_1, 923503059336);

            let liquidity111 = pool.position_manager().borrow_position_info(locked_position_111.get_locked_position_id()).info_liquidity();
            assert!(liquidity111 == 36893488147419103232*23/200, 9325035242344);

            let liquidity112 = pool.position_manager().borrow_position_info(locked_position_112.get_locked_position_id()).info_liquidity();
            assert!(liquidity112 == (36893488147419103232*77/200-56), 9325035242345);

            transfer::public_transfer(locked_position_111, admin);
            transfer::public_transfer(locked_position_112, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            test_scenario::return_shared(minter);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999988/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward3 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );

            assert!(reward3.value() == 10000000, 9234129832754); // 10% of total reward for epoch 3

            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_collect_reward_and_unlock_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999988/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (staked_position, coin_a, coin_b, reward3) = liquidity_soft_lock_v2::collect_reward_and_unlock_position<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &mut locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                locked_position,
                &clock,
                scenario.ctx()
            );

            assert!(reward3.value() == 10000000, 9234129832754); // 10% of total reward for epoch 3

            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);

            transfer::public_transfer(staked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards_in_sail() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, SailCoinType>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999988/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL3, SailCoinType>(
                &locker,
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };

        scenario.next_tx(admin);
        {
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            // reward from the second epoch was in SAIL
            // which was automatically locked in VOTING_ESCROW
            let lock = scenario.take_from_sender<voting_escrow::Lock>();

            assert!(lock.get_amount() == 10000000, 926223626362);

            lock.transfer(&mut ve, admin, &clock, scenario.ctx());
            test_scenario::return_shared(ve);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_collect_reward_sail_and_unlock_position() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, SailCoinType>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999988/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (staked_position, coin_a, coin_b) = liquidity_soft_lock_v2::collect_reward_sail_and_unlock_position<TestCoinB, TestCoinA, OSAIL3, SailCoinType>(
                &mut locker,
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                locked_position,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(staked_position, admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };

        scenario.next_tx(admin);
        {
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            // reward from the second epoch was in SAIL
            // which was automatically locked in VOTING_ESCROW
            let lock = scenario.take_from_sender<voting_escrow::Lock>();

            assert!(lock.get_amount() == 10000000, 926223626362);

            lock.transfer(&mut ve, admin, &clock, scenario.ctx());
            test_scenario::return_shared(ve);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards_after_split() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // split position in the 1/3 of epoch 2
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/3*1000);
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let (locked_position_1, locked_position_2, staking_reward) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault, 
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position,
                75000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*2/3*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999988/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_25 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut locked_position_75 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward25 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_25,
                &clock,
                scenario.ctx()
            );

            assert!(reward25.value() == 2500000-1, 9234129832754); // 25% of total reward

            transfer::public_transfer(sui::coin::from_balance(reward25, scenario.ctx()), admin);

            let reward75 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_75,
                &clock,
                scenario.ctx()
            );

            assert!(reward75.value() == 7500000, 9234129832754); // 75% of total reward

            transfer::public_transfer(sui::coin::from_balance(reward75, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_25, admin);
            transfer::public_transfer(locked_position_75, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards_after_rebalance() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // second call of change_tick_range function
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000*3/10);
        scenario.next_tx(admin);
        {
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(97),
                integer_mate::i32::from_u32(4500),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            transfer::public_transfer(locked_position, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000*7/10); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                30908999999999/10,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch (full reward)
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>(); 
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );

            assert!(reward.value() == 10000000, 9234129832754); // 100% of total reward

            transfer::public_transfer(sui::coin::from_balance(reward, scenario.ctx()), admin);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when split position
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockManagerPaused)]
    fun test_split_position_pause(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v2::locker_pause(&mut locker, true, scenario.ctx());

            let (locked_position_11, locked_position_12, staking_reward) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EFullLockPeriodEnded when split position
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EFullLockPeriodEnded)]
    fun test_split_position_full_period_ended(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(8)*1000);

            let (locked_position_11, locked_position_12, staking_reward) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EInvalidGaugePool when split position
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_split_position_invalid_gauge_pool(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,    
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

            let (locked_position_11, locked_position_12, staking_reward) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool_2,
                locked_position_1,
                50000, // 50%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_11, admin);
            transfer::public_transfer(locked_position_12, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(minter);
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Add reward to the first tranche
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL2, SailCoinType>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1000000000000,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };

        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                1000000000000,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // Distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL4, RewardCoinType3>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                2763996850087,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 5 (OSAIL5)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

        // Update Minter Period to OSAIL5
        scenario.next_tx(admin);
        {
            let initial_o_sail5_supply = update_minter_period<SailCoinType, OSAIL5>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL5
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail5_supply); // Burn OSAIL5
        };

        // Distribute gauge for epoch 5
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL5>(&mut scenario, &clock);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward4 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL4, SailCoinType, RewardCoinType3>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );

            assert!(reward4.value() == 10000000, 9234129832756);
            transfer::public_transfer(sui::coin::from_balance(reward4, scenario.ctx()), admin);

            // Claim all rewards
            let reward1 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward1, scenario.sender());

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let reward3 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward3, scenario.sender());

            let reward4 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward4, scenario.sender());

            // full unlock
            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL5>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 3794126173307114780, 92348768657674);
            assert!(remove_balance_b.value() == 534405474921791512, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // liquidity withdrawal by epochs
    #[test]
    fun test_remove_lock_liquidity_by_epoch(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position_admin) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                0,
                1000,
                1<<64,
                &clock
            );

            let (staked_position_admin_2) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                120,
                200,
                10<<64,
                &clock
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            transfer::public_transfer(staked_position_admin, admin);
            transfer::public_transfer(staked_position_admin_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };

        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/2*1000);
        // claim rewards for staking for 1, 2 and half of 3 epochs
        scenario.next_tx(admin);
        {
            let voter = scenario.take_shared<voter::Voter>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();    
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();

            let reward1 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward1, scenario.sender());

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let reward3 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward3, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/2*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // Distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // set_total_incomed_and_add_reward for epoch 4
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType3>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL4, RewardCoinType3>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward3.into_balance(),
                1000000000000,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219575652993061008986, 9234124913987);
            assert!(liquidity2 == 112465740333710919911, 9234124983278);

            let reward3 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward3, scenario.sender());

            clock::increment_for_testing(&mut clock, 1000); // one second of the first epoch has passed

            // one epoch has passed since expiration date
            // can withdraw 1/3
            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };

        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (5)

        // Update Minter Period to OSAIL5
        scenario.next_tx(admin);
        {
            let initial_o_sail5_supply = update_minter_period<SailCoinType, OSAIL5>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL5
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail5_supply); // Burn OSAIL5
        };

        // Distribute gauge for epoch 5
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL5>(&mut scenario, &clock);
        };

        // set_total_incomed_and_add_reward for epoch 5
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward4 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL5, SailCoinType>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward4.into_balance(),
                1899483949325,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        clock::increment_for_testing(&mut clock, (common::epoch_to_seconds(1)/2)*1000); // skip half of 5 epoch
        // remove_lock_liquidity 2/3 for epoch 5
        scenario.next_tx(admin);
        {
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219575652993061008986*2/3+1, 9234124913987); // 2/3 of total liquidity
            assert!(liquidity2 == 112465740333710919911, 9234124983278);

            let reward4 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward4, scenario.sender());

            // two epochs have passed since expiration date
            // can withdraw 2/3
            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL5>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
        };

        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/2*1000); // next epoch (6)

        // Update Minter Period to OSAIL6
        scenario.next_tx(admin);
        {
            let initial_o_sail6_supply = update_minter_period<SailCoinType, OSAIL6>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL6
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail6_supply); // Burn OSAIL6
        };

        // Distribute gauge for epoch 6
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL6>(&mut scenario, &clock);
        };

        // full remove and unlock position for epoch 6
        scenario.next_tx(admin);
        {
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL5, SailCoinType>(
                &locker,
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );

            let reward5 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL5>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward5, scenario.sender());

            // full unlock
            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL6>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 1082352715785369272, 92348768657674);
            assert!(remove_balance_b.value() == 365061384823952775, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };


        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // unlock position without removing liquidity
    #[test]
    fun test_unlock_position_without_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // adding reward to the first tranche
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward1 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL2, SailCoinType>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward1.into_balance(),
                1050000000000,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };

        // set_total_incomed_and_add_reward
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward2 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                3090899999999,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            // claim all rewards
            let reward1 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward1, scenario.sender());
            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let reward3 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward3, scenario.sender());

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };

        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // Distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward3 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward3, scenario.sender());

            let reward1 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            let position_id = locked_position_1.get_locked_position_id();
            assert!(locker.is_position_locked(position_id), 9234887456443);

            // full unlock
            let (staked_position, coin_a, coin_b) = liquidity_soft_lock_v2::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );
            
            assert!(!locker.is_position_locked(position_id), 9234887456444);

            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(staked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_collect_rewards(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
            let reward1 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL1, SailCoinType, RewardCoinType1>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool_2,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );
                
            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_collect_rewards_sail(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                5000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
            liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL1, SailCoinType>(
                &locker,
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool_2,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EClaimEpochIncorrect)]
    fun test_claimed_rewards_before_expiration_time(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 0);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward1 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL1, SailCoinType, RewardCoinType1>(
                &locker,
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position_1,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(sui::coin::from_balance(reward1, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when unlocking
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockManagerPaused)]
    fun test_pause_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v2::locker_pause(&mut locker, true, scenario.ctx());

            let (staked_position, coin_a, coin_b) = liquidity_soft_lock_v2::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );
            
            transfer::public_transfer(staked_position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EFullLockPeriodNotEnded when unlocking
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EFullLockPeriodNotEnded)]
    fun test_full_lock_period_not_ended_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (staked_position, coin_a, coin_b) = liquidity_soft_lock_v2::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );
            
            transfer::public_transfer(staked_position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ERewardsNotCollected when unlocking
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ERewardsNotCollected)]
    fun test_rewards_not_collected_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(4)*1000);

            let (staked_position, coin_a, coin_b) = liquidity_soft_lock_v2::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &mut gauge,
                &clock
            );
            
            transfer::public_transfer(staked_position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockManagerPaused)]
    fun test_pause_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v2::locker_pause(&mut locker, true, scenario.ctx());

            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockPeriodNotEnded when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockPeriodNotEnded)]
    fun test_lock_period_not_ended_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EInvalidGaugePool when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let  pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
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

            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool_2,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ENoLiquidityToRemove when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ENoLiquidityToRemove)]
    fun test_no_liquidity_to_remove_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                1000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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
            
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // Distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (remove_balance_a, remove_balance_b, staking_reward) = liquidity_soft_lock_v2::remove_lock_liquidity<TestCoinB, TestCoinA, SailCoinType, OSAIL4>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);
            transfer::public_transfer(staking_reward, scenario.sender());
            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // ensure liquidity in the pool
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
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

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward_11, scenario.sender());

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(new_liquidity == 179200794087989674225, 923412491398739); // liquidity should be proportionally increased by ~4.87x

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(100)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(200)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
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
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // ensure liquidity in the pool
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

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                200,
                1<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(liquidity == 18446744073709551616, 923412491398739);

            let position_id = &locked_position.get_locked_position_id();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward_11, scenario.sender());

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(new_liquidity == 4576892976317919965, 923412491398739); // liquidity should be proportionally decreased by ~4x

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(13)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(417)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_change_tick_range_interval_above_current_tick() { // interval above current tick
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // ensure liquidity in the pool
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

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(211),
                integer_mate::i32::from_u32(243),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());

            assert!(pool.current_tick_index().lt(integer_mate::i32::from_u32(211)), 92341249134363);

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(new_liquidity == 562642917157293473889, 923412491398739);

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(211)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(243)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        // second call of change_tick_range function
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000*5/10);
        scenario.next_tx(admin);
        {
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(315),
                integer_mate::i32::from_u32(590),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            assert!(pool.current_tick_index().lt(integer_mate::i32::from_u32(315)), 92341249134363);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            transfer::public_transfer(locked_position, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_below_current_tick() { // interval below current tick
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // ensure liquidity in the pool
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

            let position_admin_2 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-50,
                100,
                9<<64,
                &clock
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
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

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-1),
                integer_mate::i32::from_u32(48),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            assert!(pool.current_tick_index().gt(integer_mate::i32::from_u32(48)), 92341249134363);

            let new_position_id = &locked_position.get_locked_position_id();
            assert!(new_position_id != position_id, 932605293560);

            let new_liquidity = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_liquidity();
            assert!(new_liquidity == 360008798430211682133, 923412491398739);

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(4294967295-1)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(48)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        // second call of change_tick_range function
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000*5/10);
        scenario.next_tx(admin);
        {
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-222),
                integer_mate::i32::from_u32(4294967295-13),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            assert!(pool.current_tick_index().gt(integer_mate::i32::from_u32(4294967295-13)), 92341249134363);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            transfer::public_transfer(locked_position, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_with_return_remaining_to_position() { // changing interval with returning remaining to position
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            // ensure liquidity in the pool
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

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                200,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            // a2b
            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(6),
                integer_mate::i32::from_u32(395),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(6)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(395)), 96340634523453);

            // b2a
            let staking_reward_12 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(101),
                integer_mate::i32::from_u32(172),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_12, scenario.sender());
            
            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(101)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(172)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
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
    fun test_claim_rewards_after_change_tick_range_in_the_end_of_epoch() { // claim after change tick range in the end of epoch
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
                &mut scenario,
                &global_config,
                &mut distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            // ensure liquidity in the pool
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

            let position_admin2 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                200,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // change position in the 99/100 of epoch 2
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/100*99*1000);
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(11),
                integer_mate::i32::from_u32(150),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };
        
        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/100*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Distribute gauge for epoch 3
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        };

        // change position in the middle of epoch 3
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/2*1000);
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL3>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(100),
                integer_mate::i32::from_u32(500),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };
        
        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)/2*1000); // next epoch (4)

        // Update Minter Period to OSAIL4
        scenario.next_tx(admin);
        {
            let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL4
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        };

        // Distribute gauge for epoch 4
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        };

        // Add reward to the THIRD epoch
        scenario.next_tx(admin);
        {
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let tranche1 = get_tranche_by_index(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                0
            );

            let reward3 = sui::coin::mint_for_testing<RewardCoinType2>(10000000, scenario.ctx());
            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward3.into_balance(),
                3090899999996,
                scenario.ctx()
            );

            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the third epoch
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let reward3 = liquidity_soft_lock_v2::collect_reward<TestCoinB, TestCoinA, OSAIL3, SailCoinType, RewardCoinType2>(
                &locker,
                &mut tranche_manager,
                &ve,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            assert!(10000000 == reward3.value(), 9234129832754);

            transfer::public_transfer(sui::coin::from_balance(reward3, scenario.ctx()), admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
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
            
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ELockManagerPaused)]
    fun test_pause_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            liquidity_soft_lock_v2::locker_pause(&mut locker, true, scenario.ctx());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<stats::Stats>();
            let price_provider = scenario.take_shared<price_provider::PriceProvider>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

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

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool_2,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(100),
                integer_mate::i32::from_u32(200),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            test_scenario::return_shared(pools);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EFullLockPeriodEnded)]
    fun test_full_lock_period_ended_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*9*24*5*1000);

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
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
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(minter);
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
    #[expected_failure(abort_code = liquidity_soft_lock_v2::ENotChangedTickRange)]
    fun test_not_changed_tick_range_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
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
                10_000_000_000_000, 
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                100, // 1%
                10000000, // reward_value
                90000, // total_income,
                clock.timestamp_ms()/1000
            );

            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>( 
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

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(10),
                integer_mate::i32::from_u32(500),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(ve);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
            scenario.return_to_sender(governor_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards_after_change_tick_range_and_split_positions() { // claim after changes tick range and splits positions
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        // Setup
        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &mut clock
            );
        };

        // Create  tranche and add reward for the first epoch
        // Create a new position
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v2::init_locker(
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
                &pool,
                true,
                9000000000000000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            // first epoch
            let (staked_position) = create_and_deposit_position<TestCoinB, TestCoinA>(  
                &mut scenario,
                &global_config,
                &distribution_config,
                &mut gauge,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            // ensure liquidity in the pool
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

            let position_admin2 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                200,
                9<<64,
                &clock
            );

            // let position_admin3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
            //     &mut scenario,
            //     &global_config,
            //     &mut vault,
            //     &mut pool,
            //     90,
            //     350,
            //     9<<64,
            //     &clock
            // );

            let mut locked_positions = liquidity_soft_lock_v2::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &distribution_config,
                &mut locker,
                &mut tranche_manager,
                &mut gauge,
                &mut pool,
                staked_position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin2, admin);
            // transfer::public_transfer(position_admin3, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (2)

        // Update Minter Period to OSAIL2
        scenario.next_tx(admin);
        {
            let initial_o_sail2_supply = update_minter_period<SailCoinType, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // Distribute gauge for epoch 2
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_2<SailCoinType, OSAIL2>(&mut scenario, &clock);
        };

        // change range position in the 10/100 of epoch 2
        // current tick is less than the range
        // rewards are not accrued
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*5*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(371),
                integer_mate::i32::from_u32(409),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        // change range position in the 20/100 of epoch 2
        // current tick is greater than the upper bound of the range
        // rewards are not accrued
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*10*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967134), // -160
                integer_mate::i32::from_u32(0),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        // change range position in the 30/100 of epoch 2
        // current tick is less than the range
        // rewards are not accrued
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*10*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(499),
                integer_mate::i32::from_u32(727),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        // change range position in the 40/100 of epoch 2
        // current tick is inside the range
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*10*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967262), // -32
                integer_mate::i32::from_u32(547),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        // store position IDs to identify them in subsequent transactions
        let mut position_ids =  sui::table::new<u32, ID>(scenario.ctx());
        // change range position and split in the 50/100 of epoch 2
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*20*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut locked_position = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();
            
            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            let (mut locked_position_1, locked_position_2, staking_reward_1) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position,
                33000, // 33%
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_1, scenario.sender());

            position_ids.add(1,  sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position_1));
            position_ids.add(2,  sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position_2));

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position_1,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(40),
                integer_mate::i32::from_u32(270),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };
        
        // change range position and split in the 70/100 of epoch 2
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*20*1000/100);
        // change range position 1 and split position 2
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();
            let mut locked_position2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(); // 67%
            let mut locked_position1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(); // 33%

            assert!(position_ids.borrow(2) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position2));
            assert!(position_ids.borrow(1) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position1));

            let reward2 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position2,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward2, scenario.sender());

            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position2,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(1),
                integer_mate::i32::from_u32(250),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            let reward1 = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward1, scenario.sender());

            let staking_reward_12 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position1,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(98),
                integer_mate::i32::from_u32(141),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_12, scenario.sender());
            
            transfer::public_transfer(locked_position1, admin);
            transfer::public_transfer(locked_position2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(price_provider);
        };
        // split position 2
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();
            let locked_position2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(); // 67%

            assert!(position_ids.borrow(2) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position2));

            let (locked_position_21, locked_position_22, staking_reward_2) = liquidity_soft_lock_v2::split_position<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut gauge,
                &mut pool,
                locked_position2,
                50000, // 67% -> 33.5% + 33.5%
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(staking_reward_2, scenario.sender());

            assert!(position_ids.borrow(2) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position_21));
            position_ids.add(3,  sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position_22));

            transfer::public_transfer(locked_position_21, admin);
            transfer::public_transfer(locked_position_22, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(price_provider);
        };

        // change range position1 in the 80/100 of epoch 2
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*10*1000/100);
        scenario.next_tx(admin);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let voter = scenario.take_shared<voter::Voter>();
            let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();
            let locked_position3 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let locked_position2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
            let mut locked_position1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

            assert!(position_ids.borrow(1) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position1));
            assert!(position_ids.borrow(2) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position2));
            assert!(position_ids.borrow(3) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position3));

            let reward = liquidity_soft_lock_v2::claim_position_reward_for_staking<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &locker,
                &mut minter,
                &voter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut locked_position1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(reward, scenario.sender());

            // low current tick index
            let staking_reward_11 = liquidity_soft_lock_v2::change_tick_range<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &global_config,
                &distribution_config,
                &mut minter,
                &mut vault,
                &voter,
                &mut locker,
                &mut locked_position1,
                &mut gauge,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967262), // -32
                integer_mate::i32::from_u32(10),
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(staking_reward_11, scenario.sender());
            
            transfer::public_transfer(locked_position1, admin);
            transfer::public_transfer(locked_position2, admin);
            transfer::public_transfer(locked_position3, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };
        
        // Advance to Epoch 3 (OSAIL3)
        // clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*20*1000/100); // next epoch (3)

        // // Update Minter Period to OSAIL3
        // scenario.next_tx(admin);
        // {
        //     let initial_o_sail3_supply = update_minter_period<SailCoinType, OSAIL3>(
        //         &mut scenario,
        //         1_000_000, // Arbitrary supply for OSAIL3
        //         &clock
        //     );
        //     sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        // };

        // // Distribute gauge for epoch 3
        // scenario.next_tx(admin);
        // {
        //     distribute_gauge_epoch_3<SailCoinType, OSAIL3>(&mut scenario, &clock);
        // };

        // // Advance to Epoch 4 (OSAIL4)
        // clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (4)

        // // Update Minter Period to OSAIL4
        // scenario.next_tx(admin);
        // {
        //     let initial_o_sail4_supply = update_minter_period<SailCoinType, OSAIL4>(
        //         &mut scenario,
        //         1_000_000, // Arbitrary supply for OSAIL4
        //         &clock
        //     );
        //     sui::coin::burn_for_testing(initial_o_sail4_supply); // Burn OSAIL4
        // };

        // // Distribute gauge for epoch 4
        // scenario.next_tx(admin);
        // {
        //     distribute_gauge_epoch_3<SailCoinType, OSAIL4>(&mut scenario, &clock);
        // };

        // // Add reward to the 3 epoch
        // scenario.next_tx(admin);
        // {
        //     let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
        //     let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

        //     let tranche1 = get_tranche_by_index(
        //         &mut tranche_manager,
        //         sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
        //         0
        //     );

        //     let reward3 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
        //     pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL3, SailCoinType>(
        //         &mut tranche_manager,
        //         sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
        //         sui::object::id<pool_soft_tranche::PoolSoftTranche>(tranche1),
        //         common::epoch_start(common::epoch_to_seconds(3)),
        //         reward3.into_balance(),
        //         10300000000000,
        //         scenario.ctx()
        //     );

        //     test_scenario::return_shared(tranche_manager);
        //     transfer::public_transfer(pool, admin);
        // };
        
        // // Claim rewards for the second epoch
        // scenario.next_tx(admin);
        // {
        //     let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
        //     let locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
        //     let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        //     let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
        //     let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
        //     let mut locked_position3 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
        //     let mut locked_position2 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();
        //     let mut locked_position1 = scenario.take_from_sender<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>();

        //     assert!(position_ids.borrow(1) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position1));
        //     assert!(position_ids.borrow(2) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position2));
        //     assert!(position_ids.borrow(3) == sui::object::id<liquidity_soft_lock_v2::SoftLockedPosition<TestCoinB, TestCoinA>>(&locked_position3));

        //     // Claim rewards for the second epoch lock
        //     liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL3, SailCoinType>(
        //         &locker,
        //         &mut tranche_manager,
        //         &mut ve,
        //         &mut gauge,
        //         &mut pool,
        //         &mut locked_position1,
        //         &clock,
        //         scenario.ctx()
        //     );

        //     liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL3, SailCoinType>(
        //         &locker,
        //         &mut tranche_manager,
        //         &mut ve,
        //         &mut gauge,
        //         &mut pool,
        //         &mut locked_position2,
        //         &clock,
        //         scenario.ctx()
        //     );

        //     liquidity_soft_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL3, SailCoinType>(
        //         &locker,
        //         &mut tranche_manager,
        //         &mut ve,
        //         &mut gauge,
        //         &mut pool,
        //         &mut locked_position3,
        //         &clock,
        //         scenario.ctx()
        //     );

        //     transfer::public_transfer(locked_position1, admin);
        //     transfer::public_transfer(locked_position2, admin);
        //     transfer::public_transfer(locked_position3, admin);
        //     transfer::public_transfer(pool, admin);
        //     transfer::public_transfer(gauge, admin);
        //     test_scenario::return_shared(tranche_manager);
        //     test_scenario::return_shared(locker);
        //     test_scenario::return_shared(ve);
        // };
        
        // // CHECK SAIL LOCKED IN VOTING_ESCROW
        // scenario.next_tx(admin);
        // {
        //     let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        //     // reward from the second epoch was in SAIL
        //     // which was automatically locked in VOTING_ESCROW
        //     let lock3 = scenario.take_from_sender<voting_escrow::Lock>();
        //     let lock2 = scenario.take_from_sender<voting_escrow::Lock>();
        //     let lock1 = scenario.take_from_sender<voting_escrow::Lock>();

        //     assert!(lock1.get_amount() + lock2.get_amount() + lock3.get_amount() == 2700872, 9262236263635);

        //     voting_escrow::transfer<SailCoinType>(
        //         lock1,
        //         &mut ve,
        //         admin,
        //         &clock,
        //         scenario.ctx()
        //     );
        //     voting_escrow::transfer<SailCoinType>(
        //         lock2,
        //         &mut ve,
        //         admin,
        //         &clock,
        //         scenario.ctx()
        //     );
        //     voting_escrow::transfer<SailCoinType>(
        //         lock3,
        //         &mut ve,
        //         admin,
        //         &clock,
        //         scenario.ctx()
        //     );
        //     test_scenario::return_shared(ve);
        // };
      
        position_ids.drop();
        // position_ids.destroy_empty();
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun create_trance_and_add_reward<TestCoinB, TestCoinA, RewardCoinType>(
        scenario: &mut test_scenario::Scenario,
        tranche_manager: &mut pool_soft_tranche::PoolSoftTrancheManager,
        pool: &pool::Pool<TestCoinB, TestCoinA>,
        volume_in_coin_a: bool,
        total_volume: u128, // Q64.64
        duration_profitabilities: vector<u64>,
        minimum_remaining_volume: u64,
        reward_value: u64,
        total_income: u64,
        epoch: u64
    ) {
            // set ignore_whitelist to true
            pool_soft_tranche::set_ignore_whitelist(
                tranche_manager,
                true,
                scenario.ctx()
            );

            pool_soft_tranche::new(
                tranche_manager,
                pool,
                volume_in_coin_a,
                total_volume,  // total_volume
                duration_profitabilities, // duration_profitabilities
                minimum_remaining_volume, // minimum_remaining_volume
                scenario.ctx()
            );
            let tranches = pool_soft_tranche::get_tranches(
                tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(pool)
            );
            let new_tranche = tranches.borrow(tranches.length() - 1);
            // add reward
            let tranche_id = sui::object::id<pool_soft_tranche::PoolSoftTranche>(new_tranche);
            let reward = sui::coin::mint_for_testing<RewardCoinType>(reward_value, scenario.ctx());

            pool_soft_tranche::set_total_incomed_and_add_reward<OSAIL1,RewardCoinType>(
                tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(pool),
                tranche_id,
                epoch,
                reward.into_balance(),
                total_income,
                scenario.ctx()
            );
    }

    #[test_only]
    fun get_tranche_by_index(
        tranche_manager: &mut pool_soft_tranche::PoolSoftTrancheManager,
        pool_id: sui::object::ID,
        index: u64
    ): &mut pool_soft_tranche::PoolSoftTranche {
        let tranches = pool_soft_tranche::get_tranches(
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
        distribution_config: &distribution_config::DistributionConfig,
        gauge: &mut gauge::Gauge<TestCoinB, TestCoinA>,
        vault: &mut rewarder::RewarderGlobalVault,
        pool: &mut pool::Pool<TestCoinB, TestCoinA>,
        tick_lower: u32,
        tick_upper: u32,
        liquidity_delta: u128,
        clock: &sui::clock::Clock,
    ): distribution::gauge::StakedPosition {
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

        distribution::gauge::deposit_position<TestCoinB, TestCoinA>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            scenario.ctx(),
        )
    }

    #[test_only]
    fun full_setup_with_osail(
        scenario: &mut sui::test_scenario::Scenario,
        admin: address,
        amount_to_lock: u64,
        lock_duration_days: u64,
        current_sqrt_price: u128,
        gauge_base_emissions: u64,
        clock: &mut clock::Clock
    ) {
        scenario.next_tx(admin);
        {
            setup_distribution<SailCoinType>(scenario, admin);
        };

        scenario.next_tx(admin);
        {
            activate_minter<SailCoinType, OSAIL1>(scenario, amount_to_lock, lock_duration_days, clock);
        };

        scenario.next_tx(admin);
        {
            create_pool_and_gauge<TestCoinB, TestCoinA, SailCoinType>(
                scenario, 
                admin,
                current_sqrt_price,
                gauge_base_emissions,
                clock
            );
        };

        // Update Minter Period to OSAIL1
        scenario.next_tx(admin);
        {
            distribute_gauge_epoch_1<SailCoinType, OSAIL1>(scenario, clock);
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
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let treasury_cap = sui::coin::create_treasury_cap_for_testing<SailCoinType>(scenario.ctx());
            let (minter_obj, minter_admin_cap) = minter::create_test<SailCoinType>(
                &minter_publisher,
                option::some(treasury_cap),
                object::id(&distribution_config),
                scenario.ctx()
            );
            minter::grant_distribute_governor(
                &minter_publisher,
                sender,
                scenario.ctx()
            );
            test_utils::destroy(minter_publisher);
            transfer::public_share_object(minter_obj);
            transfer::public_transfer(minter_admin_cap, sender);
            test_scenario::return_shared(distribution_config);
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
            let (mut voter_obj, distribute_cap) = voter::create(
                &voter_publisher,
                global_config_id,
                distribution_config_id,
                scenario.ctx()
            );

            voter_obj.add_governor(&voter_publisher, sender, scenario.ctx());

            test_utils::destroy(voter_publisher);
            transfer::public_share_object(voter_obj);

            // --- Set Distribute Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_distribute_cap(&minter_admin_cap, distribute_cap);
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

        // --- RebaseDistributor Setup --- 
        scenario.next_tx(sender);
        {
            let clock = clock::create_for_testing(scenario.ctx());
            let rd_publisher = rebase_distributor::test_init(scenario.ctx());
            let (rebase_distributor_obj, rebase_distributor_cap) = rebase_distributor::create<SailCoinType>(
                &rd_publisher,
                &clock,
                scenario.ctx()
            );
            test_utils::destroy(rd_publisher);
            let rebase_distributor_id = object::id(&rebase_distributor_obj);
            transfer::public_share_object(rebase_distributor_obj);
            clock::destroy_for_testing(clock);
            // --- Set Reward Distributor Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_reward_distributor_cap(&minter_admin_cap, rebase_distributor_id, rebase_distributor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
        };
    }

    // Updates the minter period, sets the next period token to OSailCoinTypeNext
    #[test_only]
    public fun update_minter_period<SailCoinType, OSailCoinType>(
        scenario: &mut test_scenario::Scenario,
        initial_o_sail_supply: u64,
        clock: &clock::Clock,
    ): sui::coin::Coin<OSailCoinType> {
        let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
        let mut voter = scenario.take_shared<voter::Voter>();
        let voting_escrow = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        let mut rebase_distributor = scenario.take_shared<rebase_distributor::RebaseDistributor<SailCoinType>>();
        let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Correct cap for update_period

        // Create TreasuryCap for OSAIL2 for the next epoch
        let mut o_sail_cap = sui::coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());
        let initial_supply = o_sail_cap.mint(initial_o_sail_supply, scenario.ctx());

        minter::update_period_test<SailCoinType, OSailCoinType>(
            &mut minter, // minter is the receiver
            &mut voter,
            &distribution_config,
            &distribute_governor_cap, // Pass the correct DistributeGovernorCap
            &voting_escrow,
            &mut rebase_distributor,
            o_sail_cap, 
            clock,
            scenario.ctx()
        );

        // Return shared objects & caps
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(voting_escrow);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(rebase_distributor);
        scenario.return_to_sender(distribute_governor_cap);    

        initial_supply
    }

    #[test_only]
    // Activates the minter for a specific oSAIL epoch.
    // Requires the minter, voter, rd, and admin cap to be set up.
    public fun activate_minter<SailCoinType, OSailCoinType>( // Changed to public
        scenario: &mut test_scenario::Scenario,
        amount_to_lock: u64,
        lock_duration_days: u64,
        clock: &mut clock::Clock
    ) { // Returns the minted oSAIL

        // increment clock to make sure the activated_at field is not and epoch start is not 0
        let mut minter_obj = scenario.take_shared<minter::Minter<SailCoinType>>();
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut rebase_distributor = scenario.take_shared<rebase_distributor::RebaseDistributor<SailCoinType>>();
        let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
        let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        let o_sail_cap = sui::coin::create_treasury_cap_for_testing<OSailCoinType>(scenario.ctx());

        // increment clock to make sure the activated_at field is not 0 and epoch start is not 0
        clock.increment_for_testing(7 * 24 * 60 * 60 * 1000 + 1000);
        minter_obj.activate_test<SailCoinType, OSailCoinType>(
            &mut voter,
            &minter_admin_cap,
            &mut rebase_distributor,
            o_sail_cap,
            clock,
            scenario.ctx()
        );

        let sail_coin = sui::coin::mint_for_testing<SailCoinType>(amount_to_lock, scenario.ctx());
        // create_lock consumes the coin and transfers the lock to ctx.sender()
        ve.create_lock<SailCoinType>(
            sail_coin,
            lock_duration_days,
            false, // permanent lock = false
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(minter_obj);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
        test_scenario::return_shared(rebase_distributor);
        scenario.return_to_sender(minter_admin_cap);
    }

    #[test_only]
    fun create_pool_and_gauge<TestCoinB, TestCoinA, SailCoinType>(
        scenario: &mut test_scenario::Scenario,
        admin: address,
        current_sqrt_price: u128,
        gauge_base_emissions: u64,
        clock: &clock::Clock,
    ){
        let mut global_config = scenario.take_shared<config::GlobalConfig>();
        let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
        let admin_cap = scenario.take_from_sender<minter::AdminCap>(); // Minter uses AdminCap
        let mut ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
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

        let gauge = minter.create_gauge<TestCoinB, TestCoinA, SailCoinType>(
            &mut voter,
            &mut distribution_config,
            &create_cap,
            &admin_cap,
            &ve,
            &mut pool,
            gauge_base_emissions,
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(pools);
        transfer::public_transfer(pool, admin);
        transfer::public_transfer(gauge, admin);
        scenario.return_to_sender(lock);
        scenario.return_to_sender(admin_cap);
        scenario.return_to_sender(create_cap);
        test_scenario::return_shared(global_config);
        test_scenario::return_shared(distribution_config);
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        test_scenario::return_shared(ve);
    }

    #[test_only]
    fun distribute_gauge_epoch_1<SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        clock: &clock::Clock,
    ): u64 {
        // initial epoch is distributed without any historical data
        let prev_epoch_pool_emissions: u64 = 0;
        let prev_epoch_pool_fees_usd: u64 = 0;
        let epoch_pool_emissions_usd: u64 = 0;
        let epoch_pool_fees_usd: u64 = 0;
        let epoch_pool_volume_usd: u64 = 0;
        let epoch_pool_predicted_volume_usd: u64 = 0;

        distribute_gauge_emissions_controlled<TestCoinB, TestCoinA, SailCoinType, EpochOSail>(
            scenario,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            clock
        )
    }

    #[test_only]
    fun distribute_gauge_epoch_2<SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        clock: &clock::Clock,
    ): u64 {
        // epoch 2 is distributed with historical data from epoch 1
        // this data results into stable emissions, same as epoch 1 emissions
        let prev_epoch_pool_emissions: u64 = 0;
        let prev_epoch_pool_fees_usd: u64 = 0;
        let epoch_pool_emissions_usd: u64 = 1_000_000_000;
        let epoch_pool_fees_usd: u64 = 1_000_000_000;
        let epoch_pool_volume_usd: u64 = 1_000_000_000;
        let epoch_pool_predicted_volume_usd: u64 = 1_060_000_000; // +3% emissions increase

        distribute_gauge_emissions_controlled<TestCoinB, TestCoinA, SailCoinType, EpochOSail>(
            scenario,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            clock
        )
    }

    #[test_only]
    fun distribute_gauge_epoch_3<SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        clock: &clock::Clock,
    ): u64 {
        // this data results into stable emissions, same as epoch 2 emissions
        let prev_epoch_pool_emissions: u64 = 1_000_000_000;
        let prev_epoch_pool_fees_usd: u64 = 1_000_000_000;
        let epoch_pool_emissions_usd: u64 = 1_000_000_000;
        let epoch_pool_fees_usd: u64 = 1_000_000_000;
        let epoch_pool_volume_usd: u64 = 1_000_000_000;
        let epoch_pool_predicted_volume_usd: u64 = 1_060_000_000; // +3% emissions increase

        distribute_gauge_emissions_controlled<TestCoinB, TestCoinA, SailCoinType, EpochOSail>(
            scenario,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            clock
        )
    }

    // Utility to call minter.distribute_gauge
    #[test_only]
    fun distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        prev_epoch_pool_emissions: u64,
        prev_epoch_pool_fees_usd: u64,
        epoch_pool_emissions_usd: u64,
        epoch_pool_fees_usd: u64,
        epoch_pool_volume_usd: u64,
        epoch_pool_predicted_volume_usd: u64,
        clock: &clock::Clock,
    ): u64 {
        let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>(); // Minter is now responsible
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut gauge = scenario.take_from_sender<gauge::Gauge<CoinTypeA, CoinTypeB>>();
        let mut pool = scenario.take_from_sender<pool::Pool<CoinTypeA, CoinTypeB>>();
        let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Minter uses DistributeGovernorCap

        let aggregator = setup_aggregator(scenario, &mut distribution_config, one_dec18(), clock);

        let distributed_amount = minter.distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            // &mut minter, // minter is the receiver
            &mut voter,
            &distribute_governor_cap,
            &distribution_config,
            &mut gauge,
            &mut pool,
            prev_epoch_pool_emissions,
            prev_epoch_pool_fees_usd,
            epoch_pool_emissions_usd,
            epoch_pool_fees_usd,
            epoch_pool_volume_usd,
            epoch_pool_predicted_volume_usd,
            &aggregator,
            clock,
            scenario.ctx()
        );
        test_utils::destroy(aggregator);

        // Return shared objects
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(gauge);
        scenario.return_to_sender(pool);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);

        distributed_amount
    }

    public fun one_dec18(): u128 {
        ONE_DEC18
    }

    /// You can create new aggregator just prior to the call that requires it.
    /// Then just destroy it after the call.
    /// Aggregators are not shared objects due to missing store capability.
    public fun setup_aggregator(
        scenario: &mut test_scenario::Scenario,
        distribution_config: &mut distribution_config::DistributionConfig,
        price: u128, // decimals 18
        clock: &clock::Clock,
    ): aggregator::Aggregator {
        let owner = scenario.ctx().sender();
        let mut aggregator = aggregator::new_aggregator(
            aggregator::example_queue_id(),
            std::string::utf8(b"test_aggregator"),
            owner,
            vector::empty(),
            1,
            1000000000000000,
            100000000000,
            5,
            1000,
            scenario.ctx(),
        );

        // 1 * 10^18
        let result = decimal::new(price, false);
        let result_timestamp_ms = clock.timestamp_ms();
        let min_result = result;
        let max_result = result;
        let stdev = decimal::new(0, false);
        let range = decimal::new(0, false);
        let mean = result;

        aggregator::set_current_value(
            &mut aggregator,
            result,
            result_timestamp_ms,
            result_timestamp_ms,
            result_timestamp_ms,
            min_result,
            max_result,
            stdev,
            range,
            mean
        );

        distribution_config.test_set_o_sail_price_aggregator(&aggregator);
        distribution_config.test_set_sail_price_aggregator(&aggregator);

        aggregator
    }

    #[test]
    fun test_admins() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v2::add_admin(
                &admin_cap,
                &mut locker,
                admin2,
                scenario.ctx()
            );

            liquidity_soft_lock_v2::check_admin(&locker, admin2);

            liquidity_soft_lock_v2::revoke_admin(
                &admin_cap,
                &mut locker,
                admin2,
                scenario.ctx()
            );

            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EAddressNotAdmin)]
    fun test_revoke_not_admin() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v2::revoke_admin(
                &admin_cap,
                &mut locker,
                admin2,
                scenario.ctx()
            );

            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v2::EAdminNotWhitelisted)]
    fun test_not_admin_locker_pause() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v2::test_init(scenario.ctx());
            pool_soft_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v2::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v2::locker_pause(
                &mut locker,
                true,
                scenario.ctx()
            );

            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        scenario.next_tx(admin2);
        {
            let mut locker = scenario.take_shared<liquidity_soft_lock_v2::SoftLocker>();

            liquidity_soft_lock_v2::locker_pause(
                &mut locker,
                true,
                scenario.ctx()
            );

            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}
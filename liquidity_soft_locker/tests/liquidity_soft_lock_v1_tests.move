#[test_only]
module liquidity_soft_locker::liquidity_soft_lock_v1_tests {
    use sui::test_scenario;

    use liquidity_soft_locker::liquidity_soft_lock_v1;
    use liquidity_soft_locker::pool_soft_tranche;
    use liquidity_soft_locker::soft_time_manager;
    use locker_cap::locker_cap;
    use clmm_pool::position;
    use clmm_pool::pool;
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config, GlobalConfig};
    use clmm_pool::stats;
    use clmm_pool::rewarder;
    use price_provider::price_provider;
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
        
    
    #[test]
    fun test_init() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            // let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
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
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let position_id = sui::object::id<clmm_pool::position::Position>(&position);

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time, full_unlocking_time) = liquidity_soft_lock_v1::get_unlock_time(&locked_position);
            assert!(expiration_time == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253242);
            assert!(full_unlocking_time == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 9234326345);
            assert!(liquidity_soft_lock_v1::get_profitability(&locked_position) == 10000, 923463477);
            assert!(locked_position.get_locked_position_id() == position_id, 9234325235);

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun create_pool<TestCoinB, TestCoinA>(
        scenario: &mut test_scenario::Scenario,
        admin: address,
        current_sqrt_price: u128,
        clock: &clock::Clock,
    ){
        let mut global_config = scenario.take_shared<config::GlobalConfig>();
        let mut pools = scenario.take_shared<Pools>();

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

        transfer::public_transfer(pool, admin);
        test_scenario::return_shared(pools);
        test_scenario::return_shared(global_config);
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

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockManagerPaused)]
    fun test_lock_position_lock_manager_paused() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            liquidity_soft_lock_v1::locker_pause(&mut locker, true, scenario.ctx());

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EInvalidBlockPeriodIndex)]
    fun test_lock_position_invalid_block_period_index() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                4,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_lock_position_no_tranches() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
                scenario.ctx()
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EInvalidProfitabilitiesLength)]
    fun test_lock_position_invalid_profitabilities_length_in_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            locked_positions.destroy_empty();

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253242);
            assert!(full_unlocking_time_1 == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7, 92343253252);
            assert!(full_unlocking_time_2 == soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7, 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 165688655270059192614, 923412491398739);
            assert!(liquidity2 == 332041393326771866, 9234124983278);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_with_split_2() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                33<<64,
                &clock
            );

            // let total_liquidity = pool.position_manager().borrow_position_info(position_id).info_liquidity();
            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 2);
            let locked_position_2 = locked_positions.pop_back();
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            let (expiration_time_1, full_unlocking_time_1) = locked_position_1.get_unlock_time();
            assert!(expiration_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7), 9234326345);
            assert!(locked_position_1.get_profitability() == 10000, 923463477);
            let (expiration_time_2, full_unlocking_time_2) = locked_position_2.get_unlock_time();
            assert!(expiration_time_2 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 92343253252);
            assert!(full_unlocking_time_2 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 6*86400*7), 92343263123);
            assert!(locked_position_2.get_profitability() == 10000, 9234124421);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            // assert!((liquidity1 + liquidity2) == total_liquidity, 92873453487);
            assert!(liquidity1 == 165687548465414770041, 923412491398739);
            assert!(liquidity2 == 443055005967000433161, 9234124983278);

            assert!(locked_position_1.get_locked_position_id() != locked_position_2.get_locked_position_id(),9234325235);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
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

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            let (locked_position_11, locked_position_12) = liquidity_soft_lock_v1::split_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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

            let (locked_position_111, locked_position_112) = liquidity_soft_lock_v1::split_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when split position
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockManagerPaused)]
    fun test_split_position_pause(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::locker_pause(&mut locker, true, scenario.ctx());

            let (locked_position_11, locked_position_12) = liquidity_soft_lock_v1::split_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockPeriodEnded when split position
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EFullLockPeriodEnded)]
    fun test_split_position_period_ended(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let locked_position_1 = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(7)*1000);
            
            let (locked_position_11, locked_position_12) = liquidity_soft_lock_v1::split_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 2);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            assert!(expiration_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 3*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 4*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219369787329198410390, 923412491398739); // 66%
            assert!(liquidity2 == 112671605997573518490, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(5)*1000); // next epoch (4)

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (collected_fee_a, collected_fee_b) = liquidity_soft_lock_v1::collect_fee<TestCoinB, TestCoinA>(
                &mut locker,
                &global_config,
                &mut pool,
                &locked_position_2
            );
            transfer::public_transfer(sui::coin::from_balance(collected_fee_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(collected_fee_b, scenario.ctx()), admin);

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 3794126173307114780, 92348768657674);
            assert!(remove_balance_b.value() == 534405474921791512, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                (101<<64)/100,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 3);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(  
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            assert!(expiration_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 2*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 5*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219575652993061008986, 9234124913987);
            assert!(liquidity2 == 112465740333710919911, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        // Advance to Epoch 2 (OSAIL2)
        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (2)

        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (3)

        // Advance to Epoch 4 (OSAIL4)
        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (4)

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();


            // one epoch has passed since expiration date
            // can withdraw 1/3
            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        scenario.next_tx(admin);
        {
            clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (5)

            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            // two epochs have passed since expiration date
            // can withdraw 2/3
            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            test_scenario::return_shared(vault);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        scenario.next_tx(admin);
        {
            clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (6)

            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut pool,
                locked_position_2,
                &clock,
                scenario.ctx()
            );
            assert!(remove_balance_a.value() == 1082352715785369272, 92348768657674);
            assert!(remove_balance_b.value() == 365061384823952775, 92348768657674);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        // Advance to Epoch 2
        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (2)

        // Advance to Epoch 3
        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (3)

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(1)*1000); // next epoch (4)

            let position_id = locked_position_1.get_locked_position_id();
            assert!(locker.is_position_locked(position_id), 9234887456443);

            // full unlock
            let (position, coin_a, coin_b) = liquidity_soft_lock_v1::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &clock
            );

            assert!(!locker.is_position_locked(position_id), 9234887456444);

            transfer::public_transfer(position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when unlocking
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockManagerPaused)]
    fun test_pause_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v1::locker_pause(&mut locker, true, scenario.ctx());

            // full unlock
            let (position, coin_a, coin_b) = liquidity_soft_lock_v1::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &clock
            );

            transfer::public_transfer(position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // EFullLockPeriodNotEnded when unlocking
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EFullLockPeriodNotEnded)]
    fun test_full_lock_period_not_ended_when_unlock_position(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            // full unlock
            let (position, coin_a, coin_b) = liquidity_soft_lock_v1::unlock_position<TestCoinB, TestCoinA>(
                &mut locker,
                locked_position_1,
                &clock
            );

            transfer::public_transfer(position, admin);
            transfer::public_transfer(sui::coin::from_balance(coin_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(coin_b, scenario.ctx()), admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockManagerPaused when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockManagerPaused)]
    fun test_pause_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            liquidity_soft_lock_v1::locker_pause(&mut locker, true, scenario.ctx());

            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ELockPeriodNotEnded when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockPeriodNotEnded)]
    fun test_lock_period_not_ended_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951,
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 1);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut pool,
                locked_position_1,
                &clock,
                scenario.ctx()
            );
            transfer::public_transfer(sui::coin::from_balance(remove_balance_a, scenario.ctx()), admin);
            transfer::public_transfer(sui::coin::from_balance(remove_balance_b, scenario.ctx()), admin);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    // ENoLiquidityToRemove when removing liquidity
    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ENoLiquidityToRemove)]
    fun test_no_liquidity_to_remove_when_remove_liquidity(){
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 2);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                18<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            assert!(expiration_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 3*86400*7), 92343253242);
            assert!(full_unlocking_time_1 == (soft_time_manager::epoch_start(clock.timestamp_ms()/1000) + 4*86400*7), 9234326345);

            let liquidity1 = pool.position_manager().borrow_position_info(locked_position_1.get_locked_position_id()).info_liquidity();
            let liquidity2 = pool.position_manager().borrow_position_info(locked_position_2.get_locked_position_id()).info_liquidity();
            assert!(liquidity1 == 219369787329198410390, 923412491398739); // 66%
            assert!(liquidity2 == 112671605997573518490, 9234124983278);

            transfer::public_transfer(locked_position_1, admin);
            transfer::public_transfer(locked_position_2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::increment_for_testing(&mut clock, soft_time_manager::epoch_to_seconds(3)*1000); // next epoch (4)

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let locked_position_1 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();
            // locked_position_2 is the first lock from the first tranche
            let locked_position_2 = scenario.take_from_sender<liquidity_soft_lock_v1::SoftLockedPosition<TestCoinB, TestCoinA>>();

            // full unlock
            let (remove_balance_a, remove_balance_b) = liquidity_soft_lock_v1::remove_lock_liquidity<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
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
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
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
            assert!(new_liquidity == 179200794087989674225, 923412491398739); // liquidity should be proportionally increased by ~4.87x

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(100)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(200)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_with_swap_b2a() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                200,
                1<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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
            assert!(liquidity == 18446744073709551616, 923412491398739);

            let position_id = &locked_position.get_locked_position_id();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
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
            assert!(new_liquidity == 4576892976317919965, 923412491398739); // liquidity should be proportionally decreased by ~4x

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(13)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(417)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                200,
                300,
                9<<64,
                &clock
            );

            let (position_id) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
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

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(211),
                integer_mate::i32::from_u32(243),
                &clock,
                scenario.ctx()
            );

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
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
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

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-1),
                integer_mate::i32::from_u32(48),
                &clock,
                scenario.ctx()
            );

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
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                5<<64,
                &clock
            );
            let position_admin_2 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-50,
                300,
                4<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                4<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-400,
                600,
                12<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(110),
                integer_mate::i32::from_u32(160),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_up() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                5<<64,
                &clock
            );
            let position_admin_2 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-50,
                300,
                4<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                4<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                110,
                160,
                12<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-400),
                integer_mate::i32::from_u32(600),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                4<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                600,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(110),
                integer_mate::i32::from_u32(160),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range_v2() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                4<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                600,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(400),
                integer_mate::i32::from_u32(2500),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range_v3() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                9<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                600,
                10<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-1000),
                integer_mate::i32::from_u32(4294967295-50),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range_v4() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                9<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-400,
                4294967295-100,
                10<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-1000),
                integer_mate::i32::from_u32(4294967295-50),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range_v5() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                9<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-10000,
                4294967295-100,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(4294967295-4000),
                integer_mate::i32::from_u32(4294967295-450),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_change_tick_range_interval_out_range_v6() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, // tick = 148
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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
                17288384724888837365 << 64,  // total_volume
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
                300,
                9<<64,
                &clock
            );
            let position_admin_3 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                0,
                110,
                4<<64,
                &clock
            );
            let position_admin_4 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                180,
                8<<64,
                &clock
            );
            let position_admin_5 = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                200,
                2500,
                3<<64,
                &clock
            );

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                4294967295-400,
                4294967295-100,
                10<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(550),
                integer_mate::i32::from_u32(1000),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(position_admin_2, admin);
            transfer::public_transfer(position_admin_3, admin);
            transfer::public_transfer(position_admin_4, admin);
            transfer::public_transfer(position_admin_5, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
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
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                200,
                3<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            // a2b
            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(6),
                integer_mate::i32::from_u32(395),
                &clock,
                scenario.ctx()
            );

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(6)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(395)), 96340634523453);

            // b2a
            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(101),
                integer_mate::i32::from_u32(172),
                &clock,
                scenario.ctx()
            );

            let (new_tick_lower, new_tick_upper) = pool.position_manager().borrow_position_info(locked_position.get_locked_position_id()).info_tick_range();
            assert!(new_tick_lower.eq(integer_mate::i32::from_u32(101)), 96340634523452);
            assert!(new_tick_upper.eq(integer_mate::i32::from_u32(172)), 96340634523453);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(position_admin, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ELockManagerPaused)]
    fun test_pause_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            liquidity_soft_lock_v1::locker_pause(&mut locker, true, scenario.ctx());

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(100),
                integer_mate::i32::from_u32(200),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EFullLockPeriodEnded)]
    fun test_lock_period_ended_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*7*24*6*1000);

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(100),
                integer_mate::i32::from_u32(200),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::ENotChangedTickRange)]
    fun test_not_changed_tick_range_when_change_tick_range() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
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
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let (position) = create_position_with_liquidity<TestCoinB, TestCoinA>( 
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                2<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1);
            let mut locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            clock::increment_for_testing(&mut clock, 3600*5*24*1000);

            liquidity_soft_lock_v1::change_tick_range<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut locked_position,
                &mut pool,
                &mut stats,
                &price_provider,
                integer_mate::i32::from_u32(10),
                integer_mate::i32::from_u32(500),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(stats);
            test_scenario::return_shared(price_provider);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_whitelisted_providers() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();

            let empty_whitelisted_providers = locker.is_provider_whitelisted(@0x1);
            assert!(!empty_whitelisted_providers, 928254);

            liquidity_soft_lock_v1::add_addresses_to_whitelist(
                &mut locker,
                vector[@0x1, @0x2, @0x3],
                scenario.ctx()
            );

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x1);
            assert!(whitelisted_addresses, 932469);

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x2);
            assert!(whitelisted_addresses, 932469);

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x3);
            assert!(whitelisted_addresses, 932469);

            liquidity_soft_lock_v1::remove_addresses_from_whitelist(
                &mut locker,
                vector[@0x1, @0x2],
                scenario.ctx()
            );

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x1);
            assert!(!whitelisted_addresses, 932473);

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x2);
            assert!(!whitelisted_addresses, 932473);

            let whitelisted_addresses = locker.is_provider_whitelisted(@0x3);
            assert!(whitelisted_addresses, 932473);

            assert!(locker.get_ignore_whitelist_flag() == false, 932474);

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
                scenario.ctx()
            );

            assert!(locker.get_ignore_whitelist_flag() == true, 932474);

            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(locker);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_in_whitelist() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::add_addresses_to_whitelist(
                &mut locker,
                vector[admin],
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let position_id = sui::object::id<clmm_pool::position::Position>(&position);

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EProviderNotWhitelisted)]
    fun test_lock_position_not_in_whitelist() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::add_addresses_to_whitelist(
                &mut locker,
                vector[@0x4, @0x2, @0x3],
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_lock_position_when_ignore_whitelist() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let mut tranche_manager = scenario.take_shared<pool_soft_tranche::PoolSoftTrancheManager>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::set_ignore_whitelist(
                &mut locker,
                true,
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

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                10,
                500,
                9<<64,
                &clock
            );

            let mut locked_positions = liquidity_soft_lock_v1::lock_position<TestCoinB, TestCoinA>(
                &global_config,
                &mut vault,
                &mut locker,
                &mut tranche_manager,
                &mut pool,
                position,
                0,
                &clock,
                scenario.ctx()
            );
            assert!(locked_positions.length() == 1, 9234325235);
            let locked_position = locked_positions.pop_back();
            locked_positions.destroy_empty();

            transfer::public_transfer(locked_position, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            test_scenario::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_admins() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::add_admin(
                &admin_cap,
                &mut locker,
                admin2,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::check_admin(&locker, admin2);

            liquidity_soft_lock_v1::revoke_admin(
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
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EAddressNotAdmin)]
    fun test_revoke_not_admin() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::revoke_admin(
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
    #[expected_failure(abort_code = liquidity_soft_lock_v1::EAdminNotWhitelisted)]
    fun test_not_admin_locker_pause() {
        let admin = @0x1;
        let admin2 = @0x5;
        let mut scenario = test_scenario::begin(admin);
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_soft_lock_v1::test_init(scenario.ctx());
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
            create_pool<TestCoinB, TestCoinA>(
                &mut scenario, 
                admin, 
                18584142135623730951, 
                &clock
            );
        };

        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_soft_lock_v1::SuperAdminCap>();
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();
            let global_config = scenario.take_shared<config::GlobalConfig>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 4);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_soft_lock_v1::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_soft_lock_v1::locker_pause(
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
            let mut locker = scenario.take_shared<liquidity_soft_lock_v1::SoftLocker>();

            liquidity_soft_lock_v1::locker_pause(
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
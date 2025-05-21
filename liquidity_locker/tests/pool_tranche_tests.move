
module liquidity_locker::pool_tranche_tests {
    use sui::test_scenario;

    use liquidity_locker::liquidity_lock_v1;
    use liquidity_locker::pool_tranche;
    use liquidity_locker::time_manager;
    use locker_cap::locker_cap;
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config};
    use clmm_pool::stats;
    use clmm_pool::rewarder;
    use price_provider::price_provider;
    use sui::clock;
    public struct TestCoinA has drop {}
    public struct TestCoinB has drop {}
    public struct SailCoinType has drop {}
    public struct RewardCoinType1 has drop {}
    public struct RewardCoinType2 has drop {}
    public struct RewardCoinType3 has drop {}

    #[test]
    fun test_pool_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(&mut tranche_manager, sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool));
            assert!(tranches.length() == 1, 92343);
            assert!(tranches.borrow(0).is_filled() == false, 92344);
            assert!(tranches.borrow(0).get_duration_profitabilities().length() == 3, 92345);
            assert!(tranches.borrow(0).get_duration_profitabilities().borrow(2) == 30000, 923451);
            let (free_volume, volume_in_coin_a) = tranches.borrow(0).get_free_volume();
            assert!(free_volume == 10000000 << 64, 92346);
            assert!(volume_in_coin_a == true, 92347);

            std::vector::pop_back(&mut duration_profitabilities);
            std::vector::push_back(&mut duration_profitabilities, 40000);
            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                false,
                99999 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                2000, // 20%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 2, 92343);
            assert!(tranches.borrow(1).is_filled() == false, 92344);
            assert!(tranches.borrow(1).get_duration_profitabilities().length() == 3, 92345);
            assert!(tranches.borrow(1).get_duration_profitabilities().borrow(2) == 40000, 923451);
            let (free_volume, volume_in_coin_a) = tranches.borrow(1).get_free_volume();
            assert!(free_volume == 99999 << 64, 92346);
            assert!(volume_in_coin_a == false, 92347);

            // add reward
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let tranche_2 = tranches.borrow(1);
            let tranche2_id = sui::object::id<pool_tranche::PoolTranche>(tranche_2);

            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            let after_reward = pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );
            assert!(after_reward == 10000000, 92348);

            let reward2 = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            let after_balance_reward2 = pool_tranche::add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward2.into_balance(),
                scenario.ctx()
            );
            assert!(after_balance_reward2 == 20000000, 92366);

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                90000, // 100% total_income
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            assert!(reward_balance.value() == 20000000, 92349);

            // add another reward
            let new_type_reward = sui::coin::mint_for_testing<RewardCoinType2>(90000000, scenario.ctx());
            let balance_new_reward = pool_tranche::add_reward<RewardCoinType2>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                new_type_reward.into_balance(),
                scenario.ctx()
            );
            assert!(balance_new_reward == 90000000, 92370);

            let new_reward_balance1 = pool_tranche::get_reward_balance<RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                45000, // 50% total_income
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            assert!(new_reward_balance1.value() == 45000000, 92349);

            let new_reward_balance2 = pool_tranche::get_reward_balance<RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche2_id,
                45000, // 50% total_income
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            assert!(new_reward_balance2.value() == 45000000, 92349);

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            let tranche2 = tranches.borrow_mut(1);

            // full fill tranche
            pool_tranche::fill_tranches(
                tranche2,
                99999 << 64
            );
            let (free_volume2, _) = tranche2.get_free_volume();
            assert!(free_volume2 == 0, 92349);
            assert!(tranche2.is_filled() == true, 92350);

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            sui::coin::from_balance(new_reward_balance1, scenario.ctx()).burn_for_testing();
            sui::coin::from_balance(new_reward_balance2, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ERewardAlreadyClaimed)]
    fun test_reward_already_claimed() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
                &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(&mut tranche_manager, sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool));
            assert!(tranches.length() == 1, 92343);
            
            // Save required values before releasing borrows
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let pool_id = sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool);
            let timestamp = clock.timestamp_ms()/1000;
            
            // Release borrows
            let _ = tranches;
            
            // add first reward
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                pool_id,
                tranche_id,
                timestamp,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                900,
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            let reward_balance2 = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                900,
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            sui::coin::from_balance(reward_balance2, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ETotalIncomeAlreadyExists)]
    fun test_total_income_already_exists() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
                &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(&mut tranche_manager, sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool));
            assert!(tranches.length() == 1, 92343);
            
            // Save required values before releasing borrows
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let pool_id = sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool);
            let timestamp = clock.timestamp_ms()/1000;
            
            // Release borrows
            let _ = tranches;
            
            // add first reward
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                pool_id,
                tranche_id,
                timestamp,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                pool_id,
                tranche_id,
                timestamp,
                reward.into_balance(),
                1,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ETrancheNotFound)]
    fun test_tranche_not_found() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
                &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );
            
            // Trying to add reward for non-existent tranche
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            let pool_id = sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool);
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                pool_id,
                pool_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ERewardNotFound)]
    fun test_reward_not_found() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );

            // add reward
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());

            
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                90000, // 100% total_income
                (clock.timestamp_ms()/1000 + time_manager::epoch_to_seconds(2)),
                scenario.ctx()
            );

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ERewardNotEnough)]
    fun test_reward_not_enough() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 1, 92343);

            // add reward
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranches.borrow(0));
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                90001,
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ETrancheNotFound)]
    fun test_tranche_not_found_at_get_reward_balance() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 1, 92343);

            // add reward
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());

            
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                90000,
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ERewardNotFound)]
    fun test_invalid_reward_type() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 1, 92343);

            // add reward
            let tranche_1 = tranches.borrow(0);
            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche_1);
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());

            
            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000,
                scenario.ctx()
            );

            // get reward with invalid reward type
            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType2>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                tranche_id,
                tranche_id,
                90000,
                clock.timestamp_ms()/1000,
                scenario.ctx()
            );

            sui::coin::from_balance(reward_balance, scenario.ctx()).burn_for_testing();
            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::ETrancheFilled)]
    fun test_tranche_filled_at_fill_tranches() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 1, 92343);

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            let tranche = tranches.borrow_mut(0);

            // full fill tranche
            pool_tranche::fill_tranches(
                tranche,
                10000000 << 64
            );

            pool_tranche::fill_tranches(
                tranche,
                1 << 64
            );

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = pool_tranche::EInvalidAddLiquidity)]
    fun test_invalid_add_liquidity_at_fill_tranches() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            assert!(tranches.length() == 1, 92343);

            let tranches = pool_tranche::get_tranches(
                &mut tranche_manager, 
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool)
            );
            let tranche = tranches.borrow_mut(0);

            // full fill tranche
            pool_tranche::fill_tranches(
                tranche,
                10000001 << 64
            );

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_pool_tranche_minimum_remaining_volume() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
            pool_tranche::test_init(scenario.ctx());
            locker_cap::init_test(scenario.ctx());
            config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        scenario.next_tx(admin);
        {
            let create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
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
            liquidity_lock_v1::init_locker(
            &admin_cap,
                &create_cap,
                &mut locker,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let mut pools = scenario.take_shared<Pools>();

            let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                true,
                10000000 << 64,  // total_volume
                duration_profitabilities, // duration_profitabilities
                1000, // 10%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(&mut tranche_manager, sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool));
            assert!(tranches.length() == 1, 92343);
            assert!(tranches.borrow(0).is_filled() == false, 92344);
            assert!(tranches.borrow(0).get_duration_profitabilities().length() == 3, 92345);
            assert!(tranches.borrow(0).get_duration_profitabilities().borrow(2) == 30000, 923451);
            let (free_volume, volume_in_coin_a) = tranches.borrow(0).get_free_volume();
            assert!(free_volume == 10000000 << 64, 92346);
            assert!(volume_in_coin_a == true, 92347);

            // add reward
            let tranche = tranches.borrow_mut(0);

            // 89% fill tranche
            pool_tranche::fill_tranches(
                tranche,
                8900000 << 64
            );
            let (mut free_volume, _) = tranche.get_free_volume();
            assert!(free_volume == 1100000<<64, 92349);
            assert!(tranche.is_filled() == false, 92350);

            // +1%
            pool_tranche::fill_tranches(
                tranche,
                100000 << 64
            );
            (free_volume, _) = tranche.get_free_volume();
            assert!(free_volume == 1000000<<64, 92349);
            assert!(tranche.is_filled() == true, 92350);

            transfer::public_transfer(pool, admin);
            test_scenario::return_shared(pools);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(create_cap, admin);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(locker);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario);
    }
}
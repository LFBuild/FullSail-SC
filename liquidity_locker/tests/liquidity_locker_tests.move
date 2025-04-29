#[test_only]
module liquidity_locker::liquidity_locker_tests {
    use sui::test_scenario;

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
    use sui::clock;
    public struct TestCoinA has drop {}
    public struct TestCoinB has drop {}
    public struct SailCoinType has drop {}
    public struct RewardCoinType1 has drop {}
    public struct RewardCoinType2 has drop {}
    public struct RewardCoinType3 has drop {}

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
    fun test_create_pool_tranche() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            liquidity_locker::test_init(scenario.ctx());
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
            let admin_cap = scenario.take_from_sender<liquidity_locker::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_locker::Locker>();
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
            liquidity_locker::init_locker(
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
                10000000,  // total_volume
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
            assert!(free_volume == 10000000, 92346);
            assert!(volume_in_coin_a == true, 92347);

            std::vector::pop_back(&mut duration_profitabilities);
            std::vector::push_back(&mut duration_profitabilities, 40000);
            pool_tranche::new(
                &tranche_admin_cap,
                &mut tranche_manager,
                &pool,
                false,
                99999,  // total_volume
                duration_profitabilities, // duration_profitabilities
                2000, // 20%
                scenario.ctx()
            );

            let tranches = pool_tranche::get_tranches(&mut tranche_manager, sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool));
            assert!(tranches.length() == 2, 92343);
            assert!(tranches.borrow(1).is_filled() == false, 92344);
            assert!(tranches.borrow(1).get_duration_profitabilities().length() == 3, 92345);
            assert!(tranches.borrow(1).get_duration_profitabilities().borrow(2) == 40000, 923451);
            let (free_volume, volume_in_coin_a) = tranches.borrow(1).get_free_volume();
            assert!(free_volume == 99999, 92346);
            assert!(volume_in_coin_a == false, 92347);

            // add reward
            let reward = sui::coin::mint_for_testing<RewardCoinType1>(10000000, scenario.ctx());
            let after_reward = pool_tranche::add_reward<RewardCoinType1>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranches.borrow(0)),
                clock.timestamp_ms()/1000,
                reward.into_balance(),
                90000
            );
            assert!(after_reward == 10000000, 92348);

            let reward_balance = pool_tranche::get_reward_balance<RewardCoinType1>(
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranches.borrow(0)),
                10000000,
                clock.timestamp_ms()/1000
            );

            assert!(reward_balance.value() == 10000000, 92349);

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
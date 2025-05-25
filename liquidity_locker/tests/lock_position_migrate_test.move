#[test_only]
module liquidity_locker::lock_position_migrate_test {
    use sui::test_scenario;
    use sui::test_utils;

    use liquidity_locker::liquidity_lock_v1;
    use liquidity_locker::liquidity_lock_v2;
    use liquidity_locker::pool_tranche;
    use locker_cap::locker_cap;
    use clmm_pool::position;
    use clmm_pool::pool;
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config, GlobalConfig, AdminCap};
    use clmm_pool::stats;
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
    fun test_lock_position_migrate() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
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

        // Setup
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

        // Create  tranche and add reward for the first epoch
        // Create a new position
        // Create lock V1
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
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
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v1::init_locker(
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
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_lock_v1::lock_position<TestCoinB, TestCoinA>(
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
            let initial_o_sail2_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL1, OSAIL2>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL2
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail2_supply); // Burn OSAIL2
        };

        // init  liquidity_lock_v2
        scenario.next_tx(admin);
        {
            liquidity_lock_v2::test_init(scenario.ctx());
        };

        // migrate lock position from v1 to v2
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
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
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker_v1 = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut locker_v2 = scenario.take_shared<liquidity_lock_v2::Locker>();
            let locked_position_v1 = scenario.take_from_sender<liquidity_lock_v1::LockedPosition<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker_v2,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            let (coin_a, coin_b) = locked_position_v1.get_coins();
            let position_id = locked_position_v1.get_locked_position_id();
            let profitability = locked_position_v1.get_profitability();
            let (expiration_time, full_unlocking_time) = locked_position_v1.get_unlock_time();

            let locked_position_v2 = liquidity_lock_v2::lock_position_migrate<TestCoinB, TestCoinA>(
                &global_config,
                &distribution_config,
                &mut locker_v1,
                &mut locker_v2,
                &mut gauge,
                &mut pool,
                locked_position_v1,
                &clock,
                scenario.ctx()
            );

            assert!(locked_position_v2.get_locked_position_id() == position_id, 9346827946);
            assert!(locked_position_v2.get_profitability() == profitability, 9342745072243);
            let (expiration_time_v2, full_unlocking_time_v2) = locked_position_v2.get_unlock_time();
            assert!(expiration_time_v2 == expiration_time, 96250236232);
            assert!(full_unlocking_time_v2 == full_unlocking_time, 9361394232);
            let (coin_a_v2, coin_b_v2) = locked_position_v2.get_coins();
            assert!(coin_a_v2 == coin_a, 993496943592);
            assert!(coin_b_v2 == coin_b, 923692348638);
            
            transfer::public_transfer(locked_position_v2, admin);
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
            test_scenario::return_shared(locker_v1);
            test_scenario::return_shared(locker_v2);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(reward_distributor);
        };
        
        // Advance to Epoch 3 (OSAIL3)
        clock::increment_for_testing(&mut clock, common::epoch_to_seconds(1)*1000); // next epoch (3)

        // Update Minter Period to OSAIL3
        scenario.next_tx(admin);
        {
            let initial_o_sail3_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL2, OSAIL3>(
                &mut scenario,
                1_000_000, // Arbitrary supply for OSAIL3
                admin,
                &clock
            );
            sui::coin::burn_for_testing(initial_o_sail3_supply); // Burn OSAIL3
        };

        // Add reward to the SECOND epoch
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

            let reward2 = sui::coin::mint_for_testing<SailCoinType>(10000000, scenario.ctx());
            pool_tranche::set_total_incomed_and_add_reward<SailCoinType>(
                &tranche_admin_cap,
                &mut tranche_manager,
                sui::object::id<clmm_pool::pool::Pool<TestCoinB, TestCoinA>>(&pool),
                sui::object::id<pool_tranche::PoolTranche>(tranche1),
                common::epoch_start(common::epoch_to_seconds(3)),
                reward2.into_balance(),
                10300000000000,
                scenario.ctx()
            );

            transfer::public_transfer(tranche_admin_cap, admin);
            test_scenario::return_shared(tranche_manager);
            transfer::public_transfer(pool, admin);
        };

        // Claim rewards for the second epoch
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
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
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let locker = scenario.take_shared<liquidity_lock_v2::Locker>();
            let mut locked_position = scenario.take_from_sender<liquidity_lock_v2::LockedPosition<TestCoinB, TestCoinA>>();

            // Claim rewards for the second epoch lock
            liquidity_lock_v2::collect_reward_sail<TestCoinB, TestCoinA, OSAIL2, SailCoinType>(
                &mut tranche_manager,
                &mut ve,
                &mut gauge,
                &mut pool,
                &mut locked_position,
                common::epoch_start(common::epoch_to_seconds(3)),
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

        // CHECK SAIL LOCKED IN VOTING_ESCROW
        scenario.next_tx(admin);
        {
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            // reward from the second epoch was in SAIL
            // which was automatically locked in VOTING_ESCROW
            let lock = scenario.take_from_sender<voting_escrow::Lock>();
            assert!(lock.get_amount() == 999999, 926223626362); // 10% of total reward for epoch 2

            transfer::public_transfer(lock, admin);
            test_scenario::return_shared(ve);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_lock_v2::ELockManagerPaused)]
    fun test_pause_v2_when_lock_position_migrate() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
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

        // Setup
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

        // Create  tranche and add reward for the first epoch
        // Create a new position
        // Create lock V1
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v1::init_locker(
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
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_lock_v1::lock_position<TestCoinB, TestCoinA>(
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

        // init  liquidity_lock_v2
        scenario.next_tx(admin);
        {
            liquidity_lock_v2::test_init(scenario.ctx());
        };

        // migrate lock position from v1 to v2
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
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
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker_v1 = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut locker_v2 = scenario.take_shared<liquidity_lock_v2::Locker>();
            let locked_position_v1 = scenario.take_from_sender<liquidity_lock_v1::LockedPosition<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker_v2,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_lock_v2::locker_pause(&admin_cap, &mut locker_v2, true);

            let locked_position_v2 = liquidity_lock_v2::lock_position_migrate<TestCoinB, TestCoinA>(
                &global_config,
                &distribution_config,
                &mut locker_v1,
                &mut locker_v2,
                &mut gauge,
                &mut pool,
                locked_position_v1,
                &clock,
                scenario.ctx()
            );
            
            transfer::public_transfer(locked_position_v2, admin);
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
            test_scenario::return_shared(locker_v1);
            test_scenario::return_shared(locker_v2);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(reward_distributor);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_lock_v1::ELockManagerPaused)]
    fun test_pause_v1_when_lock_position_migrate() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
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

        // Setup
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

        // Create  tranche and add reward for the first epoch
        // Create a new position
        // Create lock V1
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v1::init_locker(
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
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_lock_v1::lock_position<TestCoinB, TestCoinA>(
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

        // init  liquidity_lock_v2
        scenario.next_tx(admin);
        {
            liquidity_lock_v2::test_init(scenario.ctx());
        };

        // migrate lock position from v1 to v2
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
            let locker_v1_admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
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
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker_v1 = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut locker_v2 = scenario.take_shared<liquidity_lock_v2::Locker>();
            let locked_position_v1 = scenario.take_from_sender<liquidity_lock_v1::LockedPosition<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker_v2,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            liquidity_lock_v1::locker_pause(&locker_v1_admin_cap, &mut locker_v1, true);

            let locked_position_v2 = liquidity_lock_v2::lock_position_migrate<TestCoinB, TestCoinA>(
                &global_config,
                &distribution_config,
                &mut locker_v1,
                &mut locker_v2,
                &mut gauge,
                &mut pool,
                locked_position_v1,
                &clock,
                scenario.ctx()
            );
            
            transfer::public_transfer(locked_position_v2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(locker_v1_admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker_v1);
            test_scenario::return_shared(locker_v2);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(reward_distributor);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_lock_v2::EInvalidGaugePool)]
    fun test_invalid_gauge_pool_when_lock_position_migrate() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
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

        // Setup
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

        // Create  tranche and add reward for the first epoch
        // Create a new position
        // Create lock V1
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v1::init_locker(
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
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_lock_v1::lock_position<TestCoinB, TestCoinA>(
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

        // init  liquidity_lock_v2
        scenario.next_tx(admin);
        {
            liquidity_lock_v2::test_init(scenario.ctx());
        };

        // migrate lock position from v1 to v2
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
            let tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let mut global_config = scenario.take_shared<config::GlobalConfig>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker_v1 = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut locker_v2 = scenario.take_shared<liquidity_lock_v2::Locker>();
            let locked_position_v1 = scenario.take_from_sender<liquidity_lock_v1::LockedPosition<TestCoinB, TestCoinA>>();
            let mut pools = scenario.take_shared<Pools>();

            config::add_fee_tier(&mut global_config, 2, 1000, scenario.ctx());

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker_v2,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
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

            let locked_position_v2 = liquidity_lock_v2::lock_position_migrate<TestCoinB, TestCoinA>(
                &global_config,
                &distribution_config,
                &mut locker_v1,
                &mut locker_v2,
                &mut gauge,
                &mut pool_2,
                locked_position_v1,
                &clock,
                scenario.ctx()
            );
            
            transfer::public_transfer(locked_position_v2, admin);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(pool_2, admin);
            transfer::public_transfer(admin_cap, admin);
            transfer::public_transfer(tranche_admin_cap, admin);
            transfer::public_transfer(locker_create_cap, admin);
            transfer::public_transfer(gauge_create_cap, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(pools);
            test_scenario::return_shared(tranche_manager);
            test_scenario::return_shared(global_config);
            test_scenario::return_shared(voter);
            test_scenario::return_shared(locker_v1);
            test_scenario::return_shared(locker_v2);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(reward_distributor);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = liquidity_lock_v1::ELockPeriodEnded)]
    fun test_lock_period_ended_when_lock_position_migrate() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            liquidity_lock_v1::test_init(scenario.ctx());
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

        // Setup
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

        // Create  tranche and add reward for the first epoch
        // Create a new position
        // Create lock V1
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v1::AdminCap>();
            let mut locker = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut tranche_manager = scenario.take_shared<pool_tranche::PoolTrancheManager>();
            let tranche_admin_cap = scenario.take_from_sender<pool_tranche::AdminCap>();
            let global_config = scenario.take_shared<config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let voter = scenario.take_shared<voter::Voter>();
            let governor_cap = scenario.take_from_sender<distribution::voter_cap::GovernorCap>();
            let ve = scenario.take_shared<voting_escrow::VotingEscrow<SailCoinType>>();
            let minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            let reward_distributor = scenario.take_shared<reward_distributor::RewardDistributor<SailCoinType>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v1::init_locker(
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
                1000, // 10%
                10000000, // reward_value
                10000000000000, // total_income,
                clock.timestamp_ms()/1000
            );

            let position = create_position_with_liquidity<TestCoinB, TestCoinA>(
                &mut scenario,
                &global_config,
                &mut vault,
                &mut pool,
                100,
                500,
                4<<64,
                &clock
            );

            let mut locked_positions = liquidity_lock_v1::lock_position<TestCoinB, TestCoinA>(
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

        // init  liquidity_lock_v2
        scenario.next_tx(admin);
        {
            liquidity_lock_v2::test_init(scenario.ctx());
        };

        // migrate lock position from v1 to v2
        scenario.next_tx(admin);
        {
            let locker_create_cap = scenario.take_from_sender<locker_cap::CreateCap>();
            let gauge_create_cap = scenario.take_from_sender<gauge_cap::gauge_cap::CreateCap>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let admin_cap = scenario.take_from_sender<liquidity_lock_v2::AdminCap>();
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
            let vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let mut locker_v1 = scenario.take_shared<liquidity_lock_v1::Locker>();
            let mut locker_v2 = scenario.take_shared<liquidity_lock_v2::Locker>();
            let locked_position_v1 = scenario.take_from_sender<liquidity_lock_v1::LockedPosition<TestCoinB, TestCoinA>>();

            let mut periods_blocking = std::vector::empty();
            std::vector::push_back(&mut periods_blocking, 3);
            std::vector::push_back(&mut periods_blocking, 5);
            std::vector::push_back(&mut periods_blocking, 6);
            let mut periods_post_lockdown = std::vector::empty();
            std::vector::push_back(&mut periods_post_lockdown, 1);
            std::vector::push_back(&mut periods_post_lockdown, 2);
            std::vector::push_back(&mut periods_post_lockdown, 3);
            liquidity_lock_v2::init_locker(
                &admin_cap,
                &locker_create_cap,
                &mut locker_v2,
                periods_blocking,
                periods_post_lockdown,
                scenario.ctx()
            );

            clock::increment_for_testing(&mut clock, common::epoch_to_seconds(4)*1000);

            let locked_position_v2 = liquidity_lock_v2::lock_position_migrate<TestCoinB, TestCoinA>(
                &global_config,
                &distribution_config,
                &mut locker_v1,
                &mut locker_v2,
                &mut gauge,
                &mut pool,
                locked_position_v1,
                &clock,
                scenario.ctx()
            );
            
            transfer::public_transfer(locked_position_v2, admin);
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
            test_scenario::return_shared(locker_v1);
            test_scenario::return_shared(locker_v2);
            test_scenario::return_shared(ve);
            scenario.return_to_sender(governor_cap);
            test_scenario::return_shared(minter);
            scenario.return_to_sender(minter_admin_cap);
            test_scenario::return_shared(distribution_config);
            test_scenario::return_shared(reward_distributor);
        };
        
        clock::destroy_for_testing(clock);
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

            pool_tranche::set_total_incomed_and_add_reward<RewardCoinType>(
                tranche_admin_cap,
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
            let initial_o_sail1_supply = update_minter_period_and_distribute_gauge<SailCoinType, OSAIL1, OSAIL1>(
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
    public fun update_minter_period_and_distribute_gauge<SailCoinType, PrevOSailCoinType, OSailCoinType>(
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

            minter.distribute_gauge<TestCoinB, TestCoinA, SailCoinType, PrevOSailCoinType, OSailCoinType>(
                &mut voter,
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
}
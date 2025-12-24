#[test_only]
module vault::vault_tests;
   use sui::test_scenario;
    use sui::test_utils;
    use sui::package::{Self, UpgradeCap};
    use clmm_pool::position;
    use clmm_pool::pool::{Self as pool, Pool};
    use clmm_pool::factory::{Self as factory, Pools};
    use clmm_pool::config::{Self as config, GlobalConfig};
    use clmm_pool::stats;
    use clmm_pool::rewarder;
    use price_provider::price_provider;
    use governance::distribution_config;
    use governance::voter;
    use voting_escrow::voting_escrow;
    use governance::minter;
    use governance::gauge;
    use voting_escrow::common;
    use governance::rebase_distributor;
    use sui::clock;
    use switchboard::aggregator::{Self, Aggregator};
    use switchboard::decimal;
    use sui::coin::{Self, Coin, CoinMetadata};
    use price_monitor::price_monitor::{Self, PriceMonitor};
    use std::type_name::{Self, TypeName};
    use vault::port;
    use vault::vault_config;
    use vault::port_oracle;

    use vault::usdt_tests::{Self, USDT_TESTS};

    use pyth::setup::{Self, DeployerCap};
    use pyth::state;
    use wormhole::external_address;
    use wormhole::vaa::{Self, VAA};
    use wormhole::state::{State as WormState};
    use sui::balance;

    // use sui::coin::{Self, CoinMetadata, TreasuryCap};
    const ONE_DEC18: u128 = 1000000000000000000;

    const TEST_ACCUMULATOR_SINGLE_FEED: vector<u8> = x"504e41550100000000a0010000000001005d461ac1dfffa8451edda17e4b28a46c8ae912422b2dc0cb7732828c497778ea27147fb95b4d250651931845e7f3e22c46326716bcf82be2874a9c9ab94b6e42000000000000000000000171f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b0000000000000000004155575600000000000000000000000000da936d73429246d131873a0bab90ad7b416510be01005500b10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf65f958f4883f9d2a8b5b1008d1fa01db95cf4a8c7000000006491cc757be59f3f377c0d3f423a695e81ad1eb504f8554c3620c3fd02f2ee15ea639b73fa3db9b34a245bdfa015c260c5a8a1180177cf30b2c0bebbb1adfe8f7985d051d2";

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
    public struct RewardCoinType5 has drop {}
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
    fun test_create_port() {
        let admin = @0x1234;
        let stale_price_threshold = 1000;
        let governance_emitter_chain_id= 1111;
        let governance_emitter_address = admin.to_bytes();
        let mut data_sources = vector::empty();
        // data_sources.push_back(pyth::data_source::new_data_source_for_test(
        //     governance_emitter_chain_id,
        //     external_address::from_address(admin)
        // ));
        let initial_guardians =
            vector[
                x"1337133713371337133713371337133713371337",
                x"c0dec0dec0dec0dec0dec0dec0dec0dec0dec0de",
                x"ba5edba5edba5edba5edba5edba5edba5edba5ed"
            ];
        let base_update_fee = 1000;
        let to_mint = 1000;
        let (mut scenario, mut pyth_coin, mut clock) = pyth::pyth_tests::setup_test(
            stale_price_threshold,
            governance_emitter_chain_id,
            governance_emitter_address,
            data_sources,
            initial_guardians,
            base_update_fee,
            to_mint
        );
        port_oracle::test_init(scenario.ctx());

        /*
        scenario.next_tx(admin);
        {
            let (mut pyth_state, worm_state) = take_wormhole_and_pyth_states(&scenario);
            let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
            // Create Pyth price feed
            pyth::pyth::create_price_feeds(
                &mut pyth_state,
                verified_vaas,
                &clock,
                scenario.ctx()
            );
            test_scenario::return_shared(pyth_state);
            test_scenario::return_shared(worm_state);
        };
        */


        // let mut scenario = test_scenario::begin(admin);
        // let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            // pyth::setup::init_test_only(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };
        /*
            let mut custom_price_feed = CustomPriceFeed {
                price_feed: option::none(),
                price_feed_id: option::none(),
            };

            // Initialize Pyth State
            scenario.next_tx(admin);
            {
                let mut pyth_state = pyth::state::new_state_for_test(
                    sui::package::test_publish(object::id_from_address(@pyth), scenario.ctx()),
                    pyth::data_source::new_data_source_for_test(
                        1111,
                        external_address::from_address(admin)
                    ),
                    10000,
                    0,
                    scenario.ctx()
                );

                let price_identifier_id = sui::object::new(scenario.ctx());
                let price_identifier = pyth::price_identifier::from_byte_vec(price_identifier_id.to_inner().to_bytes());

                pyth_state.register_price_info_object_for_test(
                    price_identifier,
                    price_identifier_id.to_inner()
                );

                let price = pyth::price::new(
                    pyth::i64::new(100, false), 
                    18, 
                    pyth::i64::new(1, false), 
                    clock.timestamp_ms()
                );

                let ema_price = pyth::price::new(
                    pyth::i64::new(100, false), 
                    18, 
                    pyth::i64::new(1, false), 
                    clock.timestamp_ms()
                );

                let price_feed = pyth::price_feed::new(
                    price_identifier,
                    price,
                    ema_price
                );

                custom_price_feed.price_feed = option::some(price_feed);
                custom_price_feed.price_feed_id = option::some(price_identifier_id.to_inner().to_bytes());

                transfer::public_share_object(pyth_state);
                sui::object::delete(price_identifier_id);
            };
        */
        scenario.next_tx(admin);
        {
            let mut port_oracle = scenario.take_shared<port_oracle::PortOracle>();
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            // let mut pyth_state = scenario.take_shared<pyth::state::State>();
            let (mut pyth_state, worm_state) = take_wormhole_and_pyth_states(&scenario);
            // let mut pyth_price_info_obj = scenario.take_shared<pyth::price_info::PriceInfoObject>();

            // Create price identifier to get price_feed_id
            let price_identifier_id = sui::object::new(scenario.ctx());
            let price_feed_id = price_identifier_id.to_inner().to_bytes();
            let price_identifier = pyth::price_identifier::from_byte_vec(price_feed_id);

            // port_oracle.add_oracle_info<USDT_TESTS>(
            //     &vault_global_config,
            //     &pyth_state,
            //     &usd_metadata,
            //     price_feed_id,
            //     1000,
            //     scenario.ctx()
            // );

            // let mut verified_vaas = get_verified_test_vaas(
            //     &worm_state, 
            //     &clock
            // );
            // let vaa_1 = vector::pop_back<VAA>(&mut verified_vaas);

            // let auth_price_infos = pyth::pyth::create_authenticated_price_infos_using_accumulator(
            //     &pyth_state,
            //     TEST_ACCUMULATOR_SINGLE_FEED,
            //     vaa_1,
            //     &clock
            // );

            // let hp = port_oracle.update_price<USDT_TESTS>(
            //     &vault_global_config,
            //     &pyth_state,
            //     auth_price_infos,
            //     &mut pyth_price_info_obj,
            //     &clock,
            //     scenario.ctx()
            // );

            // pyth::hot_potato_vector::destroy<pyth::price_info::PriceInfo>(hp);

            // vector::destroy_empty(verified_vaas);
            sui::object::delete(price_identifier_id);
            test_scenario::return_shared(port_oracle);
            // test_scenario::return_shared(pyth_price_info_obj);
            test_scenario::return_shared(pyth_state);
            test_scenario::return_shared(worm_state);
            test_scenario::return_shared(vault_global_config);
        };

        // scenario.next_tx(admin);
        // {
        //     create_pool_and_gauge<TestCoinB, TestCoinA, SailCoinType>(
        //         &mut scenario,
        //         admin,
        //         1 << 64,
        //         1000000000,
        //         &clock
        //     );
        // };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        scenario.next_tx(admin);
        {
            let mut coin_a = coin::mint_for_testing<TestCoinB>(100, scenario.ctx());
            let mut coin_b = coin::mint_for_testing<TestCoinA>(1000, scenario.ctx());

            (coin_a, coin_b) = swap<TestCoinB, TestCoinA>(
                &mut scenario,
                coin_a,
                coin_b,
                false,
                true,
                900,
                1,
                2 << 64,
                &clock
            );

            transfer::public_transfer(coin_a, admin);
            transfer::public_transfer(coin_b, admin);
        };

        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
             let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            // let port_oracle = scenario.take_shared<port_oracle::PortOracle>();

            // vault_global_config.add_role(&admin_cap, admin, vault_config::get_role_rebalance());

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port.rebalance<TestCoinB, TestCoinA>(
                &distribution_config,
                &mut gauge,
                &vault_global_config,
                &mut clmm_vault,
                &clmm_global_config,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let (tick_lower, tick_upper) = port.get_position_tick_range<TestCoinB, TestCoinA>(
                &gauge
            );
            assert!(tick_lower.eq(integer_mate::i32::from_u32(57)), 44444);
            assert!(tick_upper.eq(integer_mate::i32::from_u32(257)), 55555);

            port.update_liquidity_offset<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                10,
                10,
                &clock,
                scenario.ctx()
            );

            let (tick_lower, tick_upper) = port.get_position_tick_range(
                &gauge
            );
            assert!(tick_lower.eq(integer_mate::i32::from_u32(147)), 44445);
            assert!(tick_upper.eq(integer_mate::i32::from_u32(167)), 55556);

            let rebalance_threshold = port.rebalance_threshold();
            assert!(rebalance_threshold == 5, 66666);

            port.update_rebalance_threshold(
                &vault_global_config,
                1,
                scenario.ctx()
            );
            let rebalance_threshold = port.rebalance_threshold();
            assert!(rebalance_threshold == 1, 66667);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
            // test_scenario::return_shared(port_oracle);
        };

        // skip some time in order to claim rewards
        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();

            assert!((total_volume)/volume == 6, 77777); // total_tvl/tvl = 6      600_000/100_000 = 6

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000); // 2 days
        // Initialize second rewarder
        // the reward token will match the pool token
        scenario.next_tx(admin);
        {
            let emissions_per_second = 2<<64;
            let reward_amount = 10_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, TestCoinB>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        // increase liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_00, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_00, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            // port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
            //     &vault_global_config,
            //     &mut minter,
            //     &distribution_config,
            //     &mut gauge,
            //     &mut pool,
            //     &clock,
            //     scenario.ctx()
            // );

            // rewards are updated when claiming
            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward_2 = port::claim_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool_reward, admin);
            transfer::public_transfer(pool_reward_2, admin);

            port.update_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                600_000,
                &clock,
                scenario.ctx()
            );

            port.test_increase_liquidity<TestCoinB, TestCoinA>(
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut port_entry,
                tvl,
                coin_a,
                coin_b,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();
            assert!((total_volume*10/volume) == 35, 77778); // total_tvl/(tvl1+tvl2) = 3,5  700_000/(100_000+100_000) = 3,5

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // claim rewards
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );
            port.update_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );
            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward_2 = port::claim_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);
            transfer::public_transfer(pool_reward, admin);
            transfer::public_transfer(pool_reward_2, admin);

            let volume = port_entry.get_volume();

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume/2,
                &clock,
                scenario.ctx()
            );

            let res_a = (500_000+5_000_000)*40/140/2; // total_reward_b * lp_balance / total_lp_supply / 2
            let res_b = (200_000+2_000_000+172799)*40/140/2; // total_reward_a * lp_balance / total_lp_supply / 2

            // The proportions of the initial tokens in the position have changed slightly, allowing for a 3% margin of error
            assert!(withdrawn_coin_type_a.value() > res_a*97/100 && withdrawn_coin_type_a.value() < res_a*103/100 , 998);
            assert!(withdrawn_coin_type_b.value() > res_b*97/100 && withdrawn_coin_type_b.value() < res_b*103/100, 999);

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry.get_volume();
            assert!(volume == 20, 777458);
            let total_volume = port.total_volume();
            assert!(total_volume == 120, 777459);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

        // update osail rewards so that in the next epoch osail1 reward can be claimed
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        // next week, next osail
        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day

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
            distribute_gauge<SailCoinType, OSAIL2>(&mut scenario, &usd_metadata, &mut aggregator, &clock);
        };

        clock::increment_for_testing(&mut clock, 86_400*2*1000); // 2 day

        // claim new osail reward
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL2>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let osail_type = port.get_osail_type_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );
            assert!(osail_type == std::type_name::with_defining_ids<OSAIL1>(), 1234);

            let (osail1_reward_amount, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let (osail2_reward_amount, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL2, OSAIL2>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail1_reward_amount == 238095631771, 1235);
            assert!(osail2_reward_amount == 714284139579, 1236);

            let osail1_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail1_reward.value() == osail1_reward_amount, 12362);

            transfer::public_transfer(osail1_reward, admin);

            let (osail1_reward_amount_zero, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail1_reward_amount_zero == 0, 12363);

            let (osail2_reward_amount, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL2, OSAIL2>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail2_reward_amount == 714284139579, 4363443);

            let osail2_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL2, OSAIL2>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail2_reward.value() == osail2_reward_amount, 12361);

            transfer::public_transfer(osail2_reward, admin);

            let (osail2_reward_amount_zero, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL2, OSAIL2>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail2_reward_amount_zero == 0, 12362);

            port.update_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward_2 = port::claim_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool_reward, admin);
            transfer::public_transfer(pool_reward_2, admin);

            let volume = port_entry.get_volume();

            // withdraw all of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            let res_a = (((500_000+5_000_000))-((500_000+5_000_000)*40/140/2))*20/120;
            let res_b = ((200_000+2_000_000)-((200_000+2_000_000+172799)*40/140/2) + 691199)*20/120; // 691199 - new pool reward type B

            // The proportions of the initial tokens in the position have changed slightly, allowing for a 3% margin of error
            assert!(withdrawn_coin_type_a.value() > res_a*97/100 && withdrawn_coin_type_a.value() < res_a*103/100 , 9981);
            assert!(withdrawn_coin_type_b.value() > res_b*97/100 && withdrawn_coin_type_b.value() < res_b*103/100, 9992);

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry.get_volume();
            assert!(volume == 0, 99939);

            port.destory_port_entry(&vault_global_config, port_entry);

            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        sui::coin::burn_for_testing(pyth_coin);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_claim_rewards_when_port_is_stopped() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // swap
        scenario.next_tx(admin);
        {
            let mut coin_a = coin::mint_for_testing<TestCoinB>(100, scenario.ctx());
            let mut coin_b = coin::mint_for_testing<TestCoinA>(1000, scenario.ctx());

            (coin_a, coin_b) = swap<TestCoinB, TestCoinA>(
                &mut scenario,
                coin_a,
                coin_b,
                false,
                true,
                900,
                1,
                2 << 64,
                &clock
            );

            transfer::public_transfer(coin_a, admin);
            transfer::public_transfer(coin_b, admin);
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();

            assert!((total_volume)/volume == 6, 77777); // total_tvl/tvl = 6      600_000/100_000 = 6

            transfer::public_transfer(port_entry, admin);
             test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // stop vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.stop_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(port.is_stopped(), 100000);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // claim rewards and update liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_00, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_00, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            let osail_types = port.get_osail_types_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );
            assert!(osail_types.length() == 1, 36446);
            assert!(osail_types[0] == std::type_name::with_defining_ids<OSAIL1>(), 5485686);

            let last_osail_type = port.get_osail_type_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );
            assert!(last_osail_type == std::type_name::with_defining_ids<OSAIL1>(), 235425);

            let (osail1_reward_amount, _) = port.get_osail_amount_to_claim<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &port_entry,
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail1_reward_amount == 238095631771, 232324433);

            // rewards are updated when claiming
            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail_reward.value() == 238095631771, 976856);

            transfer::public_transfer(osail_reward, admin);

            let (pool_reward_amount, _) = port::get_pool_reward_amount_to_claim<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );
            assert!(pool_reward_amount == 14399, 7457445);

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );
            
            assert!(pool_reward.value() == 14399, 4574657);

            transfer::public_transfer(pool_reward, admin);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                600_000,
                &clock,
                scenario.ctx()
            );

            port.test_increase_liquidity<TestCoinB, TestCoinA>(
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut port_entry,
                tvl,
                coin_a,
                coin_b,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();
            assert!((total_volume*10/volume) == 35, 77778); // total_tvl/(tvl1+tvl2) = 3,5  700_000/(100_000+100_000) = 3,5

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );
            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let volume = port_entry.get_volume();

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume/2,
                &clock,
                scenario.ctx()
            );

            // The proportions of the initial tokens in the position have changed slightly, allowing for a 3% margin of error
            assert!(withdrawn_coin_type_a.value() == 2214414 , 998);
            assert!(withdrawn_coin_type_b.value() == 1709866, 999);

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry.get_volume();
            assert!(volume == 20, 777458);
            let total_volume = port.total_volume();
            assert!(total_volume == 120, 777459);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // full withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);
            transfer::public_transfer(pool_reward, admin);

            let volume = port_entry.get_volume();

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            // The proportions of the initial tokens in the position have changed slightly, allowing for a 3% margin of error
            assert!(withdrawn_coin_type_a.value() == 2214414 , 998);
            assert!(withdrawn_coin_type_b.value() == 1709867, 999);

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry.get_volume();
            assert!(volume == 0, 99939);

            port.destory_port_entry(&vault_global_config, port_entry);

            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // new deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();

            assert!((total_volume)/volume == 6, 77777); // total_tvl/tvl = 6      600_000/100_000 = 6

            transfer::public_transfer(port_entry, admin);
             test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        // flash loan
        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.remove_manager(&vault_global_config, admin, scenario.ctx());
            vault_global_config.add_role(&admin_cap, admin, vault_config::get_role_rebalance());

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            // // check how many unused assets are left in the buffer
            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();

            let price_coin_in = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_coin_out = vault::port_oracle::new_price(1000000000000000000, 18);
            let loan_amount = buffer_balance_a*47/100;

            let (coin_a_out, flash_loan_cert) = port.test_flash_loan<TestCoinB, TestCoinA>(
                &vault_global_config,
                price_coin_in,
                price_coin_out,
                loan_amount,
                scenario.ctx()
            );

            transfer::public_transfer(coin_a_out, admin);

            let repay_coin = sui::coin::mint_for_testing<TestCoinA>(flash_loan_cert.get_repay_amount(), scenario.ctx());

            port.repay_flash_loan<TestCoinA>(
                &vault_global_config,
                flash_loan_cert,
                repay_coin,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // start vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            port.start_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(!port.is_stopped(), 576856);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_reward_manager() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // swap
        scenario.next_tx(admin);
        {
            let mut coin_a = coin::mint_for_testing<TestCoinB>(100, scenario.ctx());
            let mut coin_b = coin::mint_for_testing<TestCoinA>(1000, scenario.ctx());

            (coin_a, coin_b) = swap<TestCoinB, TestCoinA>(
                &mut scenario,
                coin_a,
                coin_b,
                false,
                true,
                900,
                1,
                2 << 64,
                &clock
            );

            transfer::public_transfer(coin_a, admin);
            transfer::public_transfer(coin_b, admin);
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();

            assert!((total_volume)/volume == 6, 77777); // total_tvl/tvl = 6      600_000/100_000 = 6

            transfer::public_transfer(port_entry, admin);
             test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/4); // 1 day

        // add rewarder (deposit_reward and update_emission)
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            let reward_coin = sui::coin::mint_for_testing<RewardCoinType4>(1_000_000_000, scenario.ctx());

            port::rewarder_deposit_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                reward_coin.into_balance(),
                scenario.ctx()
            );

            port::rewarder_update_emission<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                100<<64, // 100 in sec
                &clock,
                scenario.ctx()
            );

            test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/4); // 0.5 day

        // claim rewards and update liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_00, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_00, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            // rewards are updated when claiming
            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(osail_reward.value() == 238095631771, 976856);

            transfer::public_transfer(osail_reward, admin);

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );
            
            assert!(pool_reward.value() == 14399, 4574657);

            transfer::public_transfer(pool_reward, admin);

            let (incentive_reward_amount, _) = port::get_incentive_reward_amount_to_claim<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &clock
            );

            assert!(incentive_reward_amount == 719999, 685644);

            let incentive_reward = port::claim_incentive_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward.value() == incentive_reward_amount, 6868774);

            transfer::public_transfer(incentive_reward, admin);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                600_000,
                &clock,
                scenario.ctx()
            );

            port.test_increase_liquidity<TestCoinB, TestCoinA>(
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut port_entry,
                tvl,
                coin_a,
                coin_b,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();
            assert!((total_volume*10/volume) == 35, 77778); // total_tvl/(tvl1+tvl2) = 3,5  700_000/(100_000+100_000) = 3,5

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400*1000); // 1 day
        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);
            transfer::public_transfer(pool_reward, admin);

            let incentive_reward = port::claim_incentive_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward.value() == 2468571, 54756454);

            transfer::public_transfer(incentive_reward, admin);

            let volume = port_entry.get_volume();

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume/2,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/4*1000); // 1/4 day

        // stop vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.stop_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(port.is_stopped(), 100000);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        // add new rewarder coin
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            let reward_coin = sui::coin::mint_for_testing<RewardCoinType5>(200_000_000, scenario.ctx());

            port::rewarder_deposit_reward<RewardCoinType5>(
                &vault_global_config,
                &mut port,
                reward_coin.into_balance(),
                scenario.ctx()
            );

            port::rewarder_update_emission<RewardCoinType5>(
                &vault_global_config,
                &mut port,
                500<<64, // 500 in sec
                &clock,
                scenario.ctx()
            );

            test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/4*1000); // 1 day
        // new deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            let total_volume = port.total_volume();
            let volume = port_entry.get_volume();

            assert!((total_volume)/volume == 6, 77777); // total_tvl/tvl = 6      600_000/100_000 = 6

            transfer::public_transfer(port_entry, admin);
             test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/4*1000); // 1 day
        // full withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry1 = scenario.take_from_sender<port::PortEntry>();
            let mut port_entry2 = scenario.take_from_sender<port::PortEntry>();

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);
            transfer::public_transfer(pool_reward, admin);

            let incentive_reward = port::claim_incentive_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward.value() == 720000+300000-1, 54756454);

            transfer::public_transfer(incentive_reward, admin);

            let incentive_reward_5 = port::claim_incentive_reward<RewardCoinType5>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward_5.value() == 1800000+1500000-1, 58537456);

            transfer::public_transfer(incentive_reward_5, admin);

            let volume = port_entry2.get_volume();
            assert!(volume == 20, 3463453);

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry2,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry2.get_volume();
            assert!(volume == 0, 99939);

            port.destory_port_entry(&vault_global_config, port_entry2);

            transfer::public_transfer(port_entry1, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/4*1000); // 1 day
        // start vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            port.start_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(!port.is_stopped(), 576856);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        // stop emission
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port::rewarder_update_emission<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                0,
                &clock,
                scenario.ctx()
            );

            test_scenario::return_shared(minter);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/8*1000); // 1 day
        // claim 4 reward type
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry1 = scenario.take_from_sender<port::PortEntry>();

            let incentive_reward = port::claim_incentive_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry1,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward.value() == 778064, 54756454);

            transfer::public_transfer(incentive_reward, admin);

            transfer::public_transfer(port_entry1, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 86_400/8*1000); // 1 day
        // full withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry2 = scenario.take_from_sender<port::PortEntry>();

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);
            transfer::public_transfer(pool_reward, admin);

            let incentive_reward = port::claim_incentive_reward<RewardCoinType4>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward.value() == 0, 54756454);

            transfer::public_transfer(incentive_reward, admin);

            let incentive_reward_5 = port::claim_incentive_reward<RewardCoinType5>(
                &vault_global_config,
                &mut port,
                &mut port_entry2,
                &clock,
                scenario.ctx()
            );

            assert!(incentive_reward_5.value() == 5980645, 58537456);

            transfer::public_transfer(incentive_reward_5, admin);

            let volume = port_entry2.get_volume();
            assert!(volume == 24, 3463453);

            // withdraw half of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry2,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            let volume = port_entry2.get_volume();
            assert!(volume == 0, 99939);

            port.destory_port_entry(&vault_global_config, port_entry2);

            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_flash_loan() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // swap
        scenario.next_tx(admin);
        {
            let mut coin_a = coin::mint_for_testing<TestCoinB>(100, scenario.ctx());
            let mut coin_b = coin::mint_for_testing<TestCoinA>(1000, scenario.ctx());

            (coin_a, coin_b) = swap<TestCoinB, TestCoinA>(
                &mut scenario,
                coin_a,
                coin_b,
                false,
                true,
                900,
                1,
                2 << 64,
                &clock
            );

            transfer::public_transfer(coin_a, admin);
            transfer::public_transfer(coin_b, admin);
        };

        // rebalance and update rewards
        // and flash loan
        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.remove_manager(&vault_global_config, admin, scenario.ctx());
            vault_global_config.add_role(&admin_cap, admin, vault_config::get_role_rebalance());

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            // with rebalance
            port.update_liquidity_offset<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                10,
                10,
                &clock,
                scenario.ctx()
            );

            let (tick_lower, tick_upper) = port.get_position_tick_range(
                &gauge
            );

            assert!(tick_lower.eq(integer_mate::i32::from_u32(138)), 44445);
            assert!(tick_upper.eq(integer_mate::i32::from_u32(158)), 55556);

            let rebalance_threshold = port.rebalance_threshold();
            assert!(rebalance_threshold == 5, 66666);

            port.update_rebalance_threshold(
                &vault_global_config,
                1,
                scenario.ctx()
            );
            let rebalance_threshold = port.rebalance_threshold();
            assert!(rebalance_threshold == 1, 66667);

            // check how many unused assets are left in the buffer
            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();
            let buffer_balance_b = port.get_buffer_asset_value<TestCoinA>();

            assert!(buffer_balance_a == 730792, 77777);
            assert!(buffer_balance_b == 0, 88888);

            assert!(pool.current_tick_index().abs_u32() == 148, 99999);

            let (liqudity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower, 
                tick_upper,
                pool.current_tick_index(), 
                pool.current_sqrt_price(), 
                buffer_balance_a*47/100,
                true
            );

            let sw_res = clmm_pool::pool::calculate_swap_result<TestCoinB, TestCoinA>(
                &clmm_global_config,
                &pool,
                true,
                true,
                buffer_balance_a*53/100
            );

            let free_balance_b_after_swap = sw_res.calculated_swap_result_amount_out();

            assert!(free_balance_b_after_swap > buffer_balance_b, 100000);

            let price_coin_in = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_coin_out = vault::port_oracle::new_price(1000000000000000000, 18);
            let loan_amount = buffer_balance_a*47/100;

            let (coin_a_out, flash_loan_cert) = port.test_flash_loan<TestCoinB, TestCoinA>(
                &vault_global_config,
                price_coin_in,
                price_coin_out,
                loan_amount,
                scenario.ctx()
            );

            transfer::public_transfer(coin_a_out, admin);

            let repay_coin = sui::coin::mint_for_testing<TestCoinA>(flash_loan_cert.get_repay_amount(), scenario.ctx());

            port.repay_flash_loan<TestCoinA>(
                &vault_global_config,
                flash_loan_cert,
                repay_coin,
                scenario.ctx()
            );

            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();
            let buffer_balance_b = port.get_buffer_asset_value<TestCoinA>();

            assert!(buffer_balance_a == 387320, 77777);
            assert!(buffer_balance_b == 341755, 88888);

            port.test_add_liquidity<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                price_coin_in,
                price_coin_out,
                &clock,
                scenario.ctx()
            );

            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();
            let buffer_balance_b = port.get_buffer_asset_value<TestCoinA>();

            assert!(buffer_balance_a == 78460, 77777);
            assert!(buffer_balance_b == 0, 88888);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // stop vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.stop_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(port.is_stopped(), 100000);

            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();
            let buffer_balance_b = port.get_buffer_asset_value<TestCoinA>();

            assert!(buffer_balance_a == 9425592, 77667);
            assert!(buffer_balance_b == 10342652, 866688);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // start vault
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            port.start_vault<TestCoinB, TestCoinA>(
                &vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            assert!(!port.is_stopped(), 100000);

            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();
            let buffer_balance_b = port.get_buffer_asset_value<TestCoinA>();

            assert!(buffer_balance_a == 78460, 773367);
            assert!(buffer_balance_b == 0, 844488);

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::INCORRECT_REPAY_AMOUNT)] // incorrect_repay_amount
    fun test_flash_loan_incorrect_repay_amount() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, TestCoinB>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000*5/2); // 5 days

        // flash loan
        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_pool_reward<TestCoinB, TestCoinA, TestCoinB>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            vault_global_config.add_role(&admin_cap, admin, vault_config::get_role_rebalance());

            // check how many unused assets are left in the buffer
            let buffer_balance_a = port.get_buffer_asset_value<TestCoinB>();

            let price_coin_in = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_coin_out = vault::port_oracle::new_price(1000000000000000000, 18);
            let loan_amount = buffer_balance_a*30/100;

            let (coin_a_out, flash_loan_cert) = port.test_flash_loan<TestCoinB, TestCoinA>(
                &vault_global_config,
                price_coin_in,
                price_coin_out,
                loan_amount,
                scenario.ctx()
            );

            transfer::public_transfer(coin_a_out, admin);

            let repay_coin = sui::coin::mint_for_testing<TestCoinA>(flash_loan_cert.get_repay_amount()-1, scenario.ctx()); // -1 to test the abort

            port.repay_flash_loan<TestCoinA>(
                &vault_global_config,
                flash_loan_cert,
                repay_coin,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::POOL_NOT_NEED_REBALANCE)] 
    fun test_rebalance_not_need_rebalance() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // rebalance
        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            vault_global_config.add_role(&admin_cap, admin, vault_config::get_role_rebalance());

            port.rebalance<TestCoinB, TestCoinA>(
                &distribution_config,
                &mut gauge,
                &vault_global_config,
                &mut clmm_vault,
                &clmm_global_config,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::NO_OPERATION_MANAGER_PERMISSION)] 
    fun test_rebalance_not_manager() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        // rebalance
        scenario.next_tx(admin);
        {
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let admin_cap = scenario.take_from_sender<vault::vault_config::AdminCap>();
            let mut port = scenario.take_shared<port::Port>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            port.remove_manager(&vault_global_config, admin, scenario.ctx());

            port.rebalance<TestCoinB, TestCoinA>(
                &distribution_config,
                &mut gauge,
                &vault_global_config,
                &mut clmm_vault,
                &clmm_global_config,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            transfer::public_transfer(admin_cap, admin);
            test_scenario::return_shared(distribution_config);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::AUM_DONE_ERR)]
    fun test_increase_liquidity_aum_done_err() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // increase liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_00, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_00, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            // port::test_calculate_aum<TestCoinB, TestCoinA>(
            //     &mut port,
            //     &vault_global_config,
            //     &mut pool,
            //     600_000,
            //     &clock,
            //     scenario.ctx()
            // );

            port.test_increase_liquidity<TestCoinB, TestCoinA>(
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut port_entry,
                tvl,
                coin_a,
                coin_b,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::NOT_UPDATED_REWARD_GROWTH_TIME)]
    fun test_increase_liquidity_not_updated_reward_growth_time() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let pool_reward = port::claim_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool_reward, admin);

            test_scenario::return_shared(port);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            transfer::public_transfer(port_entry, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // increase liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_00, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_00, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                600_000,
                &clock,
                scenario.ctx()
            );

            port.test_increase_liquidity<TestCoinB, TestCoinA>(
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &mut port_entry,
                tvl,
                coin_a,
                coin_b,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::NOT_UPDATED_OSAIL_GROWTH_TIME)]
    fun test_withdraw_liquidity_not_updated_reward_growth_time() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            let volume = port_entry.get_volume();

            // withdraw all of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::NOT_UPDATED_REWARD_GROWTH_TIME)]
    fun test_withdraw_liquidity_not_updated_osail_growth_time() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            let volume = port_entry.get_volume();

            // withdraw all of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::OSAIL_REWARD_NOT_CLAIMED)]
    fun test_withdraw_liquidity_osail_reward_not_claimed() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let volume = port_entry.get_volume();

            // withdraw all of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = vault::error::REWARD_GROWTH_NOT_MATCH)]
    fun test_withdraw_liquidity_reward_growth_not_match() {
        let admin = @0x1234;
        let mut scenario = test_scenario::begin(admin);
        let mut clock = clock::create_for_testing(scenario.ctx());
        
        // Initialize
        {
            port::test_init(scenario.ctx());
            vault_config::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            distribution_config::test_init(scenario.ctx());
            factory::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };

        let (usd_treasury_cap, usd_metadata) = usdt_tests::create_usdt_tests(&mut scenario, 6);
        let mut aggregator = setup_price_monitor_and_aggregator<TestCoinA, SailCoinType, USDT_TESTS, SailCoinType>(
            &mut scenario, 
            admin, 
            &clock
        );

        scenario.next_tx(admin);
        {
            full_setup_with_osail(
                &mut scenario, 
                admin, 
                1000, 
                182, 
                18584142135623730951, 
                10_000_000_000_000,
                &usd_metadata,
                &mut aggregator,
                &mut clock
            );
        };

        // create_port
        scenario.next_tx(admin);
        {
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let mut port_registry = scenario.take_shared<port::PortRegistry>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(10_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(10_000_000, scenario.ctx());

            port::test_create_port_internal<TestCoinB, TestCoinA>(
                &vault_global_config,
                &mut port_registry,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                100,
                100,
                5,
                true,
                1000000000,
                100,
                coin_a.into_balance(),
                coin_b.into_balance(),
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
            test_scenario::return_shared(port_registry);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // Initialize rewarder
        scenario.next_tx(admin);
        {
            let emissions_per_second = 1<<64;
            let reward_amount = 5_000_000_000;
            initialize_rewarder<TestCoinB, TestCoinA, RewardCoinType1>(
                &mut scenario,
                reward_amount,
                emissions_per_second,
                &clock,
            );
        };

        // deposit
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let mut vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let coin_a = sui::coin::mint_for_testing<TestCoinB>(2_000_000, scenario.ctx());
            let coin_b = sui::coin::mint_for_testing<TestCoinA>(5_000_000, scenario.ctx());
            let tvl = 100_000;
            let price_a = vault::port_oracle::new_price(1000000000000000000, 18);
            let price_b = vault::port_oracle::new_price(1000000000000000000, 18);

            port::test_calculate_aum<TestCoinB, TestCoinA>(
                &mut port,
                &vault_global_config,
                &mut gauge,
                &mut pool,
                500_000,
                &clock,
                scenario.ctx()
            );

            let port_entry = port::test_deposit<TestCoinB, TestCoinA>(
                &mut port,
                &mut vault_global_config,
                &clmm_global_config,
                &mut clmm_vault,
                &distribution_config,
                &mut gauge,
                &mut pool,
                coin_a,
                coin_b,
                tvl,
                price_a,
                price_b,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        clock::increment_for_testing(&mut clock, 172_800*1000/2); // 1 day

        // withdraw liquidity
        scenario.next_tx(admin);
        {
            let mut port = scenario.take_shared<port::Port>();
            let vault_global_config = scenario.take_shared<vault::vault_config::GlobalConfig>();
            let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
            let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
            let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
            let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
            let mut port_entry = scenario.take_from_sender<port::PortEntry>();

            port.update_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1>(
                &vault_global_config,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            port.update_pool_reward<TestCoinB, TestCoinA, RewardCoinType1>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &clock
            );

            let osail_reward = port::claim_position_reward<TestCoinB, TestCoinA, SailCoinType, OSAIL1, OSAIL1>(
                &vault_global_config,
                &mut port,
                &mut port_entry,
                &mut minter,
                &distribution_config,
                &mut gauge,
                &mut pool,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(osail_reward, admin);

            let volume = port_entry.get_volume();

            // withdraw all of the liquidity
            let (withdrawn_coin_type_b, withdrawn_coin_type_a) = port.withdraw<TestCoinB, TestCoinA>(
                &vault_global_config,
                &distribution_config,
                &mut gauge,
                &clmm_global_config,
                &mut clmm_vault,
                &mut pool,
                &mut port_entry,
                volume,
                &clock,
                scenario.ctx()
            );

            transfer::public_transfer(withdrawn_coin_type_b, admin);
            transfer::public_transfer(withdrawn_coin_type_a, admin);

            transfer::public_transfer(port_entry, admin);
            test_scenario::return_shared(port);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(vault_global_config);
            test_scenario::return_shared(clmm_global_config);
            test_scenario::return_shared(clmm_vault);
            test_scenario::return_shared(distribution_config);
            transfer::public_transfer(pool, admin);
            transfer::public_transfer(gauge, admin);
        };

        transfer::public_transfer(usd_treasury_cap, admin);
        transfer::public_transfer(usd_metadata, admin);
        test_utils::destroy(aggregator);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
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
    ): governance::gauge::StakedPosition {
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

        governance::gauge::deposit_position<TestCoinB, TestCoinA>(
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
        usd_metadata: &CoinMetadata<USDT_TESTS>,
        aggregator: &mut Aggregator,
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
            distribute_gauge<SailCoinType, OSAIL1>(scenario, usd_metadata, aggregator, clock);
        };
    }

    #[test_only]
    public fun setup_distribution<SailCoinType>(
        scenario: &mut test_scenario::Scenario,
        sender: address
    ) { // No return value

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
            
            let (mut voter_obj, distribute_cap) = voter::create(
                &voter_publisher,
                global_config_id,
                distribution_config_id,
                scenario.ctx()
            );

            voter_obj.add_governor(&distribution_config_obj, &voter_publisher, sender, scenario.ctx());

            test_utils::destroy(voter_publisher);
            transfer::public_share_object(voter_obj);

            // --- Set Distribute Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_distribute_cap(&minter_admin_cap, &distribution_config_obj, distribute_cap);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(distribution_config_obj);
            scenario.return_to_sender(minter_admin_cap);
        };

        // --- VotingEscrow Setup --- 
        scenario.next_tx(sender);
        {
            let clock = clock::create_for_testing(scenario.ctx());
            let ve_publisher = voting_escrow::test_init(scenario.ctx());
            let voter_publisher = voter::test_init(scenario.ctx());
            let mut voter_obj = scenario.take_shared<voter::Voter>(); 
            let voter_id = object::id(&voter_obj); 
            let (ve_obj, ve_cap) = voting_escrow::create<SailCoinType>(
                &ve_publisher,
                voter_id, 
                &clock,
                scenario.ctx()
            );

            voter_obj.set_voting_escrow_cap(&voter_publisher, ve_cap);
            test_scenario::return_shared(voter_obj);
            test_utils::destroy(voter_publisher);
            test_utils::destroy(ve_publisher);
            transfer::public_share_object(ve_obj);
            clock::destroy_for_testing(clock);
        };

        // --- RebaseDistributor Setup --- 
        scenario.next_tx(sender);
        {
            let clock = clock::create_for_testing(scenario.ctx());
            let distribution_config_obj = scenario.take_shared<distribution_config::DistributionConfig>();
            let rd_publisher = rebase_distributor::test_init(scenario.ctx());
            let (rebase_distributor_obj, rebase_distributor_cap) = rebase_distributor::create<SailCoinType>(
                &rd_publisher,
                &clock,
                scenario.ctx()
            );
            test_utils::destroy(rd_publisher);
            transfer::public_share_object(rebase_distributor_obj);
            clock::destroy_for_testing(clock);
            // --- Set Reward Distributor Cap ---
            let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>();
            let minter_admin_cap = scenario.take_from_sender<minter::AdminCap>();
            minter.set_rebase_distributor_cap(&minter_admin_cap, &distribution_config_obj, rebase_distributor_cap);
            test_scenario::return_shared(minter);
            test_scenario::return_shared(distribution_config_obj);
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

    // Activates the minter for a specific oSAIL epoch.
    // Requires the minter, voter, rd, and admin cap to be set up.
    #[test_only]
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

        let fee_tiers = global_config.fee_tiers();
        let one_tier: u32 = 1;
        if (!fee_tiers.contains(&one_tier)) {
            config::add_fee_tier(&mut global_config, one_tier, 1000, scenario.ctx());
        };

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
    fun create_pool<TestCoinB, TestCoinA>(
        scenario: &mut test_scenario::Scenario,
        current_sqrt_price: u128,
        clock: &clock::Clock,
    ){
        let mut global_config = scenario.take_shared<config::GlobalConfig>();
        let mut pools = scenario.take_shared<Pools>();

        let fee_tiers = global_config.fee_tiers();
        let one_tier: u32 = 1;
        if (!fee_tiers.contains(&one_tier)) {
            config::add_fee_tier(&mut global_config, one_tier, 1000, scenario.ctx());
        };

        let pool = factory::create_pool_<TestCoinB, TestCoinA>(
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

        test_scenario::return_shared(pools);
        transfer::public_share_object(pool);
        test_scenario::return_shared(global_config);
    }

    #[test_only]
    fun distribute_gauge<SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        usd_metadata: &CoinMetadata<USDT_TESTS>,
        aggregator: &mut Aggregator,
        clock: &clock::Clock,
    ): u64 {
        let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>(); // Minter is now responsible
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut gauge = scenario.take_from_sender<gauge::Gauge<TestCoinB, TestCoinA>>();
        let mut pool = scenario.take_from_sender<pool::Pool<TestCoinB, TestCoinA>>();
        let distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Minter uses DistributeGovernorCap
        let mut price_monitor = scenario.take_shared<PriceMonitor>();

        aggregator_set_current_value(aggregator,  one_dec18(), clock.timestamp_ms());

        // use the same emissions as in previous epoch
        let next_epoch_emissions_usd = minter.gauge_epoch_emissions_usd(object::id(&gauge));

        if (type_name::get<TestCoinA>() != type_name::get<USDT_TESTS>() || 
                type_name::get<TestCoinB>() != type_name::get<SailCoinType>()) {

            let sail_stablecoin_pool = scenario.take_shared<Pool<SailCoinType, USDT_TESTS>>();

            minter.distribute_gauge<TestCoinB, TestCoinA, SailCoinType, USDT_TESTS, SailCoinType, EpochOSail>(
                &mut voter,
                &distribute_governor_cap,
                &distribution_config,
                &mut gauge,
                &mut pool,
                next_epoch_emissions_usd,
                &mut price_monitor,
                &sail_stablecoin_pool,
                aggregator,
                clock,
                scenario.ctx()
            );

            test_scenario::return_shared(sail_stablecoin_pool);
        } else {
            minter.distribute_gauge_for_sail_pool<TestCoinB, TestCoinA, SailCoinType, EpochOSail>(
                &mut voter,
                &distribute_governor_cap,
                &distribution_config,
                &mut gauge,
                &mut pool,
                next_epoch_emissions_usd,
                &mut price_monitor,
                aggregator,
                clock,
                scenario.ctx()
            );
        };

        // Return shared objects
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(gauge);
        scenario.return_to_sender(pool);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(price_monitor);

        next_epoch_emissions_usd
    }

    // Utility to call minter.distribute_gauge
    #[test_only]
    fun distribute_gauge_emissions_controlled<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        scenario: &mut test_scenario::Scenario,
        next_epoch_emissions_usd: u64,
        usd_metadata: &CoinMetadata<USDT_TESTS>,
        aggregator: &mut Aggregator,
        clock: &clock::Clock,
    ): u64 {
        let mut minter = scenario.take_shared<minter::Minter<SailCoinType>>(); // Minter is now responsible
        let mut voter = scenario.take_shared<voter::Voter>();
        let mut gauge = scenario.take_from_sender<gauge::Gauge<CoinTypeA, CoinTypeB>>();
        let mut pool = scenario.take_from_sender<pool::Pool<CoinTypeA, CoinTypeB>>();
        let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
        let distribute_governor_cap = scenario.take_from_sender<minter::DistributeGovernorCap>(); // Minter uses DistributeGovernorCap
        let mut price_monitor = scenario.take_shared<PriceMonitor>();

        aggregator_set_current_value(aggregator,  one_dec18(), clock.timestamp_ms());

        if (type_name::get<CoinTypeA>() != type_name::get<USDT_TESTS>() || 
                type_name::get<CoinTypeB>() != type_name::get<SailCoinType>()) {

            let sail_stablecoin_pool = scenario.take_shared<Pool<USDT_TESTS, SailCoinType>>();

            minter.distribute_gauge<CoinTypeA, CoinTypeB, USDT_TESTS, SailCoinType, SailCoinType, EpochOSail>(
                &mut voter,
                &distribute_governor_cap,
                &distribution_config,
                &mut gauge,
                &mut pool,
                next_epoch_emissions_usd,
                &mut price_monitor,
                &sail_stablecoin_pool,
                aggregator,
                clock,
                scenario.ctx()
            );

            test_scenario::return_shared(sail_stablecoin_pool);
        } else {
            minter.distribute_gauge_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
                &mut voter,
                &distribute_governor_cap,
                &distribution_config,
                &mut gauge,
                &mut pool,
                next_epoch_emissions_usd,
                &mut price_monitor,
                aggregator,
                clock,
                scenario.ctx()
            );
        };

        // Return shared objects
        test_scenario::return_shared(minter);
        test_scenario::return_shared(voter);
        scenario.return_to_sender(gauge);
        scenario.return_to_sender(pool);
        test_scenario::return_shared(distribution_config);
        scenario.return_to_sender(distribute_governor_cap);
        test_scenario::return_shared(price_monitor);

        next_epoch_emissions_usd
    }

    public fun one_dec18(): u128 {
        ONE_DEC18
    }

    // CoinTypeA and CoinTypeB - to check that such a pool has already been created
    // in other cases you can pass any types, so that the USDT_TESTS/SAIL pool is created
    #[test_only]
    public fun setup_price_monitor_and_aggregator<CoinTypeA, CoinTypeB, USDT_TESTS: drop, SAIL: drop>(
        scenario: &mut test_scenario::Scenario,
        sender: address,
        clock: &clock::Clock,
    ): Aggregator {

        // create pool for USDT_TESTS/SAIL
        if (type_name::get<CoinTypeA>() != type_name::get<USDT_TESTS>() || 
            type_name::get<CoinTypeB>() != type_name::get<SAIL>()) {

            // create pool for USDT_TESTS/SAIL
            scenario.next_tx(sender);
            {
                let pool_sqrt_price: u128 = 1 << 64; // Price = 1
                create_pool<SAIL, USDT_TESTS>(
                scenario, 
                    pool_sqrt_price,
                    clock
                );
            };
        };

        // --- Initialize Price Monitor --- and aggregator
        scenario.next_tx(sender);
        {
            price_monitor::test_init(scenario.ctx());
        };

        let aggregator = setup_aggregator(scenario, one_dec18(), clock);

        // --- Price Monitor Setup --- 
        scenario.next_tx(sender);
        {
            let mut price_monitor = scenario.take_shared<price_monitor::PriceMonitor>();
            let mut distribution_config = scenario.take_shared<distribution_config::DistributionConfig>();
            let sail_stablecoin_pool = scenario.take_shared<pool::Pool<SAIL, USDT_TESTS>>();
            
            let pool_id = object::id(&sail_stablecoin_pool);

            price_monitor.add_aggregator(
                aggregator.id(),
                vector[pool_id],
                vector[6],
                vector[6],
                scenario.ctx()
            );

            distribution_config.test_set_o_sail_price_aggregator(&aggregator);
            distribution_config.test_set_sail_price_aggregator(&aggregator);

            test_scenario::return_shared(price_monitor);
            test_scenario::return_shared(distribution_config);
            transfer::public_share_object(sail_stablecoin_pool);
        };

        aggregator
    }

    /// You can create new aggregator just prior to the call that requires it.
    /// Then just destroy it after the call.
    /// Aggregators are not shared objects due to missing store capability.
    #[test_only]
    public fun setup_aggregator(
        scenario: &mut test_scenario::Scenario,
        price: u128, // decimals 18
        clock: &clock::Clock, 
    ): Aggregator {
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

        // Return aggregator to the calling function
        aggregator
    }

    #[test_only]
    public fun aggregator_set_current_value(
        aggregator: &mut Aggregator,
        price: u128, // decimals 18
        result_timestamp_ms: u64,
    ) {

        // 1 * 10^18
        let result = decimal::new(price, false);
        let min_result = result;
        let max_result = result;
        let stdev = decimal::new(0, false);
        let range = decimal::new(0, false);
        let mean = result;

        aggregator.set_current_value(
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

        // Return aggregator to the calling function
        // aggregator
    }

    #[test_only]
    fun get_verified_test_vaas(worm_state: &WormState, clock: &clock::Clock): vector<VAA> {
        let test_vaas_: vector<vector<u8>> = vector[x"0100000000010036eb563b80a24f4253bee6150eb8924e4bdf6e4fa1dfc759a6664d2e865b4b134651a7b021b7f1ce3bd078070b688b6f2e37ce2de0d9b48e6a78684561e49d5201527e4f9b00000001001171f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b0000000000000001005032574800030000000102000400951436e0be37536be96f0896366089506a59763d036728332d3e3038047851aea7c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1000000000000049a0000000000000008fffffffb00000000000005dc0000000000000003000000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000006150000000000000007215258d81468614f6b7e194c5d145609394f67b041e93e6695dcc616faadd0603b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe000000000000041a0000000000000003fffffffb00000000000005cb0000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e4000000000000048600000000000000078ac9cf3ab299af710d735163726fdae0db8465280502eb9f801f74b3c1bd190333832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d00000000000003f20000000000000002fffffffb00000000000005e70000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e40000000000000685000000000000000861db714e9ff987b6fedf00d01f9fea6db7c30632d6fc83b7bc9459d7192bc44a21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db800000000000006cb0000000000000001fffffffb00000000000005e40000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000007970000000000000001"];
        let mut verified_vaas_reversed = vector::empty<VAA>();
        let mut test_vaas = test_vaas_;
        let mut i = 0;
        while (i < vector::length(&test_vaas_)) {
            let cur_test_vaa = vector::pop_back(&mut test_vaas);
            let verified_vaa = vaa::parse_and_verify(worm_state, cur_test_vaa, clock);
            vector::push_back(&mut verified_vaas_reversed, verified_vaa);
            i=i+1;
        };
        let mut verified_vaas = vector::empty<VAA>();
        while (vector::length<VAA>(&verified_vaas_reversed)!=0){
            let cur = vector::pop_back(&mut verified_vaas_reversed);
            vector::push_back(&mut verified_vaas, cur);
        };
        vector::destroy_empty(verified_vaas_reversed);
        verified_vaas
    }

    #[test_only]
    public fun take_wormhole_and_pyth_states(scenario: &test_scenario::Scenario): (pyth::state::State, WormState){
        (scenario.take_shared<pyth::state::State>(), scenario.take_shared<WormState>())
    }

    #[test_only]
    public fun swap<CoinTypeA, CoinTypeB>(
        scenario: &mut test_scenario::Scenario,
        mut coin_a: sui::coin::Coin<CoinTypeA>,
        mut coin_b: sui::coin::Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &sui::clock::Clock,
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let global_config = scenario.take_shared<config::GlobalConfig>();
        let mut vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_from_sender<pool::Pool<CoinTypeA, CoinTypeB>>();
        let price_provider = scenario.take_shared<clmm_pool::price_provider::PriceProvider>();
        let mut stats = scenario.take_shared<clmm_pool::stats::Stats>();

        let (coin_a_out, coin_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
            &global_config,
            &mut vault,
            &mut pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            &mut stats,
            &price_provider,
            clock
        );
        let pay_amout = receipt.swap_pay_amount();
        let coin_out_value = if (a2b) {
            coin_b_out.value()
        } else {
            coin_a_out.value()
        };
        if (by_amount_in) {
            assert!(pay_amout == amount, 1111);
            assert!(coin_out_value >= amount_limit, 2222);
        } else {
            assert!(coin_out_value == amount, 3333);
            assert!(pay_amout <= amount_limit, 4444);
        };
        let (repay_amount_a, repay_amount_b) = if (a2b) {
            (coin_a.split(pay_amout, scenario.ctx()).into_balance(), sui::balance::zero<CoinTypeB>())
        } else {
            (sui::balance::zero<CoinTypeA>(), coin_b.split(pay_amout, scenario.ctx()).into_balance())
        };
        clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            &global_config,
            &mut pool,
            repay_amount_a,
            repay_amount_b,
            receipt
        );
        coin_a.join(sui::coin::from_balance<CoinTypeA>(coin_a_out, scenario.ctx()));
        coin_b.join(sui::coin::from_balance<CoinTypeB>(coin_b_out, scenario.ctx()));

        test_scenario::return_shared(global_config);
        transfer::public_transfer(pool, scenario.ctx().sender());
        test_scenario::return_shared(price_provider);
        test_scenario::return_shared(stats);
        test_scenario::return_shared(vault);
        (coin_a, coin_b)
    }

    #[test_only]
    public fun initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(
        scenario: &mut test_scenario::Scenario,
        amount: u64,
        emissions_per_second: u128,
        clock: &sui::clock::Clock,
    ) {

        let clmm_global_config = scenario.take_shared<config::GlobalConfig>();
        let mut clmm_vault = scenario.take_shared<rewarder::RewarderGlobalVault>();
        let mut pool = scenario.take_from_sender<pool::Pool<CoinTypeA, CoinTypeB>>();

        let reward_coin = sui::coin::mint_for_testing<RewardCoinType>(amount, scenario.ctx());

        clmm_pool::rewarder::deposit_reward<RewardCoinType>(
            &clmm_global_config,
            &mut clmm_vault,
            reward_coin.into_balance(),
        );

        clmm_pool::pool::initialize_rewarder<CoinTypeA, CoinTypeB, RewardCoinType>(
            &clmm_global_config,
            &mut pool,
            scenario.ctx()
        );

        clmm_pool::pool::update_emission<CoinTypeA, CoinTypeB, RewardCoinType>(
            &clmm_global_config,
            &mut pool,
            &mut clmm_vault,
            emissions_per_second,
            clock,
            scenario.ctx()
        );

        test_scenario::return_shared(clmm_global_config);
        test_scenario::return_shared(clmm_vault);
        transfer::public_transfer(pool, scenario.ctx().sender());
        // reward_coin.destroy_zero();
    }
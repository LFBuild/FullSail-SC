#[test_only]
module full_sail::gauge_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::coin::{Self, CoinMetadata};
    use sui::clock;
    use std::debug;
    use sui::balance::{Balance};
    use full_sail::gauge::{Self, Gauge};
    use full_sail::fullsail_token::{FULLSAIL_TOKEN};
    use full_sail::rewards_pool_continuous::{Self, RewardsPool};
    use full_sail::sui::{Self, SUI};
    use full_sail::usdt::{Self, USDT};
    use full_sail::liquidity_pool::{Self, LiquidityPoolConfigs, LiquidityPool, FeesAccounting};

    const OWNER: address = @0xab;

    #[test_only]
    fun setup(scenario: &mut Scenario) {
        // Initialize all modules
        liquidity_pool::init_for_testing(ts::ctx(scenario));
        usdt::init_for_testing_usdt(ts::ctx(scenario));
        sui::init_for_testing_sui(ts::ctx(scenario));
    }

    #[test]
    public fun create_test() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        setup(scenario);

        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            
            liquidity_pool::create<USDT, SUI>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let mut _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
            gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
            let mut _gauge = ts::take_shared<Gauge<USDT, SUI>>(scenario);
            assert!(gauge::claimable_rewards(@0x01, &mut _gauge, &clock) == 0, 1);
            ts::return_shared(_gauge);
            clock.destroy_for_testing();
        };

        ts::end(scenario_val);
    }

    #[test]
    public fun staking_into_gauge_test() : () {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup(scenario);
        
        next_tx(scenario, OWNER);
        {
            let mut configs = ts::take_shared<LiquidityPoolConfigs>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            liquidity_pool::create<SUI, USDT>(
                &base_metadata,
                &quote_metadata,
                &mut configs,
                false,
                ts::ctx(scenario)
            );
            
            ts::return_shared(configs);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };
        
        next_tx(scenario, OWNER);
        {
            let mut fees = ts::take_shared<FeesAccounting>(scenario);
            let mut pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
            let base_metadata = ts::take_immutable<CoinMetadata<SUI>>(scenario);
            let quote_metadata = ts::take_immutable<CoinMetadata<USDT>>(scenario);
            
            let amount = 100000;
            let base_coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            let quote_coin = coin::mint_for_testing<USDT>(amount, ts::ctx(scenario));
            
            let liquidity_out = liquidity_pool::mint_lp(
                &mut pool,
                &mut fees,
                &quote_metadata,
                &base_metadata,
                quote_coin,
                base_coin,    
                false,
                ts::ctx(scenario)
            );
            
            assert!(liquidity_out == 99000, 2);
            
            let (base_reserve, quote_reserve) = liquidity_pool::pool_reserves(&pool);
            assert!(base_reserve == amount, 3);
            assert!(quote_reserve == amount, 4);
            
            ts::return_shared(pool);
            ts::return_shared(fees);
            ts::return_immutable(base_metadata);
            ts::return_immutable(quote_metadata);
        };

        next_tx(scenario, OWNER);
        {
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let mut _liquidity_pool = ts::take_shared<LiquidityPool<USDT, SUI>>(scenario);
            gauge::create_test<USDT, SUI>(_liquidity_pool, ts::ctx(scenario));
            let mut _gauge = ts::take_shared<Gauge<USDT, SUI>>(scenario);
            assert!(gauge::claimable_rewards(@0x01, &mut _gauge, &clock) == 0, 1);
            // debug::print(&_gauge);
            ts::return_shared(_gauge);
            clock.destroy_for_testing();
        };
        ts::end(scenario_val);
    }

    // #[test]
    // public fun unstaking_into_gauge_test(source: &signer) : (coin::MintCapability<MyToken>, coin::MintCapability<MyToken1>) {
    //     setup(source);
    //     let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MyToken>(
    //         source,
    //         string::utf8(b"MyToken"),
    //         string::utf8(b"MTK"),
    //         8,
    //         true
    //     );

    //     move_to<TokenManager>(source, TokenManager {
    //         burn_cap,
    //         freeze_cap,
    //         mint_cap,
    //     });

    //     let (burn_cap1, freeze_cap1, mint_cap1) = coin::initialize<MyToken1>(
    //         source,
    //         string::utf8(b"MyToken1"),
    //         string::utf8(b"MTK1"),
    //         8,
    //         true
    //     );

    //     move_to<TokenManager1>(source, TokenManager1 {
    //         burn_cap1,
    //         freeze_cap1,
    //         mint_cap1,
    //     });
        
    //     let metadata = coin_wrapper::create_fungible_asset_test<MyToken>();
    //     let metadata1 = coin_wrapper::create_fungible_asset_test<MyToken1>();
    //     let _liquidity_pool = liquidity_pool::create_test(metadata, metadata1, false);

    //     let initial_amount = 2000;
    //     let my_token_coin = coin::mint<MyToken>(initial_amount, &mint_cap);
    //     let my_token_coin1 = coin::mint<MyToken1>(initial_amount, &mint_cap1);
    //     let _fungible_asset = coin_wrapper::wrap_test<MyToken>(my_token_coin);
    //     let _fungible_asset1 = coin_wrapper::wrap_test<MyToken1>(my_token_coin1);
    //     let _mint_lp_amount = liquidity_pool::mint_lp_test(source, _fungible_asset, _fungible_asset1, false);

    //     let _gauge = gauge::create_test(_liquidity_pool);
    //     gauge::stake(source, _gauge, 100);
    //     gauge::unstake_lp_test(source, _gauge, 50);
    //     let _stake_balance = gauge::stake_balance(signer::address_of(source), _gauge);
    //     assert!(_stake_balance == 50, 4);
    //     let _total_stake = gauge::total_stake(_gauge);
    //     assert!(_total_stake == 50, 5);
    //     (mint_cap, mint_cap1)
    // }

    // #[test]
    // public fun claiming_rewards_test(source: &signer) : (coin::MintCapability<MyToken>, coin::MintCapability<MyToken1>) {
    //     setup(source);
    //     let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MyToken>(
    //         source,
    //         string::utf8(b"MyToken"),
    //         string::utf8(b"MTK"),
    //         8,
    //         true
    //     );

    //     move_to<TokenManager>(source, TokenManager {
    //         burn_cap,
    //         freeze_cap,
    //         mint_cap,
    //     });

    //     let (burn_cap1, freeze_cap1, mint_cap1) = coin::initialize<MyToken1>(
    //         source,
    //         string::utf8(b"MyToken1"),
    //         string::utf8(b"MTK1"),
    //         8,
    //         true
    //     );

    //     move_to<TokenManager1>(source, TokenManager1 {
    //         burn_cap1,
    //         freeze_cap1,
    //         mint_cap1,
    //     });
        
    //     let metadata = coin_wrapper::create_fungible_asset_test<MyToken>();
    //     let metadata1 = coin_wrapper::create_fungible_asset_test<MyToken1>();
    //     let _liquidity_pool = liquidity_pool::create_test(metadata, metadata1, false);

    //     let initial_amount = 2000;
    //     let my_token_coin = coin::mint<MyToken>(initial_amount, &mint_cap);
    //     let my_token_coin1 = coin::mint<MyToken1>(initial_amount, &mint_cap1);
    //     let _fungible_asset = coin_wrapper::wrap_test<MyToken>(my_token_coin);
    //     let _fungible_asset1 = coin_wrapper::wrap_test<MyToken1>(my_token_coin1);
    //     let _mint_lp_amount = liquidity_pool::mint_lp_test(source, _fungible_asset, _fungible_asset1, false);

    //     let _gauge = gauge::create_test(_liquidity_pool);
    //     timestamp::update_global_time_for_test_secs(3600*24*7*3);
    //     let _claimable_rewards = gauge::claimable_rewards(signer::address_of(source), _gauge);
    //     assert!(_claimable_rewards == 0, 6);
    //     (mint_cap, mint_cap1)
    // }
}
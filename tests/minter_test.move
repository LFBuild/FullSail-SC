#[test_only]
module full_sail::minter_test {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::clock;
    use sui::coin::{Self, Coin};

    // --- modules ---
    use full_sail::minter::{Self, MinterConfig};
    use full_sail::voting_escrow::{Self, VeFullSailCollection, VeFullSailToken};
    use full_sail::fullsail_token::{Self, FULLSAIL_TOKEN, FullSailManager};
    use full_sail::epoch;

    // --- addresses ---
    const OWNER: address = @0xab;
    const RECIPIENT: address = @0xcd;

    // --- params ---
    const AMOUNT: u64 = 1000;
    const LOCK_DURATION: u64 = 52;
    const MS_IN_WEEK: u64 = 604800000; // milliseconds in a week

    fun setup() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;

        voting_escrow::init_for_testing(scenario.ctx());
        fullsail_token::init_for_testing(ts::ctx(scenario));

        ts::end(scenario_val);
    }

    #[test]
    fun test_initialize() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        
        setup();
        let clock = clock::create_for_testing(ts::ctx(scenario));
        
        let mut collection = ts::take_shared<VeFullSailCollection>(scenario);
        let mut manager = ts::take_shared<FullSailManager>(scenario);
        let treasurycap = fullsail_token::cap(&mut manager);
        next_tx(scenario, OWNER);
        let ve_token = minter::init_for_testing(scenario.ctx(), treasurycap, &mut collection, &clock);
        assert!(voting_escrow::get_lockup_expiration_epoch(&ve_token) == 104, 1);

        ts::return_shared(collection);
        ts::return_shared(manager);
        clock::destroy_for_testing(clock);
        ts::end(scenario_val);
        transfer::public_transfer(ve_token, OWNER);
    }

    #[test]
    fun test_mint() {
        let mut scenario_val = ts::begin(OWNER);
        let scenario = &mut scenario_val;
        let weekly_emission = 150000000000000;
        setup();
        let clock = clock::create_for_testing(ts::ctx(scenario));
        
        let mut collection = ts::take_shared<VeFullSailCollection>(scenario);
        let mut manager = ts::take_shared<FullSailManager>(scenario);
        let treasury_cap = fullsail_token::cap(&mut manager);
        next_tx(scenario, OWNER);
        {
            let ve_token = minter::init_for_testing(scenario.ctx(), treasury_cap, &mut collection, &clock);
            assert!(voting_escrow::get_lockup_expiration_epoch(&ve_token) == 104, 1);
            transfer::public_transfer(ve_token, OWNER);
        };
        next_tx(scenario, OWNER);
        {
            let mut minter_config = ts::take_shared<MinterConfig>(scenario);
            let (minted_tokens, additional_minted_tokens) = minter::mint(&mut minter_config, &manager, &collection, treasury_cap, &clock, scenario.ctx());
            assert!(coin::value(&minted_tokens) == weekly_emission, 2);
            assert!(coin::value(&additional_minted_tokens) > 0, 3);
            ts::return_shared(minter_config);
            coin::burn(treasury_cap, minted_tokens);
            coin::burn(treasury_cap, additional_minted_tokens);
        };
        ts::return_shared(collection);
        ts::return_shared(manager);
        clock::destroy_for_testing(clock);
        ts::end(scenario_val);
    }
}
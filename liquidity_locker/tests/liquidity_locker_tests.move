#[test_only]
module liquidity_locker::liquidity_locker_tests {
    use sui::test_scenario;

    #[test]
    fun test_calculate_and_update_rewards() {
        let admin = @0x1;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize factory and config
        {
            factory::test_init(scenario.ctx());
            config::test_init(scenario.ctx());
            gauge_cap::gauge_cap::init_test(scenario.ctx());
            stats::init_test(scenario.ctx());
            price_provider::init_test(scenario.ctx());
            rewarder::test_init(scenario.ctx());
        };
    }
}
#[test_only]
module price_monitor::price_monitor_tests;

use price_monitor::price_monitor::{Self, PriceMonitor, PriceMonitorCap, SuperAdminCap, PriceMonitorConfig};
use price_monitor::price_monitor_consts;
use sui::test_scenario::{Self, Scenario};
use sui::test_utils;

// Test constants
const ENotImplemented: u64 = 0;

#[test]
fun test_price_monitor_init() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Verify the monitor was created and shared
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        let admin_cap = test_scenario::take_from_sender<SuperAdminCap>(&scenario);
        
        // Check that the sender is the first admin
        assert!(price_monitor::is_admin(&monitor, @0x1), 0);
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
        test_scenario::return_to_sender(admin_cap);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_add_admin() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Add a new admin
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        
        // Add @0x2 as admin
        price_monitor::add_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Verify @0x2 is now an admin
        assert!(price_monitor::is_admin(&monitor, @0x2), 0);
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_remove_admin() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Add a new admin
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        
        // Add @0x2 as admin
        price_monitor::add_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Verify @0x2 is now an admin
        assert!(price_monitor::is_admin(&monitor, @0x2), 0);
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
    };
    
    // Remove the admin
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        
        // Remove @0x2 as admin
        price_monitor::remove_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Verify @0x2 is no longer an admin
        assert!(!price_monitor::is_admin(&monitor, @0x2), 0);
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_check_admin() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Test check_admin function
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        
        // This should not abort since @0x1 is an admin
        price_monitor::check_admin(&monitor, @0x1);
        
        // Return object
        test_scenario::return_shared(monitor);
    };
    
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAdminNotWhitelisted)]
fun test_check_admin_fail() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Test check_admin function with non-admin
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        
        // This should abort since @0x2 is not an admin
        price_monitor::check_admin(&monitor, @0x2);
        
        // Return object
        test_scenario::return_shared(monitor);
    };
    
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAddressNotAdmin)]
fun test_add_admin_already_exists() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Try to add the same admin twice
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        
        // Add @0x2 as admin
        price_monitor::add_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Try to add @0x2 again - this should fail
        price_monitor::add_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
    };
    
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAddressNotAdmin)]
fun test_remove_admin_not_exists() {
    let scenario = test_scenario::begin(@0x1);
    
    // Initialize the price monitor
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        price_monitor::init(test_scenario::ctx(&mut scenario));
    };
    
    // Try to remove a non-existent admin
    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let monitor = test_scenario::take_shared<PriceMonitor>(&scenario);
        let cap = test_scenario::take_from_sender<PriceMonitorCap>(&scenario);
        
        // Try to remove @0x2 who is not an admin - this should fail
        price_monitor::remove_admin(&cap, &mut monitor, @0x2, test_scenario::ctx(&mut scenario));
        
        // Return objects
        test_scenario::return_shared(monitor);
        test_scenario::return_to_sender(cap);
    };
    
    test_scenario::end(scenario);
}

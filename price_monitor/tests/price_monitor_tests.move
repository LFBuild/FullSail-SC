// #[test_only]
// module price_monitor::price_monitor_tests;

// use price_monitor::price_monitor::{Self, PriceMonitor, SuperAdminCap};
// use price_monitor::price_monitor_consts;
// use sui::test_scenario::{Self, Scenario};
// use sui::test_utils;

// // Test constants
// const ENotImplemented: u64 = 0;

// #[test]
// fun test_price_monitor_init() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Verify the monitor was created and shared
//     scenario.next_tx(admin);
//     {
//         let monitor = scenario.take_shared<PriceMonitor>();
//         let admin_cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Check that the sender is the first admin
//         assert!(price_monitor::is_admin(&monitor, @0x1), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(admin_cap);
//     };
    
//     scenario.end();
// }

// #[test]
// fun test_add_admin() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Add a new admin
//     scenario.next_tx(admin);
//     {
//         let mut monitor = scenario.take_shared<PriceMonitor>();
//         let cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Add @0x2 as admin
//         price_monitor::add_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Verify @0x2 is now an admin
//         assert!(price_monitor::is_admin(&monitor, @0x2), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(cap);
//     };
    
//     scenario.end();
// }

// #[test]
// fun test_remove_admin() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Add a new admin
//     scenario.next_tx(admin);
//     {
//         let mut monitor = scenario.take_shared<PriceMonitor>();
//         let cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Add @0x2 as admin
//         price_monitor::add_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Verify @0x2 is now an admin
//         assert!(price_monitor::is_admin(&monitor, @0x2), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(cap);
//     };
    
//     // Remove the admin
//     scenario.next_tx(admin);
//     {
//         let mut monitor = scenario.take_shared<PriceMonitor>();
//         let cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Remove @0x2 as admin
//         price_monitor::remove_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Verify @0x2 is no longer an admin
//         assert!(!price_monitor::is_admin(&monitor, @0x2), 0);
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(cap);
//     };
    
//     scenario.end();
// }

// #[test]
// fun test_check_admin() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Test check_admin function
//     scenario.next_tx(admin);
//     {
//         let monitor = scenario.take_shared<PriceMonitor>();
        
//         // This should not abort since @0x1 is an admin
//         price_monitor::check_admin(&monitor, @0x1);
        
//         // Return object
//         test_scenario::return_shared(monitor);
//     };
    
//     scenario.end();
// }

// #[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAdminNotWhitelisted)]
// fun test_check_admin_fail() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Test check_admin function with non-admin
//     scenario.next_tx(admin);
//     {
//         let monitor = scenario.take_shared<PriceMonitor>();
        
//         // This should abort since @0x2 is not an admin
//         price_monitor::check_admin(&monitor, @0x2);
        
//         // Return object
//         test_scenario::return_shared(monitor);
//     };
    
//     scenario.end();
// }

// #[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAddressNotAdmin)]
// fun test_add_admin_already_exists() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Try to add the same admin twice
//     scenario.next_tx(admin);
//     {
//         let mut monitor = scenario.take_shared<PriceMonitor>();
//         let cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Add @0x2 as admin
//         price_monitor::add_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Try to add @0x2 again - this should fail
//         price_monitor::add_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(cap);
//     };
    
//     scenario.end();
// }

// #[test, expected_failure(abort_code = ::price_monitor::price_monitor::EAddressNotAdmin)]
// fun test_remove_admin_not_exists() {
//     let admin = @0x1;
//     let mut scenario = test_scenario::begin(admin);
    
//     // Initialize the price monitor
//     scenario.next_tx(admin);
//     {
//         price_monitor::test_init(scenario.ctx());
//     };
    
//     // Try to remove a non-existent admin
//     scenario.next_tx(admin);
//     {
//         let mut monitor = scenario.take_shared<PriceMonitor>();
//         let cap = scenario.take_from_sender<SuperAdminCap>();
        
//         // Try to remove @0x2 who is not an admin - this should fail
//         price_monitor::remove_admin(&cap, &mut monitor, @0x2, scenario.ctx());
        
//         // Return objects
//         test_scenario::return_shared(monitor);
//         scenario.return_to_sender(cap);
//     };
    
//     scenario.end();
// }

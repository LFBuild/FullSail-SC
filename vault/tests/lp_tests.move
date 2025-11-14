#[test_only]
module vault::lp_tests;

use sui::test_scenario;
use sui::coin::{Self, CoinMetadata, TreasuryCap};

#[test_only]
public struct LP_TESTS has drop {} 

public fun create_lp_tests(
    scenario: &mut test_scenario::Scenario,
    decimals: u8,
): (TreasuryCap<LP_TESTS>, CoinMetadata<LP_TESTS>) {

    coin::create_currency<LP_TESTS>(
        LP_TESTS {}, 
        decimals, 
        b"LP_TESTS", 
        b"LP_TESTS", 
        b"LP_TESTS",
        std::option::none(), 
        scenario.ctx()
    )
}

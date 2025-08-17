#[test_only]
module price_monitor::usd_tests;

use sui::test_scenario;
use sui::coin::{Self, CoinMetadata, TreasuryCap};

#[test_only]
public struct USD_TESTS has drop {} 

public fun create_usd_tests(
    scenario: &mut test_scenario::Scenario,
    decimals: u8,
): (TreasuryCap<USD_TESTS>, CoinMetadata<USD_TESTS>) {

    coin::create_currency<USD_TESTS>(USD_TESTS {}, decimals, b"USD_TESTS", b"USD_TESTS", b"USD_TESTS",std::option::none(), scenario.ctx())
}

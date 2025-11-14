#[test_only]
module vault::usdt_tests;

use sui::test_scenario;
use sui::coin::{Self, CoinMetadata, TreasuryCap};

#[test_only]
public struct USDT_TESTS has drop {} 

public fun create_usdt_tests(
    scenario: &mut test_scenario::Scenario,
    decimals: u8,
): (TreasuryCap<USDT_TESTS>, CoinMetadata<USDT_TESTS>) {

    coin::create_currency<USDT_TESTS>(USDT_TESTS {}, decimals, b"USDT_TESTS", b"USDT_TESTS", b"USDT_TESTS",std::option::none(), scenario.ctx())
}

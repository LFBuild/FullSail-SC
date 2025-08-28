#[test_only]
module distribution::ausd_tests;

use sui::test_scenario;
use sui::coin::{Self, CoinMetadata, TreasuryCap};

#[test_only]
public struct AUSD_TESTS has drop {} 

public fun create_ausd_tests(
    scenario: &mut test_scenario::Scenario,
    decimals: u8,
): (TreasuryCap<AUSD_TESTS>, CoinMetadata<AUSD_TESTS>) {

    coin::create_currency<AUSD_TESTS>(AUSD_TESTS {}, decimals, b"AUSD_TESTS", b"AUSD_TESTS", b"AUSD_TESTS",std::option::none(), scenario.ctx())
}

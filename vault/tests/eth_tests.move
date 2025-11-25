#[test_only]
module vault::eth_tests;

use sui::test_scenario;
use sui::coin::{Self, CoinMetadata, TreasuryCap};

#[test_only]
public struct ETH_TESTS has drop {} 

public fun create_eth_tests(
    scenario: &mut test_scenario::Scenario,
    decimals: u8,
): (TreasuryCap<ETH_TESTS>, CoinMetadata<ETH_TESTS>) {

    coin::create_currency<ETH_TESTS>(ETH_TESTS {}, decimals, b"ETH_TESTS", b"ETH_TESTS", b"ETH_TESTS",std::option::none(), scenario.ctx())
}

#[test_only]
module full_sail::rewards_pool_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::coin::{Self, CoinMetadata};
    use sui::transfer;
    use sui::object::{Self};
    
    // --- modules ---
    use full_sail::rewards_pool;
    use full_sail::sui::{Self, SUI};
    use full_sail::usdt::{Self, USDT};
    
    // --- addresses ---
    const OWNER: address = @0xab;
    
}
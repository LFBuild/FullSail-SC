// module full_sail::gauge {
//     use std::string::{Self, String};
//     use sui::table::{Self, Table};
//     use sui::coin::{Self, Coin};
//     use sui::clock::Clock;
//     use sui::package;
//     use sui::display;
//     use sui::balance::{Self, Balance};

//     use full_sail::liquidity_pool::{Self, LiquidityPool};
//     use full_sail::rewards_pool_continuous::{Self, RewardsPool};
//     use full_sail::fullsail_token::{Self, FULLSAIL_TOKEN};

//     public struct GAUGE has drop {}

//     public struct Gauge has key {
//         id: UID,
//         rewards_pool: RewardsPool,
//         liquidity_pool: LiquidityPool,
//     }

//     public fun liquidity_pool(gauge_id: UID): LiquidityPool {
//         let gauge: Gauge = borrow_global<Gauge>(gauge_id);
//         &gauge.liquidity_pool
//     }

//     public fun claim_fees(gauge_id: UID, ctx: &mut TxContext): ( Coin<FUllSAIL_TOKEN>, Coin<FUllSAIL_TOKEN> ) {
//         // Borrow the Gauge object from global storage using the gauge_id
//         let gauge = borrow_global<Gauge>(gauge_id);

//         // Access the liquidity pool associated with this gauge
//         let pool = &gauge.liquidity_pool;

//         liquidity_pool::claim_fees(pool, ctx)
//     }

//     public fun add_rewards(gauge_id: UID, rewards: Coin<FULLSAIL_TOKEN>) {
//         let pool = rewards_pool(gauge_id);
//         rewards_pool_continuous::add_rewards(pool, rewards);
//     }

//     public fun claim_rewards(gauge_id: UID, ctx: &mut TxContext) {
//         let pool = rewards_pool(gauge);
//         rewards_pool_continuous::claim_rewards()
//     }

//     public fun claimable_rewards(account: address, gauge_id: UID): u64 {
//         let pool = rewards_pool(gauge_id);
//         rewards_pool_continuous::claimable_rewards(account, pool)
//     }

//     public fun create(pool: LiquidityPool, ctx: &mut TxContext): Gauge {
//         let publisher = package::claim(otw, ctx);
//         coin::create_store<LiquidityPool>();
//         let gauge = Gauge {
//             rewards_pool: rewards_pool_continuous::create(),
//             liquidity_pool: pool,
//         }
//         transfer.public_transfer(gauge, ctx);
//         gauge
//     }

//     public fun stake(gauge_id: UID, amount: u64, ctx: &mut TxContext) {
//         let pool = liquidity_pool(gauge_id);
//         liquidity_pool::transfer(tx_context::sender(ctx), )
//     }

//     public fun rewards_pool(gauge_id: UID): RewardsPool {
//         borrow_global<Gauge>(gauge_id).rewards_pool
//     }
// }
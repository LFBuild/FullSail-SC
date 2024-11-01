/*module full_sail::liquidity_pool {
    use std::string::{Self, String};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::math;
    use sui::table::{Table};

    // --- errors ---
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_MIN_LOCK_TIME: u64 = 2;
    const E_MAX_LOCK_TIME: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_ZERO_AMOUNT: u64 = 8;
    const E_INVALID_SPLIT_AMOUNT: u64 = 12;
    const E_ZERO_TOTAL_POWER: u64 = 14;

    // --- structs ---
    public struct LPCoin<phantom Base, phantom Quote> has drop {}

    public struct FeesAccounting has store {
        total_fees_base: u128,
        total_fees_quote: u128,
        total_fees_at_last_claim_base: Table<address, u128>,
        total_fees_at_last_claim_quote: Table<address, u128>,
        claimable_base: Table<address, u128>,
        claimable_quote: Table<address, u128>,
    }

    public struct LiquidityPool<phantom Base, phantom Quote> has key {
        id: UID,
        base_reserve: Balance<Base>,
        quote_reserve: Balance<Quote>,
        lp_supply: Balance<LPCoin<Base, Quote>>,
        fees_base: Balance<Base>,
        fees_quote: Balance<Quote>,
        swap_fee_bps: u64,
        is_stable: bool,
    }

    public struct PoolRegistry has key {
        id: UID,
        pools: vector<ID>,
        is_paused: bool,
        fee_manager: address,
        pauser: address,
        stable_fee_bps: u64,
        volatile_fee_bps: u64,
    }

    // init
    fun init(ctx: &mut TxContext) {
        let registry = PoolRegistry {
            id: object::new(ctx),
            pools: vector::empty(),
            is_paused: false,
            fee_manager: tx_context::sender(ctx),
            pauser: tx_context::sender(ctx),
            stable_fee_bps: 4,
            volatile_fee_bps: 10,
        };
        transfer::share_object(registry);
    }

    public fun create_pool<Base, Quote>(
        registry: &mut PoolRegistry,
        is_stable: bool,
        ctx: &mut TxContext
    ): ID {
        let swap_fee = if (is_stable) {
            registry.stable_fee_bps
        } else {
            registry.volatile_fee_bps
        };

        let pool = LiquidityPool<Base, Quote> {
            id: object::new(ctx),
            base_reserve: balance::zero(),
            quote_reserve: balance::zero(),
            lp_supply: balance::zero(),
            fees_base: balance::zero(),
            fees_quote: balance::zero(),
            swap_fee_bps: swap_fee,
            is_stable,
        };

        let pool_id = object::id(&pool);
        vector::push_back(&mut registry.pools, pool_id);
        transfer::share_object(pool);
        pool_id
    }
}*/
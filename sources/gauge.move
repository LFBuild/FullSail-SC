module full_sail::gauge {
    use full_sail::rewards_pool_continuous::{Self, RewardsPool, REWARD_POOL_CONTINUOUS};
    use full_sail::liquidity_pool::{Self, LiquidityPool};

    use sui::coin::{Coin};
    use sui::balance::{Balance};
    use sui::clock::{Clock};
    use sui::event;
    
    public struct Gauge<phantom BaseType, phantom QuoteType> has key, store {
        id: UID,
        rewards_pool: RewardsPool,
        liquidity_pool: LiquidityPool<BaseType, QuoteType>,
    }

    public struct StakeEvent has copy, drop {
        lp: address,
        // gauge: Gauge<BaseType, QuoteType>,
        amount: u64,
    }

    public struct UnstakeEvent has copy, drop {
        lp: address,
        // gauge: sui::object::Object<Gauge>,
        amount: u64,
    }

    public fun liquidity_pool<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : &mut LiquidityPool<BaseType, QuoteType> {
        &mut gauge.liquidity_pool
    }

    public fun claim_fees<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, ctx: &mut TxContext): (Coin<BaseType>, Coin<QuoteType>) {
        let liquidity_pool = liquidity_pool(gauge);
        liquidity_pool::claim_fees(liquidity_pool, ctx)
    }

    public fun add_rewards<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, balance: Balance<REWARD_POOL_CONTINUOUS>, clock: &Clock) {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::add_rewards(rewards_pool, balance, clock);
    }

    public fun claim_rewards<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, ctx: &mut TxContext, clock: &Clock) : Balance<REWARD_POOL_CONTINUOUS> {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::claim_rewards(tx_context::sender(ctx), rewards_pool, clock)
    }

    public fun claimable_rewards<BaseType, QuoteType>(user_address: address, gauge: &mut Gauge<BaseType, QuoteType>, clock: &Clock) : u64 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::claimable_rewards(user_address, rewards_pool, clock)
    }

    // public fun create<BaseType, QuoteType>(liquidity_pool: LiquidityPool<BaseType, QuoteType>, ctx: &mut TxContext) : Gauge<BaseType, QuoteType> {
    //     let v0 = temp::package_manager::get_signer();
    //     let v1 = sui::object::create_object_from_account(&v0);
    //     let v2 = &v1;
    //     sui::fungible_asset::create_store<temp::liquidity_pool::LiquidityPool>(v2, arg0);
    //     let v3 = sui::object::generate_signer(v2);
    //     let v4 = Gauge{
    //         rewards_pool   : temp::rewards_pool_continuous::create(sui::object::convert<temp::cellana_token::CellanaToken, sui::fungible_asset::Metadata>(temp::cellana_token::token()), rewards_duration()),
    //         extend_ref     : sui::object::generate_extend_ref(v2),
    //         liquidity_pool : arg0,
    //     };
    //     move_to<Gauge>(&v3, v4);
    //     sui::object::object_from_constructor_ref<Gauge>(v2)
    // }

    public fun stake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext, clock: &Clock) {
        // let liquidity_pool = liquidity_pool(gauge);
        // liquidity_pool::transfer(arg0, sui::object::convert<temp::liquidity_pool::LiquidityPool, temp::liquidity_pool::LiquidityPool>(v0), sui::object::object_address<Gauge>(&arg1), arg2);
        let user_address = tx_context::sender(ctx);
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::stake(user_address, rewards_pool, amount, clock);
        event::emit(StakeEvent { lp: user_address, amount: amount })
    }

    public fun stake_balance<BaseType, QuoteType>(user_address: address, gauge: &mut Gauge<BaseType, QuoteType>) : u64 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::stake_balance(user_address, rewards_pool)
    }

    public fun total_stake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : u128 {
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::total_stake(rewards_pool)
    }

    public entry fun unstake<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext) {
        abort 0
    }

    public fun rewards_duration() : u64 {
        604800
    }

    public fun rewards_pool<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : &mut rewards_pool_continuous::RewardsPool {
        &mut gauge.rewards_pool
    }

    // public fun stake_token<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>) : CoinMetadata<REWARD_POOL_CONTINUOUS> {
    //     sui::object::convert<temp::liquidity_pool::LiquidityPool, sui::fungible_asset::Metadata>(borrow_global<Gauge>(sui::object::object_address<Gauge>(&arg0)).liquidity_pool)
    // }

    public fun unstake_lp<BaseType, QuoteType>(gauge: &mut Gauge<BaseType, QuoteType>, amount: u64, ctx: &mut TxContext, clock: &Clock) {
        let sender = tx_context::sender(ctx);
        // let v1 = sui::object::generate_signer_for_extending(&borrow_global<Gauge>(sui::object::object_address<Gauge>(&arg1)).extend_ref);
        // let v2 = liquidity_pool(arg1);
        // temp::liquidity_pool::transfer(&v1, v2, v0, arg2);
        let rewards_pool = rewards_pool(gauge);
        assert!(rewards_pool_continuous::stake_balance(sender, rewards_pool) >= amount, 1);
        let rewards_pool = rewards_pool(gauge);
        rewards_pool_continuous::unstake(sender, rewards_pool, amount, clock);
        event::emit(UnstakeEvent { lp: sender, amount: amount })
    }
}

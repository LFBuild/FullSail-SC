module liquidity_locker::pool_tranche {
    use liquidity_locker::consts;

    const ENotOwner: u64 = 93458375283742382;
    const EOverflow: u64 = 98774536485623832;
    const EZeroPrice: u64 = 9375892909283584;
    const ETrancheFilled: u64 = 92357345723427311;
    const EInvalidShareLiquidityToFill: u64 = 90395023942953434;

    public struct POOL_TRANCHE has drop {}

    public struct PoolTrancheManager has store, key {
        id: UID,
        pool_tranches: sui::table::Table<ID, vector<PoolTranche>>, // pool_id -> []tranches
        // filled_tranches: sui::table::Table<ID, bool>, // tranche_id -> is_filled
    }

    public struct PoolTranche has store, key {
        id: UID,
        pool_id: ID,
        // gauge_cap: Option<gauge_cap::gauge_cap::GaugeCap>,
        locked_positions: sui::table::Table<ID, bool>, // LockedPosition id
        // rewards_balance: sui::balance::Balance<SailCoinType>,
        total_balance: u128,
        // тип койна в котором измеряется объем транша
        volume_in_coin_a: bool, // true - in coin_a, false - in coin_b
        total_volume: u128,
        current_volume: u128,
        filled: bool,

        duration_profitabilities: vector<u64>, // мультипликатор для каждой длительности блокировки
    }

    public struct InitTrancheManagerEvent has copy, drop {
        tranche_manager_id: ID,
    }

    public struct CreatePoolTrancheEvent has copy, drop {
        tranche_id: ID,
        pool_id: ID,
        volume_in_coin_a: bool,
        total_volume: u128,
        duration_profitabilities: vector<u64>,
    }

    public struct FillTrancheEvent has copy, drop {
        tranche_id: ID,
        current_volume: u128,
        filled: bool,
    }

    fun init(otw: POOL_TRANCHE, ctx: &mut sui::tx_context::TxContext) {
        let tranche_manager = PoolTrancheManager {
            id: sui::object::new(ctx),
            pool_tranches: sui::table::new(ctx),
        };
        let tranche_manager_id = sui::object::id<PoolTrancheManager>(&tranche_manager);
        sui::transfer::share_object<PoolTrancheManager>(tranche_manager);
        let event = InitTrancheManagerEvent { tranche_manager_id };
        sui::event::emit<InitTrancheManagerEvent>(event);
        sui::package::claim_and_keep<POOL_TRANCHE>(otw, ctx);
    }

    public fun new<CoinTypeA, CoinTypeB>(
        publisher: &mut sui::package::Publisher,
        manager: &mut PoolTrancheManager,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        volume_in_coin_a: bool,
        total_volume: u128,
        duration_profitabilities: vector<u64>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(publisher.from_module<PoolTrancheManager>(), ENotOwner);
        // assert!(duration_profitabilities.length() == locker.periods_blocking.length(), EInvalidProfitabilitiesLength);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let pool_tranche = PoolTranche {
            id: sui::object::new(ctx),
            pool_id,
            locked_positions: sui::table::new(ctx),
            // rewards_balance: sui::balance::zero<SailCoinType>(),
            total_balance: 0,
            volume_in_coin_a,
            total_volume,
            current_volume: 0,
            filled: false,
            duration_profitabilities,
        };

        let tranche_id = sui::object::id<PoolTranche>(&pool_tranche);
        manager.pool_tranches.borrow_mut(pool_id).push_back(pool_tranche);

        let event = CreatePoolTrancheEvent {
            tranche_id,
            pool_id,
            volume_in_coin_a,
            total_volume,
            duration_profitabilities,
        };
        sui::event::emit<CreatePoolTrancheEvent>(event);
    }

    public(package) fun get_tranches(manager: &mut PoolTrancheManager, pool_id: ID): &mut vector<PoolTranche> {
        manager.pool_tranches.borrow_mut(pool_id)
    }

    public fun is_filled(tranche: &PoolTranche): bool {
        tranche.filled
    }

    public fun get_duration_profitabilities(tranche: &PoolTranche): vector<u64> {
        tranche.duration_profitabilities
    }

    public(package) fun fill_tranches<CoinTypeA, CoinTypeB>(
        tranche: &mut PoolTranche,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        share_liquidity_to_fill: u64, // доля ликвидности позиций, которой нужно заполнить транш
    ): u64 { // возвращает долю ликвидности позиций которая не влезла в транш
        assert!(!tranche.filled, ETrancheFilled);
        assert!(share_liquidity_to_fill <= consts::lock_liquidity_share_denom()*100, EInvalidShareLiquidityToFill);

        let liquidity_in_token = 0;
        if (tranche.volume_in_coin_a) {
            liquidity_in_token = calculate_position_liquidity_in_token_a(pool, position_id)
        } else {
            liquidity_in_token = calculate_position_liquidity_in_token_b(pool, position_id)
        };
        liquidity_in_token = integer_mate::math_u128::checked_div_round(liquidity_in_token * (share_liquidity_to_fill as u128), consts::lock_liquidity_share_denom() as u128, false);
        let result = if (tranche.current_volume + liquidity_in_token >= tranche.total_volume) {
            let overflow_liquidity = tranche.current_volume + liquidity_in_token - tranche.total_volume;
            tranche.current_volume = tranche.total_volume;
            tranche.filled = true;

            integer_mate::math_u128::hi(
                integer_mate::math_u128::checked_div_round(overflow_liquidity, liquidity_in_token, false) * 100 * (consts::lock_liquidity_share_denom() as u128)
            )
        } else {
            tranche.current_volume = tranche.current_volume + liquidity_in_token;
            0
        };

        let event = FillTrancheEvent {
            tranche_id: sui::object::id<PoolTranche>(tranche),
            current_volume: tranche.current_volume,
            filled: tranche.filled,
        };
        sui::event::emit<FillTrancheEvent>(event);

        result
    }

    public fun calculate_position_liquidity_in_token_a<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 {
        // Получаем текущую цену
        let sqrt_price = pool.current_sqrt_price();
        let (price, overflow) = integer_mate::math_u128::overflowing_mul(sqrt_price, sqrt_price);
        assert!(!overflow, EOverflow);
        assert!(price > 0, EZeroPrice);

        // Получаем балансы позиции
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        // Конвертируем balance_b в эквивалент tokenA
        let amount_b_in_a = integer_mate::math_u128::checked_div_round((amount_b as u128) << 64, price, false);

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_a as u128) << 64, amount_b_in_a);
        assert!(!overflow, EOverflow);

        // Общая ликвидность в tokenA
       result
    }

    public fun calculate_position_liquidity_in_token_b<CoinTypeA, CoinTypeB>(
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
    ): u128 {
        // Получаем текущую цену
       let sqrt_price = pool.current_sqrt_price();
        let (price, overflow) = integer_mate::math_u128::overflowing_mul(sqrt_price, sqrt_price);
        assert!(!overflow, EOverflow);
        assert!(price > 0, EZeroPrice);

        // Получаем балансы позиции
        let (amount_a, amount_b) = clmm_pool::pool::get_position_amounts(pool, position_id);

        let (amount_a_in_b, overflow) = integer_mate::math_u128::overflowing_mul((amount_a as u128) << 64, price);
        assert!(!overflow, EOverflow);

        let (result, overflow) = integer_mate::math_u128::overflowing_add((amount_b as u128) << 64, amount_a_in_b);
        assert!(!overflow, EOverflow);

        // Общая ликвидность в tokenB
       result
    }
    
}
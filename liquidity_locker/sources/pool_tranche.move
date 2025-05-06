module liquidity_locker::pool_tranche {
    
    use std::type_name::{Self, TypeName};

    const ETrancheFilled: u64 = 92357345723427311;
    const ERewardAlreadyExists: u64 = 90324592349252616;
    const ERewardNotFound: u64 = 91235834582491043;
    const ETrancheNotFound: u64 = 923487825237452354;
    const ERewardNotEnough: u64 = 91294503453406623;
    const EInvalidAddLiquidity: u64 = 923487825237423743;

    /// Capability for administrative functions in the protocol.
    /// This capability is required for managing global settings and protocol parameters.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the capability
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct PoolTrancheManager has store, key {
        id: UID,
        pool_tranches: sui::table::Table<ID, vector<PoolTranche>>, // pool_id -> []tranches
    }

    public struct PoolTranche has store, key {
        id: UID,
        pool_id: ID,
        // locked_positions: sui::table::Table<ID, bool>, // LockedPosition id
        rewards_balance: sui::bag::Bag, // epoch -> balance
        total_balance_epoch: sui::table::Table<u64, u64>, // epoch -> total_balance
        total_income_epoch: sui::table::Table<u64, u64>, // epoch -> total_income
        // тип койна в котором измеряется объем транша
        volume_in_coin_a: bool, // true - in coin_a, false - in coin_b
        total_volume: u128,
        current_volume: u128,
        filled: bool,
        minimum_remaining_volume: u64, // минимальный остаток объема транша, при котором он закрывается, в долях с minimum_remaining_volume_denom

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

    public struct AddRewardEvent has copy, drop {
        tranche_id: ID,
        epoch_start: u64,
        reward_type: TypeName,
        balance_value: u64,
        total_income: u64,
    }

    public struct GetRewardEvent has copy, drop {
        tranche_id: ID,
        epoch_start: u64,
        reward_amount: u64,
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let tranche_manager = PoolTrancheManager {
            id: sui::object::new(ctx),
            pool_tranches: sui::table::new(ctx),
        };
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        let tranche_manager_id = sui::object::id<PoolTrancheManager>(&tranche_manager);
        sui::transfer::share_object<PoolTrancheManager>(tranche_manager);
        let event = InitTrancheManagerEvent { tranche_manager_id };
        sui::event::emit<InitTrancheManagerEvent>(event);
    }

    public fun minimum_remaining_volume_denom(): u64 {
        10000
    }

    public fun new<CoinTypeA, CoinTypeB>(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        volume_in_coin_a: bool,
        total_volume: u128, // Q64.64
        duration_profitabilities: vector<u64>,
        minimum_remaining_volume: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        // TODO assert!(duration_profitabilities.length() == locker.periods_blocking.length(), EInvalidProfitabilitiesLength);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let pool_tranche = PoolTranche {
            id: sui::object::new(ctx),
            pool_id,
            rewards_balance: sui::bag::new(ctx),
            total_balance_epoch: sui::table::new(ctx),
            total_income_epoch: sui::table::new(ctx),
            volume_in_coin_a,
            total_volume,
            current_volume: 0,
            filled: false,
            duration_profitabilities,
            minimum_remaining_volume,
        };

        let tranche_id = sui::object::id<PoolTranche>(&pool_tranche);
        if (!manager.pool_tranches.contains(pool_id)) {
            manager.pool_tranches.add(pool_id, vector::empty());
        };
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

    // добавляет награду в транш
    public fun add_reward<RewardCoinType>(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        pool_id: sui::object::ID,
        tranche_id: sui::object::ID,
        epoch_start: u64, // in seconds
        balance: sui::balance::Balance<RewardCoinType>,
        total_income: u64,
    ): u64 {
        let epoch_start = distribution::common::epoch_start(epoch_start);
        let pool_tranches = manager.pool_tranches.borrow_mut(pool_id);
        let mut i = 0;
        while (i < pool_tranches.length()) {
            let tranche = pool_tranches.borrow_mut(i);
            let current_tranche_id = sui::object::id<PoolTranche>(tranche);
            if (tranche_id == current_tranche_id) {

                assert!(!tranche.rewards_balance.contains(epoch_start), ERewardAlreadyExists);

                let reward_type = type_name::get<RewardCoinType>();
                let balance_value = balance.value();

                tranche.rewards_balance.add(epoch_start, sui::balance::zero<RewardCoinType>());
                let after_amount = sui::balance::join<RewardCoinType>(
                    sui::bag::borrow_mut<u64, sui::balance::Balance<RewardCoinType>>(&mut tranche.rewards_balance, epoch_start),
                    balance
                );
                tranche.total_balance_epoch.add(epoch_start, balance_value);
                tranche.total_income_epoch.add(epoch_start, total_income);

                let event = AddRewardEvent {
                    tranche_id,
                    epoch_start,
                    reward_type,
                    balance_value,
                    total_income,
                };
                sui::event::emit<AddRewardEvent>(event);
                return after_amount
            };
            i = i + 1;
        };
        abort ETrancheNotFound
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

    public fun get_free_volume(tranche: &PoolTranche): (u128, bool) {
            (tranche.total_volume - tranche.current_volume, tranche.volume_in_coin_a)
    }

    public(package) fun fill_tranches(
        tranche: &mut PoolTranche,
        add_volume: u128, // Q64.64
    ) {
        assert!(!tranche.filled, ETrancheFilled);
        assert!(tranche.current_volume + add_volume <= tranche.total_volume, EInvalidAddLiquidity);
        
        tranche.current_volume = tranche.current_volume + add_volume;
        if (tranche.current_volume == tranche.total_volume ||
            integer_mate::full_math_u128::mul_div_round(
                tranche.total_volume, 
                tranche.minimum_remaining_volume as u128, 
                minimum_remaining_volume_denom() as u128
            ) >= (tranche.total_volume - tranche.current_volume)) { 
            // если свободного места осталось менее minimum_remaining_volume от общего объема
            // закрываем транш, чтобы не плодить мелких позиций
            tranche.filled = true;
        };

        let event = FillTrancheEvent {
            tranche_id: sui::object::id<PoolTranche>(tranche),
            current_volume: tranche.current_volume,
            filled: tranche.filled,
        };
        sui::event::emit<FillTrancheEvent>(event);
    }

    public(package) fun get_reward_balance<RewardCoinType>(
        manager: &mut PoolTrancheManager,
        pool_id: sui::object::ID,
        tranche_id: sui::object::ID,
        income: u64,
        epoch_start: u64,
    ): sui::balance::Balance<RewardCoinType> {
        let epoch_start = distribution::common::epoch_start(epoch_start);
        let pool_tranches = manager.pool_tranches.borrow_mut(pool_id);
        let mut i = 0;
        while (i < pool_tranches.length()) {
            let tranche = pool_tranches.borrow_mut(i);
            let current_tranche_id = sui::object::id<PoolTranche>(tranche);
            if (tranche_id == current_tranche_id) {

                assert!(tranche.rewards_balance.contains(epoch_start), ERewardNotFound);

                // найти отношение income к total_income и применить к total_balance
                let reward_amount = integer_mate::full_math_u64::mul_div_floor(
                    *tranche.total_balance_epoch.borrow(epoch_start),
                    income,
                    *tranche.total_income_epoch.borrow(epoch_start)
                );

                let current_balance = tranche.rewards_balance.borrow_mut<u64, sui::balance::Balance<RewardCoinType>>(epoch_start);

                assert!(reward_amount <= current_balance.value(), ERewardNotEnough);

                let event = GetRewardEvent {
                    tranche_id,
                    epoch_start,
                    reward_amount,
                };
                sui::event::emit<GetRewardEvent>(event);

                return current_balance.split(reward_amount)
            };
            i = i + 1;
        };
        abort ETrancheNotFound
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let tranche_manager = PoolTrancheManager {
            id: sui::object::new(ctx),
            pool_tranches: sui::table::new(ctx),
        };
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object<PoolTrancheManager>(tranche_manager);
    }
}
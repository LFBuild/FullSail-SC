
/// Module: liquidity_locker
module liquidity_locker::liquidity_locker {
    use liquidity_locker::pool_tranche;
    use liquidity_locker::consts;

    const ENotOwner: u64 = 938728758435823242;
    const EInvalidPeriodsLength: u64 = 9387246581247184723;
    const EInvalidProfitabilitiesLength: u64 = 938775343456847243;
    const ENoRewards: u64 = 938724594823428742;
    const EPositionNotStaked: u64 = 93872134313534843;
    const EInvalidBlockPeriodIndex: u64 = 9387246545464428743;
    const ELockPeriodEnded: u64 = 994236928326934548;
    const EFullLockPeriodNotEnded: u64 = 989237458375783443;
    const EPositionAlreadyOpened: u64 = 93872465763464333;
    const EPositionNotLocked: u64 = 90239459234958343;
    const ENoTranches: u64 = 98237423747238423;
    const ETranchesFilled: u64 = 98345333323877745;
    const ERewardsNotCollected: u64 = 9129448645674544;
    const ELockPeriodNotEnded: u64 = 912049583475749665;
    public struct LIQUIDITY_LOCKER has drop {}

    // структура общего стейта
    public struct Locker has store, key {
        id: sui::object::UID,
        // list: move_stl::linked_table::LinkedTable<sui::object::ID, PoolSimpleInfo>,
        // TODO мапка по лоченым позициям и др
        positions: sui::table::Table<ID, bool>,
        // balance: sui::balance::Balance<SailCoinType>,

        // периоды блокировки, в эпохах
        periods_blocking: vector<u64>, // in epochs
        // периоды после блокировки, длина обз как periods_blocking
        periods_post_lockdown: vector<u64>, // in epochs
    }

    // структура для лоченых позиций, возвращаемая пользователю как факт владения
    public struct LockedPosition has store, key {
        id: sui::object::UID,
        position_id: sui::object::ID,
        lock_liquidity_share: u64, // в процентах*lock_liquidity_share_denom, какая доля ликвидности позиции залочена. используется, когда позиция попадается в разные транши (обычно будет 100%)
        expiration_time: u64, // ms
        full_unlocking_time: u64, // ms
        profitability: u64,
        last_claim_time: u64, // ms
    }

    public struct InitLockerEvent has copy, drop {
        locker_id: sui::object::ID,
    }

    public struct LockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        position_id: sui::object::ID,
        lock_liquidity_share: u64,
        expiration_time: u64,
        full_unlocking_time: u64,
        profitability: u64,
    }

    public struct UnlockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        position_id: sui::object::ID,
    }

    public struct CollectRewardsEvent has copy, drop {
        lock_position_id: sui::object::ID,
        earned_amount: u64,
        income: u64,
    }

    fun init(otw: LIQUIDITY_LOCKER, ctx: &mut sui::tx_context::TxContext) {
        let locker = Locker {
            id: sui::object::new(ctx),
            positions: sui::table::new<ID, bool>(ctx),
            periods_blocking: std::vector::empty<u64>(),
            periods_post_lockdown: std::vector::empty<u64>(),
        };
        let locker_id = sui::object::id<Locker>(&locker);
        sui::transfer::share_object<Locker>(locker);

        let event = InitLockerEvent { locker_id };
        sui::event::emit<InitLockerEvent>(event);

        sui::package::claim_and_keep<LIQUIDITY_LOCKER>(otw, ctx);
    }

    public fun update_lock_periods( // вызывать после деплоя
        publisher: &sui::package::Publisher,
        locker: &mut Locker, 
        periods_blocking: vector<u64>, // in epochs
        periods_post_lockdown: vector<u64>, // in epochs
    ) {
        // TODO проверить, что нельзя вызывать всем
        assert!(publisher.from_module<Locker>(), ENotOwner);
        // проверяем, что длина векторов равна
        assert!(periods_blocking.length() > 0 && 
            periods_blocking.length() == periods_post_lockdown.length(), EInvalidPeriodsLength);
            
        locker.periods_blocking = periods_blocking;
        locker.periods_post_lockdown = periods_post_lockdown;
    }

    public fun get_lock_periods(
        locker: &mut Locker,
    ): (vector<u64>, vector<u64>) {
        (locker.periods_blocking, locker.periods_post_lockdown)
    }

    public fun lock_position<CoinTypeA, CoinTypeB>(
        locker: &mut Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): vector<LockedPosition> {
        // проверяем, что позиция открыта, с ликвидностью и застейкана
        assert!(
            pool.position_manager().borrow_position_info(position_id).is_staked(),
            EPositionNotStaked
        );
        assert!(!locker.positions.contains(position_id), EPositionAlreadyOpened);
        // проверка, что индекс периода блокировки не превышает длину вектора периодов блокировки
        assert!(block_period_index < locker.periods_blocking.length(), EInvalidBlockPeriodIndex);

        let duration_block = distribution::common::epoch_to_ms(locker.periods_blocking[block_period_index]);
        let expiration_time = clock.timestamp_ms() + duration_block;
        let full_unlocking_time = expiration_time + distribution::common::epoch_to_ms(locker.periods_post_lockdown[block_period_index]);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let mut tranches = pool_tranche_manager.get_tranches(pool_id);

        assert!(tranches.length() > 0, ENoTranches);

        let lock_positions = std::vector::empty<LockedPosition>();
        let share_liquidity_to_fill = consts::lock_liquidity_share_denom() * 100; // 100%
        let mut i = 0;
        loop {
            if (i < tranches.length()) {
                break
            };

            let mut tranche = tranches.borrow_mut(i);
            if (tranche.is_filled()) {
                i = i + 1;
                continue;
            };

            let profitabilities = tranche.get_duration_profitabilities();
            assert!(profitabilities.length() == locker.periods_blocking.length(), EInvalidProfitabilitiesLength);
            
            let profitability = profitabilities[block_period_index]; // в процентах с мультипликатором

            let start_share_liquidity_to_fill = share_liquidity_to_fill;
            share_liquidity_to_fill = pool_tranche::fill_tranches(
                tranche,
                pool,
                position_id,
                share_liquidity_to_fill,
            );

            let lock_position = LockedPosition {
                id: sui::object::new(ctx),
                position_id: position_id,
                lock_liquidity_share: start_share_liquidity_to_fill - share_liquidity_to_fill,
                expiration_time: expiration_time,
                full_unlocking_time: full_unlocking_time,
                profitability: profitability,
                last_claim_time: 0,
            };
            lock_positions.push_back(lock_position);

            let lock_position_id = sui::object::id<LockedPosition>(&lock_position);
            let event = LockPositionEvent { 
                lock_position_id,
                position_id,
                lock_liquidity_share: start_share_liquidity_to_fill - share_liquidity_to_fill,
                expiration_time,
                full_unlocking_time,
                profitability,
            };
            sui::event::emit<LockPositionEvent>(event);

            if (share_liquidity_to_fill == 0) {
                // TODO для последнего транша может быть такой момент, что ликвидность позиции оказалась не полностью застейканой. Потому что часть не влезла в последний транш
                break;
            };

            i = i + 1;
        };
        assert!(share_liquidity_to_fill > 0, ETranchesFilled);

        lock_positions
    }

    // метод изменения границ позиции

    // метод получения ликвидности. Если лок полностью закончился, то с ликвидностью возвращаем позицию.
    public fun remove_liquidity<CoinTypeA, CoinTypeB, SailCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: LockedPosition,
        clock: &sui::clock::Clock
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        assert!(clock.timestamp_ms() >= lock_position.expiration_time, ELockPeriodNotEnded);

        assert!(lock_position.last_claim_time > lock_position.expiration_time, ERewardsNotCollected);

        // gauge.withdraw_position(
        //     pool,
        //     lock_position.position_id,
        //     clock,
        //     ctx,
        // );


        // let (amount_a, amount_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
        //     global_config,
        //     pool,
        //     lock_position.position_id,
        //     clock,
        // );
    }

    // метод забрать позицию, при полном разлоке
    public fun unlock_position(
        locker: &mut Locker,
        lock_position: LockedPosition,
        clock: &sui::clock::Clock,
    ) {
        assert!(locker.positions.contains(lock_position.position_id), EPositionNotLocked);
        // проверяем, что лок полностью закончен
        assert!(clock.timestamp_ms() >= lock_position.full_unlocking_time, EFullLockPeriodNotEnded);

        assert!(lock_position.last_claim_time > lock_position.expiration_time, ERewardsNotCollected);

        let event = UnlockPositionEvent {
            lock_position_id: sui::object::id<LockedPosition>(&lock_position),
            position_id: lock_position.position_id,
        };

        destroy(lock_position);
        locker.positions.remove(lock_position.position_id);

        sui::event::emit<UnlockPositionEvent>(event);
    }



    // метод сбора наград, где вызывается gauge.get_position_reward и сверху насыпается доп награда
    public fun collect_rewards<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: LockedPosition,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        // проверяем, что лок еще не закончился
        assert!(clock.timestamp_ms() < locked_position.expiration_time, ELockPeriodEnded);
        // проверяем, сколько награды получает пользователь
        let earned_amount = gauge.earned_by_position(
            pool, 
            locked_position.position_id, 
            clock,
        );
        assert!(earned_amount > 0, ENoRewards);
        //  тут ему отправляется награда
        gauge.get_position_reward(
            pool, 
            locked_position.position_id, 
            clock, 
            ctx,
        );

        // досылаем награду с лока
        // earned_amount взять процент доходности
        let income = integer_mate::full_math_u64::mul_div_ceil(
            earned_amount,
            locked_position.profitability,
            consts::profitability_rate_denom()
        );

        let lock_position_id = sui::object::id<LockedPosition>(&locked_position);
        let event = CollectRewardsEvent { 
            lock_position_id,
            earned_amount,
            income,
        };
        sui::event::emit<CollectRewardsEvent>(event);

        sui::balance::split<SailCoinType>(&mut pool.coin_b, income))
    }

    // public fun position_id(lock_position: &LockedPosition): sui::object::ID {
    //     lock_position.position_id
    // }

    // проверка, залочена ли позиция
    public fun is_position_locked(
        locker: &mut Locker,
        position_id: sui::object::ID,
    ): bool {
        locker.positions.contains(position_id)
    }

    fun destroy(lock_position: LockedPosition) {
        let LockedPosition {
            id: lock_position_id,
            position_id: _,
            lock_liquidity_share: _,
            expiration_time: _,
            full_unlocking_time: _,
            profitability: _,
            last_claim_time: _,
        } = lock_position;
        sui::object::delete(lock_position_id);
    }

}


/// Module: liquidity_locker
module liquidity_locker::liquidity_locker {
    use liquidity_locker::pool_tranche;
    use liquidity_locker::consts;

    // Bump the `VERSION` of the package.
    const VERSION: u64 = 1;

    const EInvalidPeriodsLength: u64 = 9387246581247184723;
    const EInvalidProfitabilitiesLength: u64 = 938775343456847243;
    const ENoRewards: u64 = 938724594823428742;
    const EPositionNotStaked: u64 = 93872134313534843;
    const EInvalidBlockPeriodIndex: u64 = 9387246545464428743;
    const ELockPeriodEnded: u64 = 994236928326934548;
    const EFullLockPeriodNotEnded: u64 = 989237458375783443;
    const EPositionAlreadyOpened: u64 = 93872465763464333;
    const ENoTranches: u64 = 98237423747238423;
    const ERewardsNotCollected: u64 = 9129448645674544;
    const ELockPeriodNotEnded: u64 = 912049583475749665;
    const ETrancheManagerPaused: u64 = 9160235342734283752;
    const ENotClaimedRewards: u64 = 98723476210634634;
    const EClaimEpochIncorrect: u64 = 923529561737128424;
    const ENoLiquidityToRemove: u64 = 918775475736374232;
    const EInvalidGaugePool: u64 = 95782527648184327;
    const EIncorrectDistributionOfLiquidityA: u64 = 953462374278342734;
    const EIncorrectDistributionOfLiquidityB: u64 = 953462374278342735;
    const EInvalidShareLiquidityToFill: u64 = 9023542358239423823;

    /// Capability for administrative functions in the protocol.
    /// This capability is required for managing global settings and protocol parameters.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the capability
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    /// Capability for managing liquidity locker operations.
    /// This capability is required for performing actions related to locking and unlocking liquidity positions.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the capability
    public struct LockerCap has store, key {
        id: sui::object::UID,
    }

    // структура общего стейта
    public struct Locker has store, key {
        id: sui::object::UID,
        locker_cap: Option<locker_cap::locker_cap::LockerCap>,
        version: u64,
        // мапка по лоченым позициям
        positions: sui::table::Table<ID, bool>,
        // периоды блокировки, в эпохах
        periods_blocking: vector<u64>, // in epochs
        // периоды после блокировки, длина обз как periods_blocking
        periods_post_lockdown: vector<u64>, // in epochs
        pause: bool,
    }

    // структура для лоченых позиций, возвращаемая пользователю как факт владения
    public struct LockedPosition has store, key {
        id: sui::object::UID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        expiration_time: u64, 
        full_unlocking_time: u64, 
        profitability: u64,
        last_reward_claim_time: u64,
        last_growth_inside: u128,
        lock_liquidity_info: LockLiquidityInfo,
    }

    public struct LockLiquidityInfo has store {
        total_lock_liquidity: u128, // сколько изначально ликвидности залочено
        current_lock_liquidity: u128, // сколько сейчас ликвидности залочено
        last_remove_liquidity_time: u64, // s
    }

    public struct SplitPositionResult has copy, drop {
        position_id: sui::object::ID,
        liquidity: u128,
    }

    public struct InitLockerEvent has copy, drop {
        locker_id: sui::object::ID,
    }

    public struct LockerPauseEvent has copy, drop {
        locker_id: sui::object::ID,
        pause: bool,
    }

    public struct CreateLockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        total_lock_liquidity: u128,
        expiration_time: u64,
        full_unlocking_time: u64,
        profitability: u64,
    }

    public struct UnlockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
    }

    public struct CollectRewardsEvent has copy, drop {
        lock_position_id: sui::object::ID,
        reward_type: std::type_name::TypeName,
        last_reward_claim_time: u64,
        next_reward_claim_time: u64,
        income: u64,
        reward_balance: u64,
    }
    
    fun init(ctx: &mut sui::tx_context::TxContext) {
        let locker = Locker {
            id: sui::object::new(ctx),
            locker_cap: option::none<locker_cap::locker_cap::LockerCap>(),
            version: VERSION,
            positions: sui::table::new<ID, bool>(ctx),
            periods_blocking: std::vector::empty<u64>(),
            periods_post_lockdown: std::vector::empty<u64>(),
            pause: false,
        };
        let locker_id = sui::object::id<Locker>(&locker);
        sui::transfer::share_object<Locker>(locker);
    
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));

        let event = InitLockerEvent { locker_id };
        sui::event::emit<InitLockerEvent>(event);
    }
    
    public fun init_locker( // вызывать после деплоя
        _admin_cap: &AdminCap,
        create_locker_cap: &locker_cap::locker_cap::CreateCap,
        locker: &mut Locker, 
        periods_blocking: vector<u64>, // in epochs
        periods_post_lockdown: vector<u64>, // in epochs
        ctx: &mut sui::tx_context::TxContext,
    ) {
        // проверяем, что длина векторов равна
        assert!(periods_blocking.length() > 0 && 
            periods_blocking.length() == periods_post_lockdown.length(), EInvalidPeriodsLength);

        let locker_cap = create_locker_cap.create_locker_cap(
            ctx
        );
        locker.locker_cap.fill(locker_cap);

        locker.periods_blocking = periods_blocking;
        locker.periods_post_lockdown = periods_post_lockdown;
    }

    
    public fun update_lock_periods(
        _admin_cap: &AdminCap,
        locker: &mut Locker, 
        periods_blocking: vector<u64>, // in epochs
        periods_post_lockdown: vector<u64>, // in epochs
    ) {
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

    public fun locker_pause(
        _admin_cap: &AdminCap,
        locker: &mut Locker,
        pause: bool,
    ) {
        locker.pause = pause;
        let event = LockerPauseEvent {
            locker_id: sui::object::id<Locker>(locker),
            pause,
        };
        sui::event::emit<LockerPauseEvent>(event);
    }

    public fun pause(
        locker: &Locker,
    ): bool {
        locker.pause
    }
    
    public fun lock_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): vector<LockedPosition> {
        assert!(!locker.pause, ETrancheManagerPaused);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        // проверяем, что позиция открыта, с ликвидностью и застейкана
        assert!(
            pool.position_manager().borrow_position_info(position_id).is_staked(),
            EPositionNotStaked
        );
        assert!(!locker.positions.contains(position_id), EPositionAlreadyOpened);
        // проверка, что индекс периода блокировки не превышает длину вектора периодов блокировки
        assert!(block_period_index < locker.periods_blocking.length(), EInvalidBlockPeriodIndex);

        let duration_block = distribution::common::epoch_to_seconds(locker.periods_blocking[block_period_index]);
        let current_time = clock.timestamp_ms() / 1000;
        // TODO срок округлить до эпохи
        let expiration_time = current_time + duration_block;
        let full_unlocking_time = expiration_time + distribution::common::epoch_to_seconds(locker.periods_post_lockdown[block_period_index]);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let tranches = pool_tranche_manager.get_tranches(pool_id);

        assert!(tranches.length() > 0, ENoTranches);

        gauge.lock_position(locker.locker_cap.borrow(), position_id);

        let current_growth_inside = gauge.get_current_growth_inside(pool, position_id, current_time);

        let mut lock_positions = std::vector::empty<LockedPosition>();
        let mut position_id_copy = position_id;
        let mut i = 0;
        while (i < tranches.length()) {

            let tranche = tranches.borrow_mut(i);
            if (tranche.is_filled()) {
                i = i + 1;
                continue
            };

            let tranche_id = sui::object::id<pool_tranche::PoolTranche>(tranche);

            let profitabilities = tranche.get_duration_profitabilities();
            assert!(profitabilities.length() == locker.periods_blocking.length(), EInvalidProfitabilitiesLength);
            
            let profitability = profitabilities[block_period_index]; // в процентах с мультипликатором
        
            let (delta_volume, volume_in_coin_a) = tranche.get_free_volume();
            let liquidity_in_token = if (volume_in_coin_a) {
                liquidity_locker::locker_utils::calculate_position_liquidity_in_token_a(pool, position_id_copy)
            } else {
                liquidity_locker::locker_utils::calculate_position_liquidity_in_token_b(pool, position_id_copy)
            };
            let (_position_id, lock_liquidity, split) = if (liquidity_in_token > delta_volume) { // делим позицию
                let share_first_part = integer_mate::math_u128::hi(integer_mate::full_math_u128::mul_div_floor(
                    delta_volume,
                    consts::lock_liquidity_share_denom() as u128,
                    liquidity_in_token,
                ));
                let (split_position_result1, split_position_result2) = split_position_internal(
                    global_config,
                    distribution_config,
                    locker,
                    gauge,
                    pool,
                    position_id_copy,
                    share_first_part,
                    clock,
                    ctx,
                );
                position_id_copy = split_position_result2.position_id; // для следующей итерации цикла

                pool_tranche::fill_tranches(
                    tranche,
                    delta_volume,
                );
                (split_position_result1.position_id, split_position_result1.liquidity, true)
            } else {
                pool_tranche::fill_tranches(
                    tranche,
                    liquidity_in_token,
                );
                (position_id_copy, pool.position_manager().borrow_position_info(position_id_copy).info_liquidity(), false)
            };

            let lock_liquidity_info = LockLiquidityInfo {
                total_lock_liquidity: lock_liquidity,   
                current_lock_liquidity: lock_liquidity,
                last_remove_liquidity_time: 0,
            };
            let lock_position = LockedPosition {
                id: sui::object::new(ctx),
                position_id: _position_id,
                tranche_id: tranche_id,
                expiration_time: expiration_time,
                full_unlocking_time: full_unlocking_time,
                profitability: profitability,
                last_growth_inside: current_growth_inside,
                last_reward_claim_time: current_time,
                lock_liquidity_info,
            };

            let lock_position_id = sui::object::id<LockedPosition>(&lock_position);
            let event = CreateLockPositionEvent { 
                lock_position_id,
                position_id: lock_position.position_id,
                tranche_id: lock_position.tranche_id,
                total_lock_liquidity: lock_position.lock_liquidity_info.total_lock_liquidity,
                expiration_time: lock_position.expiration_time,
                full_unlocking_time: lock_position.full_unlocking_time,
                profitability: lock_position.profitability,
            };
            sui::event::emit<CreateLockPositionEvent>(event);

            locker.positions.add(lock_position.position_id, true);
            gauge.lock_position(locker.locker_cap.borrow(), lock_position.position_id);
            lock_positions.push_back(lock_position);

            if (!split) {
                break
            };

            i = i + 1;
        };
        // для позиции, которая не влезла в последний транш
        // будет сплит, но залочена будет только та позиция, которая влезла в последний транш

        lock_positions
    }
    

    // метод получения ликвидности
    // если выводится вся ликвидность, то позиция разлочена и снимается со стейка
    public fun remove_lock_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        locker: &mut Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        assert!(!locker.pause, ETrancheManagerPaused);
        let current_time = clock.timestamp_ms() / 1000;
        assert!(current_time >= lock_position.expiration_time, ELockPeriodNotEnded);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        // если время разлока закончилось, то можно только полность разлочить позу
        // assert!(current_time < lock_position.full_unlocking_time, EFullLockPeriodEnded);

        // перед выводом склеймить все награды (не обз)
        // assert!(lock_position.last_reward_claim_time >= lock_position.expiration_time, ERewardsNotCollected);

        let full_remove = if (current_time >= lock_position.full_unlocking_time) {
            true
        } else {
            false
        };

        // определить, сколько ликвы можно вывести
        let mut remove_liquidity_amount = if (full_remove) {
            lock_position.lock_liquidity_info.current_lock_liquidity
        } else {
            // определить, сколько времени прошло после экспирации
            if (lock_position.lock_liquidity_info.last_remove_liquidity_time == 0) {
                lock_position.lock_liquidity_info.last_remove_liquidity_time = lock_position.expiration_time;
            };
            let number_epochs_after_expiration = distribution::common::number_epochs_in_timestamp(current_time - lock_position.lock_liquidity_info.last_remove_liquidity_time);
            assert!(number_epochs_after_expiration > 0, ENoLiquidityToRemove);

            // определить, какую часть от тотал можно вывести
            integer_mate::full_math_u128::mul_div_floor(
                lock_position.lock_liquidity_info.total_lock_liquidity,
                number_epochs_after_expiration as u128,
                distribution::common::number_epochs_in_timestamp(lock_position.full_unlocking_time - lock_position.expiration_time) as u128,
            )
        };
        assert!(remove_liquidity_amount > 0, ENoLiquidityToRemove);
        if (remove_liquidity_amount > lock_position.lock_liquidity_info.current_lock_liquidity) {
            remove_liquidity_amount = lock_position.lock_liquidity_info.current_lock_liquidity;
        };

        // расстейкать позу
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB>(
            locker.locker_cap.borrow(),
            pool,
            lock_position.position_id,
            clock,
        );

        let ( removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &mut position,
            remove_liquidity_amount,
            clock,
        );

        if (full_remove) {
            unlock_position(
                locker, 
                lock_position, 
                gauge, 
                clock,
            );
            // TODO event
            transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
        } else {
            // застейкать позу
            gauge.deposit_position_by_locker(
                locker.locker_cap.borrow(),
                pool,
                position,
                clock,
                ctx,
            );
            lock_position.lock_liquidity_info.current_lock_liquidity = lock_position.lock_liquidity_info.current_lock_liquidity - remove_liquidity_amount;
            lock_position.lock_liquidity_info.last_remove_liquidity_time = distribution::common::epoch_start(current_time);
            transfer::public_transfer<LockedPosition>(lock_position, sui::tx_context::sender(ctx));
        };

        (removed_a, removed_b)
    }

    // разлок позиции
    public fun unlock_position<CoinTypeA, CoinTypeB>(
        locker: &mut Locker,
        lock_position: LockedPosition,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
    ) {
        assert!(!locker.pause, ETrancheManagerPaused);
        // проверяем, что лок полностью закончен
        assert!(clock.timestamp_ms()/1000 >= lock_position.full_unlocking_time, EFullLockPeriodNotEnded);

        assert!(lock_position.last_reward_claim_time > lock_position.expiration_time, ERewardsNotCollected);

        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);

        let event = UnlockPositionEvent {
            lock_position_id: sui::object::id<LockedPosition>(&lock_position),
        };

        locker.positions.remove(lock_position.position_id);
        destroy(lock_position);

        sui::event::emit<UnlockPositionEvent>(event);
    }

    // метод сбора наград
    // можно клеймить только в эпоху следующую за последней полученной наградой и не в текущую
    // тип награды за лок позиции может отличаться от типа награды за стейкинг
    // RewardCoinType - тип награды, за стейкинг позиции
    // LockRewardCoinType - тип награды, за лок позиции
    public fun collect_rewards<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition,
        claim_epoch: u64, // timestamp s
        clock: &sui::clock::Clock,
    ): sui::balance::Balance<LockRewardCoinType> {
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(locked_position.last_reward_claim_time < locked_position.expiration_time, ENotClaimedRewards);

        // получаем баланс награды по доходности
        let reward_balance = get_rewards<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
            pool_tranche_manager,
            gauge,
            pool,
            locked_position,
            claim_epoch,
            clock,
        );

        reward_balance
    }

    // метод сбора наград в качестве токена SAIL
    // SAIL токен награды сразу лочится на максимальный период
    // можно клеймить только в эпоху следующую за последней полученной наградой
    public fun collect_rewards_sail<CoinTypeA, CoinTypeB, RewardCoinType, SailCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition,
        claim_epoch: u64, // timestamp s
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(locked_position.last_reward_claim_time < locked_position.expiration_time, ENotClaimedRewards);

        let reward_balance = get_rewards<CoinTypeA, CoinTypeB, RewardCoinType, SailCoinType>(
            pool_tranche_manager,
            gauge,
            pool,
            locked_position,
            claim_epoch,
            clock,
        );

        voting_escrow.create_lock(
            sui::coin::from_balance(reward_balance, ctx),
            distribution::common::max_lock_time(),
            true,
            clock,
            ctx
        );
    }

    fun get_rewards<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition,
        claim_epoch: u64,
        clock: &sui::clock::Clock,
    ): sui::balance::Balance<LockRewardCoinType> {
        let current_epoch = distribution::common::current_period(clock);
        // TODO next_reward_claim_time если expiration_time округляем до эпохи
        let next_reward_claim_time = if (distribution::common::epoch_next(locked_position.last_reward_claim_time) > locked_position.expiration_time) {
            locked_position.expiration_time
        } else {
            distribution::common::epoch_next(locked_position.last_reward_claim_time)
        };

        // нельзя клеймить в текущую эпоху, награды еще не занесены в транш
        assert!(claim_epoch == distribution::common::epoch_start(locked_position.last_reward_claim_time) && current_epoch >= next_reward_claim_time, EClaimEpochIncorrect); 

        // проверяем, сколько награды получает пользователь от locked_position.last_reward_claim_time до next_reward_claim_time
        let (earned_amount, last_growth_inside) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, RewardCoinType>(
            pool, 
            locked_position.position_id, 
            locked_position.last_growth_inside,
        );
        assert!(earned_amount > 0, ENoRewards);
        locked_position.last_growth_inside = last_growth_inside;

        // досылаем награду с лока
        // от earned_amount взять процент доходности
        let income = integer_mate::full_math_u64::mul_div_ceil(
            earned_amount,
            locked_position.profitability,
            consts::profitability_rate_denom()
        );

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        // получаем баланс награды по доходности
        let reward_balance = pool_tranche_manager.get_reward_balance<LockRewardCoinType>(
            pool_id,
            locked_position.tranche_id,
            income,
            distribution::common::epoch_start(locked_position.last_reward_claim_time),
        );

        let lock_position_id = sui::object::id<LockedPosition>(locked_position);
        let reward_type = std::type_name::get<LockRewardCoinType>();
        let event = CollectRewardsEvent { 
            lock_position_id,
            reward_type,
            last_reward_claim_time: locked_position.last_reward_claim_time,
            next_reward_claim_time,
            income,
            reward_balance: reward_balance.value<LockRewardCoinType>(),
        };
        sui::event::emit<CollectRewardsEvent>(event);

        locked_position.last_reward_claim_time = next_reward_claim_time;
        reward_balance
    }

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
            tranche_id: _,
            expiration_time: _,
            full_unlocking_time: _,
            profitability: _,
            last_reward_claim_time: _,
            last_growth_inside: _,
            lock_liquidity_info: LockLiquidityInfo {
                total_lock_liquidity: _,
                current_lock_liquidity: _,
                last_remove_liquidity_time: _,
            },
        } = lock_position;
        sui::object::delete(lock_position_id);
    }

    // сплит позиции на две
    public fun split_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: LockedPosition,
        share_first_part: u64, // 0..100 в lock_liquidity_share_denom
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (LockedPosition, LockedPosition) {
        assert!(!locker.pause, ETrancheManagerPaused);
        let current_time = clock.timestamp_ms() / 1000;
        assert!(current_time < lock_position.expiration_time, ELockPeriodEnded);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);

        // убрать везде из лока эту позу
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);
        locker.positions.remove(lock_position.position_id);

        let (split_position_result1, split_position_result2) = split_position_internal(
            global_config,
            distribution_config,
            locker,
            gauge,
            pool,
            lock_position.position_id,
            share_first_part,
            clock,
            ctx,
        );
            // создать соответствующие локи
        let lock_liquidity_info1 = LockLiquidityInfo {
            total_lock_liquidity: split_position_result1.liquidity,   
            current_lock_liquidity: split_position_result1.liquidity,
            last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time,
        };
        let lock_position1 = LockedPosition {
            id: sui::object::new(ctx),
            position_id: split_position_result1.position_id,
            tranche_id: lock_position.tranche_id,
            expiration_time: lock_position.expiration_time,
            full_unlocking_time: lock_position.full_unlocking_time,
            profitability: lock_position.profitability,
            last_growth_inside: 0,
            last_reward_claim_time: lock_position.last_reward_claim_time,
            lock_liquidity_info: lock_liquidity_info1,
        };

        let lock_liquidity_info2 = LockLiquidityInfo {
            total_lock_liquidity: split_position_result2.liquidity,   
            current_lock_liquidity: split_position_result2.liquidity,
            last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time,
        };
        let lock_position2 = LockedPosition {
            id: sui::object::new(ctx),
            position_id: split_position_result2.position_id,
            tranche_id: lock_position.tranche_id,
            expiration_time: lock_position.expiration_time,
            full_unlocking_time: lock_position.full_unlocking_time,
            profitability: lock_position.profitability,
            last_growth_inside: 0,
            last_reward_claim_time: lock_position.last_reward_claim_time,
            lock_liquidity_info: lock_liquidity_info2,
        };

        destroy(lock_position);
        gauge.lock_position(locker.locker_cap.borrow(), lock_position1.position_id);
        gauge.lock_position(locker.locker_cap.borrow(), lock_position2.position_id);
        locker.positions.add(lock_position1.position_id, true);
        locker.positions.add(lock_position2.position_id, true);
        
        (lock_position1, lock_position2)
    }
    
    fun split_position_internal<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        share_first_part: u64, // 0..100 в lock_liquidity_share_denom
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (SplitPositionResult, SplitPositionResult) {
        // расстейкать позу
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB>(
            locker.locker_cap.borrow(),
            pool,
            position_id,
            clock,
        );

        let (lower_tick, upper_tick) = position.tick_range();
        let total_liquidity = position.liquidity();
        let (liquidity1, liquidity2) = calculate_liquidity_split(
            total_liquidity,
            share_first_part
        );

        // выводим ликву и закрываем позу
        let (mut removed_a, mut removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &mut position,
            total_liquidity,
            clock,
            ctx,
        );

        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(global_config, pool, position);
        
        let mut position1 = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(lower_tick),
            integer_mate::i32::as_u32(upper_tick),
            ctx
        );
        let position1_id = object::id<clmm_pool::position::Position>(&position1);
        
        let mut position2 = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(lower_tick),
            integer_mate::i32::as_u32(upper_tick),
            ctx
        );
        let position2_id = object::id<clmm_pool::position::Position>(&position2);

        let receipt1 = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &mut position1,
            liquidity1,
            clock
        );
        let receipt2 = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &mut position2,
            liquidity2,
            clock
        );
        let (pay_amount_a1, pay_amount_b1) = receipt1.add_liquidity_pay_amount();
        let (pay_amount_a2, pay_amount_b2) = receipt2.add_liquidity_pay_amount();
        assert!(pay_amount_a1 + pay_amount_a2 == removed_a.value<CoinTypeA>(), EIncorrectDistributionOfLiquidityA);
        assert!(pay_amount_b1 + pay_amount_b2 == removed_b.value<CoinTypeB>(), EIncorrectDistributionOfLiquidityB);

        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            removed_a.split<CoinTypeA>(pay_amount_a1),
            removed_b.split<CoinTypeB>(pay_amount_b1),
            receipt1,
        );
        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            removed_a,
            removed_b,
            receipt2,
        );

        distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position1,
            clock,
            ctx,
        );
        distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position2,
            clock,
            ctx,
        );
        
        (SplitPositionResult { position_id: position1_id, liquidity: liquidity1 }, 
            SplitPositionResult { position_id: position2_id, liquidity: liquidity2 } )
    }

    fun calculate_liquidity_split(
        total_liquidity: u128,
        share_first_part: u64,
    ): (u128, u128) {
        assert!(share_first_part <= consts::lock_liquidity_share_denom(), EInvalidShareLiquidityToFill);
        let liquidity1 = integer_mate::full_math_u128::mul_div_floor(
            total_liquidity,
            share_first_part as u128,
            consts::lock_liquidity_share_denom() as u128
        );
        
        (liquidity1, total_liquidity - liquidity1)
    }

    // метод снятия ликвидности и сбора комиссии
    fun remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): ( sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let ( removed_a,  removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            liquidity,
            clock
        );

        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            false
        );
        let coin_a = sui::coin::from_balance<CoinTypeA>(collected_fee_a, ctx);
        let coin_b = sui::coin::from_balance<CoinTypeB>(collected_fee_b, ctx);
        if (coin_a.value<CoinTypeA>() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(coin_a, tx_context::sender(ctx));
        } else {
            coin_a.destroy_zero();
        };
        if (coin_b.value<CoinTypeB>() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(coin_b, tx_context::sender(ctx));
        } else {
            coin_b.destroy_zero();
        };

        (removed_a, removed_b)
    }
    
    // TODO: метод изменения границ позиции
    
    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let locker = Locker {
            id: sui::object::new(ctx),
            locker_cap: option::none<locker_cap::locker_cap::LockerCap>(),
            version: VERSION,
            positions: sui::table::new<ID, bool>(ctx),
            periods_blocking: std::vector::empty<u64>(),
            periods_post_lockdown: std::vector::empty<u64>(),
            pause: false,
        };
        let locker_id = sui::object::id<Locker>(&locker);
        sui::transfer::share_object<Locker>(locker);
    
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
    }
}

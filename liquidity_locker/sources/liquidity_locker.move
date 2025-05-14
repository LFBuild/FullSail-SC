/// Module: liquidity_locker
module liquidity_locker::liquidity_locker {
    use liquidity_locker::pool_tranche;
    use liquidity_locker::consts;
    use liquidity_locker::locker_utils;
    
    // Bump the `VERSION` of the package.
    const VERSION: u64 = 1;

    const EInvalidPeriodsLength: u64 = 938724658124718472;
    const EInvalidProfitabilitiesLength: u64 = 93877534345684724;
    const ENoRewards: u64 = 93872459482342874;
    const EPositionNotStaked: u64 = 9387213431353484;
    const EInvalidBlockPeriodIndex: u64 = 938724654546442874;
    const ELockPeriodEnded: u64 = 99423692832693454;
    const EFullLockPeriodNotEnded: u64 = 98923745837578344;
    const EPositionAlreadyLocked: u64 = 9387246576346433;
    const ENoTranches: u64 = 9823742374723842;
    const ERewardsNotCollected: u64 = 912944864567454;
    const ELockPeriodNotEnded: u64 = 91204958347574966;
    const ELockManagerPaused: u64 = 916023534273428375;
    const ENotClaimedRewards: u64 = 9872347621063463;
    const EClaimEpochIncorrect: u64 = 92352956173712842;
    const ENoLiquidityToRemove: u64 = 91877547573637423;
    const EInvalidGaugePool: u64 = 9578252764818432;
    const EIncorrectDistributionOfLiquidityA: u64 = 95346237427834273;
    const EIncorrectDistributionOfLiquidityB: u64 = 95346237427834273;
    const EInvalidShareLiquidityToFill: u64 = 902354235823942382;
    const EPositionNotLocked: u64 = 92035925692467234;
    const ENotChangedTickRange: u64 = 96203676234264517;
    const EIncorrectSwapResultA: u64 = 9259346230481212;
    const EIncorrectSwapResultB: u64 = 9259346230481213;
    
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

    /// Main state structure for the liquidity locker protocol.
    /// This structure holds all the essential data for managing locked liquidity positions.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the locker instance
    /// * `locker_cap` - Optional capability for managing locker operations
    /// * `version` - Protocol version number
    /// * `positions` - Table mapping position IDs to their locked status
    /// * `periods_blocking` - Vector of lock periods measured in epochs
    /// * `periods_post_lockdown` - Vector of post-lock periods in epochs (must match length of periods_blocking)
    /// * `pause` - Flag indicating if the locker is paused
    public struct Locker has store, key {
        id: sui::object::UID,
        locker_cap: Option<locker_cap::locker_cap::LockerCap>,
        version: u64,
        positions: sui::table::Table<ID, bool>,
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
        pause: bool,
    }

    /// Structure representing a locked liquidity position that is returned to the user as proof of ownership.
    /// This structure contains all the necessary information about a locked position including its status, timing parameters.
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - The type of the first token in the liquidity pair
    /// * `CoinTypeB` - The type of the second token in the liquidity pair
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the locked position
    /// * `position_id` - ID of the underlying liquidity position
    /// * `tranche_id` - ID of the tranche this position belongs to
    /// * `expiration_time` - Timestamp when the lock period expires
    /// * `full_unlocking_time` - Timestamp when the position can be fully unlocked
    /// * `profitability` - Profitability rate in parts multiplied by profitability_rate_denom
    /// * `last_reward_claim_time` - Timestamp of the last reward claim
    /// * `last_growth_inside` - Last recorded growth inside the position's range
    /// * `lock_liquidity_info` - Information about the locked liquidity
    /// * `coin_a` - Accumulated balance of the first token from position rebalancing that will be returned to position liquidity
    /// * `coin_b` - Accumulated balance of the second token from position rebalancing that will be returned to position liquidity
    public struct LockedPosition<phantom CoinTypeA, phantom CoinTypeB> has store, key {
        id: sui::object::UID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        expiration_time: u64, 
        full_unlocking_time: u64, 
        profitability: u64,
        last_reward_claim_time: u64,
        last_growth_inside: u128,
        lock_liquidity_info: LockLiquidityInfo,
        coin_a: sui::balance::Balance<CoinTypeA>,
        coin_b: sui::balance::Balance<CoinTypeB>,
    }

    /// Structure containing information about locked liquidity position.
    /// 
    /// # Fields
    /// * `total_lock_liquidity` - Initial amount of liquidity that was locked
    /// * `current_lock_liquidity` - Current amount of locked liquidity
    /// * `last_remove_liquidity_time` - Timestamp of the last liquidity removal in seconds
    public struct LockLiquidityInfo has store {
        total_lock_liquidity: u128,
        current_lock_liquidity: u128,
        last_remove_liquidity_time: u64,
    }

    /// Structure representing the result of splitting a position into two parts.
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - The type of the first token in the liquidity pair
    /// * `CoinTypeB` - The type of the second token in the liquidity pair
    /// 
    /// # Fields
    /// * `position_id` - Unique identifier for the split position
    /// * `liquidity` - Amount of liquidity allocated to this split position
    public struct SplitPositionResult<phantom CoinTypeA, phantom CoinTypeB> has copy, drop {
        position_id: sui::object::ID,
        liquidity: u128,
    }

    /// Event emitted when a new locker is initialized.
    /// 
    /// # Fields
    /// * `locker_id` - Unique identifier of the newly created locker
    public struct InitLockerEvent has copy, drop {
        locker_id: sui::object::ID,
    }

    /// Event emitted when the blocking and post-lockdown periods are updated.
    /// 
    /// # Fields
    /// * `locker_id` - Unique identifier of the locker
    /// * `periods_blocking` - Vector of blocking periods in epochs
    /// * `periods_post_lockdown` - Vector of post-lockdown periods in epochs
    public struct UpdateLockPeriodsEvent has copy, drop {   
        locker_id: sui::object::ID,
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
    }

    /// Event emitted when the locker's pause state changes.
    /// 
    /// # Fields
    /// * `locker_id` - Unique identifier of the locker
    /// * `pause` - New pause state (true if paused, false if unpaused)
    public struct LockerPauseEvent has copy, drop {
        locker_id: sui::object::ID,
        pause: bool,
    }

    /// Event emitted when a new locked position is created.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `position_id` - Unique identifier of the underlying liquidity position
    /// * `tranche_id` - Unique identifier of the tranche this position belongs to
    /// * `total_lock_liquidity` - Total amount of liquidity locked in the position
    /// * `expiration_time` - Timestamp when the lock period ends
    /// * `full_unlocking_time` - Timestamp when the position can be fully unlocked
    /// * `profitability` - Profitability rate for this locked position
    public struct CreateLockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        total_lock_liquidity: u128,
        expiration_time: u64,
        full_unlocking_time: u64,
        profitability: u64,
    }

    /// Event emitted when a locked position is unlocked.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the unlocked position
    public struct UnlockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
    }

    /// Event emitted when rewards are collected from a locked position.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `reward_type` - Type of the reward token being collected
    /// * `last_reward_claim_time` - Timestamp of the previous reward claim
    /// * `next_reward_claim_time` - Timestamp when these rewards were claimed
    /// * `income` - Amount of rewards earned based on profitability
    /// * `reward_balance` - Total balance of rewards collected
    public struct CollectRewardsEvent has copy, drop {
        lock_position_id: sui::object::ID,
        reward_type: std::type_name::TypeName,
        last_reward_claim_time: u64,
        next_reward_claim_time: u64,
        income: u64,
        reward_balance: u64,
    }

    /// Event emitted when the tick range of a locked position is changed.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `new_position_id` - Unique identifier of the new position with updated range
    /// * `new_lock_liquidity` - Amount of liquidity in the new position
    /// * `new_tick_lower` - New lower tick boundary of the position
    /// * `new_tick_upper` - New upper tick boundary of the position
    public struct ChangeRangePositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        new_position_id: sui::object::ID,
        new_lock_liquidity: u128,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
    }
    
    /// Initializes the liquidity locker module.
    /// 
    /// This function creates and initializes the main Locker object with default values,
    /// creates an AdminCap for administrative control, and emits an initialization event.
    /// 
    /// # Arguments
    /// * `ctx` - The transaction context
    /// 
    /// # Events
    /// Emits `InitLockerEvent` with the ID of the created locker
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
    
    /// Initializes the locker with blocking and post-lockdown periods.
    /// 
    /// This function should be called after deployment to set up the locker with
    /// specified blocking and post-lockdown periods. It creates a locker capability
    /// and configures the time periods for position locking.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `create_locker_cap` - Capability to create locker functionality
    /// * `locker` - The locker object to initialize
    /// * `periods_blocking` - Vector of blocking periods in epochs
    /// * `periods_post_lockdown` - Vector of post-lockdown periods in epochs
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If periods_blocking is empty
    /// * If periods_blocking and periods_post_lockdown have different lengths
    public fun init_locker(
        _admin_cap: &AdminCap,
        create_locker_cap: &locker_cap::locker_cap::CreateCap,
        locker: &mut Locker, 
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(periods_blocking.length() > 0 && 
            periods_blocking.length() == periods_post_lockdown.length(), EInvalidPeriodsLength);

        let locker_cap = create_locker_cap.create_locker_cap(
            ctx
        );
        locker.locker_cap.fill(locker_cap);

        locker.periods_blocking = periods_blocking;
        locker.periods_post_lockdown = periods_post_lockdown;

        let event = UpdateLockPeriodsEvent {
            locker_id: sui::object::id<Locker>(locker),
            periods_blocking,
            periods_post_lockdown,
        };
        sui::event::emit<UpdateLockPeriodsEvent>(event);
    }

    
    /// Updates the blocking and post-lockdown periods for the locker.
    /// 
    /// This function allows administrators to modify the time periods used for position locking.
    /// Both vectors must have the same length and cannot be empty.
    /// New periods will only be applied to new position locks, existing locked positions will keep their original periods.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `locker` - The locker object to update
    /// * `periods_blocking` - Vector of blocking periods in epochs
    /// * `periods_post_lockdown` - Vector of post-lockdown periods in epochs
    /// 
    /// # Aborts
    /// * If periods_blocking is empty
    /// * If periods_blocking and periods_post_lockdown have different lengths
    public fun update_lock_periods(
        _admin_cap: &AdminCap,
        locker: &mut Locker, 
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
    ) {
        assert!(periods_blocking.length() > 0 && 
            periods_blocking.length() == periods_post_lockdown.length(), EInvalidPeriodsLength);
            
        locker.periods_blocking = periods_blocking;
        locker.periods_post_lockdown = periods_post_lockdown;

        let event = UpdateLockPeriodsEvent {
            locker_id: sui::object::id<Locker>(locker),
            periods_blocking,
            periods_post_lockdown,
        };
        sui::event::emit<UpdateLockPeriodsEvent>(event);
    }

    /// Returns the current blocking and post-lockdown periods configured for the locker.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to query
    /// 
    /// # Returns
    /// A tuple containing two vectors:
    /// * First vector contains the blocking periods in epochs
    /// * Second vector contains the post-lockdown periods in epochs
    public fun get_lock_periods(
        locker: &mut Locker,
    ): (vector<u64>, vector<u64>) {
        (locker.periods_blocking, locker.periods_post_lockdown)
    }

    /// Updates the pause state of the locker and emits an event.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `locker` - The locker object to update
    /// * `pause` - New pause state (true to pause, false to unpause)
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

    /// Returns the current pause state of the locker.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to query
    /// 
    /// # Returns
    /// Boolean indicating if the locker is paused (true) or active (false)
    public fun pause(
        locker: &Locker,
    ): bool {
        locker.pause
    }
    
    /// Locks a position in the locker by distributing it across available tranches.
    /// The position may be split if it doesn't fit entirely in a single tranche.
    /// Only staked positions can be locked.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the CLMM pool
    /// * `vault` - Global reward vault
    /// * `distribution_config` - Distribution configuration
    /// * `locker` - The locker object to use
    /// * `pool_tranche_manager` - Manager for pool tranches
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `position_id` - ID of the position to lock
    /// * `block_period_index` - Index of the blocking period to use from the periods_blocking vector to determine the lock duration
    /// * `clock` - Clock for time-based operations
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Vector of locked positions created from the original position
    /// 
    /// # Aborts
    /// * `ELockManagerPaused` - If the locker is paused
    /// * `EInvalidGaugePool` - If the gauge pool is invalid
    /// * `EPositionNotStaked` - If the position is not staked
    /// * `EPositionAlreadyLocked` - If the position is already locked
    /// * `EInvalidBlockPeriodIndex` - If the block period index is invalid
    /// * `ENoTranches` - If there are no tranches available
    /// * `EInvalidProfitabilitiesLength` - If the profitabilities length is invalid
    public fun lock_position<CoinTypeA, CoinTypeB, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): vector<LockedPosition<CoinTypeA, CoinTypeB>> {
        assert!(!locker.pause, ELockManagerPaused);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(
            pool.position_manager().borrow_position_info(position_id).is_staked(),
            EPositionNotStaked
        );
        assert!(!locker.positions.contains(position_id), EPositionAlreadyLocked);
        assert!(block_period_index < locker.periods_blocking.length(), EInvalidBlockPeriodIndex);

        let duration_block = distribution::common::epoch_to_seconds(locker.periods_blocking[block_period_index]);
        let current_time = clock.timestamp_ms() / 1000;
        let expiration_time = distribution::common::epoch_next(current_time + duration_block);
        let full_unlocking_time = expiration_time + distribution::common::epoch_to_seconds(locker.periods_post_lockdown[block_period_index]);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let tranches = pool_tranche_manager.get_tranches(pool_id);

        assert!(tranches.length() > 0, ENoTranches);

        let current_growth_inside = gauge.get_current_growth_inside(pool, position_id, current_time);

        let mut lock_positions = std::vector::empty<LockedPosition<CoinTypeA, CoinTypeB>>();
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
            
            let profitability = profitabilities[block_period_index];
        
            let (delta_volume, volume_in_coin_a) = tranche.get_free_volume();
            let liquidity_in_token = if (volume_in_coin_a) {
                locker_utils::calculate_position_liquidity_in_token_a(pool, position_id_copy)
            } else {
                locker_utils::calculate_position_liquidity_in_token_b(pool, position_id_copy)
            };

            let (
                _position_id, 
                lock_liquidity, 
                remainder_a,
                remainder_b,
                split,
            ) = if (liquidity_in_token > delta_volume) { // split position
                let share_first_part = integer_mate::full_math_u128::mul_div_floor(
                    delta_volume,
                    consts::lock_liquidity_share_denom() as u128,
                    liquidity_in_token,
                ) as u64;
                let (
                    split_position_result1, 
                    split_position_result2,
                    remainder_a,
                    remainder_b,
                ) = split_position_internal<CoinTypeA, CoinTypeB, EpochOSail>(
                    global_config,
                    vault,
                    distribution_config,
                    locker,
                    gauge,
                    pool,
                    position_id_copy,
                    share_first_part,
                    clock,
                    ctx,
                );
                position_id_copy = split_position_result2.position_id; // for next iteration

                pool_tranche::fill_tranches(
                    tranche,
                    delta_volume,
                );

                // return
                (
                    split_position_result1.position_id, 
                    split_position_result1.liquidity, 
                    remainder_a,
                    remainder_b,
                    true,
                )
            } else {
                pool_tranche::fill_tranches(
                    tranche,
                    liquidity_in_token,
                );

                // return
                (
                    position_id_copy, 
                    pool.position_manager().borrow_position_info(position_id_copy).info_liquidity(), 
                    sui::balance::zero<CoinTypeA>(),
                    sui::balance::zero<CoinTypeB>(),
                    false,
                )
            };

            let lock_liquidity_info = LockLiquidityInfo {
                total_lock_liquidity: lock_liquidity,   
                current_lock_liquidity: lock_liquidity,
                last_remove_liquidity_time: 0,
            };
            let mut lock_position = LockedPosition<CoinTypeA, CoinTypeB> {
                id: sui::object::new(ctx),
                position_id: _position_id,
                tranche_id: tranche_id,
                expiration_time: expiration_time,
                full_unlocking_time: full_unlocking_time,
                profitability: profitability,
                last_growth_inside: current_growth_inside,
                last_reward_claim_time: current_time,
                lock_liquidity_info,
                coin_a: sui::balance::zero<CoinTypeA>(),
                coin_b: sui::balance::zero<CoinTypeB>(),
            };
            lock_position.coin_a.join(remainder_a);
            lock_position.coin_b.join(remainder_b);

            let lock_position_id = sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position);
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
            assert!(i < tranches.length() || position_id_copy == _position_id, EPositionNotLocked);
        };

        lock_positions
    }

    public fun get_unlock_time<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): (u64, u64) {
        (lock_position.expiration_time, lock_position.full_unlocking_time)
    }

    public fun get_profitability<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): u64 {
        lock_position.profitability
    }

    public fun get_locked_position_id<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): sui::object::ID {
        lock_position.position_id
    }

    // проверка, залочена ли позиция
    public fun is_position_locked(
        locker: &mut Locker,
        position_id: sui::object::ID,
    ): bool {
        locker.positions.contains(position_id)
    }
            
    // метод получения ликвидности
    // если выводится вся ликвидность, то позиция разлочена и снимается со стейка
    public fun remove_lock_liquidity<CoinTypeA, CoinTypeB, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(current_time >= lock_position.expiration_time, ELockPeriodNotEnded);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);

        // перед выводом склеймить все награды (так как зависит от ликвидности)
        assert!(lock_position.last_reward_claim_time >= current_time || 
            lock_position.last_reward_claim_time >= lock_position.expiration_time, ERewardsNotCollected);

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
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB, EpochOSail>(
            locker.locker_cap.borrow(),
            pool,
            lock_position.position_id,
            clock,
            ctx,
        );

        let ( removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
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
                ctx,
            );
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
            // TODO event
            lock_position.lock_liquidity_info.current_lock_liquidity = lock_position.lock_liquidity_info.current_lock_liquidity - remove_liquidity_amount;
            lock_position.lock_liquidity_info.last_remove_liquidity_time = distribution::common::epoch_start(current_time);
            transfer::public_transfer<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position, sui::tx_context::sender(ctx));
        };

        (removed_a, removed_b)
    }

    // разлок позиции
    public fun unlock_position<CoinTypeA, CoinTypeB>(
        locker: &mut Locker,
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(!locker.pause, ELockManagerPaused);
        // проверяем, что лок полностью закончен
        assert!(clock.timestamp_ms()/1000 >= lock_position.full_unlocking_time, EFullLockPeriodNotEnded);

        assert!(lock_position.last_reward_claim_time >= lock_position.expiration_time, ERewardsNotCollected);

        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);

        let event = UnlockPositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
        };

        locker.positions.remove(lock_position.position_id);
        destroy(lock_position, ctx);

        sui::event::emit<UnlockPositionEvent>(event);
    }

    // метод сбора наград
    // можно клеймить только в эпоху следующую за последней полученной наградой и не в текущую
    // тип награды за лок позиции может отличаться от типа награды за стейкинг
    // RewardCoinType - тип награды, за стейкинг позиции
    // LockRewardCoinType - тип награды, за лок позиции
    public fun collect_reward<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        claim_epoch: u64, // timestamp s
        clock: &sui::clock::Clock,
    ): sui::balance::Balance<LockRewardCoinType> {
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(locked_position.last_reward_claim_time < locked_position.expiration_time, ENotClaimedRewards);

        // получаем баланс награды по доходности
        let reward_balance = get_rewards_internal<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
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
    public fun collect_reward_sail<CoinTypeA, CoinTypeB, RewardCoinType, SailCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        claim_epoch: u64, // timestamp s
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(locked_position.last_reward_claim_time < locked_position.expiration_time, ENotClaimedRewards);

        let reward_balance = get_rewards_internal<CoinTypeA, CoinTypeB, RewardCoinType, SailCoinType>(
            pool_tranche_manager,
            gauge,
            pool,
            locked_position,
            claim_epoch,
            clock,
        );

        voting_escrow.create_lock(
            sui::coin::from_balance(reward_balance, ctx),
            distribution::common::max_lock_time() / distribution::common::day(),
            true,
            clock,
            ctx
        );
    }

    fun get_rewards_internal<CoinTypeA, CoinTypeB, RewardCoinType, LockRewardCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        claim_epoch: u64,
        clock: &sui::clock::Clock,
    ): sui::balance::Balance<LockRewardCoinType> {
        let current_epoch = distribution::common::current_period(clock);
        let next_reward_claim_time = if (distribution::common::epoch_next(locked_position.last_reward_claim_time) > locked_position.expiration_time) {
            // такого исхода не будет, так как expiration_time округляется до эпохи
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
        let income = integer_mate::full_math_u64::mul_div_floor(
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

        let lock_position_id = sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(locked_position);
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

    fun destroy<CoinTypeA, CoinTypeB>(lock_position: LockedPosition<CoinTypeA, CoinTypeB>, ctx: &mut TxContext) {
        let LockedPosition<CoinTypeA, CoinTypeB> {
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
            coin_a: coin_a,
            coin_b: coin_b,
        } = lock_position;
        if (coin_a.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(sui::coin::from_balance(coin_a, ctx), tx_context::sender(ctx));        
        } else {
            coin_a.destroy_zero();
        };
        if (coin_b.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(sui::coin::from_balance(coin_b, ctx), tx_context::sender(ctx));
        } else {
            coin_b.destroy_zero();
        };
        sui::object::delete(lock_position_id);
    }

    // сплит позиции на две
    public fun split_position<CoinTypeA, CoinTypeB, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        share_first_part: u64, // 0..100 в lock_liquidity_share_denom
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (LockedPosition<CoinTypeA, CoinTypeB>, LockedPosition<CoinTypeA, CoinTypeB>) {

        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(current_time < lock_position.expiration_time, ELockPeriodEnded);

        // перед выводом склеймить все награды TODO или автоматический клейм 
        assert!(lock_position.last_reward_claim_time >= current_time || 
            lock_position.last_reward_claim_time >= lock_position.expiration_time, ERewardsNotCollected);
        assert!(share_first_part <= consts::lock_liquidity_share_denom() && share_first_part > 0, EInvalidShareLiquidityToFill);

        // убрать везде из лока эту позу
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);
        locker.positions.remove(lock_position.position_id);

        let (
            split_position_result1, 
            split_position_result2,
            remainder_a,
            remainder_b,
        ) = split_position_internal<CoinTypeA, CoinTypeB, EpochOSail>(
            global_config,
            vault,
            distribution_config,
            locker,
            gauge,
            pool,
            lock_position.position_id,
            share_first_part,
            clock,
            ctx,
        );

        // первый лок обновляем
        lock_position.position_id = split_position_result1.position_id; // не меняется
        lock_position.lock_liquidity_info.total_lock_liquidity = split_position_result1.liquidity;
        lock_position.lock_liquidity_info.current_lock_liquidity = split_position_result1.liquidity;

        // создание нового лока для новой позиции
        // все остатки сплитим в такой же пропорции
        let new_coin_a_value = integer_mate::full_math_u64::mul_div_floor(
            lock_position.coin_a.value(),
            share_first_part as u64,
            consts::lock_liquidity_share_denom() as u64
        );
        let new_coin_b_value = integer_mate::full_math_u64::mul_div_floor(
            lock_position.coin_b.value(),
            (consts::lock_liquidity_share_denom() - share_first_part) as u64,
            consts::lock_liquidity_share_denom() as u64
        );
        let new_lock_liquidity_info = LockLiquidityInfo {
            total_lock_liquidity: split_position_result2.liquidity,   
            current_lock_liquidity: split_position_result2.liquidity,
            last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time,
        };
        let mut new_lock_position = LockedPosition<CoinTypeA, CoinTypeB> {
            id: sui::object::new(ctx),
            position_id: split_position_result2.position_id,
            tranche_id: lock_position.tranche_id,
            expiration_time: lock_position.expiration_time,
            full_unlocking_time: lock_position.full_unlocking_time,
            profitability: lock_position.profitability,
            last_growth_inside: lock_position.last_growth_inside,
            last_reward_claim_time: lock_position.last_reward_claim_time,
            lock_liquidity_info: new_lock_liquidity_info,
            coin_a: lock_position.coin_a.split(new_coin_a_value),
            coin_b: lock_position.coin_b.split(new_coin_b_value),
        };
        new_lock_position.coin_a.join(remainder_a);
        new_lock_position.coin_b.join(remainder_b);

        gauge.lock_position(locker.locker_cap.borrow(), lock_position.position_id);
        gauge.lock_position(locker.locker_cap.borrow(), new_lock_position.position_id);
        locker.positions.add(lock_position.position_id, true);
        locker.positions.add(new_lock_position.position_id, true);
        
        (lock_position, new_lock_position)
    }
    
    fun split_position_internal<CoinTypeA, CoinTypeB, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &Locker,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        share_first_part: u64, // 0..100 в lock_liquidity_share_denom
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (SplitPositionResult<CoinTypeA, CoinTypeB>, SplitPositionResult<CoinTypeA, CoinTypeB>,
        sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        // расстейкать позу
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB, EpochOSail>(
            locker.locker_cap.borrow(),
            pool,
            position_id,
            clock,
            ctx,
        );

        let (lower_tick, upper_tick) = position.tick_range();
        let total_liquidity = position.liquidity();
        let ( _, mut liquidity2) = calculate_liquidity_split(
            total_liquidity,
            share_first_part
        );

        // выводим ликву и закрываем позу
        let (mut removed_a, mut removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            liquidity2,
            clock,
            ctx,
        );

        let liquidity1 = position.liquidity();
        let mut removed_amount_a = removed_a.value<CoinTypeA>();
        let mut removed_amount_b = removed_b.value<CoinTypeB>();
        
        let mut position2 = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(lower_tick),
            integer_mate::i32::as_u32(upper_tick),
            ctx
        );
        let position2_id = object::id<clmm_pool::position::Position>(&position2);

        let (amount_a_2_calc, mut amount_b_2_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            lower_tick,
            upper_tick,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            liquidity2,
            true
        );
        if (amount_a_2_calc > removed_amount_a) { // если сумма превышает из-за округлений, то придется снизить ликвидность второй позиции
            (liquidity2, _, amount_b_2_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                lower_tick,
                upper_tick,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                removed_amount_a,
                true
            );
        };
        if (amount_b_2_calc > removed_amount_b) { // если сумма превышает из-за округлений, то придется снизить ликвидность второй позиции
            (liquidity2, _, _) = clmm_pool::clmm_math::get_liquidity_by_amount(
                lower_tick,
                upper_tick,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                removed_amount_b,
                false
            );
        };

        let (remainder_a, remainder_b) = add_liquidity_internal<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position2,
            removed_a,
            removed_b,
            liquidity2,
            clock
        );
        
        distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
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

        (
            SplitPositionResult { 
                position_id: position_id, 
                liquidity: liquidity1,
            }, 
            SplitPositionResult { 
                position_id: position2_id, 
                liquidity: liquidity2, 
            },
            remainder_a,
            remainder_b,
        )
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

    fun calculate_amount_coin_split<CoinType>(
        mut total_balance: sui::balance::Balance<CoinType>,
        share_first_part: u64,
    ): (sui::balance::Balance<CoinType>, sui::balance::Balance<CoinType>) {
        assert!(share_first_part <= consts::lock_liquidity_share_denom(), EInvalidShareLiquidityToFill);
        let amount_a = integer_mate::full_math_u128::mul_div_floor(
            total_balance.value<CoinType>() as u128,
            share_first_part as u128,
            consts::lock_liquidity_share_denom() as u128
        );

        let balance_a = total_balance.split<CoinType>(amount_a as u64);
        
        (balance_a, total_balance)
    }
    
    // метод изменения границ позиции
    // создает новую позицию с новым интервалом
    // возвращает новый объет лока позиции
    public fun change_tick_range<CoinTypeA, CoinTypeB, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        lock_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(!locker.pause, ELockManagerPaused);
        assert!(distribution::gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(clock.timestamp_ms()/1000 < lock_position.expiration_time, ELockPeriodEnded);

        // перед выводом склеймить все награды TODO или автоматический клейм 
        assert!(lock_position.last_reward_claim_time >= clock.timestamp_ms()/1000, ERewardsNotCollected);

        // убрать везде из лока эту позу
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);
        locker.positions.remove(lock_position.position_id);

        // расстейкать позу
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB, EpochOSail>(
            locker.locker_cap.borrow(),
            pool,
            lock_position.position_id,
            clock,
            ctx,
        );
        let (tick_lower, tick_upper) = position.tick_range();
        assert!(!new_tick_lower.eq(tick_lower) || !new_tick_upper.eq(tick_upper), ENotChangedTickRange);

        let position_liquidity = position.liquidity();

        // выводим ликву и закрываем позу
        let (mut removed_a, mut removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            position_liquidity,
            clock,
            ctx,
        );

        // приведем баланс токенов в одному токену B
        let current_volume_coins_in_token_b = locker_utils::calculate_token_a_in_token_b(pool, removed_a.value()) + removed_b.value();

        std::debug::print(&std::string::utf8(b"removed_a START"));
        std::debug::print(&removed_a.value());
        std::debug::print(&std::string::utf8(b"removed_b START"));
        std::debug::print(&removed_b.value());

        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(global_config, pool, position);

        let mut new_position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(new_tick_lower),
            integer_mate::i32::as_u32(new_tick_upper),
            ctx
        );
        let new_position_id = object::id<clmm_pool::position::Position>(&new_position);

        // в зависимости от сужения или расширения диапазона, количество токенов в этом же объеме ликвидности  будет разным
        let (pre_amount_a_calc, pre_amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            new_tick_lower,
            new_tick_upper,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            position_liquidity,
            true // round_up == true, тк repay_add_liquidity округление вверх
        );
        
        // необходимо определить ликвидность в новом диапазоне для имеющихся токенов
        // приведем баланс токенов в одному токену B
        let after_volume_coins_in_token_b = locker_utils::calculate_token_a_in_token_b(pool, pre_amount_a_calc) + pre_amount_b_calc;

        // определить соотношение объемов токенов в новом диапазоне
        // если уменьшились - то пропорционально увеличить ликвидность
        // если увеличились - то пропорционально уменьшить ликвидность
        let mut liquidity_calc = integer_mate::full_math_u128::mul_div_floor(
            position_liquidity,
            current_volume_coins_in_token_b as u128,
            after_volume_coins_in_token_b as u128
        );

        let (mut amount_a_calc, mut amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            new_tick_lower,
            new_tick_upper,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            liquidity_calc,
            true // round_up == true, тк repay_add_liquidity округление вверх
        );

        std::debug::print(&std::string::utf8(b"amount_a_calc"));
        std::debug::print(&amount_a_calc);
        std::debug::print(&std::string::utf8(b"amount_b_calc"));
        std::debug::print(&amount_b_calc);
        std::debug::print(&std::string::utf8(b"liquidity_calc"));
        std::debug::print(&(liquidity_calc));

        if ((removed_b.value() > amount_b_calc) || (removed_a.value() > amount_a_calc)) {
            // рассчет liquidity_calc перед свопом
            // иначе после свопа меняется цена 
            if (removed_b.value() > amount_b_calc) {
                let calculate_swap_result = clmm_pool::pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    false,
                    true,
                    removed_b.value() - amount_b_calc
                );

                let amount_a_out = calculate_swap_result.calculated_swap_result_amount_out();
                if ((amount_a_out + removed_a.value()) < amount_a_calc) {

                    (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                        new_tick_lower,
                        new_tick_upper,
                        pool.current_tick_index(),
                        pool.current_sqrt_price(),
                        amount_a_out + removed_a.value(),
                        true
                    );
                };
            } else {
                let calculate_swap_result = clmm_pool::pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    true,
                    true,
                    removed_a.value() - amount_a_calc
                );

                let amount_b_out = calculate_swap_result.calculated_swap_result_amount_out();
                if ((amount_b_out + removed_b.value()) < amount_b_calc) {

                    (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                        new_tick_lower,
                        new_tick_upper,
                        pool.current_tick_index(),
                        pool.current_sqrt_price(),
                        amount_b_out + removed_b.value(),
                        false
                    );
                };
            };
        };

        // добавим ликвидность до свопа
        let receipt = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut new_position,
            liquidity_calc,
            clock
        );
        let (pay_amount_a, pay_amount_b) = receipt.add_liquidity_pay_amount();

        if ((removed_b.value() > amount_b_calc) || (removed_a.value() > amount_a_calc)) {
            // Балансировка токенов через своп
            // если баланс койна уменьшается, то свопаем эту часть, получаем максимальное значение второго койна и на него ориентируемся
            let (receipt, swap_pay_amount_a, swap_pay_amount_b) = if (removed_b.value() > amount_b_calc) {
                // свопаем B в A
                std::debug::print(&std::string::utf8(b"swap_b2a"));
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    false, // a2b = false, т.к. мы свопаем B в A
                    true, // by_amount_in = true, т.к. мы указываем количество входного токена
                    removed_b.value() - amount_b_calc,
                    clmm_pool::tick_math::max_sqrt_price(),
                    stats,
                    price_provider,
                    clock
                );
                removed_b.join(amount_b_out);
                removed_a.join(amount_a_out);
                // здесь должны свапнуть лишний B койн и получить А, но его будет не достаточно до amount_a_calc
                let swap_pay_amount_b_receipt = receipt.swap_pay_amount();
                let swap_pay_amount_b = removed_b.split(swap_pay_amount_b_receipt);

                std::debug::print(&std::string::utf8(b"swap_pay_amount_b"));
                std::debug::print(&swap_pay_amount_b.value());
                std::debug::print(&std::string::utf8(b"removed_b after split"));
                std::debug::print(& removed_b.value());

                // std::debug::print(&std::string::utf8(b"amount_a_calc RES"));
                // std::debug::print(&amount_a_calc);
                // std::debug::print(&std::string::utf8(b"amount_b_calc RES"));
                // std::debug::print(&amount_b_calc);

                (receipt, sui::balance::zero<CoinTypeA>(), swap_pay_amount_b)
            } else {
                std::debug::print(&std::string::utf8(b"swap_a2b"));
                // свопаем A в B
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    true,
                    true, // by_amount_in = true, т.к. мы указываем количество входного токена
                    removed_a.value() - amount_a_calc,
                    clmm_pool::tick_math::min_sqrt_price(),
                    stats,
                    price_provider,
                    clock
                );
                removed_a.join(amount_a_out);
                removed_b.join(amount_b_out);

                // здесь должны свапнуть лишний A койн и получить B, но его будет не достаточно до amount_b_calc
                let swap_pay_amount_a_receipt = receipt.swap_pay_amount();
                let swap_pay_amount_a = removed_a.split(swap_pay_amount_a_receipt);

                std::debug::print(&std::string::utf8(b"swap_pay_amount_a"));
                std::debug::print(&swap_pay_amount_a.value());
                std::debug::print(&std::string::utf8(b"removed_a after split"));
                std::debug::print(&removed_a.value());

                // std::debug::print(&std::string::utf8(b"swap_amount_b_out"));
                // std::debug::print(&amount_b_out.value());
                // std::debug::print(&std::string::utf8(b"amount_b SUM"));
                // std::debug::print(&(amount_b_out.value() + removed_b.value()));

                (receipt, swap_pay_amount_a, sui::balance::zero<CoinTypeB>())
            };

            assert!(removed_a.value() >= amount_a_calc, EIncorrectSwapResultA);
            assert!(removed_b.value() >= amount_b_calc, EIncorrectSwapResultB);

            clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                swap_pay_amount_a,
                swap_pay_amount_b,
                receipt
            );
        };

        if (removed_a.value() > pay_amount_a) {
            let removed_a_value = removed_a.value();
            std::debug::print(&std::string::utf8(b"ADD FIX A _a_value"));
            std::debug::print(&(removed_a_value - pay_amount_a));

            lock_position.coin_a.join(removed_a.split(removed_a_value - pay_amount_a));
        };
        if (removed_b.value() > pay_amount_b) {
            let removed_b_value = removed_b.value();
            std::debug::print(&std::string::utf8(b"ADD FIX B _b_value"));
            std::debug::print(&(removed_b_value - pay_amount_b));

            lock_position.coin_b.join(removed_b.split(removed_b_value - pay_amount_b));
        };
        
        assert!(pay_amount_a == removed_a.value(), EIncorrectDistributionOfLiquidityA);
        assert!(pay_amount_b == removed_b.value(), EIncorrectDistributionOfLiquidityB);

        std::debug::print(&std::string::utf8(b"RES liquidity_calc"));
        std::debug::print(&(liquidity_calc));

        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            removed_a,
            removed_b,
            receipt,
        );

        // остатки попробовать залить обратно в позу
        add_liquidity_by_lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            lock_position,
            &mut new_position,
            clock
        );

        let new_position_liquidity = new_position.liquidity();

        // застейкать позу
        distribution::gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            new_position,
            clock,
            ctx,
        );

        lock_position.position_id = new_position_id;
        lock_position.lock_liquidity_info.total_lock_liquidity = new_position_liquidity;
        lock_position.lock_liquidity_info.current_lock_liquidity = new_position_liquidity;
       
        let event = ChangeRangePositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position),
            new_position_id: new_position_id,
            new_lock_liquidity: new_position_liquidity,
            new_tick_lower: new_tick_lower,
            new_tick_upper: new_tick_upper,
        };

        gauge.lock_position(locker.locker_cap.borrow(), new_position_id);
        locker.positions.add(new_position_id, true);

        sui::event::emit<ChangeRangePositionEvent>(event);
    }

    fun add_liquidity_by_lock_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        clock: &sui::clock::Clock,
    ) {
        if (lock_position.coin_a.value() > 0 && lock_position.coin_b.value() > 0) {
            let (tick_lower, tick_upper) = position.tick_range();
            let (mut liquidity_calc, mut amount_a_calc, mut amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower,
                tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                lock_position.coin_a.value(),
                true
            );
            if (amount_b_calc > lock_position.coin_b.value()) {
                (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                    tick_lower,
                    tick_upper,
                    pool.current_tick_index(),
                    pool.current_sqrt_price(),
                    lock_position.coin_b.value(),
                    false
                );
            };

            std::debug::print(&std::string::utf8(b"add_liquidity_by_lock_position"));
            std::debug::print(&std::string::utf8(b"amount_a_calc"));
            std::debug::print(&amount_a_calc);
            std::debug::print(&std::string::utf8(b"amount_b_calc"));
            std::debug::print(&amount_b_calc);
             std::debug::print(&std::string::utf8(b"liquidity_calc"));
            std::debug::print(&liquidity_calc);

            let (remainder_a, remainder_b) = add_liquidity_internal<CoinTypeA, CoinTypeB>(
                global_config,
                vault,
                pool,
                position,
                lock_position.coin_a.split(amount_a_calc),
                lock_position.coin_b.split(amount_b_calc),
                liquidity_calc,
                clock
            );

            lock_position.coin_a.join(remainder_a);
            lock_position.coin_b.join(remainder_b);
            std::debug::print(&std::string::utf8(b" lock_position.coin_a"));
            std::debug::print(& lock_position.coin_a.value());
            std::debug::print(&std::string::utf8(b" lock_position.coin_b"));
            std::debug::print(& lock_position.coin_b.value());
        }
    }

    // внутренний метод добавления ликвидности в новую позицию
    fun add_liquidity_internal<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        mut amount_a: sui::balance::Balance<CoinTypeA>,
        mut amount_b: sui::balance::Balance<CoinTypeB>,
        liquidity: u128,
        clock: &sui::clock::Clock,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let receipt = clmm_pool::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            position,
            liquidity,
            clock
        );
        let (pay_amount_a, pay_amount_b) = receipt.add_liquidity_pay_amount();
        let mut balance_a = amount_a.value();
        let mut balance_b = amount_b.value();

        let mut remainder_a = sui::balance::zero<CoinTypeA>();
        if (pay_amount_a < balance_a) {
            remainder_a.join(amount_a.split(balance_a - pay_amount_a));
            balance_a = amount_a.value<CoinTypeA>();
        };

        let mut remainder_b = sui::balance::zero<CoinTypeB>();
        if (pay_amount_b < balance_b) {
            remainder_b.join(amount_b.split(balance_b - pay_amount_b));
            balance_b = amount_b.value<CoinTypeB>();
        };

        assert!(pay_amount_a == balance_a, EIncorrectDistributionOfLiquidityA);
        assert!(pay_amount_b == balance_b, EIncorrectDistributionOfLiquidityB);

        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            amount_a,
            amount_b,
            receipt,
        );

        (remainder_a, remainder_b)
    }

        // метод снятия ликвидности и сбора комиссии
    fun remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): ( sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let ( removed_a,  removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
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
        sui::transfer::share_object<Locker>(locker);
    
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
    }
}

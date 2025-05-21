/// Liquidity Locker Module
/// 
/// This module provides functionality for locking liquidity positions in a CLMM (Concentrated Liquidity Market Maker) pool.
/// It allows users to lock their liquidity positions for a specified period and earn rewards based on their lock duration
/// and the amount of liquidity provided.
/// 
/// Key features:
/// * Lock liquidity positions for specified periods
/// * Split and modify locked positions
/// * Change tick ranges of locked positions
/// 
/// The module integrates with the CLMM pool system.
/// It ensures that locked positions cannot be modified or withdrawn before the lock period ends.
/// 
/// # Security
/// The module implements various security checks to ensure:
/// * Positions cannot be modified before lock period ends
/// * Invalid operations are prevented through capability-based access control
/// 
/// # Integration
/// This module works in conjunction with:
/// * CLMM Pool system for liquidity management
/// * Pool Tranche system for determining lock profitability and reward distribution
module liquidity_locker::liquidity_lock_v1 {
    use liquidity_locker::pool_tranche;
    use liquidity_locker::consts;
    use liquidity_locker::locker_utils;
    use liquidity_locker::time_manager;
    
    // Bump the `VERSION` of the package.
    const VERSION: u64 = 1;

    const EInvalidPeriodsLength: u64 = 938724658124718472;
    const EInvalidProfitabilitiesLength: u64 = 93877534345684724;
    const EInvalidBlockPeriodIndex: u64 = 938724654546442874;
    const ELockPeriodEnded: u64 = 99423692832693454;
    const EFullLockPeriodNotEnded: u64 = 98923745837578344;
    const EPositionAlreadyLocked: u64 = 9387246576346433;
    const ENoTranches: u64 = 9823742374723842;
    const ERewardsNotCollected: u64 = 912944864567454;
    const ELockPeriodNotEnded: u64 = 91204958347574966;
    const ELockManagerPaused: u64 = 916023534273428375;
    const ENoLiquidityToRemove: u64 = 91877547573637423;
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
        positions: sui::object_table::ObjectTable<ID, clmm_pool::position::Position>,
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
    /// * `accumulated_amount_earned` - Accumulated rewards from the last unclaimed epoch. 
    /// These rewards are stored during position rebalancing to account for liquidity changes. Reset after each reward claim.
    public struct LockedPosition<phantom CoinTypeA, phantom CoinTypeB> has store, key {
        id: sui::object::UID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        expiration_time: u64, 
        full_unlocking_time: u64, 
        profitability: u64,
        last_reward_claim_time: u64,
        last_growth_inside: u128,
        accumulated_amount_earned: u64,
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

    /// Event emitted when the liquidity of a locked position is updated.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `current_lock_liquidity` - Current amount of locked liquidity
    /// * `last_remove_liquidity_time` - Timestamp of the last liquidity removal
    public struct UpdateLockLiquidityEvent has copy, drop {
        lock_position_id: sui::object::ID,
        current_lock_liquidity: u128,
        last_remove_liquidity_time: u64,
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
            positions: sui::object_table::new<ID, clmm_pool::position::Position>(ctx),
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
    /// * `locker` - The locker object to use
    /// * `pool_tranche_manager` - Manager for pool tranches
    /// * `pool` - The pool containing the position
    /// * `position` - Position liquidity to lock
    /// * `block_period_index` - Index of the blocking period to use from the periods_blocking vector to determine the lock duration
    /// * `clock` - Clock for time-based operations
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Vector of locked positions created from the original position
    /// 
    /// # Aborts
    /// * `ELockManagerPaused` - If the locker is paused
    /// * `EPositionAlreadyLocked` - If the position is already locked
    /// * `EInvalidBlockPeriodIndex` - If the block period index is invalid
    /// * `ENoTranches` - If there are no tranches available
    /// * `EInvalidProfitabilitiesLength` - If the profitabilities length is invalid
    public fun lock_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut position: clmm_pool::position::Position,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): vector<LockedPosition<CoinTypeA, CoinTypeB>> {
        assert!(!locker.pause, ELockManagerPaused);
        let position_id = sui::object::id<clmm_pool::position::Position>(&position);
        assert!(!locker.positions.contains(position_id), EPositionAlreadyLocked);
        assert!(block_period_index < locker.periods_blocking.length(), EInvalidBlockPeriodIndex);

        let duration_block = time_manager::epoch_to_seconds(locker.periods_blocking[block_period_index]);
        let current_time = clock.timestamp_ms() / 1000;
        let expiration_time = time_manager::epoch_next(current_time + duration_block);
        let full_unlocking_time = expiration_time + time_manager::epoch_to_seconds(locker.periods_post_lockdown[block_period_index]);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let tranches = pool_tranche_manager.get_tranches(pool_id);

        assert!(tranches.length() > 0, ENoTranches);

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
                    new_position
                ) = split_position_internal<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    &mut position,
                    share_first_part,
                    clock,
                    ctx,
                );
                position_id_copy = split_position_result2.position_id; // for next iteration
                locker.positions.add(split_position_result2.position_id, new_position);

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
                last_growth_inside: 0,
                accumulated_amount_earned: 0,
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

            lock_positions.push_back(lock_position);

            if (!split) {
                break
            };

            i = i + 1;
            assert!(i < tranches.length() || position_id_copy == _position_id, EPositionNotLocked);
        };

        locker.positions.add(position_id, position);

        lock_positions
    }

    /// Returns the expiration time and full unlocking time for a locked position
    /// 
    /// # Arguments
    /// * `lock_position` - The locked position to get unlock times for
    /// 
    /// # Returns
    /// Tuple of (expiration_time, full_unlocking_time)
    public fun get_unlock_time<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): (u64, u64) {
        (lock_position.expiration_time, lock_position.full_unlocking_time)
    }

    /// Returns the profitability value for a locked position
    /// 
    /// # Arguments
    /// * `lock_position` - The locked position to get profitability for
    /// 
    /// # Returns
    /// The profitability rate value, representing rate multiplied by profitability_rate_denom
    public fun get_profitability<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): u64 {
        lock_position.profitability
    }

    /// Returns the position ID for a locked position
    /// 
    /// # Arguments
    /// * `lock_position` - The locked position to get ID for
    /// 
    /// # Returns
    /// The position ID
    public fun get_locked_position_id<CoinTypeA, CoinTypeB>(
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
    ): sui::object::ID {
        lock_position.position_id
    }

    /// Checks if a position is currently locked
    /// 
    /// # Arguments
    /// * `locker` - The locker instance to check against
    /// * `position_id` - The position ID to check
    /// 
    /// # Returns
    /// True if position is locked, false otherwise
    public fun is_position_locked(
        locker: &mut Locker,
        position_id: sui::object::ID,
    ): bool {
        locker.positions.contains(position_id)
    }
            
    /// Removes liquidity from a locked position. 
    /// Liquidity can be removed partially, proportionally to the epochs passed since expiration_time. 
    /// Before removing liquidity, all rewards must be claimed. 
    /// If all liquidity is removed, the position is unlocked and unstaked. 
    /// The lock_position object is destroyed and the clmm_pool::position::Position object is transferred to the sender.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the CLMM pool
    /// * `vault` - Global reward vault
    /// * `locker` - The locker instance
    /// * `pool` - The pool containing the position
    /// * `lock_position` - The locked position to remove liquidity from
    /// * `clock` - Clock for time-based operations
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Tuple of (Balance<CoinTypeA>, Balance<CoinTypeB>) containing the removed liquidity
    /// 
    /// # Aborts
    /// * `ELockManagerPaused` - If the locker is paused
    /// * `ELockPeriodNotEnded` - If the lock period has not ended
    /// * `ERewardsNotCollected` - If rewards have not been collected
    /// * `ENoLiquidityToRemove` - If there is no liquidity available to remove
    public fun remove_lock_liquidity<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(current_time >= lock_position.expiration_time, ELockPeriodNotEnded);

        let full_remove = if (current_time >= lock_position.full_unlocking_time) {
            true
        } else {
            false
        };

        // Calculate how much liquidity can be removed
        let mut remove_liquidity_amount = if (full_remove) {
            lock_position.lock_liquidity_info.current_lock_liquidity
        } else {
            if (lock_position.lock_liquidity_info.last_remove_liquidity_time == 0) {
                lock_position.lock_liquidity_info.last_remove_liquidity_time = lock_position.expiration_time;
            };
            let number_epochs_after_expiration = time_manager::number_epochs_in_timestamp(current_time - lock_position.lock_liquidity_info.last_remove_liquidity_time);
            assert!(number_epochs_after_expiration > 0, ENoLiquidityToRemove);

            // Calculate portion of total liquidity that can be removed
            integer_mate::full_math_u128::mul_div_floor(
                lock_position.lock_liquidity_info.total_lock_liquidity,
                number_epochs_after_expiration as u128,
                time_manager::number_epochs_in_timestamp(lock_position.full_unlocking_time - lock_position.expiration_time) as u128,
            )
        };
        assert!(remove_liquidity_amount > 0, ENoLiquidityToRemove);
        if (remove_liquidity_amount > lock_position.lock_liquidity_info.current_lock_liquidity) {
            remove_liquidity_amount = lock_position.lock_liquidity_info.current_lock_liquidity;
        };

        let mut position = locker.positions.remove(lock_position.position_id);

        let ( removed_a, removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            remove_liquidity_amount,
            clock,
        );

        if (full_remove) {
            let event = UnlockPositionEvent {
                lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
            };

            destroy(lock_position, ctx);

            sui::event::emit<UnlockPositionEvent>(event);

            transfer::public_transfer<clmm_pool::position::Position>(position, sui::tx_context::sender(ctx));
        } else {
            locker.positions.add(lock_position.position_id, position);

            lock_position.lock_liquidity_info.current_lock_liquidity = lock_position.lock_liquidity_info.current_lock_liquidity - remove_liquidity_amount;
            lock_position.lock_liquidity_info.last_remove_liquidity_time = time_manager::epoch_start(current_time);
            
            let event = UpdateLockLiquidityEvent {
                lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
                current_lock_liquidity: lock_position.lock_liquidity_info.current_lock_liquidity,
                last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time,
            };
            sui::event::emit<UpdateLockLiquidityEvent>(event);

            transfer::public_transfer<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position, sui::tx_context::sender(ctx));
        };

        (removed_a, removed_b)
    }

    /// Completely unlocks a position and destroys the LockedPosition object.
    /// Full unlocking is only possible after the full_unlocking_time has passed
    /// and all rewards have been claimed.
    /// 
    /// # Arguments
    /// * `locker` - The locker object containing the position
    /// * `lock_position` - The locked position to unlock
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the full unlocking time has not been reached
    /// * If rewards have not been collected
    public fun unlock_position<CoinTypeA, CoinTypeB>(
        locker: &mut Locker,
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): clmm_pool::position::Position {
        assert!(!locker.pause, ELockManagerPaused);
        // Verify that the full lock period has ended
        assert!(clock.timestamp_ms()/1000 >= lock_position.full_unlocking_time, EFullLockPeriodNotEnded);

        let event = UnlockPositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
        };
        let position_id = lock_position.position_id;
        destroy(lock_position, ctx);

        sui::event::emit<UnlockPositionEvent>(event);

        locker.positions.remove(position_id)
    }

    /// Destroys a locked position and transfers any remaining coins to the sender.
    /// 
    /// This function handles the cleanup of a locked position by:
    /// 1. Transferring any remaining coins to the sender
    /// 2. Destroying zero balances
    /// 3. Deleting the position object
    /// 
    /// # Arguments
    /// * `lock_position` - The locked position to destroy
    /// * `ctx` - The transaction context
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
            accumulated_amount_earned: _,
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


    /// Splits a locked position into two positions with specified liquidity share.
    /// The function splits the position into two parts:
    /// 1. Original position: retains share_first_part of the liquidity
    /// 2. New position: receives the remaining liquidity (1 - share_first_part in lock_liquidity_share_denom)
    /// Both positions maintain identical lock period and profitability settings.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `locker` - The locker containing the position
    /// * `pool` - The pool containing the position
    /// * `lock_position` - The locked position to split
    /// * `share_first_part` - Share of liquidity for the first position (0..1.0 in lock_liquidity_share_denom)
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Tuple of two LockedPosition objects representing the split positions
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the lock period has ended
    /// * If rewards have not been collected
    /// * If share_first_part is invalid
    public fun split_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        share_first_part: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (LockedPosition<CoinTypeA, CoinTypeB>, LockedPosition<CoinTypeA, CoinTypeB>) {

        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(current_time < lock_position.expiration_time, ELockPeriodEnded);

        assert!(share_first_part <= consts::lock_liquidity_share_denom() && share_first_part > 0, EInvalidShareLiquidityToFill);

        // Remove position from locker
        let mut position = locker.positions.remove(lock_position.position_id);

        let (
            split_position_result1, 
            split_position_result2,
            remainder_a,
            remainder_b,
            new_position
        ) = split_position_internal<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            share_first_part,
            clock,
            ctx,
        );

        // Update first lock position
        lock_position.position_id = split_position_result1.position_id; // remains unchanged
        lock_position.lock_liquidity_info.total_lock_liquidity = split_position_result1.liquidity;
        lock_position.lock_liquidity_info.current_lock_liquidity = split_position_result1.liquidity;
        lock_position.last_growth_inside = 0;
        lock_position.accumulated_amount_earned = 0;

        // Create new lock position with proportional split of remaining assets
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
            last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time
        };
        let mut new_lock_position = LockedPosition<CoinTypeA, CoinTypeB> {
            id: sui::object::new(ctx),
            position_id: split_position_result2.position_id,
            tranche_id: lock_position.tranche_id,
            expiration_time: lock_position.expiration_time,
            full_unlocking_time: lock_position.full_unlocking_time,
            profitability: lock_position.profitability,
            last_growth_inside: 0,
            accumulated_amount_earned: 0,
            last_reward_claim_time: lock_position.last_reward_claim_time,
            lock_liquidity_info: new_lock_liquidity_info,
            coin_a: lock_position.coin_a.split(new_coin_a_value),
            coin_b: lock_position.coin_b.split(new_coin_b_value),
        };

        new_lock_position.coin_a.join(remainder_a);
        new_lock_position.coin_b.join(remainder_b);

        // Register both positions in locker
        locker.positions.add(lock_position.position_id, position);
        locker.positions.add(new_lock_position.position_id, new_position);

        (lock_position, new_lock_position)
    }
    
    /// Internal function to split a position into two parts with specified liquidity share.
    /// 
    /// This function handles the position splitting process by:
    /// 1. Calculating liquidity split based on share_first_part
    /// 2. Removing liquidity from the original position
    /// 3. Creating a new position
    /// 4. Adding liquidity to the new position
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `locker` - The locker containing the position
    /// * `pool` - The pool containing the position
    /// * `position_id` - ID of the position to split
    /// * `share_first_part` - Share of liquidity for the first position (0..1.0 in lock_liquidity_share_denom)
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Tuple containing:
    /// * SplitPositionResult for the original position
    /// * SplitPositionResult for the new position
    /// * Remainder balance of CoinTypeA
    /// * Remainder balance of CoinTypeB
    fun split_position_internal<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        share_first_part: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (SplitPositionResult<CoinTypeA, CoinTypeB>, SplitPositionResult<CoinTypeA, CoinTypeB>,
        sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>,
        clmm_pool::position::Position
    ) {

        let (lower_tick, upper_tick) = position.tick_range();
        let total_liquidity = position.liquidity();
        let ( _, mut liquidity2) = calculate_liquidity_split(
            total_liquidity,
            share_first_part
        );

        // Remove liquidity and collect fees
        let (removed_a, removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            position,
            liquidity2,
            clock,
            ctx,
        );

        let liquidity1 = position.liquidity();
        let removed_amount_a = removed_a.value<CoinTypeA>();
        let removed_amount_b = removed_b.value<CoinTypeB>();
        
        // Create new position with same tick range
        let mut position2 = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(lower_tick),
            integer_mate::i32::as_u32(upper_tick),
            ctx
        );
        let position2_id = object::id<clmm_pool::position::Position>(&position2);

        // Calculate amounts and adjust liquidity if needed due to rounding
        let (amount_a_2_calc, mut amount_b_2_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            lower_tick,
            upper_tick,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            liquidity2,
            true
        );
        if (amount_a_2_calc > removed_amount_a) { // Adjust liquidity if calculated amount exceeds available due to rounding
            (liquidity2, _, amount_b_2_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                lower_tick,
                upper_tick,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                removed_amount_a,
                true
            );
        };
        if (amount_b_2_calc > removed_amount_b) { // Adjust liquidity if calculated amount exceeds available due to rounding
            (liquidity2, _, _) = clmm_pool::clmm_math::get_liquidity_by_amount(
                lower_tick,
                upper_tick,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                removed_amount_b,
                false
            );
        };

        // Add liquidity to new position
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

        (
            SplitPositionResult { 
                position_id: object::id<clmm_pool::position::Position>(position), 
                liquidity: liquidity1,
            }, 
            SplitPositionResult { 
                position_id: position2_id, 
                liquidity: liquidity2, 
            },
            remainder_a,
            remainder_b,
            position2
        )
    }

    /// Calculates the split of total liquidity into two parts based on the specified share ratio.
    /// 
    /// This function divides the total liquidity into two portions:
    /// 1. First portion: Calculated based on the provided share ratio
    /// 2. Second portion: Remaining liquidity after the first portion
    /// 
    /// # Arguments
    /// * `total_liquidity` - Total amount of liquidity to split
    /// * `share_first_part` - Share ratio for the first portion (0..1.0 in lock_liquidity_share_denom)
    /// 
    /// # Returns
    /// Tuple containing (liquidity_first_part, liquidity_second_part)
    /// 
    /// # Aborts
    /// * If share_first_part exceeds the maximum allowed share denominator
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
    
    /// Changes the tick range of a locked position by creating a new position with the specified range.
    /// 
    /// This function performs the following operations:
    /// 1. Validates the position can be modified (not paused, not expired)
    /// 2. Unlocks and withdraws the existing position
    /// 3. Removes liquidity and collects fees from the old position
    /// 4. Creates a new position with the specified tick range
    /// 5. Calculates and adjusts liquidity for the new range
    /// 6. Performs necessary token swaps to balance the position
    /// 7. Adds liquidity to the new position
    /// 8. Locks the new position and updates the locker state
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `locker` - Locker instance managing the position
    /// * `lock_position` - The locked position to modify
    /// * `pool` - The pool containing the position
    /// * `stats` - Pool statistics
    /// * `price_provider` - Price provider for the pool
    /// * `new_tick_lower` - New lower tick bound for the position
    /// * `new_tick_upper` - New upper tick bound for the position
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the lock period has ended
    /// If rewards have not been collected
    /// * If the new tick range is the same as the current range
    /// * If token swap results are incorrect
    /// * If liquidity distribution is incorrect
    public fun change_tick_range<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        locker: &mut Locker,
        lock_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {

        let current_time = clock.timestamp_ms()/1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(current_time < lock_position.expiration_time, ELockPeriodEnded);        
        
        let mut position =locker.positions.remove(lock_position.position_id);

        let (tick_lower, tick_upper) = position.tick_range();
        assert!(!new_tick_lower.eq(tick_lower) || !new_tick_upper.eq(tick_upper), ENotChangedTickRange);

        let position_liquidity = position.liquidity();

        // Remove liquidity and collect fees
        let (mut removed_a, mut removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            position_liquidity,
            clock,
            ctx,
        );

        // Calculate total value in token B terms
        let current_volume_coins_in_token_b = locker_utils::calculate_token_a_in_token_b(pool, removed_a.value()) + removed_b.value();

        // Close old position and create new one
        clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(global_config, pool, position);

        let mut new_position = clmm_pool::pool::open_position<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            integer_mate::i32::as_u32(new_tick_lower),
            integer_mate::i32::as_u32(new_tick_upper),
            ctx
        );
        let new_position_id = object::id<clmm_pool::position::Position>(&new_position);

        // Calculate token amounts for new range with current liquidity
        let (pre_amount_a_calc, pre_amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            new_tick_lower,
            new_tick_upper,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            position_liquidity,
            true
        );
        
        // Calculate total value in token B terms for new range
        let after_volume_coins_in_token_b = locker_utils::calculate_token_a_in_token_b(pool, pre_amount_a_calc) + pre_amount_b_calc;

        // Adjust liquidity based on value ratio between ranges
        let mut liquidity_calc = integer_mate::full_math_u128::mul_div_floor(
            position_liquidity,
            current_volume_coins_in_token_b as u128,
            after_volume_coins_in_token_b as u128
        );

        // Calculate final token amounts with adjusted liquidity
        let (mut amount_a_calc, mut amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
            new_tick_lower,
            new_tick_upper,
            pool.current_tick_index(),
            pool.current_sqrt_price(),
            liquidity_calc,
            true
        );

        // Handle token imbalances through swaps
        if ((removed_b.value() > amount_b_calc) || (removed_a.value() > amount_a_calc)) {
            // Calculate liquidity before swap to avoid price impact
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

        // Add liquidity before swap
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
            // Token balance adjustment through swap
            // If token balance decreases, swap that portion to get maximum value of second token as reference
            let (receipt, swap_pay_amount_a, swap_pay_amount_b) = if (removed_b.value() > amount_b_calc) {
                // Swap B to A
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    false, // a2b = false, since we swap B to A
                    true,
                    removed_b.value() - amount_b_calc,
                    clmm_pool::tick_math::max_sqrt_price(),
                    stats,
                    price_provider,
                    clock
                );
                removed_b.join(amount_b_out);
                removed_a.join(amount_a_out);

                // Swap excess B token to get A, but it won't be sufficient to reach amount_a_calc
                let swap_pay_amount_b_receipt = receipt.swap_pay_amount();
                let swap_pay_amount_b = removed_b.split(swap_pay_amount_b_receipt);

                (receipt, sui::balance::zero<CoinTypeA>(), swap_pay_amount_b)
            } else {
                // Swap A to B
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    true,
                    true,
                    removed_a.value() - amount_a_calc,
                    clmm_pool::tick_math::min_sqrt_price(),
                    stats,
                    price_provider,
                    clock
                );
                removed_a.join(amount_a_out);
                removed_b.join(amount_b_out);

                // Swap excess A token to get B, but it won't be sufficient to reach amount_b_calc
                let swap_pay_amount_a_receipt = receipt.swap_pay_amount();
                let swap_pay_amount_a = removed_a.split(swap_pay_amount_a_receipt);

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

            lock_position.coin_a.join(removed_a.split(removed_a_value - pay_amount_a));
        };
        if (removed_b.value() > pay_amount_b) {
            let removed_b_value = removed_b.value();

            lock_position.coin_b.join(removed_b.split(removed_b_value - pay_amount_b));
        };
        
        assert!(pay_amount_a == removed_a.value(), EIncorrectDistributionOfLiquidityA);
        assert!(pay_amount_b == removed_b.value(), EIncorrectDistributionOfLiquidityB);

        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            removed_a,
            removed_b,
            receipt,
        );

        // Add remaining tokens back to position
        add_liquidity_by_lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            lock_position,
            &mut new_position,
            clock
        );

        let new_position_liquidity = new_position.liquidity();

        lock_position.position_id = new_position_id;
        lock_position.lock_liquidity_info.total_lock_liquidity = new_position_liquidity;
        lock_position.lock_liquidity_info.current_lock_liquidity = new_position_liquidity;
        lock_position.last_growth_inside = 0;
        lock_position.accumulated_amount_earned = lock_position.accumulated_amount_earned + 0;
       
        let event = ChangeRangePositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position),
            new_position_id: new_position_id,
            new_lock_liquidity: new_position_liquidity,
            new_tick_lower: new_tick_lower,
            new_tick_upper: new_tick_upper,
        };

        locker.positions.add(new_position_id, new_position);

        sui::event::emit<ChangeRangePositionEvent>(event);
    }

    /// Removes liquidity from a position and collects accumulated fees.
    /// 
    /// This function performs two main operations:
    /// 1. Removes the specified amount of liquidity from the position
    /// 2. Collects any accumulated fees from the position
    /// 
    /// The collected fees are transferred to the transaction sender if they are non-zero,
    /// otherwise they are destroyed.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `pool` - The pool containing the position
    /// * `position` - Position to remove liquidity from
    /// * `liquidity` - Amount of liquidity to remove
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Tuple containing balances of both token types after liquidity removal
    fun remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): ( sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            true
        );

        if (collected_fee_a.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(sui::coin::from_balance<CoinTypeA>(collected_fee_a, ctx), tx_context::sender(ctx));
        } else {
            collected_fee_a.destroy_zero();
        };
        
        if (collected_fee_b.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(sui::coin::from_balance<CoinTypeB>(collected_fee_b, ctx), tx_context::sender(ctx));
        } else {
            collected_fee_b.destroy_zero();
        };

        let (removed_a,  removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            position,
            liquidity,
            clock
        );

        (removed_a, removed_b)
    }

    /// Attempts to add remaining token balances from a locked position back as liquidity.
    /// 
    /// This function checks if there are any remaining token balances in the LockedPosition
    /// that can be added back as liquidity to the position. It calculates the optimal
    /// amounts of both tokens that can be added while maintaining the correct ratio,
    /// and adds them as liquidity if possible.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `pool` - The pool containing the position
    /// * `lock_position` - Locked position containing remaining token balances
    /// * `position` - Position to add liquidity to
    /// * `clock` - Clock object for timestamp verification
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
        }
    }

    /// Internal function to add liquidity to a position.
    /// 
    /// This function handles the liquidity addition process by:
    /// 1. Adding liquidity to the position and getting a receipt
    /// 2. Calculating required payment amounts
    /// 3. Handling any remainder balances
    /// 4. Verifying correct distribution of liquidity
    /// 5. Return remaining tokens after liquidity addition
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `pool` - The pool to add liquidity to
    /// * `position` - Position to add liquidity to
    /// * `amount_a` - Balance of first token type
    /// * `amount_b` - Balance of second token type
    /// * `liquidity` - Amount of liquidity to add
    /// * `clock` - Clock object for timestamp verification
    /// 
    /// # Returns
    /// Tuple containing remainder balances of both token types
    /// 
    /// # Aborts
    /// * If the distribution of liquidity tokens is incorrect
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

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let locker = Locker {
            id: sui::object::new(ctx),
            locker_cap: option::none<locker_cap::locker_cap::LockerCap>(),
            version: VERSION,
            positions: sui::object_table::new<ID, clmm_pool::position::Position>(ctx),
            periods_blocking: std::vector::empty<u64>(),
            periods_post_lockdown: std::vector::empty<u64>(),
            pause: false,
        };
        sui::transfer::share_object<Locker>(locker);
    
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
    }

    #[test_only]
    public fun get_coins<CoinTypeA, CoinTypeB>(lock: &LockedPosition<CoinTypeA, CoinTypeB>): (u64, u64) {
        (lock.coin_a.value(), lock.coin_b.value())
    }
    
}

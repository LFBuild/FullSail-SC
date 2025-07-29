/// Liquidity Locker Module V2 with rewards
/// 
/// This module provides functionality for locking liquidity positions in a CLMM (Concentrated Liquidity Market Maker) pool.
/// It allows users to lock their liquidity positions for a specified period and earn rewards based on their lock duration
/// and the amount of liquidity provided.
/// 
/// Key features:
/// * Lock liquidity positions for specified periods
/// * Split and modify locked positions
/// * Change tick ranges of locked positions
/// * Claim rewards from locked positions
/// 
/// The module integrates with the CLMM pool system and uses a gauge-based reward distribution mechanism.
/// It ensures that locked positions cannot be modified or withdrawn before the lock period ends, while still
/// allowing users to earn rewards during the lock period.
/// 
/// # Security
/// The module implements various security checks to ensure:
/// * Positions cannot be modified before lock period ends
/// * Rewards must be claimed before position modifications
/// * Invalid operations are prevented through capability-based access control
/// 
/// # Integration
/// This module works in conjunction with:
/// * CLMM Pool system for liquidity management
/// * Distribution system for reward calculations
/// * Pool Tranche system for determining lock profitability and reward distribution
module liquidity_locker::liquidity_lock_v2 {
    use liquidity_locker::pool_tranche;
    use liquidity_locker::consts;
    use liquidity_locker::locker_utils;
    use distribution::common;
    use distribution::gauge;
    
    // Bump the `VERSION` of the package.
    const VERSION: u64 = 1;

    const EInvalidPeriodsLength: u64 = 938724658124718472;
    const EInvalidProfitabilitiesLength: u64 = 93877534345684724;
    const ENoRewards: u64 = 93872459482342874;
    const EPositionNotStaked: u64 = 9387213431353484;
    const EInvalidBlockPeriodIndex: u64 = 938724654546442874;
    const EFullLockPeriodNotEnded: u64 = 98923745837578344;
    const EFullLockPeriodEnded: u64 = 93297692597493433;
    const EPositionAlreadyLocked: u64 = 9387246576346433;
    const ENoTranches: u64 = 9823742374723842;
    const ERewardsNotCollected: u64 = 912944864567454;
    const ELockPeriodNotEnded: u64 = 91204958347574966;
    const ELockManagerPaused: u64 = 916023534273428375;
    const EClaimEpochIncorrect: u64 = 92352956173712842;
    const ENoLiquidityToRemove: u64 = 91877547573637423;
    const EInvalidGaugePool: u64 = 9578252764818432;
    const EIncorrectLiquidityAmountA: u64 = 95346237427834273;
    const EIncorrectLiquidityAmountB: u64 = 92368340637234706;
    const EInvalidShareLiquidityToFill: u64 = 902354235823942382;
    const EPositionNotLocked: u64 = 92035925692467234;
    const ENotChangedTickRange: u64 = 96203676234264517;
    const EIncorrectSwapResultA: u64 = 9259346230481212;
    const EIncorrectSwapResultB: u64 = 9387240376820348;
    const EPackageVersionMismatch: u64 = 9346920730473042;
    const ELockerInitialized: u64 = 9329703470234099;
    const EInsufficientBalanceAOutput: u64 = 9367234807236103;
    const EInsufficientBalanceBOutput: u64 = 9247240362830633;
    const EAdminNotWhitelisted: u64 = 9389469239702349;
    const EAddressNotAdmin: u64 = 9630793046376343;
    const EInvalidEpochOSailToken: u64 = 9435974578489789;
    const EInvalidRewardCoinType: u64 = 9230764536453211;

    /// Capability for administrative functions in the protocol.
    /// This capability is required for managing global settings and protocol parameters.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the capability
    public struct SuperAdminCap has store, key {
        id: sui::object::UID,
    }

    /// Main state structure for the liquidity locker protocol.
    /// This structure holds all the essential data for managing locked liquidity positions.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the locker instance
    /// * `locker_cap` - Optional capability for managing locker operations
    /// * `version` - Protocol version number
    /// * `admins` - Vector of admin addresses that are allowed to manage the locker
    /// * `staked_positions` - Table mapping position IDs to their staked position
    /// * `periods_blocking` - Vector of lock periods measured in epochs
    /// * `periods_post_lockdown` - Vector of post-lock periods in epochs (must match length of periods_blocking)
    /// * `pause` - Flag indicating if the locker is paused
    public struct Locker has store, key {
        id: sui::object::UID,
        locker_cap: Option<locker_cap::locker_cap::LockerCap>,
        version: u64,
        admins: sui::vec_set::VecSet<address>,
        staked_positions: sui::object_table::ObjectTable<ID, distribution::gauge::StakedPosition>, // key - position ID
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
        pause: bool,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
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
    /// * `start_lock_time` - Timestamp when the lock period starts
    /// * `expiration_time` - Timestamp when the lock period expires
    /// * `full_unlocking_time` - Timestamp when the position can be fully unlocked
    /// * `profitability` - Profitability rate in parts multiplied by profitability_rate_denom
    /// * `last_reward_claim_epoch` - Epoch of the last reward claim
    /// * `last_growth_inside` - Last recorded growth inside the position's range
    /// * `lock_liquidity_info` - Information about the locked liquidity
    /// * `coin_a` - Accumulated balance of the first token from position rebalancing that will be returned to position liquidity
    /// * `coin_b` - Accumulated balance of the second token from position rebalancing that will be returned to position liquidity
    /// * `accumulated_amount_earned` - Accumulated rewards from the last unclaimed epoch.
    /// * `earned_epoch` - Table tracking earned rewards per epoch (epoch -> earned)
    /// These rewards are stored during position rebalancing to account for liquidity changes. Reset after each reward claim.
    public struct LockedPosition<phantom CoinTypeA, phantom CoinTypeB> has store, key {
        id: sui::object::UID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        start_lock_time: u64,
        expiration_time: u64, 
        full_unlocking_time: u64, 
        profitability: u64,
        last_reward_claim_epoch: u64,
        last_growth_inside: u128,
        accumulated_amount_earned: u64,
        earned_epoch: sui::table::Table<u64, u64>,
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
    /// * `start_lock_time` - Timestamp when the lock period starts
    /// * `expiration_time` - Timestamp when the lock period ends
    /// * `full_unlocking_time` - Timestamp when the position can be fully unlocked
    /// * `profitability` - Profitability rate for this locked position
    /// * `last_reward_claim_epoch` - Epoch of the last reward claim
    /// * `last_growth_inside` - Last recorded growth inside the position's range
    /// * `remainder_a` - Remaining amount of the first token after rebalancing
    /// * `remainder_b` - Remaining amount of the second token after rebalancing
    public struct CreateLockPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        position_id: sui::object::ID,
        tranche_id: sui::object::ID,
        total_lock_liquidity: u128,
        start_lock_time: u64,
        expiration_time: u64,
        full_unlocking_time: u64,
        profitability: u64,
        last_reward_claim_epoch: u64,
        last_growth_inside: u128,
        remainder_a: u64,
        remainder_b: u64,
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

    /// Event emitted when a position is split.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `new_lock_position_id` - Unique identifier of the new locked position
    /// * `share_first_part` - Share of the first part of the position
    /// * `new_total_lock_liquidity` - Total amount of liquidity locked in the new position
    /// * `new_current_lock_liquidity` - Current amount of locked liquidity in the new position
    /// * `new_last_growth_inside` - Last recorded growth inside the new position's range
    /// * `new_accumulated_amount_earned` - Accumulated rewards from the last unclaimed epoch. 
    /// These rewards are stored during position rebalancing to account for liquidity changes. Reset after each reward claim.
    /// * `remainder_a` - Remaining amount of the first token after rebalancing
    /// * `remainder_b` - Remaining amount of the second token after rebalancing
    public struct SplitPositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        new_lock_position_id: sui::object::ID,
        share_first_part: u64,
        new_total_lock_liquidity: u128,
        new_current_lock_liquidity: u128,
        new_last_growth_inside: u128,
        new_accumulated_amount_earned: u64,
        remainder_a: u64,
        remainder_b: u64,
    }

    /// Event emitted when the tick range of a locked position is changed.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `new_position_id` - Unique identifier of the new position with updated range
    /// * `new_lock_liquidity` - Amount of liquidity in the new position
    /// * `new_tick_lower` - New lower tick boundary of the position
    /// * `new_tick_upper` - New upper tick boundary of the position
    /// * `new_last_growth_inside` - New last recorded growth inside the position's range
    /// * `new_accumulated_amount_earned` - New accumulated rewards from the last unclaimed epoch. 
    /// * `remainder_a` - Remaining amount of the first token after rebalancing
    /// * `remainder_b` - Remaining amount of the second token after rebalancing
    public struct ChangeRangePositionEvent has copy, drop {
        lock_position_id: sui::object::ID,
        new_position_id: sui::object::ID,
        new_lock_liquidity: u128,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
        new_last_growth_inside: u128,
        new_accumulated_amount_earned: u64,
        new_total_lock_liquidity: u128,
        new_current_lock_liquidity: u128,
        remainder_a: u64,
        remainder_b: u64,
    }

    /// Event emitted when rewards are collected from a locked position.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the locked position
    /// * `reward_type` - Type of the reward token being collected
    /// * `claim_epoch` - Epoch timestamp in seconds for claiming rewards
    /// * `income` - Amount of rewards earned based on profitability
    /// * `reward_balance` - Total balance of rewards collected
    public struct CollectRewardsEvent has copy, drop {
        lock_position_id: sui::object::ID,
        reward_type: std::type_name::TypeName,
        claim_epoch: u64,
        income: u64,
        reward_balance: u64,
    }

    /// Event emitted when the first claim in epoch is made.
    /// 
    /// # Fields
    /// * `last_growth_inside` - Last growth inside value
    /// * `earned_amount_calc` - Earned amount calculated
    /// * `last_reward_claim_epoch` - Epoch of the last reward claim
    /// * `next_reward_claim_epoch` - Epoch of the next reward claim
    public struct FirstClaimInEpochEvent has copy, drop {
        last_growth_inside: u128,
        earned_amount_calc: u64,
        last_reward_claim_epoch: u64,
        next_reward_claim_epoch: u64,
    }

    /// Event emitted when a locked position is migrated.
    /// 
    /// # Fields
    /// * `lock_position_id` - Unique identifier of the migrated position
    /// * `position_id` - Unique identifier of the underlying liquidity position
    /// * `last_growth_inside` - Last growth inside value
    public struct MigrateLockPositionEvent has copy, drop {
        lock_position_id_v1: sui::object::ID,
        lock_position_id_v2: sui::object::ID,
        position_id: sui::object::ID,
        last_growth_inside: u128,
    }

    /// Creates a locker v2 with the specified parameters.
    /// 
    /// This function creates a new locker with the same parameters as the locker v1,
    /// but with a different version number. It also initializes the locker v2 and
    /// emits an initialization event.
    /// 
    /// It is necessary because when upgrading, the init function is not called.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `locker_v1` - The locker v1 object to create the locker v2 from
    /// * `create_locker_cap` - Capability to create locker functionality
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the locker v2 has already been initialized (error code: ELockerInitialized)
    public fun create_locker(
        _admin_cap: &mut liquidity_locker::liquidity_lock_v1::SuperAdminCap,
        locker_v1: &liquidity_locker::liquidity_lock_v1::Locker,
        create_locker_cap: &locker_cap::locker_cap::CreateCap,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(!_admin_cap.get_init_locker_v2(), ELockerInitialized);

        _admin_cap.init_locker_v2();

        let (periods_blocking, periods_post_lockdown) = locker_v1.get_lock_periods();
        
        let mut locker = Locker {
            id: sui::object::new(ctx),
            locker_cap: option::none<locker_cap::locker_cap::LockerCap>(),
            version: VERSION,
            admins: sui::vec_set::from_keys<address>(*locker_v1.admins().keys<address>()),
            staked_positions: sui::object_table::new<ID, distribution::gauge::StakedPosition>(ctx),
            periods_blocking: periods_blocking,
            periods_post_lockdown: periods_post_lockdown,
            pause: locker_v1.pause(),
            bag: sui::bag::new(ctx),
        };

        let locker_id = sui::object::id<Locker>(&locker);

        let event = InitLockerEvent { locker_id };
        sui::event::emit<InitLockerEvent>(event);


        let locker_cap = create_locker_cap.create_locker_cap(
            ctx
        );
        locker.locker_cap.fill(locker_cap);

        locker.periods_blocking = periods_blocking;
        locker.periods_post_lockdown = periods_post_lockdown;

        let event = UpdateLockPeriodsEvent {
            locker_id: locker_id,
            periods_blocking,
            periods_post_lockdown,
        };
        sui::event::emit<UpdateLockPeriodsEvent>(event);

        sui::transfer::share_object<Locker>(locker);

        let admin_cap = SuperAdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<SuperAdminCap>(admin_cap, sui::tx_context::sender(ctx));
    }
    
    /// Updates the blocking and post-lockdown periods for the locker.
    /// 
    /// This function allows administrators to modify the time periods used for position locking.
    /// Both vectors must have the same length and cannot be empty.
    /// New periods will only be applied to new position locks, existing locked positions will keep their original periods.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to update
    /// * `periods_blocking` - Vector of blocking periods in epochs
    /// * `periods_post_lockdown` - Vector of post-lockdown periods in epochs
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    /// * If periods_blocking is empty
    /// * If periods_blocking and periods_post_lockdown have different lengths
    public fun update_lock_periods(
        locker: &mut Locker, 
        periods_blocking: vector<u64>,
        periods_post_lockdown: vector<u64>,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        checked_package_version(locker);
        check_admin(locker, sui::tx_context::sender(ctx));
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
    /// * `locker` - The locker object to update
    /// * `pause` - New pause state (true to pause, false to unpause)
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun locker_pause(
        locker: &mut Locker,
        pause: bool,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        checked_package_version(locker);
        check_admin(locker, sui::tx_context::sender(ctx));
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

    /// Checks if the package version matches the expected version.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to check
    /// 
    /// # Abort Conditions
    /// * If the package version is not a version of liquidity_locker_v1 (error code: EPackageVersionMismatch)
    public fun checked_package_version(locker: &Locker) {
        assert!(locker.version == VERSION, EPackageVersionMismatch);
    }

    /// Checks if the provided admin is whitelisted in the locker.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to check
    /// * `admin` - The address of the admin to check
    /// 
    /// # Abort Conditions
    /// * If the admin is not whitelisted (error code: EAdminNotWhitelisted)
    public fun check_admin(locker: &Locker, admin: address) {
        assert!(locker.admins.contains<address>(&admin), EAdminNotWhitelisted);
    }

    /// Adds an admin to the locker.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `locker` - The locker object to add the admin to
    /// * `new_admin` - The address of the admin to add
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the admin is not whitelisted (error code: EAdminNotWhitelisted)
    /// * If the new_admin address is already an admin (error code: EAddressNotAdmin)
    public fun add_admin(
        _admin_cap: &SuperAdminCap,
        locker: &mut Locker, 
        new_admin: address, 
        ctx: &mut sui::tx_context::TxContext,
    ) {
        checked_package_version(locker);
        check_admin(locker, sui::tx_context::sender(ctx));

        assert!(!locker.admins.contains(&new_admin), EAddressNotAdmin);
        locker.admins.insert(new_admin);
    }

    /// Checks if the provided admin is whitelisted in the locker.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to check
    /// * `admin` - The address of the admin to check
    /// 
    /// # Returns
    /// Boolean indicating if the admin is whitelisted (true) or not (false)
    public fun is_admin(locker: &Locker, admin: address): bool {
        locker.admins.contains(&admin)
    }

    /// Revokes an admin from the locker.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `locker` - The locker object to revoke the admin from
    /// * `who` - The address of the admin to revoke
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the admin is not whitelisted (error code: EAdminNotWhitelisted)
    /// * If the who address is not an admin (error code: EAddressNotAdmin)
    public fun revoke_admin(
        _admin_cap: &SuperAdminCap,
        locker: &mut Locker,
        who: address,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        checked_package_version(locker);
        check_admin(locker, sui::tx_context::sender(ctx));

        assert!(locker.admins.contains(&who), EAddressNotAdmin);
        locker.admins.remove(&who); 
    }

    /// Returns the version of the locker.
    /// 
    /// # Arguments
    /// * `locker` - The locker object to get the version from
    /// 
    /// # Returns
    /// The version of the locker
    public fun get_locker_version(locker: &Locker): u64 {
        locker.version
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
    /// * `staked_position` - Staked position to lock
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
    public fun lock_position<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &mut Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        block_period_index: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): vector<LockedPosition<CoinTypeA, CoinTypeB>> {
        checked_package_version(locker);
        assert!(!locker.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(
            pool.position_manager().borrow_position_info(staked_position.position_id()).is_staked(),
            EPositionNotStaked
        );
        assert!(!locker.staked_positions.contains(staked_position.position_id()), EPositionAlreadyLocked);
        assert!(block_period_index < locker.periods_blocking.length(), EInvalidBlockPeriodIndex);

        let duration_block = common::epoch_to_seconds(locker.periods_blocking[block_period_index]);
        let current_time = clock.timestamp_ms() / 1000;
        let expiration_time = common::epoch_next(current_time + duration_block);
        let full_unlocking_time = expiration_time + common::epoch_to_seconds(locker.periods_post_lockdown[block_period_index]);

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let tranches = pool_tranche_manager.get_tranches(pool_id);

        assert!(tranches.length() > 0, ENoTranches);

        let current_growth_inside = gauge.get_current_growth_inside(pool, staked_position.position_id(), current_time);

        let mut lock_positions = std::vector::empty<LockedPosition<CoinTypeA, CoinTypeB>>();
        let mut opt_staked_position: Option<distribution::gauge::StakedPosition> = std::option::some(staked_position);
        let mut i = 0;
        while (i < tranches.length()) {

            if (opt_staked_position.is_none()) {
                break
            };

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
                locker_utils::calculate_position_liquidity_in_token_a(pool, opt_staked_position.borrow().position_id())
            } else {
                locker_utils::calculate_position_liquidity_in_token_b(pool, opt_staked_position.borrow().position_id())
            };

            let (
                staked_position_for_lock, 
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
                    staked_position_1, 
                    liquidity_1,
                    staked_position_2,
                    _,
                    remainder_a,
                    remainder_b,
                ) = split_position_internal<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    distribution_config,
                    locker,
                    gauge,
                    pool,
                    opt_staked_position.extract(),
                    share_first_part,
                    clock,
                    ctx,
                );

                opt_staked_position.fill(staked_position_2); // for next iteration

                pool_tranche::fill_tranches(
                    tranche,
                    delta_volume,
                );

                // return
                (
                    staked_position_1, 
                    liquidity_1, 
                    remainder_a,
                    remainder_b,
                    true,
                )
            } else {
                pool_tranche::fill_tranches(
                    tranche,
                    liquidity_in_token,
                );

                let staked_position_1 = opt_staked_position.extract();

                // return
                let position_liquidity = pool.position_manager().borrow_position_info(staked_position_1.position_id()).info_liquidity();
                (
                    staked_position_1, 
                    position_liquidity, 
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
                position_id: staked_position_for_lock.position_id(),
                tranche_id: tranche_id,
                start_lock_time: current_time,
                expiration_time: expiration_time,
                full_unlocking_time: full_unlocking_time,
                profitability: profitability,
                last_growth_inside: current_growth_inside,
                accumulated_amount_earned: 0,
                earned_epoch: sui::table::new(ctx),
                last_reward_claim_epoch: common::epoch_start(current_time),
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
                start_lock_time: lock_position.start_lock_time,
                expiration_time: lock_position.expiration_time,
                full_unlocking_time: lock_position.full_unlocking_time,
                profitability: lock_position.profitability,
                last_reward_claim_epoch: lock_position.last_reward_claim_epoch,
                last_growth_inside: lock_position.last_growth_inside,
                remainder_a: lock_position.coin_a.value(),
                remainder_b: lock_position.coin_b.value(),
            };
            sui::event::emit<CreateLockPositionEvent>(event);

            locker.staked_positions.add(lock_position.position_id, staked_position_for_lock);
            gauge.lock_position(locker.locker_cap.borrow(), lock_position.position_id);
            lock_positions.push_back(lock_position);

            if (!split) {
                break
            };

            i = i + 1;
            assert!(i < tranches.length() || !opt_staked_position.is_none(), EPositionNotLocked);
        };

        assert!(opt_staked_position.is_none(), EPositionNotLocked);
        opt_staked_position.destroy_none();

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
        locker.staked_positions.contains(position_id)
    }

    /// Safely removes liquidity from a locked position and transfers it to the sender address.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the CLMM pool
    /// * `distribution_config` - Distribution configuration
    /// * `minter` - Minter object
    /// * `vault` - Global reward vault
    /// * `voter` - Voter object
    /// * `locker` - The locker instance
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `lock_position` - The locked position to remove liquidity from
    /// * `min_amount_a` - Minimum amount of CoinTypeA to remove
    /// * `min_amount_b` - Minimum amount of CoinTypeB to remove
    /// * `clock` - Clock for time-based operations
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `SailCoinType` - SAIL token type
    /// * `EpochOSail` - The OSail token of the current epoch
    /// 
    /// # Returns
    /// Tuple of (Balance<CoinTypeA>, Balance<CoinTypeB>) containing the removed liquidity
    /// 
    /// # Aborts
    /// * `ELockManagerPaused` - If the locker is paused
    /// * `ELockPeriodNotEnded` - If the lock period has not ended
    /// * `EInvalidGaugePool` - If the gauge pool is invalid
    /// * `ERewardsNotCollected` - If rewards have not been collected
    /// * `ENoLiquidityToRemove` - If there is no liquidity available to remove
    /// * `EInsufficientBalanceAOutput` - If the amount of CoinTypeA to remove is less than the minimum amount min_amount_a
    /// * `EInsufficientBalanceBOutput` - If the amount of CoinTypeB to remove is less than the minimum amount min_amount_b
    public fun remove_lock_liquidity_save<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        voter: &distribution::voter::Voter,
        locker: &mut Locker,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        min_amount_a: u64,
        min_amount_b: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, sui::coin::Coin<EpochOSail>) {
        let (removed_a, removed_b, staking_reward) = remove_lock_liquidity<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            global_config,
            distribution_config,
            minter,
            vault,
            voter,
            locker,
            gauge,
            pool,
            lock_position,
            clock,
            ctx
        );

        assert!(removed_a.value<CoinTypeA>() >= min_amount_a, EInsufficientBalanceAOutput);
        assert!(removed_b.value<CoinTypeB>() >= min_amount_b, EInsufficientBalanceBOutput);
        
        (removed_a, removed_b, staking_reward)
    }
            
    /// Removes liquidity from a locked position. 
    /// Liquidity can be removed partially, proportionally to the epochs passed since expiration_time. 
    /// Before removing liquidity, all rewards must be claimed. 
    /// If all liquidity is removed, the position is unlocked and unstaked. 
    /// The lock_position object is destroyed and the clmm_pool::position::Position object is transferred to the sender.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the CLMM pool
    /// * `distribution_config` - Distribution configuration
    /// * `minter` - Minter object
    /// * `vault` - Global reward vault
    /// * `voter` - Voter object
    /// * `locker` - The locker instance
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `lock_position` - The locked position to remove liquidity from
    /// * `clock` - Clock for time-based operations
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `SailCoinType` - SAIL token type
    /// * `EpochOSail` - The OSail token of the current epoch
    /// 
    /// # Returns
    /// Tuple of (Balance<CoinTypeA>, Balance<CoinTypeB>) containing the removed liquidity
    /// 
    /// # Aborts
    /// * `ELockManagerPaused` - If the locker is paused
    /// * `ELockPeriodNotEnded` - If the lock period has not ended
    /// * `EInvalidGaugePool` - If the gauge pool is invalid
    /// * `ERewardsNotCollected` - If rewards have not been collected
    /// * `ENoLiquidityToRemove` - If there is no liquidity available to remove
    public fun remove_lock_liquidity<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        voter: &distribution::voter::Voter,
        locker: &mut Locker,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>, sui::coin::Coin<EpochOSail>) {
        checked_package_version(locker);
        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(current_time >= lock_position.expiration_time, ELockPeriodNotEnded);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);

        // Claim all rewards before removing liquidity (as rewards depend on liquidity)
        assert!(lock_position.last_reward_claim_epoch >= common::epoch_start(current_time) || 
            lock_position.last_reward_claim_epoch >= lock_position.full_unlocking_time, ERewardsNotCollected);
        assert!(std::type_name::get<EpochOSail>() == minter.borrow_current_epoch_o_sail(), EInvalidEpochOSailToken);

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
            let number_epochs_after_expiration = common::number_epochs_in_timestamp(current_time - lock_position.lock_liquidity_info.last_remove_liquidity_time);
            assert!(number_epochs_after_expiration > 0, ENoLiquidityToRemove);

            // Calculate portion of total liquidity that can be removed
            integer_mate::full_math_u128::mul_div_floor(
                lock_position.lock_liquidity_info.total_lock_liquidity,
                number_epochs_after_expiration as u128,
                common::number_epochs_in_timestamp(lock_position.full_unlocking_time - lock_position.expiration_time) as u128,
            )
        };
        assert!(remove_liquidity_amount > 0, ENoLiquidityToRemove);
        if (remove_liquidity_amount > lock_position.lock_liquidity_info.current_lock_liquidity) {
            remove_liquidity_amount = lock_position.lock_liquidity_info.current_lock_liquidity;
        };

        // calculate current reward before liquidity removal
        if (!full_remove) {
            let (current_earned, last_growth_inside) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, EpochOSail>(
                pool, 
                lock_position.position_id, 
                lock_position.last_growth_inside,
                clock
            );
            lock_position.last_growth_inside = last_growth_inside;
            lock_position.accumulated_amount_earned = lock_position.accumulated_amount_earned + current_earned;
        };

        // claim rewards for staked position
        let staking_reward = claim_position_reward_for_staking<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            locker,
            minter,
            voter,
            distribution_config,
            gauge,
            pool,
            &mut lock_position, 
            clock, 
            ctx
        );

        let old_staked_position = locker.staked_positions.remove(lock_position.position_id);

        // Unstake the position
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB>(
            locker.locker_cap.borrow(),
            pool,
            old_staked_position,
            clock,
            ctx,
        );

        let (mut removed_a, mut removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            remove_liquidity_amount,
            clock,
        );

        if (full_remove) {
            let (coin_a, coin_b) = unlock_position_internal(locker, lock_position, gauge);

            removed_a.join(coin_a);
            removed_b.join(coin_b);
            
            clmm_pool::pool::close_position<CoinTypeA, CoinTypeB>(global_config, pool, position);
        } else {
            // Restake the position
            let new_staked_position = gauge.deposit_position_by_locker(
                distribution_config,
                locker.locker_cap.borrow(),
                pool,
                position,
                clock,
                ctx,
            );
            locker.staked_positions.add(lock_position.position_id, new_staked_position);

            lock_position.lock_liquidity_info.current_lock_liquidity = lock_position.lock_liquidity_info.current_lock_liquidity - remove_liquidity_amount;
            lock_position.lock_liquidity_info.last_remove_liquidity_time = common::epoch_start(current_time);
            
            let event = UpdateLockLiquidityEvent {
                lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
                current_lock_liquidity: lock_position.lock_liquidity_info.current_lock_liquidity,
                last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time,
            };
            sui::event::emit<UpdateLockLiquidityEvent>(event);

            transfer::public_transfer<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position, sui::tx_context::sender(ctx));
        };

        (removed_a, removed_b, staking_reward)
    }

    /// Completely unlocks a position and destroys the LockedPosition object.
    /// Full unlocking is only possible after the full_unlocking_time has passed
    /// and all rewards have been claimed.
    /// 
    /// # Arguments
    /// * `locker` - The locker object containing the position
    /// * `lock_position` - The locked position to unlock
    /// * `clock` - Clock object for timestamp verification
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// 
    /// # Returns
    /// Tuple of (StakedPosition, Balance<CoinTypeA>, Balance<CoinTypeB>) containing the staked position that was unlocked and the remaining coins
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the full unlocking time has not been reached
    /// * If rewards have not been collected
    public fun unlock_position<CoinTypeA, CoinTypeB>(
        locker: &mut Locker,
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ): (distribution::gauge::StakedPosition, sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        checked_package_version(locker);
        assert!(!locker.pause, ELockManagerPaused);
        // Verify that the full lock period has ended
        assert!(clock.timestamp_ms()/1000 >= lock_position.full_unlocking_time, EFullLockPeriodNotEnded);

        assert!(lock_position.last_reward_claim_epoch >= lock_position.full_unlocking_time, ERewardsNotCollected);

        let position_id = lock_position.position_id;

        let (coin_a, coin_b) = unlock_position_internal(locker, lock_position, gauge);

        (locker.staked_positions.remove(position_id), coin_a, coin_b)
    }

    /// Unlocks a position internally
    /// 
    /// # Arguments
    /// * `locker` - The locker object containing the position
    /// * `lock_position` - The locked position to unlock
    /// * `gauge` - The gauge associated with the position
    /// 
    /// # Returns
    /// Tuple of (Balance<CoinTypeA>, Balance<CoinTypeB>) containing the remaining coins
    fun unlock_position_internal<CoinTypeA, CoinTypeB>(
        locker: &Locker,
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);

        let event = UnlockPositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
        };
        sui::event::emit<UnlockPositionEvent>(event);

        destroy(lock_position)
    }

    /// Destroys a locked position and transfers any remaining coins to the sender.
    /// 
    /// This function handles the cleanup of a locked position by:
    /// 1. Transferring any remaining coins to the sender
    /// 2. Deleting the position object
    /// 
    /// # Arguments
    /// * `lock_position` - The locked position to destroy
    /// 
    /// # Returns
    /// Tuple of (Balance<CoinTypeA>, Balance<CoinTypeB>) containing the remaining coins
    fun destroy<CoinTypeA, CoinTypeB>(
        lock_position: LockedPosition<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>)  {
        let LockedPosition<CoinTypeA, CoinTypeB> {
            id: lock_position_id,
            position_id: _,
            tranche_id: _,
            start_lock_time: _,
            expiration_time: _,
            full_unlocking_time: _,
            profitability: _,
            last_reward_claim_epoch: _,
            last_growth_inside: _,
            accumulated_amount_earned: _,
            earned_epoch: _earned_epoch,
            lock_liquidity_info: LockLiquidityInfo {
                total_lock_liquidity: _,
                current_lock_liquidity: _,
                last_remove_liquidity_time: _,
            },
            coin_a: coin_a,
            coin_b: coin_b,
        } = lock_position;

        _earned_epoch.drop();
        sui::object::delete(lock_position_id);

        (coin_a, coin_b)
    }

    /// Claims rewards in RewardCoinType for a staked position.
    /// You cannot do this directly from gauge, since you do not own StakedPosition
    /// 
    /// # Arguments
    /// * `locker` - Locker object
    /// * `minter` - Minter object
    /// * `voter` - Voter object
    /// * `distribution_config` - Distribution configuration
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `locked_position` - Locked position to claim rewards for
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the gauge and pool do not match
    /// * If rewards have already been claimed for the current period
    public fun claim_position_reward_for_staking<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        locker: &Locker,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        voter: &distribution::voter::Voter,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::coin::Coin<RewardCoinType> {
        checked_package_version(locker);
        assert!(!locker.pause, ELockManagerPaused);

        distribution::minter::get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
            minter,
            voter,
            distribution_config,
            gauge,
            pool,
            locker.staked_positions.borrow(locked_position.position_id),
            clock,
            ctx
        )
    }

    /// Collects rewards for a locked position.
    /// Rewards can only be claimed in the epoch following the last reward claim and not in the current epoch.
    /// The reward type for locked positions may differ from the staking reward type.
    /// 
    /// # Arguments
    /// * `locker` - SoftLocker object
    /// * `pool_tranche_manager` - Manager for pool tranches
    /// * `voting_escrow` - Voting escrow contract for SAIL token type verification
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `locked_position` - The locked position to collect rewards from
    /// * `claim_epoch` - Epoch timestamp in seconds for claiming rewards
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `EpochOSail` - The OSail token of the epoch for which the reward is being claimed
    /// * `SailCoinType` - SAIL token type
    /// * `LockRewardCoinType` - Reward type for locked positions
    /// 
    /// # Returns
    /// Balance of rewards collected for the locked position
    /// 
    /// # Aborts
    /// * If the gauge and pool do not match
    /// * If rewards have already been claimed for the current period
    public fun collect_reward<CoinTypeA, CoinTypeB, EpochOSail, SailCoinType, LockRewardCoinType>(
        locker: &Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        _: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        claim_epoch: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<LockRewardCoinType> {
        checked_package_version(locker);
        assert!(!locker.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(std::type_name::get<SailCoinType>() != std::type_name::get<LockRewardCoinType>(), EInvalidRewardCoinType);

        // Get reward balance based on profitability
        let reward_balance = get_rewards_internal<CoinTypeA, CoinTypeB, EpochOSail, LockRewardCoinType>(
            pool_tranche_manager,
            gauge,
            pool,
            locked_position,
            claim_epoch,
            clock,
            ctx
        );

        reward_balance
    }

    /// Collects rewards for a locked position in SAIL tokens.
    /// SAIL reward tokens are immediately locked for the maximum period.
    /// Rewards can only be claimed in the epoch following the last reward claim.
    /// 
    /// # Arguments
    /// * `pool_tranche_manager` - Manager for pool tranches
    /// * `voting_escrow` - Voting escrow contract for SAIL token locking
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `locked_position` - The locked position to collect rewards from
    /// * `claim_epoch` - Epoch timestamp in seconds for claiming rewards
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `EpochOSail` - The OSail token of the epoch for which the reward is being claimed
    /// * `SailCoinType` - SAIL token type for locked rewards
    /// 
    /// # Aborts
    /// * If the gauge and pool do not match
    /// * If rewards have already been claimed for the current period
    public fun collect_reward_sail<CoinTypeA, CoinTypeB, EpochOSail, SailCoinType>(
        locker: &Locker,
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        claim_epoch: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        checked_package_version(locker);
        assert!(!locker.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);

        let reward_balance = get_rewards_internal<CoinTypeA, CoinTypeB, EpochOSail, SailCoinType>(
            pool_tranche_manager,
            gauge,
            pool,
            locked_position,
            claim_epoch,
            clock,
            ctx
        );

        voting_escrow.create_lock(
            sui::coin::from_balance(reward_balance, ctx),
            common::max_lock_time() / common::day(),
            true,
            clock,
            ctx
        );
    }

    /// Internal function to calculate and distribute rewards for a locked position.
    /// 
    /// This function handles the reward calculation and distribution process by:
    /// 1. Determining the next valid claim time based on epochs
    /// 2. Calculating earned rewards for the period
    /// 3. Applying profitability rate to determine final reward amount
    /// 4. Retrieving the reward balance from the pool tranche
    /// 5. Emitting an event with reward details
    /// 
    /// # Arguments
    /// * `pool_tranche_manager` - Manager for pool tranches
    /// * `gauge` - Gauge for the pool
    /// * `pool` - The pool containing the position
    /// * `locked_position` - The locked position to collect rewards from
    /// * `claim_epoch` - Epoch timestamp in seconds for claiming rewards
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `EpochOSail` - The OSail token of the epoch for which the reward is being claimed
    /// * `LockRewardCoinType` - Reward type for locked positions
    /// 
    /// # Returns
    /// Balance of rewards to be distributed
    /// 
    /// # Aborts
    /// * If incorrect claim_epoch
    /// * If no rewards are available to claim
    fun get_rewards_internal<CoinTypeA, CoinTypeB, EpochOSail, LockRewardCoinType>(
        pool_tranche_manager: &mut pool_tranche::PoolTrancheManager,
        gauge: &gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        locked_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        mut claim_epoch: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<LockRewardCoinType> {
        claim_epoch = common::epoch_start(claim_epoch);

        let osail_epoch = std::type_name::get<EpochOSail>();
        assert!(osail_epoch == pool_tranche_manager.get_osail_epoch(claim_epoch), EInvalidEpochOSailToken);

        assert!(claim_epoch >= common::epoch_start(locked_position.start_lock_time) &&
            claim_epoch <= locked_position.last_reward_claim_epoch &&
            claim_epoch < common::epoch_start(locked_position.full_unlocking_time), EClaimEpochIncorrect); 

        let next_reward_claim_epoch = common::epoch_next(claim_epoch);

        let full_earned_amount = if (claim_epoch == locked_position.last_reward_claim_epoch && 
            !locked_position.earned_epoch.contains(claim_epoch)) {  // first claim in epoch

            // Calculate rewards earned
            let (mut earned_amount_calc, last_growth_inside) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, EpochOSail>(
                pool, 
                locked_position.position_id, 
                locked_position.last_growth_inside,
                clock
            );

            earned_amount_calc = earned_amount_calc + locked_position.accumulated_amount_earned;
            assert!(earned_amount_calc > 0, ENoRewards);

            locked_position.last_growth_inside = last_growth_inside;
            locked_position.accumulated_amount_earned = 0;
            locked_position.earned_epoch.add(claim_epoch, earned_amount_calc);

            let event = FirstClaimInEpochEvent {
                last_growth_inside,
                earned_amount_calc,
                last_reward_claim_epoch: locked_position.last_reward_claim_epoch,
                next_reward_claim_epoch,
            };
            
            locked_position.last_reward_claim_epoch = next_reward_claim_epoch;

            sui::event::emit<FirstClaimInEpochEvent>(event);

            earned_amount_calc
        } else {
            *locked_position.earned_epoch.borrow(claim_epoch)
        };

        // Calculate final reward amount based on profitability rate
        let income = integer_mate::full_math_u64::mul_div_floor(
            full_earned_amount,
            locked_position.profitability,
            consts::profitability_rate_denom()
        );

        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);

        // Get reward balance based on profitability
        let reward_balance = pool_tranche_manager.get_reward_balance<LockRewardCoinType>(
            pool_id,
            locked_position.tranche_id,
            sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(locked_position),
            income,
            claim_epoch,
            ctx,
        );

        let lock_position_id = sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(locked_position);
        let reward_type = std::type_name::get<LockRewardCoinType>();
        let event = CollectRewardsEvent { 
            lock_position_id,
            reward_type,
            claim_epoch,
            income,
            reward_balance: reward_balance.value<LockRewardCoinType>(),
        };
        sui::event::emit<CollectRewardsEvent>(event);

        reward_balance
    }

    /// Splits a locked position into two positions with specified liquidity share.
    /// The function splits the position into two parts:
    /// 1. Original position: retains share_first_part of the liquidity
    /// 2. New position: receives the remaining liquidity (1 - share_first_part in lock_liquidity_share_denom)
    /// Both positions maintain identical lock period and profitability settings.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `distribution_config` - Configuration for reward distribution
    /// * `minter` - Minter object
    /// * `vault` - Global vault for rewards
    /// * `voter` - Voter object
    /// * `locker` - The locker containing the position
    /// * `gauge` - Gauge associated with the position
    /// * `pool` - The pool containing the position
    /// * `lock_position` - The locked position to split
    /// * `share_first_part` - Share of liquidity for the first position (0..1.0 in lock_liquidity_share_denom)
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `SailCoinType` - SAIL token type
    /// * `EpochOSail` - The OSail token of the current epoch
    /// 
    /// # Returns
    /// Tuple of two LockedPosition objects representing the split positions
    /// sui::coin::Coin<EpochOSail> is the last rewards for the staked position
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the gauge and pool do not match
    /// * If the lock period has ended
    /// * If rewards have not been collected
    /// * If share_first_part is invalid
    public fun split_position<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        voter: &distribution::voter::Voter,
        locker: &mut Locker,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position: LockedPosition<CoinTypeA, CoinTypeB>,
        share_first_part: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (LockedPosition<CoinTypeA, CoinTypeB>, LockedPosition<CoinTypeA, CoinTypeB>, sui::coin::Coin<EpochOSail>) {
        checked_package_version(locker);
        let current_time = clock.timestamp_ms() / 1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(current_time < lock_position.full_unlocking_time, EFullLockPeriodEnded);

        // Ensure all rewards are collected before splitting
        assert!(lock_position.last_reward_claim_epoch >= common::epoch_start(current_time) || 
            lock_position.last_reward_claim_epoch >= lock_position.full_unlocking_time, ERewardsNotCollected);
        assert!(share_first_part <= consts::lock_liquidity_share_denom() && share_first_part > 0, EInvalidShareLiquidityToFill);
        assert!(std::type_name::get<EpochOSail>() == minter.borrow_current_epoch_o_sail(), EInvalidEpochOSailToken);

        // calculate current reward before split
        // let (current_earned, growth_inside) = gauge.earned_by_position<CoinTypeA, CoinTypeB, EpochOSail>(pool, lock_position.position_id, clock);
        let (current_earned, last_growth_inside) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, EpochOSail>(
            pool, 
            lock_position.position_id, 
            lock_position.last_growth_inside,
            clock
        );

        // claim last rewards for staked position
        let staking_reward = claim_position_reward_for_staking<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            locker,
            minter,
            voter,
            distribution_config,
            gauge,
            pool,
            &mut lock_position,
            clock,
            ctx
        );

        // Remove position from locker and gauge
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);
        let staked_position = locker.staked_positions.remove(lock_position.position_id);

        let (
            staked_position_1, 
            liquidity_1,
            staked_position_2,
            liquidity_2,
            remainder_a,
            remainder_b,
        ) = split_position_internal<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            distribution_config,
            locker,
            gauge,
            pool,
            staked_position,
            share_first_part,
            clock,
            ctx,
        );

        // Update first lock position
        lock_position.position_id = staked_position_1.position_id(); // remains unchanged
        lock_position.lock_liquidity_info.total_lock_liquidity = liquidity_1;
        lock_position.lock_liquidity_info.current_lock_liquidity = liquidity_1;
        lock_position.last_growth_inside = last_growth_inside;

        let current_accumulated_amount_earned = lock_position.accumulated_amount_earned + current_earned;
        lock_position.accumulated_amount_earned = integer_mate::full_math_u128::mul_div_floor(
            current_accumulated_amount_earned as u128,
            share_first_part as u128,
            consts::lock_liquidity_share_denom() as u128
        ) as u64;

        // Create new lock position with proportional split of remaining assets
        let new_coin_a_value = calculate_remainder_coin_split(
            lock_position.coin_a.value(),
            share_first_part
        );
        let new_coin_b_value = calculate_remainder_coin_split(
            lock_position.coin_b.value(),
            share_first_part
        );
        let new_lock_liquidity_info = LockLiquidityInfo {
            total_lock_liquidity: liquidity_2,   
            current_lock_liquidity: liquidity_2,
            last_remove_liquidity_time: lock_position.lock_liquidity_info.last_remove_liquidity_time
        };
        let mut new_lock_position = LockedPosition<CoinTypeA, CoinTypeB> {
            id: sui::object::new(ctx),
            position_id: staked_position_2.position_id(),
            tranche_id: lock_position.tranche_id,
            start_lock_time: lock_position.start_lock_time,
            expiration_time: lock_position.expiration_time,
            full_unlocking_time: lock_position.full_unlocking_time,
            profitability: lock_position.profitability,
            last_growth_inside: lock_position.last_growth_inside,
            accumulated_amount_earned: current_accumulated_amount_earned - lock_position.accumulated_amount_earned,
            earned_epoch: sui::table::new(ctx),
            last_reward_claim_epoch: lock_position.last_reward_claim_epoch,
            lock_liquidity_info: new_lock_liquidity_info,
            coin_a: lock_position.coin_a.split(new_coin_a_value),
            coin_b: lock_position.coin_b.split(new_coin_b_value),
        };

        new_lock_position.coin_a.join(remainder_a);
        new_lock_position.coin_b.join(remainder_b);

        // Register both positions in gauge and locker
        gauge.lock_position(locker.locker_cap.borrow(), lock_position.position_id);
        gauge.lock_position(locker.locker_cap.borrow(), new_lock_position.position_id);
        locker.staked_positions.add(lock_position.position_id, staked_position_1);
        locker.staked_positions.add(new_lock_position.position_id, staked_position_2);

        let new_lock_position_id = sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&new_lock_position);
        let split_event = SplitPositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position),
            new_lock_position_id: new_lock_position_id,
            share_first_part,
            new_total_lock_liquidity: lock_position.lock_liquidity_info.total_lock_liquidity,
            new_current_lock_liquidity: lock_position.lock_liquidity_info.current_lock_liquidity,
            new_last_growth_inside: lock_position.last_growth_inside,
            new_accumulated_amount_earned: lock_position.accumulated_amount_earned,
            remainder_a: lock_position.coin_a.value(),
            remainder_b: lock_position.coin_b.value(),
        };
        sui::event::emit<SplitPositionEvent>(split_event);

        let event = CreateLockPositionEvent {
            lock_position_id: new_lock_position_id,
            position_id: new_lock_position.position_id,
            tranche_id: new_lock_position.tranche_id,
            total_lock_liquidity: new_lock_position.lock_liquidity_info.total_lock_liquidity,
            start_lock_time: new_lock_position.start_lock_time,
            expiration_time: new_lock_position.expiration_time,
            full_unlocking_time: new_lock_position.full_unlocking_time,
            profitability: new_lock_position.profitability,
            last_reward_claim_epoch: new_lock_position.last_reward_claim_epoch,
            last_growth_inside: new_lock_position.last_growth_inside,
            remainder_a: new_lock_position.coin_a.value(),
            remainder_b: new_lock_position.coin_b.value(),
        };
        sui::event::emit<CreateLockPositionEvent>(event);

        (lock_position, new_lock_position, staking_reward)
    }
    
    /// Internal function to split a position into two parts with specified liquidity share.
    /// 
    /// This function handles the position splitting process by:
    /// 1. Withdrawing the original position from the gauge
    /// 2. Calculating liquidity split based on share_first_part
    /// 3. Removing liquidity from the original position
    /// 4. Creating a new position
    /// 5. Adding liquidity to the new position
    /// 6. Depositing both positions back to the gauge
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `vault` - Global vault for rewards
    /// * `distribution_config` - Configuration for reward distribution
    /// * `locker` - The locker containing the position
    /// * `gauge` - Gauge associated with the position
    /// * `pool` - The pool containing the position
    /// * `staked_position` - Staked position to split
    /// * `share_first_part` - Share of liquidity for the first position (0..1.0 in lock_liquidity_share_denom)
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Tuple containing:
    /// * Staked position for the original position
    /// * Liquidity for the original position
    /// * Staked position for the new position
    /// * Liquidity for the new position
    /// * Remainder balance of CoinTypeA
    /// * Remainder balance of CoinTypeB
    fun split_position_internal<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker: &Locker,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_position: distribution::gauge::StakedPosition,
        share_first_part: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (distribution::gauge::StakedPosition, u128, distribution::gauge::StakedPosition, u128,
        sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        // Withdraw position from gauge
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB>(
            locker.locker_cap.borrow(),
            pool,
            staked_position,
            clock,
            ctx,
        );

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
            &mut position,
            liquidity2,
            clock
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
        
        // Deposit both positions back to gauge
        let staked_position_1 = gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx,
        );
        let staked_position_2 = gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position2,
            clock,
            ctx,
        );

        (
            staked_position_1, 
            liquidity1, 
            staked_position_2, 
            liquidity2, 
            remainder_a,
            remainder_b,
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

    /// Calculates the split of a coin value into two parts based on the specified share ratio.
    /// 
    /// # Arguments
    /// * `coin_value` - Value of the coin to split
    /// * `share_first_part` - Share ratio for the first portion (0..1.0 in lock_liquidity_share_denom)
    /// 
    /// # Returns
    /// The value of the second portion of the coin
    /// 
    /// # Aborts
    /// * If share_first_part exceeds the maximum allowed share denominator
    fun calculate_remainder_coin_split(
        coin_value: u64,
        share_first_part: u64,
    ): u64 {

        assert!(share_first_part <= consts::lock_liquidity_share_denom(), EInvalidShareLiquidityToFill);

        let new_coin_value = integer_mate::full_math_u64::mul_div_floor(
            coin_value,
            (consts::lock_liquidity_share_denom() - share_first_part) as u64,
            consts::lock_liquidity_share_denom() as u64
        );
        
        new_coin_value
    }
    
    /// Changes the tick range of a locked position by creating a new position with the specified range.
    /// 
    /// This function performs the following operations:
    /// 1. Validates the position can be modified (not paused, valid gauge pool, not expired)
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
    /// * `distribution_config` - Distribution configuration for rewards
    /// * `minter` - Minter object
    /// * `vault` - Global vault for rewards
    /// * `voter` - Voter object
    /// * `locker` - Locker instance managing the position
    /// * `lock_position` - The locked position to modify
    /// * `gauge` - Gauge instance for the pool
    /// * `pool` - The pool containing the position
    /// * `stats` - Pool statistics
    /// * `price_provider` - Price provider for the pool
    /// * `new_tick_lower` - New lower tick bound for the position
    /// * `new_tick_upper` - New upper tick bound for the position
    /// * `clock` - Clock object for timestamp verification
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool
    /// * `SailCoinType` - SAIL token type
    /// * `EpochOSail` - The OSail token of the current epoch
    /// 
    /// # Returns
    /// sui::coin::Coin<EpochOSail> is the last rewards for the staked position
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the gauge pool is invalid
    /// * If the lock period has ended
    /// If rewards have not been collected
    /// * If the new tick range is the same as the current range
    /// * If token swap results are incorrect
    /// * If liquidity distribution is incorrect
    public fun change_tick_range<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        minter: &mut distribution::minter::Minter<SailCoinType>,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        voter: &distribution::voter::Voter,
        locker: &mut Locker,
        lock_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): sui::coin::Coin<EpochOSail> {
        checked_package_version(locker);
        let current_time = clock.timestamp_ms()/1000;
        assert!(!locker.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(current_time < lock_position.full_unlocking_time, EFullLockPeriodEnded);

        // Ensure rewards are collected before modifying position
        assert!(lock_position.last_reward_claim_epoch >= common::epoch_start(current_time) || 
            lock_position.last_reward_claim_epoch >= lock_position.full_unlocking_time, ERewardsNotCollected);

        assert!(std::type_name::get<EpochOSail>() == minter.borrow_current_epoch_o_sail(), EInvalidEpochOSailToken);

        // calculate current reward before change tick range
        // let (current_earned, _) = gauge.earned_by_position<CoinTypeA, CoinTypeB, EpochOSail>(pool, lock_position.position_id, clock);
        let (current_earned, _) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, EpochOSail>(
            pool, 
            lock_position.position_id, 
            lock_position.last_growth_inside,
            clock
        );

        // claim last rewards for staked position
        let staking_reward = claim_position_reward_for_staking<CoinTypeA, CoinTypeB, SailCoinType, EpochOSail>(
            locker,
            minter,
            voter,
            distribution_config,
            gauge,
            pool,
            lock_position,
            clock,
            ctx
        );

        // Unlock position from gauge and remove from locker
        gauge.unlock_position(locker.locker_cap.borrow(), lock_position.position_id);
        let staked_position = locker.staked_positions.remove(lock_position.position_id);

        // Withdraw position from gauge
        let mut position = gauge.withdraw_position_by_locker<CoinTypeA, CoinTypeB>(
            locker.locker_cap.borrow(),
            pool,
            staked_position,
            clock,
            ctx,
        );

        let (tick_lower, tick_upper) = position.tick_range();
        assert!(!new_tick_lower.eq(tick_lower) || !new_tick_upper.eq(tick_upper), ENotChangedTickRange);

        let sqrt_price_diff_old = clmm_pool::tick_math::get_sqrt_price_at_tick(tick_upper) - clmm_pool::tick_math::get_sqrt_price_at_tick(tick_lower);
        let sqrt_price_diff_new = clmm_pool::tick_math::get_sqrt_price_at_tick(new_tick_upper) - clmm_pool::tick_math::get_sqrt_price_at_tick(new_tick_lower);

        let position_liquidity = position.liquidity();

        // Remove liquidity and collect fees
        let (removed_a, removed_b) = remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            &mut position,
            position_liquidity,
            clock
        );

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

        let (mut liquidity_calc) = integer_mate::full_math_u128::mul_div_floor(
            position_liquidity,
            sqrt_price_diff_old,
            sqrt_price_diff_new
        );

        lock_position.coin_a.join(removed_a);
        lock_position.coin_b.join(removed_b);

        add_liquidity_by_lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            lock_position,
            &mut new_position,
            clock
        );

        if (
            (new_position.liquidity() >= liquidity_calc) || 
            (lock_position.coin_a.value() == 0 && lock_position.coin_b.value() == 0)
        ) {
            liquidity_calc = 0;
        } else {
            liquidity_calc = liquidity_calc - new_position.liquidity();
        };

        if (liquidity_calc > 0) {
            // Calculate final token amounts with adjusted liquidity
            let (mut amount_a_calc, mut amount_b_calc) = clmm_pool::clmm_math::get_amount_by_liquidity(
                new_tick_lower,
                new_tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                liquidity_calc,
                true
            );

            if (lock_position.coin_b.value() < amount_b_calc && lock_position.coin_a.value() < amount_a_calc) {
                (liquidity_calc, amount_a_calc, amount_b_calc) = get_liquidity_by_amount_by_lock_position(
                    pool, 
                    lock_position, 
                    new_tick_lower, 
                    new_tick_upper
                );
            };

            // Handle token imbalances through swaps
            // Calculate liquidity before swap to avoid price impact
            if (lock_position.coin_b.value() > amount_b_calc) {
                let calculate_swap_result = clmm_pool::pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    false,
                    true,
                    lock_position.coin_b.value() - amount_b_calc
                );

                let amount_a_out = calculate_swap_result.calculated_swap_result_amount_out();

                if ((amount_a_out + lock_position.coin_a.value()) < amount_a_calc) {
                    (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                        new_tick_lower,
                        new_tick_upper,
                        pool.current_tick_index(),
                        pool.current_sqrt_price(),
                        amount_a_out + lock_position.coin_a.value(),
                        true
                    );
                };
            } else {
                if (lock_position.coin_a.value() > amount_a_calc) {
                    let calculate_swap_result = clmm_pool::pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
                        global_config,
                        pool,
                        true,
                        true,
                        lock_position.coin_a.value() - amount_a_calc
                    );

                    let amount_b_out = calculate_swap_result.calculated_swap_result_amount_out();

                    if ((amount_b_out + lock_position.coin_b.value()) < amount_b_calc) {
                        (liquidity_calc, amount_a_calc, amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                            new_tick_lower,
                            new_tick_upper,
                            pool.current_tick_index(),
                            pool.current_sqrt_price(),
                            amount_b_out + lock_position.coin_b.value(),
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

            if ((lock_position.coin_b.value() > amount_b_calc) || (lock_position.coin_a.value() > amount_a_calc)) {
                // Token balance adjustment through swap
                // If token balance decreases, swap that portion to get maximum value of second token as reference
                let (receipt, swap_pay_amount_a, swap_pay_amount_b) = if (lock_position.coin_b.value() > amount_b_calc) {
                    // Swap B to A
                    let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                        global_config,
                        vault,
                        pool,
                        false, // a2b = false, since we swap B to A
                        true,
                        lock_position.coin_b.value() - amount_b_calc,
                        clmm_pool::tick_math::max_sqrt_price(),
                        stats,
                        price_provider,
                        clock
                    );
                    lock_position.coin_b.join(amount_b_out);
                    lock_position.coin_a.join(amount_a_out);

                    // Swap excess B token to get A, but it won't be sufficient to reach amount_a_calc
                    let swap_pay_amount_b_receipt = receipt.swap_pay_amount();
                    let swap_pay_amount_b = lock_position.coin_b.split(swap_pay_amount_b_receipt);

                    (receipt, sui::balance::zero<CoinTypeA>(), swap_pay_amount_b)
                } else {
                    // Swap A to B
                    let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                        global_config,
                        vault,
                        pool,
                        true,
                        true,
                        lock_position.coin_a.value() - amount_a_calc,
                        clmm_pool::tick_math::min_sqrt_price(),
                        stats,
                        price_provider,
                        clock
                    );
                    lock_position.coin_a.join(amount_a_out);
                    lock_position.coin_b.join(amount_b_out);

                    // Swap excess A token to get B, but it won't be sufficient to reach amount_b_calc
                    let swap_pay_amount_a_receipt = receipt.swap_pay_amount();
                    let swap_pay_amount_a = lock_position.coin_a.split(swap_pay_amount_a_receipt);

                    (receipt, swap_pay_amount_a, sui::balance::zero<CoinTypeB>())
                };

                assert!(lock_position.coin_a.value() >= amount_a_calc, EIncorrectSwapResultA);
                assert!(lock_position.coin_b.value() >= amount_b_calc, EIncorrectSwapResultB);

                clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    swap_pay_amount_a,
                    swap_pay_amount_b,
                    receipt
                );
            };

            let add_coin_a = lock_position.coin_a.split(pay_amount_a);
            let add_coin_b = lock_position.coin_b.split(pay_amount_b);
            
            assert!(pay_amount_a == add_coin_a.value(), EIncorrectLiquidityAmountA);
            assert!(pay_amount_b == add_coin_b.value(), EIncorrectLiquidityAmountB);

            clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
                global_config,
                pool,
                add_coin_a,
                add_coin_b,
                receipt,
            );
        };

        add_liquidity_by_lock_position_with_swap_internal<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            lock_position,
            &mut new_position,
            stats,
            price_provider,
            clock
        );

        let new_position_liquidity = new_position.liquidity();

        // Stake position
        let staked_position = gauge::deposit_position<CoinTypeA, CoinTypeB>(
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

        // get growth_inside for new range
        // let (_, growth_inside) = gauge.earned_by_position<CoinTypeA, CoinTypeB, EpochOSail>(pool, lock_position.position_id, clock);
        let (_, growth_inside) = gauge.full_earned_for_type<CoinTypeA, CoinTypeB, EpochOSail>(
            pool, 
            lock_position.position_id, 
            0,
            clock
        );
        lock_position.last_growth_inside = growth_inside;
        lock_position.accumulated_amount_earned = lock_position.accumulated_amount_earned + current_earned;
       
        let event = ChangeRangePositionEvent {
            lock_position_id: sui::object::id<LockedPosition<CoinTypeA, CoinTypeB>>(lock_position),
            new_position_id: new_position_id,
            new_lock_liquidity: new_position_liquidity,
            new_tick_lower: new_tick_lower,
            new_tick_upper: new_tick_upper,
            new_last_growth_inside: lock_position.last_growth_inside,
            new_accumulated_amount_earned: lock_position.accumulated_amount_earned,
            new_total_lock_liquidity: lock_position.lock_liquidity_info.total_lock_liquidity,
            new_current_lock_liquidity: lock_position.lock_liquidity_info.current_lock_liquidity,
            remainder_a: lock_position.coin_a.value(),
            remainder_b: lock_position.coin_b.value(),
        };

        gauge.lock_position(locker.locker_cap.borrow(), new_position_id);
        locker.staked_positions.add(new_position_id, staked_position);

        sui::event::emit<ChangeRangePositionEvent>(event);

        staking_reward
    }

    fun get_liquidity_by_amount_by_lock_position<CoinTypeA, CoinTypeB>(
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: &LockedPosition<CoinTypeA, CoinTypeB>,
        new_tick_lower: integer_mate::i32::I32,
        new_tick_upper: integer_mate::i32::I32,
    ): (u128, u64, u64) { // liquidity_calc, amount_a_calc, amount_b_calc
        if (
            lock_position.coin_a.value() == 0 &&
            lock_position.coin_b.value() == 0
        ) {
            return (0, 0, 0)
        };

        if (
            (lock_position.coin_a.value() > 0 &&
            lock_position.coin_a.value() < lock_position.coin_b.value()) ||
            lock_position.coin_b.value() == 0
        ) {
            clmm_pool::clmm_math::get_liquidity_by_amount(
                new_tick_lower,
                new_tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                lock_position.coin_a.value(),
                true
            )
        } else {
            clmm_pool::clmm_math::get_liquidity_by_amount(
                new_tick_lower,
                new_tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                lock_position.coin_b.value(),
                false
            )
        }
    }

    fun add_liquidity_by_lock_position_with_swap_internal<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        lock_position: &mut LockedPosition<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        stats: &mut clmm_pool::stats::Stats,
        price_provider: &price_provider::price_provider::PriceProvider,
        clock: &sui::clock::Clock,
    ) {
        let (tick_lower, tick_upper) = position.tick_range();
        if (integer_mate::i32::gte(pool.current_tick_index(), tick_lower) && integer_mate::i32::lt(pool.current_tick_index(), tick_upper)) {
            if (lock_position.coin_b.value() == 0 && lock_position.coin_a.value() > 2) {
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    vault,
                    pool,
                    true,
                    true,
                    lock_position.coin_a.value()/2,
                    clmm_pool::tick_math::min_sqrt_price(),
                    stats,
                    price_provider,
                    clock
                );
                lock_position.coin_a.join(amount_a_out);
                lock_position.coin_b.join(amount_b_out);

                clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    lock_position.coin_a.split(receipt.swap_pay_amount()),
                    sui::balance::zero<CoinTypeB>(),
                    receipt
                );
            };
            if (lock_position.coin_a.value() == 0 && lock_position.coin_b.value() > 2) {
                let (amount_a_out, amount_b_out, receipt) = clmm_pool::pool::flash_swap<CoinTypeA, CoinTypeB>(
                            global_config,
                            vault,
                            pool,
                            false,
                            true,
                            lock_position.coin_b.value()/2,
                            clmm_pool::tick_math::max_sqrt_price(),
                            stats,
                            price_provider,
                            clock
                        );
                        lock_position.coin_b.join(amount_b_out);
                        lock_position.coin_a.join(amount_a_out);

                clmm_pool::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
                    global_config,
                    pool,
                    sui::balance::zero<CoinTypeA>(),
                    lock_position.coin_b.split(receipt.swap_pay_amount()),
                    receipt
                );
            };
        };

        add_liquidity_by_lock_position<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            lock_position,
            position,
            clock
        );
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
    /// 
    /// # Returns
    /// Tuple containing balances of both token types after liquidity removal
    fun remove_liquidity_and_collect_fee<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut clmm_pool::position::Position,
        liquidity: u128,
        clock: &sui::clock::Clock
    ): ( sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {

        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            true
        );

        let (mut removed_a, mut removed_b) = clmm_pool::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            vault,
            pool,
            position,
            liquidity,
            clock
        );

        removed_a.join(collected_fee_a);
        removed_b.join(collected_fee_b);

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
        let (tick_lower, tick_upper) = position.tick_range();
        let (liquidity_calc, amount_a_calc, amount_b_calc) = if (
            integer_mate::i32::gte(pool.current_tick_index(), tick_upper) ||
            (integer_mate::i32::gt(pool.current_tick_index(), tick_lower) &&
            tick_upper.sub(pool.current_tick_index()).lt(pool.current_tick_index().sub(tick_lower)))
        ) {
            if (lock_position.coin_b.value() == 0) {
                return
            };
            let (_liquidity_calc, _amount_a_calc, _amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower,
                tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                lock_position.coin_b.value(),
                false
            );
            if (_amount_a_calc > lock_position.coin_a.value()) {
                if (lock_position.coin_a.value() == 0) {
                    return
                };
                clmm_pool::clmm_math::get_liquidity_by_amount(
                    tick_lower,
                    tick_upper,
                    pool.current_tick_index(),
                    pool.current_sqrt_price(),
                    lock_position.coin_a.value(),
                    true
                )
            } else {
                (_liquidity_calc, _amount_a_calc, _amount_b_calc)
            }
        } else {
            if (lock_position.coin_a.value() == 0) {
                return
            };
            let (_liquidity_calc, _amount_a_calc, _amount_b_calc) = clmm_pool::clmm_math::get_liquidity_by_amount(
                tick_lower,
                tick_upper,
                pool.current_tick_index(),
                pool.current_sqrt_price(),
                lock_position.coin_a.value(),
                true
            );
            if (_amount_b_calc > lock_position.coin_b.value()) {
                if (lock_position.coin_b.value() == 0) {
                    return
                };
                clmm_pool::clmm_math::get_liquidity_by_amount(
                    tick_lower,
                    tick_upper,
                    pool.current_tick_index(),
                    pool.current_sqrt_price(),
                    lock_position.coin_b.value(),
                    false
                )
            } else {
                (_liquidity_calc, _amount_a_calc, _amount_b_calc)
            }
        };

        if (lock_position.coin_a.value() >= amount_a_calc && lock_position.coin_b.value() >= amount_b_calc) {
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

        assert!(pay_amount_a == balance_a, EIncorrectLiquidityAmountA);
        assert!(pay_amount_b == balance_b, EIncorrectLiquidityAmountB);

        clmm_pool::pool::repay_add_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            amount_a,
            amount_b,
            receipt,
        );

        (remainder_a, remainder_b)
    }

    /// Migrates a locked position from v1 to v2.
    /// 
    /// # Arguments
    /// * `global_config` - Global configuration for the pool
    /// * `distribution_config` - Distribution configuration for rewards
    /// * `locker` - Locker instance managing the position
    /// * `locker_v1` - Locker v1 instance managing the position
    /// * `gauge` - Gauge instance for the pool
    /// * `pool` - The pool containing the position
    /// * `lock_position_v1` - LockedPosition v1 to migrate
    /// * `clock` - Clock object
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// * New LockedPosition v2
    /// 
    /// # Aborts
    /// * If the locker is paused
    /// * If the gauge is invalid
    /// * If the position is already locked
    /// * If the lock period has ended
    public fun lock_position_migrate<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        locker_v1: &mut liquidity_locker::liquidity_lock_v1::Locker,
        locker_v2: &mut Locker,
        gauge: &mut gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        mut lock_position_v1: liquidity_locker::liquidity_lock_v1::LockedPosition<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): LockedPosition<CoinTypeA, CoinTypeB> {
        checked_package_version(locker_v2);
        assert!(!locker_v2.pause, ELockManagerPaused);
        assert!(gauge::check_gauger_pool(gauge, pool), EInvalidGaugePool);
        assert!(!locker_v2.staked_positions.contains(lock_position_v1.get_locked_position_id()), EPositionAlreadyLocked);

        let current_time = clock.timestamp_ms()/1000;
        let start_epoch = common::epoch_start(current_time);
        let lock_position_id_v1 = object::id<liquidity_locker::liquidity_lock_v1::LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position_v1);

        let (
            tranche_id, 
            start_lock_time, 
            expiration_time, 
            full_unlocking_time, 
            coin_a, 
            coin_b,
        ) = liquidity_locker::liquidity_lock_v1::get_lock_position_info_for_migrate(&mut lock_position_v1);

        let lock_liquidity_info = LockLiquidityInfo {
            total_lock_liquidity: 0,   
            current_lock_liquidity: 0,
            last_remove_liquidity_time: 0,
        };
        let mut lock_position_v2 = LockedPosition<CoinTypeA, CoinTypeB> {
            id: sui::object::new(ctx),
            position_id: lock_position_v1.get_locked_position_id(),
            tranche_id: tranche_id,
            start_lock_time: start_lock_time,
            expiration_time: expiration_time,
            full_unlocking_time: full_unlocking_time,
            profitability: lock_position_v1.get_profitability(),
            last_growth_inside: 0,
            accumulated_amount_earned: 0,
            earned_epoch: sui::table::new(ctx),
            last_reward_claim_epoch: start_epoch,
            lock_liquidity_info,
            coin_a: coin_a,
            coin_b: coin_b,
        };

        let position = liquidity_locker::liquidity_lock_v1::lock_position_migrate(
            locker_v1,
            lock_position_v1,
            clock,
            ctx
        );
        let position_id = object::id<clmm_pool::position::Position>(&position);

        lock_position_v2.lock_liquidity_info.total_lock_liquidity = position.liquidity();
        lock_position_v2.lock_liquidity_info.current_lock_liquidity = lock_position_v2.lock_liquidity_info.total_lock_liquidity;

        let (collected_fee_a, collected_fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &position,
            true
        );
        if (collected_fee_a.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(
                sui::coin::from_balance(collected_fee_a, ctx), 
                tx_context::sender(ctx)
            );        
        } else {
            collected_fee_a.destroy_zero();
        };

        if (collected_fee_b.value() > 0) {
            transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(
                sui::coin::from_balance(collected_fee_b, ctx), 
                tx_context::sender(ctx)
            );
        } else {
            collected_fee_b.destroy_zero();
        };

        // Stake position
        let staked_position = gauge::deposit_position<CoinTypeA, CoinTypeB>(
            global_config,
            distribution_config,
            gauge,
            pool,
            position,
            clock,
            ctx
        );

        lock_position_v2.last_growth_inside = gauge.get_current_growth_inside(pool, position_id, current_time);

        locker_v2.staked_positions.add(position_id, staked_position);
        gauge.lock_position(locker_v2.locker_cap.borrow(), position_id);

        let event = MigrateLockPositionEvent { 
            lock_position_id_v1: lock_position_id_v1,
            lock_position_id_v2: object::id<LockedPosition<CoinTypeA, CoinTypeB>>(&lock_position_v2),
            position_id: position_id,
            last_growth_inside: lock_position_v2.last_growth_inside,
        };
        sui::event::emit<MigrateLockPositionEvent>(event);

        lock_position_v2
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let mut locker = Locker {
            id: sui::object::new(ctx),
            locker_cap: option::none<locker_cap::locker_cap::LockerCap>(),
            version: VERSION,
            admins: sui::vec_set::empty<address>(),
            staked_positions: sui::object_table::new<ID, distribution::gauge::StakedPosition>(ctx),
            periods_blocking: std::vector::empty<u64>(),
            periods_post_lockdown: std::vector::empty<u64>(),
            pause: false,
            bag: sui::bag::new(ctx),
        };
        locker.admins.insert(sui::tx_context::sender(ctx));

        sui::transfer::share_object<Locker>(locker);
    
        let admin_cap = SuperAdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<SuperAdminCap>(admin_cap, sui::tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_locker(
        _admin_cap: &SuperAdminCap,
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

    #[test_only]
    public fun get_coins<CoinTypeA, CoinTypeB>(lock: &LockedPosition<CoinTypeA, CoinTypeB>): (u64, u64) {
        (lock.coin_a.value(), lock.coin_b.value())
    }
}
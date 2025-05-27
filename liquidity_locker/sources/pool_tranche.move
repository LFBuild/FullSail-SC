/// Pool Tranche Module
/// 
/// This module manages tranches (segments) of liquidity pools in the liquidity locker system.
/// Each pool can have multiple tranches, where each tranche defines:
/// * Maximum liquidity volume in terms of either token A or token B
/// * Profitability rates for locked positions that enter the tranche
/// * Minimum remaining volume threshold that determines when the tranche closes
/// 
/// Key features:
/// * Create and manage pool-specific tranches with configurable parameters
/// * Track reward balances and income per epoch for each tranche
/// * Handle volume measurements in either token A or token B
/// * Manage profitability rates for different lock durations
/// * Control minimum remaining volume thresholds
/// * Distribute additional rewards in any token type proportionally to staking rewards each epoch
/// 
/// The module uses a tranche-based approach to organize liquidity and rewards.
/// When a tranche is filled (reaches its maximum volume), no new positions can enter it.
/// Each tranche maintains its own reward balance and tracks total volume and income.
/// Additional rewards are distributed proportionally to the staking rewards earned by positions in that tranche.
/// 
/// # Security
/// The module implements various security checks:
/// * Prevents duplicate reward entries
/// * Validates tranche existence before operations
/// * Ensures sufficient reward balances
/// * Controls tranche filling status
/// 
/// # Integration
/// This module works in conjunction with:
/// * Liquidity locker for position management
/// * Distribution system for reward calculations
/// * CLMM Pool system for liquidity tracking
module liquidity_locker::pool_tranche {
    
    use std::type_name::{Self, TypeName};
    use liquidity_locker::consts;
    use liquidity_locker::time_manager;

    const ETrancheFilled: u64 = 92357345723427311;
    const ERewardNotFound: u64 = 91235834582491043;
    const ETrancheNotFound: u64 = 923487825237452354;
    const ERewardNotEnough: u64 = 91294503453406623;
    const EInvalidAddLiquidity: u64 = 923487825237423743;
    const ETotalIncomeAlreadyExists: u64 = 932078340620346346;
    const ERewardAlreadyClaimed: u64 = 930267340729430623;
    const ETokenNotWhitelisted: u64 = 932069230794534963;

    // `VERSION` of the package.
    const VERSION: u64 = 1;

    /// Capability for administrative functions in the protocol.
    /// This capability is required for managing global settings and protocol parameters.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the capability
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    /// Manager for pool tranches that organizes tranches by pool ID.
    /// Maintains a mapping of pool IDs to their associated tranches.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the manager
    /// * `pool_tranches` - Table mapping pool IDs to their tranche vectors
    /// * `whitelisted_tokens` - Vector of whitelisted token types that are allowed to be used as rewards in the tranches
    /// * `ignore_whitelist` - Flag indicating if the whitelist should be ignored
    public struct PoolTrancheManager has store, key {
        id: UID,
        version: u64,
        pool_tranches: sui::table::Table<ID, vector<PoolTranche>>,
        whitelisted_tokens: sui::vec_set::VecSet<TypeName>,
        ignore_whitelist: bool
    }

    /// Represents a tranche within a pool that defines profitability multipliers for positions.
    /// Each tranche determines reward multipliers and tracks its volume capacity.
    /// Each tranche has its own token balances for rewards.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the tranche
    /// * `pool_id` - ID of the associated pool
    /// * `rewards_balance` - Bag storing total reward balances (reward_type -> balance)
    /// * `total_balance_epoch` - Table tracking total value balance of one type coin per epoch (epoch -> reward_type -> balance)
    /// * `total_income_epoch` - Table tracking total income per epoch (epoch -> total_income)
    /// * `claimed_rewards` - Table tracking claimed rewards per epoch  (lock id -> epoch -> reward_type -> claimed)
    /// * `volume_in_coin_a` - Flag indicating if volume is measured in coin A (true) or coin B (false)
    /// * `total_volume` - Maximum volume capacity of the tranche
    /// * `current_volume` - Current volume in the tranche
    /// * `filled` - Flag indicating if tranche has reached capacity
    /// * `minimum_remaining_volume` - Minimum volume threshold for tranche closure (in shares with minimum_remaining_volume_denom)
    /// * `duration_profitabilities` - Vector of profitability rates for different lock durations
    public struct PoolTranche has store, key {
        id: UID,
        pool_id: ID,
        rewards_balance: sui::bag::Bag,
        total_balance_epoch: sui::table::Table<u64, sui::table::Table<type_name::TypeName, u64>>,
        total_income_epoch: sui::table::Table<u64, u64>,
        claimed_rewards: sui::table::Table<ID, sui::table::Table<u64, sui::table::Table<type_name::TypeName, bool>>>,
        volume_in_coin_a: bool,
        total_volume: u128,
        current_volume: u128,
        filled: bool,
        minimum_remaining_volume: u64,
        duration_profitabilities: vector<u64>,
    }

    /// Event emitted when a new tranche manager is initialized.
    /// 
    /// # Fields
    /// * `tranche_manager_id` - Unique identifier of the created tranche manager
    public struct InitTrancheManagerEvent has copy, drop {
        tranche_manager_id: ID,
    }

    /// Event emitted when the ignore_whitelist flag is set.
    /// 
    /// # Fields
    /// * `ignore_whitelist` - Boolean value indicating if the whitelist should be ignored
    public struct SetIgnoreWhitelistEvent has copy, drop {
        ignore_whitelist: bool,
    }

    /// Event emitted when a token type is added to the whitelist.

    /// # Fields
    /// * `token_type` - The token type that was added to the whitelist
    public struct AddTokenTypeToWhitelistEvent has copy, drop {
        token_type: TypeName,
    }

    /// Event emitted when a token type is removed from the whitelist.
    /// 
    /// # Fields
    /// * `token_type` - The token type that was removed from the whitelist
    public struct RemoveTokenTypeFromWhitelistEvent has copy, drop {
        token_type: TypeName,
    }

    /// Event emitted when a new pool tranche is created.
    /// 
    /// # Fields
    /// * `tranche_id` - Unique identifier of the created tranche
    /// * `pool_id` - ID of the associated pool
    /// * `volume_in_coin_a` - Flag indicating if volume is measured in coin A (true) or coin B (false)
    /// * `total_volume` - Maximum volume capacity of the tranche (Q64.64 format)
    /// * `duration_profitabilities` - Vector of profitability rates for different lock durations
    public struct CreatePoolTrancheEvent has copy, drop {
        tranche_id: ID,
        pool_id: ID,
        volume_in_coin_a: bool,
        total_volume: u128,
        duration_profitabilities: vector<u64>,
    }

    /// Event emitted when a tranche's volume is updated.
    /// 
    /// # Fields
    /// * `tranche_id` - ID of the tranche being filled
    /// * `current_volume` - Current volume in the tranche (Q64.64 format)
    /// * `filled` - Flag indicating if tranche has reached capacity
    public struct FillTrancheEvent has copy, drop {
        tranche_id: ID,
        current_volume: u128,
        filled: bool,
    }

    /// Event emitted when rewards are added to a tranche.
    /// 
    /// # Fields
    /// * `tranche_id` - ID of the tranche receiving rewards
    /// * `epoch_start` - Start time of the epoch when rewards were added
    /// * `reward_type` - Type of reward token being added
    /// * `balance_value` - Amount of rewards added
    public struct AddRewardEvent has copy, drop {
        tranche_id: ID,
        epoch_start: u64,
        reward_type: TypeName,
        balance_value: u64,
        after_amount: u64,
    }

    /// Event emitted when total income is set for a tranche.
    /// 
    /// # Fields
    /// * `tranche_id` - ID of the tranche
    /// * `epoch_start` - Start time of the epoch
    /// * `total_income` - Total income accumulated in the tranche
    public struct SetIncomeEvent has copy, drop {
        tranche_id: ID,
        epoch_start: u64,
        total_income: u64,
    }

    /// Event emitted when rewards are claimed from a tranche.
    /// 
    /// # Fields
    /// * `tranche_id` - ID of the tranche from which rewards are claimed
    /// * `epoch_start` - Start time of the epoch for which rewards are claimed
    /// * `reward_amount` - Amount of rewards claimed
    public struct GetRewardEvent has copy, drop {
        tranche_id: ID,
        epoch_start: u64,
        reward_amount: u64,
    }

    /// Initializes the pool tranche manager and creates the admin capability.
    /// This function sets up the core infrastructure for managing pool tranches,
    /// including creating the manager object and transferring admin capabilities.
    /// 
    /// # Arguments
    /// * `ctx` - Transaction context for creating new objects
    /// 
    /// # Events
    /// Emits `InitTrancheManagerEvent` with the ID of the created manager
    fun init(ctx: &mut sui::tx_context::TxContext) {
        let tranche_manager = PoolTrancheManager {
            id: sui::object::new(ctx),
            version: VERSION,
            pool_tranches: sui::table::new(ctx),
            whitelisted_tokens: sui::vec_set::empty<TypeName>(),
            ignore_whitelist: false
        };

        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));

        let tranche_manager_id = sui::object::id<PoolTrancheManager>(&tranche_manager);
        sui::transfer::share_object<PoolTrancheManager>(tranche_manager);
        
        let event = InitTrancheManagerEvent { tranche_manager_id };
        sui::event::emit<InitTrancheManagerEvent>(event);
    }

    /// Sets the ignore_whitelist flag in the pool tranche manager.
    /// This function allows administrators to control whether token whitelist checks should be ignored.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability required for modifying manager settings
    /// * `manager` - The pool tranche manager instance to modify
    /// * `ignore` - Boolean value to set for the ignore_whitelist flag
    public fun set_ignore_whitelist(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        ignore: bool
    ) {
        manager.ignore_whitelist = ignore;

        let event = SetIgnoreWhitelistEvent {
            ignore_whitelist: ignore,
        };
        sui::event::emit<SetIgnoreWhitelistEvent>(event);
    }

    /// Returns the ignore_whitelist flag.
    /// 
    /// # Arguments
    /// * `manager` - The pool tranche manager instance
    /// 
    /// # Returns
    public fun get_ignore_whitelist_flag(manager: &PoolTrancheManager): bool {
        manager.ignore_whitelist
    }

    /// Adds a token types to the whitelist of allowed reward tokens.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability required for modifying manager settings
    /// * `manager` - The pool tranche manager instance
    /// * `token_types` - Vector of token types to add to the whitelist
    public fun add_token_types_to_whitelist(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        token_types: vector<TypeName>
    ) {
        let mut i = 0;
        while (i < token_types.length()) {
            let token_type = *token_types.borrow(i);
            if (!manager.whitelisted_tokens.contains(&token_type)) {
                manager.whitelisted_tokens.insert(token_type);

                let event = AddTokenTypeToWhitelistEvent {
                    token_type,
                };
                sui::event::emit<AddTokenTypeToWhitelistEvent>(event);
            };

            i = i + 1;
        }
    }

    /// Removes a token types from the whitelist of allowed reward tokens.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability required for modifying manager settings
    /// * `manager` - The pool tranche manager instance
    /// * `token_types` - Vector of token types to remove from the whitelist
    public fun remove_token_types_from_whitelist(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        token_types: vector<TypeName>
    ) {
        let mut i = 0;
        while (i < token_types.length()) {
            let token_type = *token_types.borrow(i);
            if (manager.whitelisted_tokens.contains(&token_type)) {
                manager.whitelisted_tokens.remove(&token_type);

                let event = RemoveTokenTypeFromWhitelistEvent {
                    token_type,
                };
                sui::event::emit<RemoveTokenTypeFromWhitelistEvent>(event);
            };

            i = i + 1;
        }
    }

    /// Returns the vector of whitelisted token types.
    /// 
    /// # Arguments
    /// * `manager` - The pool tranche manager instance
    /// 
    /// # Returns
    /// Vector of whitelisted token types
    public fun get_whitelisted_tokens(manager: &PoolTrancheManager): vector<TypeName> {
        manager.whitelisted_tokens.into_keys()
    }

    /// Creates a new pool tranche.
    /// This function initializes a new tranche with specified volume and profitability parameters,
    /// and associates it with a specific pool.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability required for creating tranches
    /// * `manager` - The pool tranche manager instance
    /// * `pool` - The CLMM pool associated with this tranche
    /// * `volume_in_coin_a` - Flag indicating if volume is measured in terms of coin A
    /// * `total_volume` - Total volume capacity of the tranche (in Q64.64 fixed-point format)
    /// * `duration_profitabilities` - Vector of profitability rates for different lock durations. Length must match locker.periods_blocking length
    /// * `minimum_remaining_volume` - Minimum volume that must remain in the tranche
    /// * `ctx` - Transaction context for creating new objects
    /// 
    /// # Events
    /// Emits `CreatePoolTrancheEvent` with details of the created tranche
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
            claimed_rewards: sui::table::new(ctx),
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

    /// Sets total_income_epoch and adds a reward for a specific tranche in the pool.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Admin capability for authorization
    /// * `manager` - Reference to the pool tranche manager
    /// * `pool_id` - ID of the pool containing the tranche
    /// * `tranche_id` - ID of the tranche to add reward to
    /// * `epoch_start` - Start time of the epoch in seconds
    /// * `balance` - Balance of reward tokens to add
    /// * `total_income` - Total income for the epoch
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// The total balance after adding the reward
    /// 
    /// # Aborts
    /// * If the reward token is not whitelisted and the ignore_whitelist flag is not set
    /// * If income for this epoch already exists
    /// * If tranche is not found
    public fun set_total_incomed_and_add_reward<RewardCoinType>(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        pool_id: sui::object::ID,
        tranche_id: sui::object::ID,
        epoch_start: u64,
        balance: sui::balance::Balance<RewardCoinType>,
        total_income: u64,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let reward_type = type_name::get<RewardCoinType>();
        assert!(manager.ignore_whitelist || manager.whitelisted_tokens.contains(&reward_type), ETokenNotWhitelisted);

        let tranche = get_tranche_by_id(manager, pool_id, tranche_id);

        let epoch_start = time_manager::epoch_start(epoch_start);
        assert!(!tranche.total_income_epoch.contains(epoch_start), ETotalIncomeAlreadyExists);

        tranche.total_income_epoch.add(epoch_start, total_income);

        let event = SetIncomeEvent {
            tranche_id,
            epoch_start,
            total_income,
        };
        sui::event::emit<SetIncomeEvent>(event);

        add_reward_internal(tranche, epoch_start, balance, ctx)
    }

    /// Adds a reward to a specific tranche in the pool for the epoch.
    /// 
    /// # Arguments
    /// * `_admin_cap` - Admin capability for authorization
    /// * `manager` - Reference to the pool tranche manager
    /// * `pool_id` - ID of the pool containing the tranche
    /// * `tranche_id` - ID of the tranche to add reward to
    /// * `epoch_start` - Start time of the epoch in seconds
    /// * `balance` - Balance of reward tokens to add
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// The total balance after adding the reward
    ///
    /// # Aborts
    /// * If the reward token is not whitelisted and the ignore_whitelist flag is not set
    /// * If tranche is not found
    public fun add_reward<RewardCoinType>(
        _admin_cap: &AdminCap,
        manager: &mut PoolTrancheManager,
        pool_id: sui::object::ID,
        tranche_id: sui::object::ID,
        epoch_start: u64,
        balance: sui::balance::Balance<RewardCoinType>,
        ctx: &mut sui::tx_context::TxContext
    ): u64 {
        let reward_type = type_name::get<RewardCoinType>();
        assert!(manager.ignore_whitelist || manager.whitelisted_tokens.contains(&reward_type), ETokenNotWhitelisted);

        let tranche = get_tranche_by_id(manager, pool_id, tranche_id);

        let epoch_start = time_manager::epoch_start(epoch_start);
        add_reward_internal(tranche, epoch_start, balance, ctx)
    }
    
    /// Internal function to add a reward to a specific tranche in the pool for the epoch.
    /// 
    /// # Arguments
    /// * `tranche` - Mutable reference to the pool tranche
    /// * `epoch_start` - Start time of the epoch in seconds
    /// * `balance` - Balance of reward tokens to add
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// The total balance after adding the reward
    fun add_reward_internal<RewardCoinType>(
        tranche: &mut PoolTranche,
        epoch_start: u64,
        balance: sui::balance::Balance<RewardCoinType>,
        ctx: &mut sui::tx_context::TxContext,
    ): u64 {
        let reward_type = type_name::get<RewardCoinType>();

        let balance_value = balance.value();

        if (!tranche.rewards_balance.contains(reward_type)) {
            tranche.rewards_balance.add(reward_type, sui::balance::zero<RewardCoinType>());
        };

        let after_amount = sui::balance::join<RewardCoinType>(
            sui::bag::borrow_mut<type_name::TypeName, sui::balance::Balance<RewardCoinType>>(&mut tranche.rewards_balance, reward_type),
            balance
        );

        if (!tranche.total_balance_epoch.contains(epoch_start)) {
            tranche.total_balance_epoch.add(epoch_start, sui::table::new(ctx));
        };

        if (!tranche.total_balance_epoch.borrow(epoch_start).contains(reward_type)) {
            tranche.total_balance_epoch.borrow_mut(epoch_start).add(reward_type, 0);
        };

        *tranche.total_balance_epoch.borrow_mut(epoch_start).borrow_mut(reward_type) = *tranche.total_balance_epoch.borrow(epoch_start).borrow(reward_type) + balance_value;

        let event = AddRewardEvent {
            tranche_id: sui::object::id<PoolTranche>(tranche),
            epoch_start,
            reward_type,
            balance_value,
            after_amount
        };
        sui::event::emit<AddRewardEvent>(event);

        after_amount
    }

    /// Returns a mutable reference to the vector of pool tranches for a given pool ID.
    /// 
    /// # Arguments
    /// * `manager` - Reference to the pool tranche manager
    /// * `pool_id` - ID of the pool to get tranches for
    /// 
    /// # Returns
    /// Mutable reference to vector of pool tranches
    public(package) fun get_tranches(manager: &mut PoolTrancheManager, pool_id: ID): &mut vector<PoolTranche> {
        manager.pool_tranches.borrow_mut(pool_id)
    }

    /// Checks if a tranche has been filled to its capacity.
    /// 
    /// # Arguments
    /// * `tranche` - Reference to the pool tranche to check
    /// 
    /// # Returns
    /// True if the tranche is filled, false otherwise
    public fun is_filled(tranche: &PoolTranche): bool {
        tranche.filled
    }

    /// Returns the vector of duration profitabilities for a tranche.
    /// These values represent the profitability rates for different lock durations.
    /// 
    /// # Arguments
    /// * `tranche` - Reference to the pool tranche
    /// 
    /// # Returns
    /// Vector of profitability rates for different durations
    public fun get_duration_profitabilities(tranche: &PoolTranche): vector<u64> {
        tranche.duration_profitabilities
    }

    /// Returns the remaining available volume in a tranche and whether it's denominated in token A.
    /// 
    /// # Arguments
    /// * `tranche` - Reference to the pool tranche
    /// 
    /// # Returns
    /// Tuple containing:
    /// * Remaining volume (Q64.64 fixed-point format)
    /// * Boolean indicating if volume is in token A (true) or token B (false)
    public fun get_free_volume(tranche: &PoolTranche): (u128, bool) {
            (tranche.total_volume - tranche.current_volume, tranche.volume_in_coin_a)
    }

    /// Returns the balance of a specific tranche for a given reward type.
    /// 
    /// # Arguments
    /// * `manager` - Mutable reference to the pool tranche manager
    /// * `pool_id` - ID of the pool containing the tranche
    /// * `tranche_id` - ID of the tranche to get balance from
    ///
    /// # Returns
    /// Balance of the tranche for the given reward type
    public fun get_balance_amount<RewardCoinType>(
        manager: &mut PoolTrancheManager,
        pool_id: ID,
        tranche_id: ID
    ): u64 {
        let tranche = get_tranche_by_id(manager, pool_id, tranche_id);
        let reward_type = type_name::get<RewardCoinType>();
        if (!tranche.rewards_balance.contains(reward_type)) {
            return 0
        };

        tranche.rewards_balance.borrow<type_name::TypeName, sui::balance::Balance<RewardCoinType>>(reward_type).value()
    }

    /// Fills a tranche with additional volume and marks it as filled if necessary.
    /// This function adds liquidity to a tranche and checks if it should be marked as filled
    /// based on either reaching total volume or remaining volume being too small.
    /// 
    /// # Arguments
    /// * `tranche` - Mutable reference to the pool tranche to fill
    /// * `add_volume` - Amount of volume to add (in Q64.64 fixed-point format)
    /// 
    /// # Aborts
    /// * If the tranche is already filled
    /// * If adding the volume would exceed the tranche's total volume
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
                consts::minimum_remaining_volume_denom() as u128
            ) >= (tranche.total_volume - tranche.current_volume)) { 

            // If remaining volume is less than minimum_remaining_volume of total volume,
            // mark the tranche as filled to prevent creating small positions
            tranche.filled = true;
        };

        let event = FillTrancheEvent {
            tranche_id: sui::object::id<PoolTranche>(tranche),
            current_volume: tranche.current_volume,
            filled: tranche.filled,
        };
        sui::event::emit<FillTrancheEvent>(event);
    }

    /// Retrieves the reward balance for a specific tranche and epoch.
    /// This function calculates and returns the reward balance based on the provided income
    /// and the tranche's total balance and income for the specified epoch.
    /// 
    /// # Arguments
    /// * `manager` - Mutable reference to the pool tranche manager
    /// * `pool_id` - ID of the pool containing the tranche
    /// * `tranche_id` - ID of the specific tranche to get rewards from
    /// * `lock_id` - lock liquidity ID
    /// * `income` - Amount of income to calculate rewards for
    /// * `epoch_start` - Start time of the epoch
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// Balance of reward tokens for the specified amount
    /// 
    /// # Aborts
    /// * If the tranche is not found
    /// * If the lock id already claimed this reward type in this epoch
    /// * If no rewards exist for the specified epoch
    /// * If there are insufficient rewards for the calculated amount
    public(package) fun get_reward_balance<RewardCoinType>(
        manager: &mut PoolTrancheManager,
        pool_id: ID,
        tranche_id: ID,
        lock_id: ID,
        income: u64,
        epoch_start: u64,
        ctx: &mut sui::tx_context::TxContext
    ): sui::balance::Balance<RewardCoinType> {
        
        let tranche = get_tranche_by_id(manager, pool_id, tranche_id);

        let epoch_start = time_manager::epoch_start(epoch_start);
        let reward_type = type_name::get<RewardCoinType>();

        assert!(!tranche.claimed_rewards.contains(lock_id) ||
            !tranche.claimed_rewards.borrow(lock_id).contains(epoch_start) ||
            !tranche.claimed_rewards.borrow(lock_id).borrow(epoch_start).contains(reward_type), ERewardAlreadyClaimed);

        assert!(tranche.total_balance_epoch.contains(epoch_start) &&
            tranche.total_balance_epoch.borrow(epoch_start).contains(reward_type) &&
            *tranche.total_balance_epoch.borrow(epoch_start).borrow(reward_type) > 0 &&
            tranche.rewards_balance.borrow<type_name::TypeName, sui::balance::Balance<RewardCoinType>>(reward_type).value() > 0, ERewardNotFound);

        // Calculate reward amount based on the ratio of income to total income
        let reward_amount = integer_mate::full_math_u64::mul_div_floor(
            *tranche.total_balance_epoch.borrow(epoch_start).borrow(reward_type),
            income,
            *tranche.total_income_epoch.borrow(epoch_start)
        );

        let current_balance = tranche.rewards_balance.borrow_mut<type_name::TypeName, sui::balance::Balance<RewardCoinType>>(reward_type);

        assert!(reward_amount <= current_balance.value(), ERewardNotEnough);

        if (!tranche.claimed_rewards.contains(lock_id)) {
            tranche.claimed_rewards.add(lock_id, sui::table::new(ctx));
        };

        if (!tranche.claimed_rewards.borrow(lock_id).contains(epoch_start)) {
            tranche.claimed_rewards.borrow_mut(lock_id).add(epoch_start, sui::table::new(ctx));
        };

        if (!tranche.claimed_rewards.borrow(lock_id).borrow(epoch_start).contains(reward_type)) {
            tranche.claimed_rewards.borrow_mut(lock_id).borrow_mut(epoch_start).add(reward_type, true);
        } else {
            *tranche.claimed_rewards.borrow_mut(lock_id).borrow_mut(epoch_start).borrow_mut(reward_type) = true;
        };

        let event = GetRewardEvent {
            tranche_id,
            epoch_start,
            reward_amount,
        };
        sui::event::emit<GetRewardEvent>(event);

        current_balance.split(reward_amount)
    }

    /// Returns a mutable reference to the tranche with the specified ID.
    /// 
    /// # Arguments
    /// * `manager` - Pool tranche manager
    /// * `pool_id` - ID of the pool containing the tranche
    /// * `tranche_id` - ID of the tranche to get
    ///
    /// # Returns
    /// Mutable reference to the tranche with the specified ID
    ///
    /// # Aborts
    /// * If the tranche is not found
    fun get_tranche_by_id(
        manager: &mut PoolTrancheManager, 
        pool_id: ID, 
        tranche_id: ID
    ): &mut PoolTranche {
        let pool_tranches = manager.pool_tranches.borrow_mut(pool_id);
        let mut i = 0;
        while (i < pool_tranches.length()) {
            let tranche = pool_tranches.borrow_mut(i);
            if (tranche_id == sui::object::id<PoolTranche>(tranche)) {
                return tranche
            };

            i = i + 1;
        };

        abort ETrancheNotFound
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let tranche_manager = PoolTrancheManager {
            id: sui::object::new(ctx),
            version: VERSION,
            pool_tranches: sui::table::new(ctx),
            whitelisted_tokens: sui::vec_set::empty<TypeName>(),
            ignore_whitelist: false
        };
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object<PoolTrancheManager>(tranche_manager);
    }
}
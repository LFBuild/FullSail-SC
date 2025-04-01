/// Position module for the CLMM (Concentrated Liquidity Market Maker) pool system.
/// This module provides functionality for:
/// * Managing liquidity positions in the pool
/// * Handling position creation and modification
/// * Managing position fees and rewards
/// * Controlling position staking and unstaking
/// 
/// The module implements:
/// * Position creation and management
/// * Liquidity provision and removal
/// * Fee collection and distribution
/// * Position staking mechanics
/// 
/// # Key Concepts
/// * Position - Represents a liquidity position in the pool
/// * Liquidity - The amount of tokens provided to the pool
/// * Fees - Trading fees earned by the position
/// * Staking - Mechanism for earning additional rewards
/// 
/// # Events
/// * Position creation events
/// * Position modification events
/// * Fee collection events
/// * Staking status change events
module clmm_pool::position {
    /// Event emitted when a position's staking status is changed.
    /// 
    /// # Fields
    /// * `position_id` - ID of the position
    /// * `staked` - New staking status (true if staked, false if unstaked)
    public struct StakePositionEvent has copy, drop {
        position_id: sui::object::ID,
        staked: bool,
    }

    /// Manages all positions in the pool system.
    /// This structure maintains a collection of positions and their associated information.
    /// 
    /// # Fields
    /// * `tick_spacing` - Minimum distance between initialized ticks
    /// * `position_index` - Counter for generating unique position indices
    /// * `positions` - Linked table containing all position information
    public struct PositionManager has store {
        tick_spacing: u32,
        position_index: u64,
        positions: move_stl::linked_table::LinkedTable<sui::object::ID, PositionInfo>,
    }

    /// Witness type for position module initialization.
    /// Used to ensure proper module initialization and access control.
    public struct POSITION has drop {}

    /// Represents a liquidity position in the pool.
    /// This structure contains the core position data and metadata.
    /// 
    /// # Fields
    /// * `id` - Unique identifier for the position
    /// * `pool` - ID of the pool this position belongs to
    /// * `index` - Unique index of the position
    /// * `coin_type_a` - Type of the first token in the pair
    /// * `coin_type_b` - Type of the second token in the pair
    /// * `name` - Name of the position
    /// * `description` - Description of the position
    /// * `url` - URL for position metadata
    /// * `tick_lower_index` - Lower tick boundary of the position
    /// * `tick_upper_index` - Upper tick boundary of the position
    /// * `liquidity` - Amount of liquidity in the position
    public struct Position has store, key {
        id: sui::object::UID,
        pool: sui::object::ID,
        index: u64,
        coin_type_a: std::type_name::TypeName,
        coin_type_b: std::type_name::TypeName,
        name: std::string::String,
        description: std::string::String,
        url: std::string::String,
        tick_lower_index: integer_mate::i32::I32,
        tick_upper_index: integer_mate::i32::I32,
        liquidity: u128,
    }

    /// Contains detailed information about a position's state and accumulated fees.
    /// This structure tracks all position-specific metrics and rewards.
    /// 
    /// # Fields
    /// * `position_id` - ID of the associated position
    /// * `liquidity` - Current liquidity in the position
    /// * `tick_lower_index` - Lower tick boundary
    /// * `tick_upper_index` - Upper tick boundary
    /// * `fee_growth_inside_a` - Accumulated fees for token A within the position's range
    /// * `fee_growth_inside_b` - Accumulated fees for token B within the position's range
    /// * `fee_owned_a` - Unclaimed fees for token A
    /// * `fee_owned_b` - Unclaimed fees for token B
    /// * `points_owned` - Unclaimed points rewards
    /// * `points_growth_inside` - Accumulated points within the position's range
    /// * `rewards` - Vector of additional rewards for the position
    /// * `fullsale_distribution_staked` - Whether the position is staked for FULLSALE rewards
    /// * `fullsale_distribution_growth_inside` - Accumulated FULLSALE rewards within the position's range
    /// * `fullsale_distribution_owned` - Unclaimed FULLSALE rewards
    public struct PositionInfo has copy, drop, store {
        position_id: sui::object::ID,
        liquidity: u128,
        tick_lower_index: integer_mate::i32::I32,
        tick_upper_index: integer_mate::i32::I32,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        fee_owned_a: u64,
        fee_owned_b: u64,
        points_owned: u128,
        points_growth_inside: u128,
        rewards: vector<PositionReward>,
        fullsale_distribution_staked: bool,
        fullsale_distribution_growth_inside: u128,
        fullsale_distribution_owned: u64,
    }

    /// Represents a reward for a position.
    /// This structure tracks both accumulated and unclaimed rewards.
    /// 
    /// # Fields
    /// * `growth_inside` - Accumulated rewards within the position's range
    /// * `amount_owned` - Unclaimed reward amount
    public struct PositionReward has copy, drop, store {
        growth_inside: u128,
        amount_owned: u64,
    }
    
    /// Checks if a position is empty (has no liquidity, fees, or rewards).
    /// A position is considered empty if:
    /// * It has no liquidity
    /// * It has no unclaimed fees for either token
    /// * It has no unclaimed rewards
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information structure
    /// 
    /// # Returns
    /// * `true` if the position has no liquidity, fees, or rewards
    /// * `false` otherwise
    public fun is_empty(position_info: &PositionInfo): bool {
        let mut all_rewards_empty = true;
        let mut reward_index = 0;
        while (reward_index < std::vector::length<PositionReward>(&position_info.rewards)) {
            let reward_is_empty = std::vector::borrow<PositionReward>(&position_info.rewards, reward_index).amount_owned == 0;
            all_rewards_empty = reward_is_empty;
            if (!reward_is_empty) {
                break
            };
            reward_index = reward_index + 1;
        };
        let position_empty = if (position_info.liquidity == 0) {
            if (position_info.fee_owned_a == 0) {
                position_info.fee_owned_b == 0
            } else {
                false
            }
        } else {
            false
        };
        position_empty && all_rewards_empty
    }
    
    /// Creates a new position manager with specified tick spacing.
    /// This function initializes the position management system.
    /// 
    /// # Arguments
    /// * `tick_spacing` - Minimum distance between initialized ticks
    /// * `ctx` - Mutable reference to the transaction context
    /// 
    /// # Returns
    /// A new PositionManager instance with:
    /// * The specified tick spacing
    /// * Initial position index set to 0
    /// * Empty linked table for positions
    public(package) fun new(tick_spacing: u32, ctx: &mut sui::tx_context::TxContext): PositionManager {
        PositionManager {
            tick_spacing,
            position_index: 0,
            positions: move_stl::linked_table::new<sui::object::ID, PositionInfo>(ctx),
        }
    }

    /// Returns a mutable reference to the position information for a given position ID.
    /// This function performs validation to ensure the position exists and the ID matches.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to borrow
    /// 
    /// # Returns
    /// Mutable reference to the position information
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match the stored ID (error code: 6)
    fun borrow_mut_position_info(position_manager: &mut PositionManager, position_id: sui::object::ID): &mut PositionInfo {
        assert!(move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id), 6);
        let position_info = move_stl::linked_table::borrow_mut<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id);
        assert!(position_info.position_id == position_id, 6);
        position_info
    }
    
    /// Returns an immutable reference to the position information for a given position ID.
    /// This function performs validation to ensure the position exists and the ID matches.
    /// 
    /// # Arguments
    /// * `position_manager` - Reference to the position manager
    /// * `position_id` - ID of the position to borrow
    /// 
    /// # Returns
    /// Immutable reference to the position information
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match the stored ID (error code: 6)
    public fun borrow_position_info(position_manager: &PositionManager, position_id: sui::object::ID): &PositionInfo {
        assert!(move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id), 6);
        let position_info = move_stl::linked_table::borrow<sui::object::ID, PositionInfo>(&position_manager.positions, position_id);
        assert!(position_info.position_id == position_id, 6);
        position_info
    }
    
    /// Validates the tick range for a position.
    /// Checks that:
    /// * Lower tick is less than upper tick
    /// * Lower tick is greater than or equal to minimum allowed tick
    /// * Upper tick is less than or equal to maximum allowed tick
    /// * Both ticks are aligned with the tick spacing
    /// 
    /// # Arguments
    /// * `tick_lower` - Lower tick boundary
    /// * `tick_upper` - Upper tick boundary
    /// * `tick_spacing` - Minimum distance between initialized ticks
    /// 
    /// # Abort Conditions
    /// * If any of the tick range validation conditions are not met (error code: 5)
    public fun check_position_tick_range(tick_lower: integer_mate::i32::I32, tick_upper: integer_mate::i32::I32, tick_spacing: u32) {
        let is_valid = if (integer_mate::i32::lt(tick_lower, tick_upper)) {
            if (integer_mate::i32::gte(tick_lower, clmm_pool::tick_math::min_tick())) {
                if (integer_mate::i32::lte(tick_upper, clmm_pool::tick_math::max_tick())) {
                    if (integer_mate::i32::mod(tick_lower, integer_mate::i32::from(tick_spacing)) == integer_mate::i32::zero()) {
                        integer_mate::i32::mod(tick_upper, integer_mate::i32::from(tick_spacing)) == integer_mate::i32::zero()
                    } else {
                        false
                    }
                } else {
                    false
                }
            } else {
                false
            }
        } else {
            false
        };
        assert!(is_valid, 5);
    }
    
    /// Closes a position by removing it from the position manager and destroying the position object.
    /// This function can only be called if the position is empty (has no liquidity, fees, or rewards).
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position` - The position to close
    /// 
    /// # Abort Conditions
    /// * If the position is not empty (error code: 7)
    public(package) fun close_position(position_manager: &mut PositionManager, position: Position) {
        let position_id = sui::object::id<Position>(&position);
        if (!is_empty(borrow_mut_position_info(position_manager, position_id))) {
            abort 7
        };
        move_stl::linked_table::remove<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id);
        destroy(position);
    }

    /// Decreases the liquidity of a position by a specified amount.
    /// This function updates all accumulated fees, points, rewards, and FULLSALE distribution before decreasing liquidity.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position` - Mutable reference to the position to modify
    /// * `liquidity` - Amount of liquidity to decrease
    /// * `fee_growth_a` - Updated fee growth for token A
    /// * `fee_growth_b` - Updated fee growth for token B
    /// * `points_growth` - Updated points growth
    /// * `rewards_growth` - Vector of updated rewards growth
    /// * `fullsale_growth` - Updated FULLSALE distribution growth
    /// 
    /// # Returns
    /// The new liquidity amount after decrease
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If the current liquidity is less than the amount to decrease (error code: 9)
    public(package) fun decrease_liquidity(
        position_manager: &mut PositionManager,
        position: &mut Position,
        liquidity: u128,
        fee_growth_a: u128,
        fee_growth_b: u128,
        points_growth: u128,
        rewards_growth: vector<u128>,
        fullsale_growth: u128
    ): u128 {
        let position_info = borrow_mut_position_info(position_manager, sui::object::id<Position>(position));
        if (liquidity == 0) {
            return position_info.liquidity
        };
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        update_points_internal(position_info, points_growth);
        update_rewards_internal(position_info, rewards_growth);
        update_fullsale_distribution_internal(position_info, fullsale_growth);
        assert!(position_info.liquidity >= liquidity, 9);
        position_info.liquidity = position_info.liquidity - liquidity;
        position.liquidity = position_info.liquidity;
        position_info.liquidity
    }
    
    /// Returns the description of a position.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The position's description as a string
    public fun description(position: &Position): std::string::String {
        position.description
    }

    /// Destroys a position by deleting its object ID.
    /// This function is used internally to clean up position objects.
    /// 
    /// # Arguments
    /// * `position` - The position to destroy
    fun destroy(position: Position) {
        let Position {
            id: position_id,
            pool: _,
            index: _,
            coin_type_a: _,
            coin_type_b: _,
            name: _,
            description: _,
            url: _,
            tick_lower_index: _,
            tick_upper_index: _,
            liquidity: _,
        } = position;
        sui::object::delete(position_id);
    }

    /// Fetches a list of position information up to the specified limit.
    /// If position_ids is empty, starts from the first position in the linked table.
    /// Otherwise, starts from the first position ID in the provided vector.
    /// 
    /// # Arguments
    /// * `position_manager` - Reference to the position manager
    /// * `position_ids` - Vector of position IDs to start fetching from. If empty, starts from the beginning
    /// * `limit` - Maximum number of positions to return
    /// 
    /// # Returns
    /// Vector of PositionInfo structures containing information about the fetched positions
    /// 
    /// # Details
    /// * Iterates through the linked table of positions
    /// * Returns up to 'limit' number of positions
    /// * If position_ids is provided, starts from the first ID in the vector
    /// * If position_ids is empty, starts from the first position in the linked table
    public fun fetch_positions(
        position_manager: &PositionManager,
        position_ids: vector<sui::object::ID>,
        limit: u64
    ): vector<PositionInfo> {
        let mut positions = std::vector::empty<PositionInfo>();
        let next_id = if (std::vector::is_empty<sui::object::ID>(&position_ids)) {
            move_stl::linked_table::head<sui::object::ID, PositionInfo>(&position_manager.positions)
        } else {
            std::option::some<sui::object::ID>(*std::vector::borrow<sui::object::ID>(&position_ids, 0))
        };
        let mut current_id = next_id;
        let mut count = 0;
        while (std::option::is_some<sui::object::ID>(&current_id)) {
            let node = move_stl::linked_table::borrow_node<sui::object::ID, PositionInfo>(
                &position_manager.positions,
                *std::option::borrow<sui::object::ID>(&current_id)
            );
            current_id = move_stl::linked_table::next<sui::object::ID, PositionInfo>(node);
            std::vector::push_back<PositionInfo>(
                &mut positions,
                *move_stl::linked_table::borrow_value<sui::object::ID, PositionInfo>(node)
            );
            let new_count = count + 1;
            count = new_count;
            if (new_count == limit) {
                break
            };
        };
        positions
    }
    
    /// Increases the liquidity of a position by a specified amount.
    /// This function updates all accumulated fees, points, rewards, and FULLSALE distribution before increasing liquidity.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position` - Mutable reference to the position to modify
    /// * `liquidity_delta` - Amount of liquidity to add
    /// * `fee_growth_a` - Updated fee growth for token A
    /// * `fee_growth_b` - Updated fee growth for token B
    /// * `points_growth` - Updated points growth
    /// * `rewards_growth` - Vector of updated rewards growth
    /// * `fullsale_growth` - Updated FULLSALE distribution growth
    /// 
    /// # Returns
    /// The new liquidity amount after increase
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If adding liquidity_delta would cause overflow (error code: 8)
    public(package) fun increase_liquidity(
        position_manager: &mut PositionManager,
        position: &mut Position,
        liquidity_delta: u128,
        fee_growth_a: u128,
        fee_growth_b: u128,
        points_growth: u128,
        rewards_growth: vector<u128>,
        fullsale_growth: u128
    ): u128 {
        let position_info = borrow_mut_position_info(position_manager, sui::object::id<Position>(position));
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        update_points_internal(position_info, points_growth);
        update_rewards_internal(position_info, rewards_growth);
        update_fullsale_distribution_internal(position_info, fullsale_growth);
        assert!(integer_mate::math_u128::add_check(position_info.liquidity, liquidity_delta), 8);
        position_info.liquidity = position_info.liquidity + liquidity_delta;
        position.liquidity = position_info.liquidity;
        position_info.liquidity
    }
    
    /// Returns the unique index of a position.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The position's unique index
    public fun index(position: &Position): u64 {
        position.index
    }

    /// Returns the accumulated fee growth inside the position's range for both tokens.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// Tuple containing fee growth for token A and token B
    public fun info_fee_growth_inside(position_info: &PositionInfo): (u128, u128) {
        (position_info.fee_growth_inside_a, position_info.fee_growth_inside_b)
    }

    /// Returns the unclaimed fees for both tokens.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// Tuple containing unclaimed fees for token A and token B
    public fun info_fee_owned(position_info: &PositionInfo): (u64, u64) {
        (position_info.fee_owned_a, position_info.fee_owned_b)
    }

    /// Returns the current liquidity in the position.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// The current liquidity amount
    public fun info_liquidity(position_info: &PositionInfo): u128 {
        position_info.liquidity
    }

    /// Returns the unclaimed FULLSALE distribution rewards.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// The amount of unclaimed FULLSALE rewards
    public fun info_fullsale_distribution_owned(position_info: &PositionInfo): u64 {
        position_info.fullsale_distribution_owned
    }

    /// Returns the accumulated points growth inside the position's range.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// The accumulated points growth
    public fun info_points_growth_inside(position_info: &PositionInfo): u128 {
        position_info.points_growth_inside
    }

    /// Returns the unclaimed points rewards.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// The amount of unclaimed points
    public fun info_points_owned(position_info: &PositionInfo): u128 {
        position_info.points_owned
    }

    /// Returns the unique identifier of the position.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// The position's unique ID
    public fun info_position_id(position_info: &PositionInfo): sui::object::ID {
        position_info.position_id
    }

    /// Returns a reference to the vector of rewards for the position.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// Reference to the vector of position rewards
    public fun info_rewards(position_info: &PositionInfo): &vector<PositionReward> {
        &position_info.rewards
    }

    /// Returns the tick range of the position.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// Tuple containing the lower and upper tick boundaries
    public fun info_tick_range(position_info: &PositionInfo): (integer_mate::i32::I32, integer_mate::i32::I32) {
        (position_info.tick_lower_index, position_info.tick_upper_index)
    }

    /// Initializes the position module by setting up display fields and transferring ownership.
    /// This function is called during module initialization to:
    /// * Set up display fields for position objects
    /// * Configure metadata display for the Fullsale Finance interface
    /// * Transfer display and publisher objects to the module owner
    /// 
    /// # Arguments
    /// * `position_witness` - Witness type for position module initialization
    /// * `ctx` - Mutable reference to the transaction context
    /// 
    /// # Details
    /// Sets up the following display fields:
    /// * name - Position name
    /// * coin_a - First token type
    /// * coin_b - Second token type
    /// * link - Position link in Fullsale Finance app
    /// * image_url - Position image URL
    /// * description - Position description
    /// * website - Project website
    /// * creator - Position creator
    /// 
    /// # Transfers
    /// * Transfers the Display<Position> object to the transaction sender
    /// * Transfers the Publisher object to the transaction sender
    fun init(position_witness: POSITION, ctx: &mut sui::tx_context::TxContext) {
        let mut display_keys = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"name"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"coin_a"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"coin_b")); 
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"link"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"image_url"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"description"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"website"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"creator"));

        let mut display_values = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{name}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{coin_type_a}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{coin_type_b}"));
        std::vector::push_back<std::string::String>(
            &mut display_values,
            std::string::utf8(b"https://app.fullsalefinance.io/position?chain=sui&id={id}")
        );
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{url}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{description}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"https://fullsalefinance.io"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"FULLSALE"));

        let publisher = sui::package::claim<POSITION>(position_witness, ctx);
        let mut display = sui::display::new_with_fields<Position>(&publisher, display_keys, display_values, ctx);
        sui::display::update_version<Position>(&mut display);
        sui::transfer::public_transfer<sui::display::Display<Position>>(display, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<sui::package::Publisher>(publisher, sui::tx_context::sender(ctx));
    }
    
    /// Returns the number of initialized rewards for a position.
    /// 
    /// # Arguments
    /// * `position_manager` - Reference to the position manager
    /// * `position_id` - ID of the position to check
    /// 
    /// # Returns
    /// The number of rewards initialized for the position
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    public fun inited_rewards_count(position_manager: &PositionManager, position_id: sui::object::ID): u64 {
        std::vector::length<PositionReward>(
            &move_stl::linked_table::borrow<sui::object::ID, PositionInfo>(&position_manager.positions, position_id).rewards
        )
    }

    /// Checks if a position exists in the position manager.
    /// 
    /// # Arguments
    /// * `position_manager` - Reference to the position manager
    /// * `position_id` - ID of the position to check
    /// 
    /// # Returns
    /// * `true` if the position exists
    /// * `false` otherwise
    public fun is_position_exist(position_manager: &PositionManager, position_id: sui::object::ID): bool {
        move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id)
    }

    /// Checks if a position is currently staked for FULLSALE rewards.
    /// 
    /// # Arguments
    /// * `position_info` - Reference to the position information
    /// 
    /// # Returns
    /// * `true` if the position is staked
    /// * `false` otherwise
    public fun is_staked(position_info: &PositionInfo): bool {
        position_info.fullsale_distribution_staked
    }

    /// Returns the current liquidity of a position.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The current liquidity amount
    public fun liquidity(position: &Position): u128 {
        position.liquidity
    }

    /// Marks a position as staked or unstaked for FULLSALE rewards.
    /// This function emits a StakePositionEvent to track the staking status change.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to modify
    /// * `staked` - New staking status (true to stake, false to unstake)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If the new staking status is the same as the current status (error code: 11)
    public(package) fun mark_position_staked(position_manager: &mut PositionManager, position_id: sui::object::ID, staked: bool) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        assert!(position_info.fullsale_distribution_staked != staked, 11);
        position_info.fullsale_distribution_staked = staked;
        let stake_event = StakePositionEvent {
            position_id: position_info.position_id,
            staked: staked,
        };
        sui::event::emit<StakePositionEvent>(stake_event);
    }

    /// Returns the name of a position.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The position's name as a string
    public fun name(position: &Position): std::string::String {
        position.name
    }
    
    /// Generates a new position name based on pool and position indices.
    /// The format is "Fullsale position:{pool_index}-{position_index}".
    /// 
    /// # Arguments
    /// * `pool_index` - Index of the pool
    /// * `position_index` - Index of the position
    /// 
    /// # Returns
    /// A formatted string containing the position name
    fun new_position_name(pool_index: u64, position_index: u64): std::string::String {
        let mut position_name = std::string::utf8(b"Fullsale position:");
        std::string::append(&mut position_name, clmm_pool::utils::str(pool_index));
        std::string::append_utf8(&mut position_name, b"-");
        std::string::append(&mut position_name, clmm_pool::utils::str(position_index));
        position_name
    }
    
    /// Creates a new liquidity position in the pool.
    /// This function initializes both the Position and PositionInfo structures with default values.
    /// 
    /// # Type Parameters
    /// * `T0` - Type of the first token in the pair
    /// * `T1` - Type of the second token in the pair
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `pool_id` - ID of the pool this position belongs to
    /// * `pool_index` - Index of the pool
    /// * `pool_url` - URL for pool metadata
    /// * `tick_lower` - Lower tick boundary for the position
    /// * `tick_upper` - Upper tick boundary for the position
    /// * `ctx` - Mutable reference to the transaction context
    /// 
    /// # Returns
    /// A new Position object with:
    /// * Unique ID and index
    /// * Pool association
    /// * Token types
    /// * Name and description
    /// * Tick range
    /// * Initial liquidity of 0
    /// 
    /// # Abort Conditions
    /// * If the tick range is invalid (error code: 5)
    /// * If the position ID does not match (error code: 6)
    public(package) fun open_position<T0, T1>(
        position_manager: &mut PositionManager,
        pool_id: sui::object::ID,
        pool_index: u64,
        pool_url: std::string::String,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        ctx: &mut sui::tx_context::TxContext
    ): Position {
        check_position_tick_range(tick_lower, tick_upper, position_manager.tick_spacing);
        let next_position_index = position_manager.position_index + 1;
        let position = Position {
            id: sui::object::new(ctx),
            pool: pool_id,
            index: next_position_index,
            coin_type_a: std::type_name::get<T0>(),
            coin_type_b: std::type_name::get<T1>(),
            name: new_position_name(pool_index, next_position_index),
            description: std::string::utf8(b"Fullsale Liquidity Position"),
            url: pool_url,
            tick_lower_index: tick_lower,
            tick_upper_index: tick_upper,
            liquidity: 0,
        };
        let position_id = sui::object::id<Position>(&position);
        let position_info = PositionInfo {
            position_id,
            liquidity: 0,
            tick_lower_index: tick_lower,
            tick_upper_index: tick_upper,
            fee_growth_inside_a: 0,
            fee_growth_inside_b: 0,
            fee_owned_a: 0,
            fee_owned_b: 0,
            points_owned: 0,
            points_growth_inside: 0,
            rewards: std::vector::empty<PositionReward>(),
            fullsale_distribution_staked: false,
            fullsale_distribution_growth_inside: 0,
            fullsale_distribution_owned: 0,
        };
        move_stl::linked_table::push_back<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id, position_info);
        position_manager.position_index = next_position_index;
        position
    }

    /// Returns the ID of the pool that this position belongs to.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The pool's unique identifier
    public fun pool_id(position: &Position): sui::object::ID {
        position.pool
    }

    /// Resets the unclaimed fees for both tokens in a position to zero.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to reset
    /// 
    /// # Returns
    /// Tuple containing the reset fee amounts (both will be 0)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    public(package) fun reset_fee(position_manager: &mut PositionManager, position_id: sui::object::ID): (u64, u64) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        position_info.fee_owned_a = 0;
        position_info.fee_owned_b = 0;
        (position_info.fee_owned_a, position_info.fee_owned_b)
    }
    
    /// Resets the unclaimed amount for a specific reward in a position to zero.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position
    /// * `reward_index` - Index of the reward to reset
    /// 
    /// # Returns
    /// The reset reward amount (will be 0)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If the reward index is out of bounds
    public(package) fun reset_rewarder(position_manager: &mut PositionManager, position_id: sui::object::ID, reward_index: u64): u64 {
        let reward = std::vector::borrow_mut<PositionReward>(&mut borrow_mut_position_info(position_manager, position_id).rewards, reward_index);
        reward.amount_owned = 0;
        reward.amount_owned
    }

    /// Returns the unclaimed amount for a reward.
    /// 
    /// # Arguments
    /// * `reward` - Reference to the reward
    /// 
    /// # Returns
    /// The amount of unclaimed rewards
    public fun reward_amount_owned(reward: &PositionReward): u64 {
        reward.amount_owned
    }

    /// Returns the accumulated growth inside the position's range for a reward.
    /// 
    /// # Arguments
    /// * `reward` - Reference to the reward
    /// 
    /// # Returns
    /// The accumulated growth amount
    public fun reward_growth_inside(reward: &PositionReward): u128 {
        reward.growth_inside
    }

    /// Returns a vector of unclaimed reward amounts for all rewards in a position.
    /// This function iterates through all rewards and collects their unclaimed amounts.
    /// 
    /// # Arguments
    /// * `position_manager` - Reference to the position manager
    /// * `position_id` - ID of the position to check
    /// 
    /// # Returns
    /// Vector of unclaimed reward amounts, one for each reward
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    public(package) fun rewards_amount_owned(position_manager: &PositionManager, position_id: sui::object::ID): vector<u64> {
        let rewards = info_rewards(borrow_position_info(position_manager, position_id));
        let mut index = 0;
        let mut amounts = std::vector::empty<u64>();
        while (index < std::vector::length<PositionReward>(rewards)) {
            std::vector::push_back<u64>(&mut amounts, reward_amount_owned(std::vector::borrow<PositionReward>(rewards, index)));
            index = index + 1;
        };
        amounts
    }

    /// Updates the description of a position.
    /// This function allows modifying the position's description after creation.
    /// 
    /// # Arguments
    /// * `position` - Mutable reference to the position to update
    /// * `description` - New description string for the position
    public fun set_description(position: &mut Position, description: std::string::String) {
        position.description = description;
    }

    /// Sets up display fields for a position with custom metadata.
    /// This function configures how the position will be displayed in the Fullsale Finance interface.
    /// 
    /// # Arguments
    /// * `global_config` - Reference to the global configuration
    /// * `publisher` - Reference to the package publisher
    /// * `description` - Custom description for the position
    /// * `link` - Custom link to the position in Fullsale Finance app
    /// * `project_url` - URL of the project website
    /// * `creator` - Name of the position creator
    /// * `ctx` - Mutable reference to the transaction context
    /// 
    /// # Details
    /// Sets up the following display fields:
    /// * name - Position name (template: "{name}")
    /// * coin_a - First token type (template: "{coin_type_a}")
    /// * coin_b - Second token type (template: "{coin_type_b}")
    /// * link - Custom position link
    /// * image_url - Position image URL (template: "{url}")
    /// * description - Custom description
    /// * project_url - Custom project website
    /// * creator - Custom creator name
    /// 
    /// # Abort Conditions
    /// * If the package version check fails
    public fun set_display(
        global_config: &clmm_pool::config::GlobalConfig,
        publisher: &sui::package::Publisher,
        description: std::string::String,
        link: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        let mut keys = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"name"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"coin_a"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"coin_b")); 
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"link"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"image_url"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"description"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"project_url"));
        std::vector::push_back<std::string::String>(&mut keys, std::string::utf8(b"creator"));
        let mut values = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut values, std::string::utf8(b"{name}"));
        std::vector::push_back<std::string::String>(&mut values, std::string::utf8(b"{coin_type_a}"));
        std::vector::push_back<std::string::String>(&mut values, std::string::utf8(b"{coin_type_b}"));
        std::vector::push_back<std::string::String>(&mut values, link);
        std::vector::push_back<std::string::String>(&mut values, std::string::utf8(b"{url}"));
        std::vector::push_back<std::string::String>(&mut values, description);
        std::vector::push_back<std::string::String>(&mut values, project_url);
        std::vector::push_back<std::string::String>(&mut values, creator);
        let mut display = sui::display::new_with_fields<Position>(publisher, keys, values, ctx);
        sui::display::update_version<Position>(&mut display);
        sui::transfer::public_transfer<sui::display::Display<Position>>(display, sui::tx_context::sender(ctx));
    }

    /// Returns the tick range of a position.
    /// This function provides the lower and upper tick boundaries that define the position's price range.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// Tuple containing:
    /// * Lower tick boundary (i32)
    /// * Upper tick boundary (i32)
    public fun tick_range(position: &Position): (integer_mate::i32::I32, integer_mate::i32::I32) {
        (position.tick_lower_index, position.tick_upper_index)
    }

    /// Updates the fee growth for both tokens and resets unclaimed fees to zero.
    /// This function first updates the accumulated fees based on:
    /// * Current position liquidity
    /// * Difference between new and previous fee growth for each token
    /// Then resets the unclaimed fees to zero.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `fee_growth_a` - Updated fee growth value for token A
    /// * `fee_growth_b` - Updated fee growth value for token B
    /// 
    /// # Returns
    /// Tuple containing the reset fee amounts (both will be 0)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If adding fee delta would cause overflow (error code: 1)
    public(package) fun update_and_reset_fee(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        fee_growth_a: u128,
        fee_growth_b: u128
    ): (u64, u64) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        position_info.fee_owned_a = 0;
        position_info.fee_owned_b = 0;
        (position_info.fee_owned_a, position_info.fee_owned_b)
    }

    /// Updates the FULLSALE distribution growth and resets the unclaimed amount to zero.
    /// This function first updates the accumulated FULLSALE rewards based on the new growth value,
    /// then resets the unclaimed amount to zero.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `fullsale_growth` - Updated FULLSALE distribution growth value
    /// 
    /// # Returns
    /// The reset FULLSALE reward amount (will be 0)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If adding FULLSALE delta would cause overflow (error code: 9223374347547181055)
    public(package) fun update_and_reset_fullsale_distribution(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        fullsale_growth: u128
    ): u64 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_fullsale_distribution_internal(position_info, fullsale_growth);
        position_info.fullsale_distribution_owned = 0;
        position_info.fullsale_distribution_owned
    }

    /// Updates the rewards growth and resets the unclaimed amount for a specific reward to zero.
    /// This function first updates all accumulated rewards based on the new growth values,
    /// then resets the unclaimed amount for the specified reward to zero.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `rewards_growth` - Vector of updated rewards growth values
    /// * `reward_index` - Index of the reward to reset
    /// 
    /// # Returns
    /// The reset reward amount (will be 0)
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If the reward index is out of bounds (error code: 10)
    /// * If adding reward delta would cause overflow (error code: 1)
    public(package) fun update_and_reset_rewards(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        rewards_growth: vector<u128>,
        reward_index: u64
    ): u64 {
        assert!(std::vector::length<u128>(&rewards_growth) > reward_index, 10);
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_rewards_internal(position_info, rewards_growth);
        let reward = std::vector::borrow_mut<PositionReward>(&mut position_info.rewards, reward_index);
        reward.amount_owned = 0;
        reward.amount_owned
    }

    /// Updates the fee growth for both tokens in a position.
    /// This function updates the accumulated fees based on:
    /// * Current position liquidity
    /// * Difference between new and previous fee growth for each token
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `fee_growth_a` - Updated fee growth value for token A
    /// * `fee_growth_b` - Updated fee growth value for token B
    /// 
    /// # Returns
    /// Tuple containing unclaimed fees for tokens A and B
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If adding fee delta would cause overflow (error code: 1)
    public(package) fun update_fee(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        fee_growth_a: u128,
        fee_growth_b: u128
    ): (u64, u64) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        info_fee_owned(position_info)
    }

    /// Updates the fee growth and owned amounts for both tokens in a position.
    /// This internal function calculates the new fees based on:
    /// * The position's current liquidity
    /// * The difference between new and previous fee growth for each token
    /// 
    /// # Arguments
    /// * `position_info` - Mutable reference to the position information
    /// * `fee_growth_a` - Updated fee growth for token A
    /// * `fee_growth_b` - Updated fee growth for token B
    /// 
    /// # Details
    /// The function:
    /// 1. Calculates fee deltas based on liquidity and growth differences
    /// 2. Updates the accumulated fees for both tokens
    /// 3. Updates the internal growth tracking
    /// 
    /// # Abort Conditions
    /// * If adding either fee delta would cause overflow (error code: 1)
    fun update_fee_internal(position_info: &mut PositionInfo, fee_growth_a: u128, fee_growth_b: u128) {
        let fee_owned_a_delta = integer_mate::full_math_u128::mul_shr(
            position_info.liquidity,
            integer_mate::math_u128::wrapping_sub(fee_growth_a, position_info.fee_growth_inside_a),
            64
        ) as u64;
        let fee_owned_b_delta = integer_mate::full_math_u128::mul_shr(
            position_info.liquidity,
            integer_mate::math_u128::wrapping_sub(fee_growth_b, position_info.fee_growth_inside_b),
            64
        ) as u64;
        assert!(integer_mate::math_u64::add_check(position_info.fee_owned_a, fee_owned_a_delta), 1);
        assert!(integer_mate::math_u64::add_check(position_info.fee_owned_b, fee_owned_b_delta), 1);
        position_info.fee_owned_a = position_info.fee_owned_a + fee_owned_a_delta;
        position_info.fee_owned_b = position_info.fee_owned_b + fee_owned_b_delta;
        position_info.fee_growth_inside_a = fee_growth_a;
        position_info.fee_growth_inside_b = fee_growth_b;
    }

    /// Updates the FULLSALE distribution growth for a position.
    /// This function calculates and updates the accumulated FULLSALE rewards.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `fullsale_growth` - Updated FULLSALE distribution growth value
    /// 
    /// # Returns
    /// The current unclaimed FULLSALE rewards amount
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    public(package) fun update_fullsale_distribution(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        fullsale_growth: u128
    ): u64 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_fullsale_distribution_internal(position_info, fullsale_growth);
        position_info.fullsale_distribution_owned
    }

    /// Updates the FULLSALE distribution growth and owned amounts for a position.
    /// This internal function calculates the new FULLSALE rewards based on:
    /// * The position's current liquidity
    /// * The difference between new and previous FULLSALE growth
    /// 
    /// # Arguments
    /// * `position_info` - Mutable reference to the position information
    /// * `fullsale_growth` - Updated FULLSALE distribution growth value
    /// 
    /// # Details
    /// The function:
    /// 1. Calculates the FULLSALE delta based on liquidity and growth difference
    /// 2. Updates the accumulated FULLSALE rewards
    /// 3. Updates the internal growth tracking
    /// 
    /// # Abort Conditions
    /// * If adding the FULLSALE delta would cause overflow (error code: 9223374347547181055)
    fun update_fullsale_distribution_internal(position_info: &mut PositionInfo, fullsale_growth: u128) {
        let fullsale_delta = integer_mate::full_math_u128::mul_shr(
            position_info.liquidity,
            integer_mate::math_u128::wrapping_sub(
                fullsale_growth,
                position_info.fullsale_distribution_growth_inside
            ),
            64
        ) as u64;
        assert!(
            integer_mate::math_u64::add_check(
                position_info.fullsale_distribution_owned,
                fullsale_delta
            ),
            9223374347547181055
        );
        position_info.fullsale_distribution_owned = position_info.fullsale_distribution_owned + fullsale_delta;
        position_info.fullsale_distribution_growth_inside = fullsale_growth;
    }

    /// Updates the points growth for a position.
    /// This function calculates and updates accumulated points based on the position's liquidity
    /// and the difference between new and previous points growth.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `points_growth` - Updated points growth value
    /// 
    /// # Returns
    /// The current unclaimed points amount
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    /// * If adding points delta would cause overflow (error code: 3)
    public(package) fun update_points(position_manager: &mut PositionManager, position_id: sui::object::ID, points_growth: u128): u128 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_points_internal(position_info, points_growth);
        position_info.points_owned
    }

    /// Internal method for updating growth and accumulated points for a position.
    /// Calculates new points based on:
    /// * Current position liquidity
    /// * Difference between new and previous points growth
    /// 
    /// # Arguments
    /// * `position_info` - Mutable reference to the position information
    /// * `points_growth` - Updated points growth value
    /// 
    /// # Details
    /// The function:
    /// 1. Calculates points delta based on liquidity and growth difference
    /// 2. Updates accumulated points
    /// 3. Updates internal growth tracking
    /// 
    /// # Abort Conditions
    /// * If adding points delta would cause overflow (error code: 3)
    fun update_points_internal(position_info: &mut PositionInfo, points_growth: u128) {
        let points_delta = integer_mate::full_math_u128::mul_shr(
            position_info.liquidity,
            integer_mate::math_u128::wrapping_sub(points_growth, position_info.points_growth_inside),
            64
        );
        assert!(integer_mate::math_u128::add_check(position_info.points_owned, points_delta), 3);
        position_info.points_owned = position_info.points_owned + points_delta;
        position_info.points_growth_inside = points_growth;
    }

    /// Updates the rewards growth for a position.
    /// This function calculates and updates accumulated rewards for all reward types.
    /// 
    /// # Arguments
    /// * `position_manager` - Mutable reference to the position manager
    /// * `position_id` - ID of the position to update
    /// * `rewards_growth` - Vector of updated reward growth values
    /// 
    /// # Returns
    /// Vector of current unclaimed reward amounts for each reward type
    /// 
    /// # Abort Conditions
    /// * If the position does not exist (error code: 6)
    /// * If the position ID does not match (error code: 6)
    public(package) fun update_rewards(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        rewards_growth: vector<u128>
    ): vector<u64> {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_rewards_internal(position_info, rewards_growth);
        let rewards = info_rewards(position_info);
        let mut i = 0;
        let mut result = std::vector::empty<u64>();
        while (i < std::vector::length<PositionReward>(rewards)) {
            std::vector::push_back<u64>(&mut result, reward_amount_owned(std::vector::borrow<PositionReward>(rewards, i)));
            i = i + 1;
        };
        result
    }

    /// Internal method for updating growth and accumulated rewards for a position.
    /// Calculates new rewards based on:
    /// * Current position liquidity
    /// * Difference between new and previous growth for each reward
    /// 
    /// # Arguments
    /// * `position_info` - Mutable reference to the position information
    /// * `rewards_growth` - Vector of updated reward growth values
    /// 
    /// # Details
    /// The function:
    /// 1. For each reward, calculates delta based on liquidity and growth difference
    /// 2. Updates accumulated rewards
    /// 3. Updates internal growth tracking
    /// 4. Creates new rewards if their count is less than the number of growth values
    /// 
    /// # Abort Conditions
    /// * If adding reward delta would cause overflow (error code: 1)
    fun update_rewards_internal(position_info: &mut PositionInfo, rewards_growth: vector<u128>) {
        let mut index = 0;
        while (index < std::vector::length<u128>(&rewards_growth)) {
            let current_growth = *std::vector::borrow<u128>(&rewards_growth, index);
            if (std::vector::length<PositionReward>(&position_info.rewards) > index) {
                let reward = std::vector::borrow_mut<PositionReward>(&mut position_info.rewards, index);
                let reward_delta = integer_mate::full_math_u128::mul_shr(
                    integer_mate::math_u128::wrapping_sub(current_growth, reward.growth_inside),
                    position_info.liquidity,
                    64
                ) as u64;
                assert!(integer_mate::math_u64::add_check(reward.amount_owned, reward_delta), 1);
                reward.growth_inside = current_growth;
                reward.amount_owned = reward.amount_owned + reward_delta;
            } else {
                let new_reward = PositionReward {
                    growth_inside: current_growth,
                    amount_owned: integer_mate::full_math_u128::mul_shr(current_growth, position_info.liquidity, 64) as u64,
                };
                std::vector::push_back<PositionReward>(&mut position_info.rewards, new_reward);
            };
            index = index + 1;
        };
    }

    /// Returns the URL for position metadata.
    /// This function provides access to the position's associated URL, which can be used
    /// for displaying additional information or resources related to the position.
    /// 
    /// # Arguments
    /// * `position` - Reference to the position
    /// 
    /// # Returns
    /// The position's URL as a string
    public fun url(position: &Position): std::string::String {
        position.url
    }
}


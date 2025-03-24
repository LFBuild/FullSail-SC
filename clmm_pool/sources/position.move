module clmm_pool::position {
    public struct StakePositionEvent has copy, drop {
        position_id: sui::object::ID,
        staked: bool,
    }

    public struct PositionManager has store {
        tick_spacing: u32,
        position_index: u64,
        positions: move_stl::linked_table::LinkedTable<sui::object::ID, PositionInfo>,
    }

    public struct POSITION has drop {}

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
        magma_distribution_staked: bool,
        magma_distribution_growth_inside: u128,
        magma_distribution_owned: u64,
    }

    public struct PositionReward has copy, drop, store {
        growth_inside: u128,
        amount_owned: u64,
    }
    
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
    
    public(package) fun new(tick_spacing: u32, ctx: &mut sui::tx_context::TxContext): PositionManager {
        PositionManager {
            tick_spacing,
            position_index: 0,
            positions: move_stl::linked_table::new<sui::object::ID, PositionInfo>(ctx),
        }
    }

    fun borrow_mut_position_info(position_manager: &mut PositionManager, position_id: sui::object::ID): &mut PositionInfo {
        assert!(move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id), 6);
        let position_info = move_stl::linked_table::borrow_mut<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id);
        assert!(position_info.position_id == position_id, 6);
        position_info
    }
    
    public fun borrow_position_info(position_manager: &PositionManager, position_id: sui::object::ID): &PositionInfo {
        assert!(move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id), 6);
        let position_info = move_stl::linked_table::borrow<sui::object::ID, PositionInfo>(&position_manager.positions, position_id);
        assert!(position_info.position_id == position_id, 6);
        position_info
    }
    
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
    
    public(package) fun close_position(position_manager: &mut PositionManager, position: Position) {
        let position_id = sui::object::id<Position>(&position);
        if (!is_empty(borrow_mut_position_info(position_manager, position_id))) {
            abort 7
        };
        move_stl::linked_table::remove<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id);
        destroy(position);
    }
    public(package) fun decrease_liquidity(
        position_manager: &mut PositionManager,
        position: &mut Position,
        liquidity: u128,
        fee_growth_a: u128,
        fee_growth_b: u128,
        points_growth: u128,
        rewards_growth: vector<u128>,
        magma_growth: u128
    ): u128 {
        let position_info = borrow_mut_position_info(position_manager, sui::object::id<Position>(position));
        if (liquidity == 0) {
            return position_info.liquidity
        };
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        update_points_internal(position_info, points_growth);
        update_rewards_internal(position_info, rewards_growth);
        update_magma_distribution_internal(position_info, magma_growth);
        assert!(position_info.liquidity >= liquidity, 9);
        position_info.liquidity = position_info.liquidity - liquidity;
        position.liquidity = position_info.liquidity;
        position_info.liquidity
    }
    
    public fun description(position: &Position): std::string::String {
        position.description
    }

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
    public fun fetch_positions(
        position_manager: &PositionManager,
        position_ids: vector<sui::object::ID>,
        limit: u64
    ): vector<PositionInfo> {
        let mut positions = std::vector::empty<PositionInfo>();
        let next_id = if (std::vector::is_empty<sui::object::ID>(&position_ids)) {
            move_stl::linked_table::head<sui::object::ID, PositionInfo>(&position_manager.positions)
        } else {
            move_stl::linked_table::next<sui::object::ID, PositionInfo>(
                move_stl::linked_table::borrow_node<sui::object::ID, PositionInfo>(
                    &position_manager.positions,
                    *std::vector::borrow<sui::object::ID>(&position_ids, 0)
                )
            )
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
    public(package) fun increase_liquidity(
        position_manager: &mut PositionManager,
        position: &mut Position,
        liquidity_delta: u128,
        fee_growth_a: u128,
        fee_growth_b: u128,
        points_growth: u128,
        rewards_growth: vector<u128>,
        magma_growth: u128
    ): u128 {
        let position_info = borrow_mut_position_info(position_manager, sui::object::id<Position>(position));
        update_fee_internal(position_info, fee_growth_a, fee_growth_b);
        update_points_internal(position_info, points_growth);
        update_rewards_internal(position_info, rewards_growth);
        update_magma_distribution_internal(position_info, magma_growth);
        assert!(integer_mate::math_u128::add_check(position_info.liquidity, liquidity_delta), 8);
        position_info.liquidity = position_info.liquidity + liquidity_delta;
        position.liquidity = position_info.liquidity;
        position_info.liquidity
    }
    public fun index(position: &Position): u64 {
        position.index
    }

    public fun info_fee_growth_inside(position_info: &PositionInfo): (u128, u128) {
        (position_info.fee_growth_inside_a, position_info.fee_growth_inside_b)
    }

    public fun info_fee_owned(position_info: &PositionInfo): (u64, u64) {
        (position_info.fee_owned_a, position_info.fee_owned_b)
    }

    public fun info_liquidity(position_info: &PositionInfo): u128 {
        position_info.liquidity
    }

    public fun info_magma_distribution_owned(position_info: &PositionInfo): u64 {
        position_info.magma_distribution_owned
    }

    public fun info_points_growth_inside(position_info: &PositionInfo): u128 {
        position_info.points_growth_inside
    }

    public fun info_points_owned(position_info: &PositionInfo): u128 {
        position_info.points_owned
    }

    public fun info_position_id(position_info: &PositionInfo): sui::object::ID {
        position_info.position_id
    }

    public fun info_rewards(position_info: &PositionInfo): &vector<PositionReward> {
        &position_info.rewards
    }

    public fun info_tick_range(position_info: &PositionInfo): (integer_mate::i32::I32, integer_mate::i32::I32) {
        (position_info.tick_lower_index, position_info.tick_upper_index)
    }
    fun init(position_witness: POSITION, ctx: &mut sui::tx_context::TxContext) {
        let mut display_keys = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"name"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"coin_a"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"coin_b")); 
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"link"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"image_url"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"description"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"project_url"));
        std::vector::push_back<std::string::String>(&mut display_keys, std::string::utf8(b"creator"));

        let mut display_values = std::vector::empty<std::string::String>();
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{name}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{coin_type_a}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{coin_type_b}"));
        std::vector::push_back<std::string::String>(
            &mut display_values,
            std::string::utf8(b"https://app.cetus.zone/position?chain=sui&id={id}")
        );
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{url}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"{description}"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"https://cetus.zone"));
        std::vector::push_back<std::string::String>(&mut display_values, std::string::utf8(b"Cetus"));

        let publisher = sui::package::claim<POSITION>(position_witness, ctx);
        let mut display = sui::display::new_with_fields<Position>(&publisher, display_keys, display_values, ctx);
        sui::display::update_version<Position>(&mut display);
        sui::transfer::public_transfer<sui::display::Display<Position>>(display, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer<sui::package::Publisher>(publisher, sui::tx_context::sender(ctx));
    }
    public fun inited_rewards_count(position_manager: &PositionManager, position_id: sui::object::ID): u64 {
        std::vector::length<PositionReward>(
            &move_stl::linked_table::borrow<sui::object::ID, PositionInfo>(&position_manager.positions, position_id).rewards
        )
    }

    public fun is_position_exist(position_manager: &PositionManager, position_id: sui::object::ID): bool {
        move_stl::linked_table::contains<sui::object::ID, PositionInfo>(&position_manager.positions, position_id)
    }

    public fun is_staked(position_info: &PositionInfo): bool {
        position_info.magma_distribution_staked
    }

    public fun liquidity(position: &Position): u128 {
        position.liquidity
    }

    public(package) fun mark_position_staked(position_manager: &mut PositionManager, position_id: sui::object::ID, staked: bool) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        assert!(position_info.magma_distribution_staked != staked, 11);
        position_info.magma_distribution_staked = staked;
        let stake_event = StakePositionEvent {
            position_id: position_info.position_id,
            staked: staked,
        };
        sui::event::emit<StakePositionEvent>(stake_event);
    }

    public fun name(position: &Position): std::string::String {
        position.name
    }
    
    fun new_position_name(pool_index: u64, position_index: u64): std::string::String {
        let mut position_name = std::string::utf8(b"Magma position:");
        std::string::append(&mut position_name, clmm_pool::utils::str(pool_index));
        std::string::append_utf8(&mut position_name, b"-");
        std::string::append(&mut position_name, clmm_pool::utils::str(position_index));
        position_name
    }
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
            description: std::string::utf8(b"Magma Liquidity Position"),
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
            magma_distribution_staked: false,
            magma_distribution_growth_inside: 0,
            magma_distribution_owned: 0,
        };
        move_stl::linked_table::push_back<sui::object::ID, PositionInfo>(&mut position_manager.positions, position_id, position_info);
        position_manager.position_index = next_position_index;
        position
    }

    public fun pool_id(position: &Position): sui::object::ID {
        position.pool
    }

    public(package) fun reset_fee(position_manager: &mut PositionManager, position_id: sui::object::ID): (u64, u64) {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        position_info.fee_owned_a = 0;
        position_info.fee_owned_b = 0;
        (position_info.fee_owned_a, position_info.fee_owned_b)
    }
    
    public(package) fun reset_rewarder(position_manager: &mut PositionManager, position_id: sui::object::ID, reward_index: u64): u64 {
        let reward = std::vector::borrow_mut<PositionReward>(&mut borrow_mut_position_info(position_manager, position_id).rewards, reward_index);
        reward.amount_owned = 0;
        reward.amount_owned
    }

    public fun reward_amount_owned(reward: &PositionReward): u64 {
        reward.amount_owned
    }

    public fun reward_growth_inside(reward: &PositionReward): u128 {
        reward.growth_inside
    }
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

    public fun set_description(position: &mut Position, description: std::string::String) {
        position.description = description;
    }

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

    public fun tick_range(position: &Position): (integer_mate::i32::I32, integer_mate::i32::I32) {
        (position.tick_lower_index, position.tick_upper_index)
    }
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
    public(package) fun update_and_reset_magma_distribution(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        magma_growth: u128
    ): u64 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_magma_distribution_internal(position_info, magma_growth);
        position_info.magma_distribution_owned = 0;
        position_info.magma_distribution_owned
    }
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

    public(package) fun update_magma_distribution(
        position_manager: &mut PositionManager,
        position_id: sui::object::ID,
        magma_growth: u128
    ): u64 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_magma_distribution_internal(position_info, magma_growth);
        position_info.magma_distribution_owned
    }

    fun update_magma_distribution_internal(position_info: &mut PositionInfo, magma_growth: u128) {
        let magma_delta = integer_mate::full_math_u128::mul_shr(
            position_info.liquidity,
            integer_mate::math_u128::wrapping_sub(
                magma_growth,
                position_info.magma_distribution_growth_inside
            ),
            64
        ) as u64;
        assert!(
            integer_mate::math_u64::add_check(
                position_info.magma_distribution_owned,
                magma_delta
            ),
            9223374347547181055
        );
        position_info.magma_distribution_owned = position_info.magma_distribution_owned + magma_delta;
        position_info.magma_distribution_growth_inside = magma_growth;
    }

    public(package) fun update_points(position_manager: &mut PositionManager, position_id: sui::object::ID, points_growth: u128): u128 {
        let position_info = borrow_mut_position_info(position_manager, position_id);
        update_points_internal(position_info, points_growth);
        position_info.points_owned
    }

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

    public fun url(position: &Position): std::string::String {
        position.url
    }

    // decompiled from Move bytecode v6
}


module clmm_pool::tick {
    public struct TickManager has store {
        tick_spacing: u32,
        ticks: move_stl::skip_list::SkipList<Tick>,
    }

    public struct Tick has copy, drop, store {
        index: integer_mate::i32::I32,
        sqrt_price: u128,
        liquidity_net: integer_mate::i128::I128,
        liquidity_gross: u128,
        fee_growth_outside_a: u128,
        fee_growth_outside_b: u128,
        points_growth_outside: u128,
        rewards_growth_outside: vector<u128>,
        magma_distribution_staked_liquidity_net: integer_mate::i128::I128,
        magma_distribution_growth_outside: u128,
    }

    public(package) fun new(tick_spacing: u32, seed: u64, ctx: &mut sui::tx_context::TxContext): TickManager {
        TickManager {
            tick_spacing,
            ticks: move_stl::skip_list::new<Tick>(16, 2, seed, ctx),
        }
    }

    public fun borrow_tick(tick_manager: &TickManager, tick_index: integer_mate::i32::I32): &Tick {
        move_stl::skip_list::borrow<Tick>(&tick_manager.ticks, tick_score(tick_index))
    }

    public fun borrow_tick_for_swap(
        tick_manager: &TickManager,
        score: u64,
        is_prev: bool
    ): (&Tick, move_stl::option_u64::OptionU64) {
        let node = move_stl::skip_list::borrow_node<Tick>(&tick_manager.ticks, score);
        let next_score = if (is_prev) {
            move_stl::skip_list::prev_score<Tick>(node)
        } else {
            move_stl::skip_list::next_score<Tick>(node)
        };
        (move_stl::skip_list::borrow_value<Tick>(node), next_score)
    }
    public(package) fun cross_by_swap(
        tick_manager: &mut TickManager,
        tick_index: integer_mate::i32::I32,
        is_a2b: bool,
        current_liquidity: u128,
        staked_liquidity: u128,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        points_growth_global: u128,
        rewards_growth_global: vector<u128>,
        magma_growth_global: u128
    ): (u128, u128) {
        let tick = move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, tick_score(tick_index));
        let (liquidity_delta, staked_liquidity_delta) = if (is_a2b) {
            (integer_mate::i128::neg(tick.liquidity_net), integer_mate::i128::neg(
                tick.magma_distribution_staked_liquidity_net
            ))
        } else {
            (tick.liquidity_net, tick.magma_distribution_staked_liquidity_net)
        };
        let (new_liquidity, new_staked_liquidity) = if (!integer_mate::i128::is_neg(liquidity_delta)) {
            let liquidity_abs = integer_mate::i128::abs_u128(liquidity_delta);
            assert!(integer_mate::math_u128::add_check(liquidity_abs, current_liquidity), 1);
            let staked_abs = integer_mate::i128::abs_u128(staked_liquidity_delta);
            assert!(integer_mate::math_u128::add_check(staked_abs, staked_liquidity), 1);
            (current_liquidity + liquidity_abs, staked_liquidity + staked_abs)
        } else {
            let liquidity_abs = integer_mate::i128::abs_u128(liquidity_delta);
            assert!(current_liquidity >= liquidity_abs, 1);
            let staked_abs = integer_mate::i128::abs_u128(staked_liquidity_delta);
            assert!(staked_liquidity >= staked_abs, 9223372401926995967);
            (current_liquidity - liquidity_abs, staked_liquidity - staked_abs)
        };
        tick.fee_growth_outside_a = integer_mate::math_u128::wrapping_sub(fee_growth_global_a, tick.fee_growth_outside_a);
        tick.fee_growth_outside_b = integer_mate::math_u128::wrapping_sub(fee_growth_global_b, tick.fee_growth_outside_b);
        let mut i = 0;
        while (i < std::vector::length<u128>(&rewards_growth_global)) {
            let reward_growth = *std::vector::borrow<u128>(&rewards_growth_global, i);
            if (std::vector::length<u128>(&tick.rewards_growth_outside) > i) {
                let reward_outside = std::vector::borrow_mut<u128>(&mut tick.rewards_growth_outside, i);
                *reward_outside = integer_mate::math_u128::wrapping_sub(reward_growth, *reward_outside);
            } else {
                std::vector::push_back<u128>(&mut tick.rewards_growth_outside, reward_growth);
            };
            i = i + 1;
        };
        tick.points_growth_outside = integer_mate::math_u128::wrapping_sub(points_growth_global, tick.points_growth_outside);
        tick.magma_distribution_growth_outside = integer_mate::math_u128::wrapping_sub(
            magma_growth_global,
            tick.magma_distribution_growth_outside
        );
        (new_liquidity, new_staked_liquidity)
    }
    public(package) fun decrease_liquidity(
        tick_manager: &mut TickManager,
        current_tick_index: integer_mate::i32::I32,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        liquidity: u128,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        points_growth_global: u128,
        rewards_growth_global: vector<u128>,
        magma_growth_global: u128
    ) {
        if (liquidity == 0) {
            return
        };
        let lower_score = tick_score(tick_lower);
        let upper_score = tick_score(tick_upper);
        assert!(move_stl::skip_list::contains<Tick>(&tick_manager.ticks, lower_score), 3);
        assert!(move_stl::skip_list::contains<Tick>(&tick_manager.ticks, upper_score), 3);
        if (update_by_liquidity(
            move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, lower_score),
            current_tick_index,
            liquidity,
            false,
            false,
            false,
            fee_growth_global_a,
            fee_growth_global_b,
            points_growth_global,
            rewards_growth_global,
            magma_growth_global
        ) == 0) {
            move_stl::skip_list::remove<Tick>(&mut tick_manager.ticks, lower_score);
        };
        if (update_by_liquidity(
            move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, upper_score),
            current_tick_index,
            liquidity,
            false,
            false,
            true,
            fee_growth_global_a,
            fee_growth_global_b,
            points_growth_global,
            rewards_growth_global,
            magma_growth_global
        ) == 0) {
            move_stl::skip_list::remove<Tick>(&mut tick_manager.ticks, upper_score);
        };
    }
    fun default(tick_index: integer_mate::i32::I32): Tick {
        Tick {
            index: tick_index,
            sqrt_price: clmm_pool::tick_math::get_sqrt_price_at_tick(tick_index),
            liquidity_net: integer_mate::i128::from(0),
            liquidity_gross: 0,
            fee_growth_outside_a: 0,
            fee_growth_outside_b: 0,
            points_growth_outside: 0,
            rewards_growth_outside: std::vector::empty<u128>(),
            magma_distribution_staked_liquidity_net: integer_mate::i128::from(0),
            magma_distribution_growth_outside: 0,
        }
    }

    fun default_rewards_growth_outside(rewards_count: u64): vector<u128> {
        if (rewards_count <= 0) {
            std::vector::empty<u128>()
        } else {
            let mut rewards = std::vector::empty<u128>();
            let mut index = 0;
            while (index < rewards_count) {
                std::vector::push_back<u128>(&mut rewards, 0);
                index = index + 1;
            };
            rewards
        }
    }

    public fun fee_growth_outside(tick: &Tick): (u128, u128) {
        (tick.fee_growth_outside_a, tick.fee_growth_outside_b)
    }
    public fun fetch_ticks(tick_manager: &TickManager, tick_indices: vector<u32>, limit: u64): vector<Tick> {
        let mut result = std::vector::empty<Tick>();
        let next_score = if (std::vector::is_empty<u32>(&tick_indices)) {
            move_stl::skip_list::head<Tick>(&tick_manager.ticks)
        } else {
            move_stl::skip_list::find_next<Tick>(
                &tick_manager.ticks,
                tick_score(integer_mate::i32::from_u32(*std::vector::borrow<u32>(&tick_indices, 0))),
                false
            )
        };
        let mut current_score = next_score;
        let mut count = 0;
        while (move_stl::option_u64::is_some(&current_score)) {
            let node = move_stl::skip_list::borrow_node<Tick>(&tick_manager.ticks, move_stl::option_u64::borrow(&current_score));
            std::vector::push_back<Tick>(&mut result, *move_stl::skip_list::borrow_value<Tick>(node));
            current_score = move_stl::skip_list::next_score<Tick>(node);
            let new_count = count + 1;
            count = new_count;
            if (new_count == limit) {
                break
            };
        };
        result
    }
    public fun first_score_for_swap(
        tick_manager: &TickManager,
        tick_index: integer_mate::i32::I32,
        is_reverse: bool
    ): move_stl::option_u64::OptionU64 {
        if (is_reverse) {
            move_stl::skip_list::find_prev<Tick>(&tick_manager.ticks, tick_score(tick_index), true)
        } else {
            let next_score = if (integer_mate::i32::eq(
                tick_index,
                integer_mate::i32::neg_from(clmm_pool::tick_math::tick_bound() + 1)
            )) {
                move_stl::skip_list::find_next<Tick>(&tick_manager.ticks, tick_score(clmm_pool::tick_math::min_tick()), true)
            } else {
                move_stl::skip_list::find_next<Tick>(&tick_manager.ticks, tick_score(tick_index), false)
            };
            next_score
        }
    }

    public fun get_fee_in_range(
        current_tick_index: integer_mate::i32::I32,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        tick_lower: std::option::Option<Tick>,
        tick_upper: std::option::Option<Tick>
    ): (u128, u128) {
        let (fee_growth_below_a, fee_growth_below_b) = if (std::option::is_none<Tick>(&tick_lower)) {
            (fee_growth_global_a, fee_growth_global_b)
        } else {
            let tick_l = std::option::borrow<Tick>(&tick_lower);
            let (fee_a, fee_b) = if (integer_mate::i32::lt(current_tick_index, tick_l.index)) {
                (integer_mate::math_u128::wrapping_sub(
                    fee_growth_global_a,
                    tick_l.fee_growth_outside_a
                ), integer_mate::math_u128::wrapping_sub(
                    fee_growth_global_b,
                    tick_l.fee_growth_outside_b
                ))
            } else {
                (tick_l.fee_growth_outside_a, tick_l.fee_growth_outside_b)
            };
            (fee_a, fee_b)
        };

        let (fee_growth_above_a, fee_growth_above_b) = if (std::option::is_none<Tick>(&tick_upper)) {
            (0, 0)
        } else {
            let tick_u = std::option::borrow<Tick>(&tick_upper);
            let (fee_a, fee_b) = if (integer_mate::i32::lt(current_tick_index, tick_u.index)) {
                (tick_u.fee_growth_outside_a, tick_u.fee_growth_outside_b)
            } else {
                (integer_mate::math_u128::wrapping_sub(
                    fee_growth_global_a,
                    tick_u.fee_growth_outside_a
                ), integer_mate::math_u128::wrapping_sub(
                    fee_growth_global_b,
                    tick_u.fee_growth_outside_b
                ))
            };
            (fee_a, fee_b)
        };
        (integer_mate::math_u128::wrapping_sub(
            integer_mate::math_u128::wrapping_sub(fee_growth_global_a, fee_growth_below_a),
            fee_growth_above_a
        ), integer_mate::math_u128::wrapping_sub(
            integer_mate::math_u128::wrapping_sub(fee_growth_global_b, fee_growth_below_b),
            fee_growth_above_b
        ))
    }

    public fun get_magma_distribution_growth_in_range(
        current_tick_index: integer_mate::i32::I32,
        magma_growth_global: u128,
        tick_lower: std::option::Option<Tick>,
        tick_upper: std::option::Option<Tick>
    ): u128 {
        let magma_growth_below = if (std::option::is_none<Tick>(&tick_lower)) {
            magma_growth_global
        } else {
            let tick_l = std::option::borrow<Tick>(&tick_lower);
            let magma_below = if (integer_mate::i32::lt(current_tick_index, tick_l.index)) {
                integer_mate::math_u128::wrapping_sub(magma_growth_global, tick_l.magma_distribution_growth_outside)
            } else {
                tick_l.magma_distribution_growth_outside
            };
            magma_below
        };
        let magma_growth_above = if (std::option::is_none<Tick>(&tick_upper)) {
            0
        } else {
            let tick_u = std::option::borrow<Tick>(&tick_upper);
            let magma_above = if (integer_mate::i32::lt(current_tick_index, tick_u.index)) {
                tick_u.magma_distribution_growth_outside
            } else {
                integer_mate::math_u128::wrapping_sub(magma_growth_global, tick_u.magma_distribution_growth_outside)
            };
            magma_above
        };
        integer_mate::math_u128::wrapping_sub(integer_mate::math_u128::wrapping_sub(magma_growth_global, magma_growth_below), magma_growth_above)
    }
    public fun get_points_in_range(
        current_tick_index: integer_mate::i32::I32,
        points_growth_global: u128,
        tick_lower: std::option::Option<Tick>,
        tick_upper: std::option::Option<Tick>
    ): u128 {
        let points_growth_below = if (std::option::is_none<Tick>(&tick_lower)) {
            points_growth_global
        } else {
            let tick_l = std::option::borrow<Tick>(&tick_lower);
            let points_below = if (integer_mate::i32::lt(current_tick_index, tick_l.index)) {
                integer_mate::math_u128::wrapping_sub(points_growth_global, tick_l.points_growth_outside)
            } else {
                tick_l.points_growth_outside
            };
            points_below
        };
        let points_growth_above = if (std::option::is_none<Tick>(&tick_upper)) {
            0
        } else {
            let tick_u = std::option::borrow<Tick>(&tick_upper);
            let points_above = if (integer_mate::i32::lt(current_tick_index, tick_u.index)) {
                tick_u.points_growth_outside
            } else {
                integer_mate::math_u128::wrapping_sub(points_growth_global, tick_u.points_growth_outside)
            };
            points_above
        };
        integer_mate::math_u128::wrapping_sub(integer_mate::math_u128::wrapping_sub(points_growth_global, points_growth_below), points_growth_above)
    }

    public fun get_reward_growth_outside(tick: &Tick, reward_index: u64): u128 {
        if (std::vector::length<u128>(&tick.rewards_growth_outside) <= reward_index) {
            0
        } else {
            *std::vector::borrow<u128>(&tick.rewards_growth_outside, reward_index)
        }
    }

    public fun get_rewards_in_range(
        current_tick_index: integer_mate::i32::I32,
        rewards_growth_global: vector<u128>,
        tick_lower: std::option::Option<Tick>,
        tick_upper: std::option::Option<Tick>
    ): vector<u128> {
        let mut rewards_in_range = std::vector::empty<u128>();
        let mut reward_index = 0;
        while (reward_index < std::vector::length<u128>(&rewards_growth_global)) {
            let reward_growth_global = *std::vector::borrow<u128>(&rewards_growth_global, reward_index);
            let reward_growth_below = if (std::option::is_none<Tick>(&tick_lower)) {
                reward_growth_global
            } else {
                let tick_l = std::option::borrow<Tick>(&tick_lower);
                let reward_below = if (integer_mate::i32::lt(current_tick_index, tick_l.index)) {
                    integer_mate::math_u128::wrapping_sub(reward_growth_global, get_reward_growth_outside(tick_l, reward_index))
                } else {
                    get_reward_growth_outside(tick_l, reward_index)
                };
                reward_below
            };
            let reward_growth_above = if (std::option::is_none<Tick>(&tick_upper)) {
                0
            } else {
                let tick_u = std::option::borrow<Tick>(&tick_upper);
                let reward_above = if (integer_mate::i32::lt(current_tick_index, tick_u.index)) {
                    get_reward_growth_outside(tick_u, reward_index)
                } else {
                    let reward_outside = get_reward_growth_outside(tick_u, reward_index);
                    integer_mate::math_u128::wrapping_sub(reward_growth_global, reward_outside)
                };
                reward_above
            };
            std::vector::push_back<u128>(
                &mut rewards_in_range,
                integer_mate::math_u128::wrapping_sub(integer_mate::math_u128::wrapping_sub(reward_growth_global, reward_growth_below), reward_growth_above)
            );
            reward_index = reward_index + 1;
        };
        rewards_in_range
    }
    public(package) fun increase_liquidity(
        tick_manager: &mut TickManager,
        current_tick_index: integer_mate::i32::I32,
        tick_lower: integer_mate::i32::I32,
        tick_upper: integer_mate::i32::I32,
        liquidity: u128,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        points_growth_global: u128,
        rewards_growth_global: vector<u128>,
        magma_distribution_growth_global: u128
    ) {
        if (liquidity == 0) {
            return
        };
        let tick_lower_score = tick_score(tick_lower);
        let tick_upper_score = tick_score(tick_upper);
        let mut is_upper_initialized = false;
        let mut is_lower_initialized = false;
        if (!move_stl::skip_list::contains<Tick>(&tick_manager.ticks, tick_lower_score)) {
            move_stl::skip_list::insert<Tick>(&mut tick_manager.ticks, tick_lower_score, default(tick_lower));
            is_lower_initialized = true;
        };
        if (!move_stl::skip_list::contains<Tick>(&tick_manager.ticks, tick_upper_score)) {
            move_stl::skip_list::insert<Tick>(&mut tick_manager.ticks, tick_upper_score, default(tick_upper));
            is_upper_initialized = true;
        };
        update_by_liquidity(
            move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, tick_lower_score),
            current_tick_index,
            liquidity,
            is_lower_initialized,
            true,
            false,
            fee_growth_global_a,
            fee_growth_global_b,
            points_growth_global,
            rewards_growth_global,
            magma_distribution_growth_global
        );
        update_by_liquidity(
            move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, tick_upper_score),
            current_tick_index,
            liquidity,
            is_upper_initialized,
            true,
            true,
            fee_growth_global_a,
            fee_growth_global_b,
            points_growth_global,
            rewards_growth_global,
            magma_distribution_growth_global
        );
    }
    public fun index(tick: &Tick): integer_mate::i32::I32 {
        tick.index
    }

    public fun liquidity_gross(tick: &Tick): u128 {
        tick.liquidity_gross
    }

    public fun liquidity_net(tick: &Tick): integer_mate::i128::I128 {
        tick.liquidity_net
    }

    public fun magma_distribution_growth_outside(tick: &Tick): u128 {
        tick.magma_distribution_growth_outside
    }

    public fun magma_distribution_staked_liquidity_net(tick: &Tick): integer_mate::i128::I128 {
        tick.magma_distribution_staked_liquidity_net
    }

    public fun points_growth_outside(tick: &Tick): u128 {
        tick.points_growth_outside
    }

    public fun rewards_growth_outside(tick: &Tick): &vector<u128> {
        &tick.rewards_growth_outside
    }

    public fun sqrt_price(tick: &Tick): u128 {
        tick.sqrt_price
    }

    fun tick_score(tick_index: integer_mate::i32::I32): u64 {
        let bound_adjusted_tick = integer_mate::i32::as_u32(
            integer_mate::i32::add(tick_index, integer_mate::i32::from(clmm_pool::tick_math::tick_bound()))
        );
        assert!(bound_adjusted_tick >= 0 && bound_adjusted_tick <= clmm_pool::tick_math::tick_bound() * 2, 2);
        bound_adjusted_tick as u64
    }

    public fun tick_spacing(manager: &TickManager): u32 {
        manager.tick_spacing
    }
    
    public(package) fun try_borrow_tick(manager: &TickManager, tick_index: integer_mate::i32::I32): std::option::Option<Tick> {
        let score = tick_score(tick_index);
        if (!move_stl::skip_list::contains<Tick>(&manager.ticks, score)) {
            return std::option::none<Tick>()
        };
        std::option::some<Tick>(*move_stl::skip_list::borrow<Tick>(&manager.ticks, score))
    }

    fun update_by_liquidity(
        tick: &mut Tick,
        current_tick_index: integer_mate::i32::I32,
        liquidity: u128,
        is_lower_initialized: bool,
        is_add: bool,
        is_upper: bool,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        points_growth_global: u128,
        rewards_growth_global: vector<u128>,
        magma_distribution_growth_global: u128
    ): u128 {
        let updated_liquidity_gross = if (is_add) {
            assert!(integer_mate::math_u128::add_check(tick.liquidity_gross, liquidity), 0);
            tick.liquidity_gross + liquidity
        } else {
            assert!(tick.liquidity_gross >= liquidity, 1);
            tick.liquidity_gross - liquidity
        };
        if (updated_liquidity_gross == 0) {
            return 0
        };
        let (points_growth_outside, magma_growth_outside, fee_growth_outside_a, fee_growth_outside_b, rewards_growth_outside) = if (is_lower_initialized) {
            let (fee_outside_a, fee_outside_b, rewards_outside, points_outside, magma_outside) = if (integer_mate::i32::lt(current_tick_index, tick.index)) {
                (0, 0, default_rewards_growth_outside(std::vector::length<u128>(&rewards_growth_global)), 0, 0)
            } else {
                (fee_growth_global_a, fee_growth_global_b, rewards_growth_global, points_growth_global, magma_distribution_growth_global)
            };
            (points_outside, magma_outside, fee_outside_a, fee_outside_b, rewards_outside)
        } else {
            (tick.points_growth_outside, tick.magma_distribution_growth_outside, tick.fee_growth_outside_a, tick.fee_growth_outside_b, tick.rewards_growth_outside)
        };
        let (liquidity_delta_result, overflow_detected) = if (is_add) {
            let (delta_value_add, overflow_flag_add) = if (is_upper) {
                let (subtraction_result_add, subtraction_overflow_add) = integer_mate::i128::overflowing_sub(
                    tick.liquidity_net,
                    integer_mate::i128::from(liquidity)
                );
                (subtraction_result_add, subtraction_overflow_add)
            } else {
                let (addition_result_add, addition_overflow_add) = integer_mate::i128::overflowing_add(
                    tick.liquidity_net,
                    integer_mate::i128::from(liquidity)
                );
                (addition_result_add, addition_overflow_add)
            };
            (delta_value_add, overflow_flag_add)
        } else {
            let (delta_value_sub, overflow_flag_sub) = if (is_upper) {
                let (addition_result_sub, addition_overflow_sub) = integer_mate::i128::overflowing_add(
                    tick.liquidity_net,
                    integer_mate::i128::from(liquidity)
                );
                (addition_result_sub, addition_overflow_sub)
            } else {
                let (subtraction_result_sub, subtraction_overflow_sub) = integer_mate::i128::overflowing_sub(
                    tick.liquidity_net,
                    integer_mate::i128::from(liquidity)
                );
                (subtraction_result_sub, subtraction_overflow_sub)
            };
            (delta_value_sub, overflow_flag_sub)
        };
        if (overflow_detected) {
            abort 0
        };
        tick.liquidity_gross = updated_liquidity_gross;
        tick.liquidity_net = liquidity_delta_result;
        tick.fee_growth_outside_a = fee_growth_outside_a;
        tick.fee_growth_outside_b = fee_growth_outside_b;
        tick.rewards_growth_outside = rewards_growth_outside;
        tick.points_growth_outside = points_growth_outside;
        tick.magma_distribution_growth_outside = magma_growth_outside;
        updated_liquidity_gross
    }

    public(package) fun update_magma_stake(
        tick_manager: &mut TickManager,
        tick_index: integer_mate::i32::I32,
        liquidity_delta: integer_mate::i128::I128,
        is_decrease: bool
    ) {
        let tick = move_stl::skip_list::borrow_mut<Tick>(&mut tick_manager.ticks, tick_score(tick_index));
        if (is_decrease) {
            tick.magma_distribution_staked_liquidity_net = integer_mate::i128::wrapping_sub(
                tick.magma_distribution_staked_liquidity_net,
                liquidity_delta
            );
        } else {
            tick.magma_distribution_staked_liquidity_net = integer_mate::i128::wrapping_add(
                tick.magma_distribution_staked_liquidity_net,
                liquidity_delta
            );
        };
    }

    // decompiled from Move bytecode v6
}


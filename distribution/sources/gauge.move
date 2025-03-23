module distribution::gauge {

    const EInvalidVoter: u64 = 9223373656058429456;

    const ENontifyRewardInvalidAmount: u64 = 9223373716188102674;

    const EDepositPositionDistributionConfInvalid: u64 = 9223373183611043839;
    const EDepositPositionGaugeNotAlive: u64 = 9223373157842747416;
    const EDepositPositionGaugeDoesNotMatchPool: u64 = 9223373162136666120;
    const EDepositPositionPositionDoesNotMatchPool: u64 = 9223373166431764490;
    const EDepositPositionPositionAlreadyStaked: u64 = 9223373175021174786;

    const EEarnedByAccountGaugeDoesNotMatchPool: u64 = 9223372724050001928;

    const EEarnedByPositionGaugeDoesNotMatchPool: u64 = 9223372693985230856;
    const EEarnedByPositionNotDepositedPosition: u64 = 9223372698279936004;


    const EGetPositionRewardGaugeDoesNotMatchPool: u64 = 9223373428424638472;
    const EGetPositionRewardPositionNotStaked: u64 = 9223373432719343620;

    const EGetRewardGaugeDoesNotMatchPool: u64 = 9223373454194442248;
    const EGetRewardSenderHasNoDepositedPositions: u64 = 9223373462784638988;

    const EGetRewardForGaugeDoesNotMatchPool: u64 = 9223373510029017096;
    const EGetRewardForRecipientHasNoPositions: u64 = 9223373514324246540;

    const ENotifyRewardAmountRewardRateZero: u64 = 9223373952411435028;
    const ENotifyRewardInsufficientReserves: u64 = 9223373956706533398;
    const ENotifyRewardWithoutClaimInvalidAmount: u64 = 9223373819267317778;

    const EReceiveGaugeCapGaugeDoesNotMatch: u64 = 9223373119186534399;

    const EWithdrawPositionNotDepositedPosition: u64 = 9223373570158297092;
    const EWithdrawPositionNotReceivedPosition: u64 = 9223373578748887054;
    const EWithdrawPositionNotOwnerOfPosition: u64 = 9223373617403461644;

    public struct TRANSFORMER has drop {}

    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct EventNotifyReward has copy, drop, store {
        sender: sui::object::ID,
        amount: u64,
    }

    public struct EventClaimFees has copy, drop, store {
        amount_a: u64,
        amount_b: u64,
    }

    public struct RewardProfile has store {
        growth_inside: u128,
        amount: u64,
        last_update_time: u64,
    }

    public struct EventClaimReward has copy, drop, store {
        from: address,
        position_id: sui::object::ID,
        receiver: address,
        amount: u64,
    }

    public struct EventWithdrawPosition has copy, drop, store {
        position_id: sui::object::ID,
        gauger_id: sui::object::ID,
    }

    public struct EventDepositGauge has copy, drop, store {
        gauger_id: sui::object::ID,
        pool_id: sui::object::ID,
        position_id: sui::object::ID,
    }

    public struct EventGaugeCreated has copy, drop, store {
        id: sui::object::ID,
        pool_id: sui::object::ID,
    }

    public struct EventGaugeSetVoter has copy, drop, store {
        id: sui::object::ID,
        voter_id: sui::object::ID,
    }

    public struct Gauge<phantom CoinTypeA, phantom CoinTypeB, phantom SailCoinType> has store, key {
        id: sui::object::UID,
        pool_id: sui::object::ID,
        gauge_cap: std::option::Option<gauge_cap::gauge_cap::GaugeCap>,
        distribution_config: sui::object::ID,
        staked_positions: sui::object_table::ObjectTable<sui::object::ID, clmm_pool::position::Position>,
        staked_position_infos: sui::table::Table<sui::object::ID, PositionStakeInfo>,
        reserves_balance: sui::balance::Balance<SailCoinType>,
        fee_a: sui::balance::Balance<CoinTypeA>,
        fee_b: sui::balance::Balance<CoinTypeB>,
        voter: std::option::Option<sui::object::ID>,
        reward_rate: u128,
        period_finish: u64,
        reward_rate_by_epoch: sui::table::Table<u64, u128>,
        stakes: sui::table::Table<address, vector<sui::object::ID>>,
        rewards: sui::table::Table<sui::object::ID, RewardProfile>,
    }

    public struct PositionStakeInfo has drop, store {
        from: address,
        received: bool,
    }

    public fun pool_id<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>
    ): sui::object::ID {
        gauge.pool_id
    }

    public fun check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): bool {
        (gauge.pool_id != sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(
            pool
        ) || pool.get_magma_distribution_gauger_id() != sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(
            gauge
        )) && false || true
    }

    fun check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap
    ) {
        let voter_id = voter_cap.get_voter_id();
        assert!(&voter_id == gauge.voter.borrow(), EInvalidVoter);
    }

    public fun claim_fees<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        _notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        gauge.claim_fees_internal(pool)
    }

    fun claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let weekCoinPerSecond = clmm_pool::config::week();
        let (fee_a, fee_b) = pool.collect_magma_distribution_gauger_fees(gauge.gauge_cap.borrow());
        if (fee_a.value<CoinTypeA>() > 0 || fee_b.value<CoinTypeB>() > 0) {
            let amount_a = gauge.fee_a.join<CoinTypeA>(fee_a);
            let amount_b = gauge.fee_b.join<CoinTypeB>(fee_b);
            let withdrawn_a = if (amount_a > weekCoinPerSecond) {
                gauge.fee_a.withdraw_all<CoinTypeA>()
            } else {
                sui::balance::zero<CoinTypeA>()
            };
            let withdraw_b = if (amount_b > weekCoinPerSecond) {
                gauge.fee_b.withdraw_all<CoinTypeB>()
            } else {
                sui::balance::zero<CoinTypeB>()
            };
            let claim_fees_event = EventClaimFees {
                amount_a,
                amount_b,
            };
            sui::event::emit<EventClaimFees>(claim_fees_event);
            return (withdrawn_a, withdraw_b)
        };
        fee_a.destroy_zero();
        fee_b.destroy_zero();
        (sui::balance::zero<CoinTypeA>(), sui::balance::zero<CoinTypeB>())
    }

    public(package) fun create<CoinTypeA, CoinTypeB, SailCoinType>(
        distribution_config: &distribution::distribution_config::DistributionConfig,
        pool_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext
    ): Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
        let id = sui::object::new(ctx);
        let gauge_created_event = EventGaugeCreated {
            id: sui::object::uid_to_inner(&id),
            pool_id,
        };
        sui::event::emit<EventGaugeCreated>(gauge_created_event);
        Gauge<CoinTypeA, CoinTypeB, SailCoinType> {
            id,
            pool_id,
            gauge_cap: std::option::none<gauge_cap::gauge_cap::GaugeCap>(),
            distribution_config: sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ),
            staked_positions: sui::object_table::new<sui::object::ID, clmm_pool::position::Position>(ctx),
            staked_position_infos: sui::table::new<sui::object::ID, PositionStakeInfo>(ctx),
            reserves_balance: sui::balance::zero<SailCoinType>(),
            fee_a: sui::balance::zero<CoinTypeA>(),
            fee_b: sui::balance::zero<CoinTypeB>(),
            voter: std::option::none<sui::object::ID>(),
            reward_rate: 0,
            period_finish: 0,
            reward_rate_by_epoch: sui::table::new<u64, u128>(ctx),
            stakes: sui::table::new<address, vector<sui::object::ID>>(ctx),
            rewards: sui::table::new<sui::object::ID, RewardProfile>(ctx),
        }
    }

    public fun deposit_position<CoinTypeA, CoinTypeB, SailCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position: clmm_pool::position::Position,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let sender = sui::tx_context::sender(ctx);
        let pool_id = sui::object::id<clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>>(pool);
        let position_id = sui::object::id<clmm_pool::position::Position>(&position);
        assert!(
            sui::object::id<distribution::distribution_config::DistributionConfig>(
                distribution_config
            ) == gauge.distribution_config,
            EDepositPositionDistributionConfInvalid
        );
        assert!(
            distribution_config.is_gauge_alive(sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)),
            EDepositPositionGaugeNotAlive
        );
        assert!(
            gauge.check_gauger_pool(pool),
            EDepositPositionGaugeDoesNotMatchPool
        );
        assert!(position.pool_id() == pool_id, EDepositPositionPositionDoesNotMatchPool);
        assert!(
            !pool.position_manager().borrow_position_info(position_id).is_staked(),
            EDepositPositionPositionAlreadyStaked
        );
        let position_stake = PositionStakeInfo {
            from: sender,
            received: false,
        };
        gauge.staked_position_infos.add(position_id, position_stake);
        let (fee_a, fee_b) = clmm_pool::pool::collect_fee<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            &position,
            true
        );
        sui::transfer::public_transfer<sui::coin::Coin<CoinTypeA>>(
            sui::coin::from_balance<CoinTypeA>(fee_a, ctx),
            sender
        );
        sui::transfer::public_transfer<sui::coin::Coin<CoinTypeB>>(
            sui::coin::from_balance<CoinTypeB>(fee_b, ctx),
            sender
        );
        let (lower_tick, upper_tick) = position.tick_range();
        if (!gauge.stakes.contains(sender)) {
            let mut position_ids = std::vector::empty<sui::object::ID>();
            position_ids.push_back(position_id);
            gauge.stakes.add(sender, position_ids);
        } else {
            gauge.stakes.borrow_mut(sender).push_back(position_id);
        };
        let position_liquidity = position.liquidity();
        gauge.staked_positions.add(position_id, position);
        if (!gauge.rewards.contains(position_id)) {
            let new_reward_profile = RewardProfile {
                growth_inside: pool.get_magma_distribution_growth_inside(lower_tick, upper_tick, 0),
                amount: 0,
                last_update_time: clock.timestamp_ms() / 1000,
            };
            gauge.rewards.add(position_id, new_reward_profile);
        } else {
            let reward_profile = gauge.rewards.borrow_mut(position_id);
            reward_profile.growth_inside = pool.get_magma_distribution_growth_inside(lower_tick, upper_tick, 0);
            reward_profile.last_update_time = clock.timestamp_ms() / 1000;
        };
        pool.mark_position_staked(gauge.gauge_cap.borrow(), position_id);
        gauge.staked_position_infos.borrow_mut(position_id).received = true;
        pool.stake_in_magma_distribution(gauge.gauge_cap.borrow(), position_liquidity, lower_tick, upper_tick, clock);
        let deposit_gauge_event = EventDepositGauge {
            gauger_id: sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            pool_id,
            position_id,
        };
        sui::event::emit<EventDepositGauge>(deposit_gauge_event);
    }

    public fun earned_by_account<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        account: address,
        clock: &sui::clock::Clock
    ): u64 {
        assert!(
            gauge.check_gauger_pool(pool),
            EEarnedByAccountGaugeDoesNotMatchPool
        );
        let position_ids = gauge.stakes.borrow(account);
        let mut i = 0;
        let mut total_earned = 0;
        while (i < position_ids.length()) {
            total_earned = total_earned + gauge.earned_internal(pool, position_ids[i], clock.timestamp_ms() / 1000);
            i = i + 1;
        };
        total_earned
    }

    public fun earned_by_position<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock
    ): u64 {
        assert!(
            gauge.check_gauger_pool(pool),
            EEarnedByPositionGaugeDoesNotMatchPool
        );
        assert!(
            gauge.staked_positions.contains(position_id),
            EEarnedByPositionNotDepositedPosition
        );
        gauge.earned_internal(pool, position_id, clock.timestamp_ms() / 1000)
    }

    fun earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        time: u64
    ): u64 {
        let time_since_last_update = time - pool.get_magma_distribution_last_updated();
        let mut current_growth_global = pool.get_magma_distribution_growth_global();
        let distribution_reseve_x64 = (pool.get_magma_distribution_reserve() as u128) * 1 << 64;
        let staked_liquidity = pool.get_magma_distribution_staked_liquidity();
        let should_update_growth = if (time_since_last_update >= 0) {
            if (distribution_reseve_x64 > 0) {
                staked_liquidity > 0
            } else {
                false
            }
        } else {
            false
        };
        if (should_update_growth) {
            let mut potential_reward_amount = gauge.reward_rate * (time_since_last_update as u128);
            if (potential_reward_amount > distribution_reseve_x64) {
                potential_reward_amount = distribution_reseve_x64;
            };
            current_growth_global = current_growth_global + integer_mate::math_u128::checked_div_round(
                potential_reward_amount,
                staked_liquidity,
                false
            );
        };
        let position = gauge.staked_positions.borrow(position_id);
        let (lower_tick, upper_tick) = position.tick_range();
        integer_mate::full_math_u128::mul_div_floor(
            pool.get_magma_distribution_growth_inside(
                lower_tick,
                upper_tick,
                current_growth_global
            ) - gauge.rewards.borrow(position_id).growth_inside,
            position.liquidity(),
            1 << 64
        ) as u64
    }

    public fun get_position_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(
            gauge.check_gauger_pool(pool),
            EGetPositionRewardGaugeDoesNotMatchPool
        );
        assert!(
            gauge.staked_positions.contains(position_id),
            EGetPositionRewardPositionNotStaked
        );
        gauge.get_reward_internal(pool, position_id, clock, ctx);
    }

    public fun get_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(gauge.check_gauger_pool(pool), EGetRewardGaugeDoesNotMatchPool);
        let sender = sui::tx_context::sender(ctx);
        assert!(
            gauge.stakes.contains(sender),
            EGetRewardSenderHasNoDepositedPositions
        );
        let position_ids = gauge.stakes.borrow(sender);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < position_ids.length()) {
            position_ids_copy.push_back(position_ids[i]);
            i = i + 1;
        };
        let mut j = 0;
        while (j < position_ids_copy.length()) {
            gauge.get_reward_internal(pool, position_ids_copy[j], clock, ctx);
            j = j + 1;
        };
    }

    public fun get_reward_for<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(gauge.check_gauger_pool(pool), EGetRewardForGaugeDoesNotMatchPool);
        assert!(
            gauge.stakes.contains(recipient),
            EGetRewardForRecipientHasNoPositions
        );
        let position_ids = gauge.stakes.borrow(recipient);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < position_ids.length()) {
            position_ids_copy.push_back(position_ids[i]);
            i = i + 1;
        };
        let mut j = 0;
        while (j < position_ids_copy.length()) {
            gauge.get_reward_internal(pool, position_ids_copy[j], clock, ctx);
            j = j + 1;
        };
    }

    fun get_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (lower_tick, upper_tick) = gauge.staked_positions.borrow(position_id).tick_range();
        let reward = gauge.update_reward_internal(pool, position_id, lower_tick, upper_tick, clock);
        if (reward.value<SailCoinType>() > 0) {
            let position_owner = gauge.staked_position_infos.borrow(position_id).from;
            let amount = reward.value<SailCoinType>();
            sui::transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                sui::coin::from_balance<SailCoinType>(reward, ctx),
                position_owner
            );
            let claim_reward_event = EventClaimReward {
                from: sui::tx_context::sender(ctx),
                position_id,
                receiver: position_owner,
                amount,
            };
            sui::event::emit<EventClaimReward>(claim_reward_event);
        } else {
            reward.destroy_zero();
        };
    }

    public fun notify_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        balance: sui::balance::Balance<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        gauge.check_voter_cap(voter_cap);
        let amount = balance.value<SailCoinType>();
        assert!(amount > 0, ENontifyRewardInvalidAmount);
        gauge.reserves_balance.join<SailCoinType>(balance);
        let (fee_a, fee_b) = gauge.claim_fees_internal(pool);
        gauge.notify_reward_amount_internal(pool, amount, clock);
        let event_notify_reward = EventNotifyReward {
            sender: sui::object::id_from_address(sui::tx_context::sender(ctx)),
            amount,
        };
        sui::event::emit<EventNotifyReward>(event_notify_reward);
        (fee_a, fee_b)
    }

    fun notify_reward_amount_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        amount: u64,
        clock: &sui::clock::Clock
    ) {
        let current_time = clock.timestamp_ms() / 1000;
        let time_until_next_epoch = clmm_pool::config::epoch_next(current_time) - current_time;
        pool.update_magma_distribution_growth_global(gauge.gauge_cap.borrow(), clock);
        let next_epoch_time = current_time + time_until_next_epoch;
        let total_amount = amount + pool.get_magma_distribution_rollover();
        if (current_time >= gauge.period_finish) {
            gauge.reward_rate = integer_mate::full_math_u128::mul_div_floor(
                total_amount as u128,
                1 << 64,
                time_until_next_epoch as u128
            );
            pool.sync_magma_distribution_reward(
                gauge.gauge_cap.borrow(),
                gauge.reward_rate,
                gauge.reserves_balance.value<SailCoinType>(),
                next_epoch_time
            );
        } else {
            let future_rewards = integer_mate::full_math_u128::mul_div_floor(
                (time_until_next_epoch as u128),
                gauge.reward_rate,
                1 << 64
            );
            gauge.reward_rate = integer_mate::full_math_u128::mul_div_floor(
                (total_amount as u128) + future_rewards,
                1 << 64,
                time_until_next_epoch as u128
            );
            pool.sync_magma_distribution_reward(
                gauge.gauge_cap.borrow(),
                gauge.reward_rate,
                gauge.reserves_balance.value<SailCoinType>() + ((future_rewards / 1 << 64) as u64),
                next_epoch_time
            );
        };
        gauge.reward_rate_by_epoch.add(clmm_pool::config::epoch_start(current_time), gauge.reward_rate);
        assert!(gauge.reward_rate != 0, ENotifyRewardAmountRewardRateZero);
        assert!(
            gauge.reward_rate <= integer_mate::full_math_u128::mul_div_floor(
                gauge.reserves_balance.value<SailCoinType>() as u128,
                1 << 64,
                time_until_next_epoch as u128
            ),
            ENotifyRewardInsufficientReserves
        );
        gauge.period_finish = next_epoch_time;
        let notify_reward_event = EventNotifyReward {
            sender: *gauge.voter.borrow(),
            amount: total_amount,
        };
        sui::event::emit<EventNotifyReward>(notify_reward_event);
    }

    public fun notify_reward_without_claim<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        balance: sui::balance::Balance<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        gauge.check_voter_cap(voter_cap);
        let amount = balance.value<SailCoinType>();
        assert!(amount > 0, ENotifyRewardWithoutClaimInvalidAmount);
        gauge.reserves_balance.join<SailCoinType>(balance);
        gauge.notify_reward_amount_internal(pool, amount, clock);
        let notify_reward_event = EventNotifyReward {
            sender: sui::object::id_from_address(sui::tx_context::sender(ctx)),
            amount,
        };
        sui::event::emit<EventNotifyReward>(notify_reward_event);
    }

    public fun period_finish<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>
    ): u64 {
        gauge.period_finish
    }

    public(package) fun receive_gauge_cap<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        gauge_cap: gauge_cap::gauge_cap::GaugeCap
    ) {
        assert!(gauge.pool_id == gauge_cap.get_pool_id(), EReceiveGaugeCapGaugeDoesNotMatch);
        gauge.gauge_cap.fill(gauge_cap);
    }

    public fun reserves_balance<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>
    ): u64 {
        gauge.reserves_balance.value<SailCoinType>()
    }

    public fun reward_rate<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>
    ): u128 {
        gauge.reward_rate
    }

    public fun reward_rate_by_epoch_start<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        epoch_start_time: u64
    ): u128 {
        *gauge.reward_rate_by_epoch.borrow(epoch_start_time)
    }

    public(package) fun set_voter<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_id: sui::object::ID
    ) {
        gauge.voter.fill(voter_id);
        let gauge_set_voter_event = EventGaugeSetVoter {
            id: sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            voter_id,
        };
        sui::event::emit<EventGaugeSetVoter>(gauge_set_voter_event);
    }

    public fun stakes<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        owner: address
    ): vector<sui::object::ID> {
        let position_ids = gauge.stakes.borrow(owner);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < position_ids.length()) {
            position_ids_copy.push_back(position_ids[i]);
            i = i + 1;
        };
        position_ids_copy
    }

    fun update_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        lower_tick: integer_mate::i32::I32,
        upper_tick: integer_mate::i32::I32,
        clock: &sui::clock::Clock
    ): sui::balance::Balance<SailCoinType> {
        let current_time = clock.timestamp_ms() / 1000;
        let amount_earned = gauge.earned_internal(pool, position_id, current_time);
        let reward_profile = gauge.rewards.borrow_mut(position_id);
        if (reward_profile.last_update_time >= current_time) {
            reward_profile.amount = 0;
            return gauge.reserves_balance.split<SailCoinType>(reward_profile.amount)
        };
        pool.update_magma_distribution_growth_global(gauge.gauge_cap.borrow(), clock);
        reward_profile.last_update_time = current_time;
        reward_profile.amount = reward_profile.amount + amount_earned;
        reward_profile.growth_inside = pool.get_magma_distribution_growth_inside(lower_tick, upper_tick, 0);
        reward_profile.amount = 0;
        gauge.reserves_balance.split<SailCoinType>(reward_profile.amount)
    }

    public fun withdraw_position<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(
            gauge.staked_positions.contains(position_id) && gauge.staked_position_infos.contains(position_id),
            EWithdrawPositionNotDepositedPosition
        );
        if (gauge.earned_by_position(pool, position_id, clock) > 0) {
            gauge.get_position_reward(pool, position_id, clock, ctx)
        };
        let position_stake_info = gauge.staked_position_infos.remove(position_id);
        assert!(position_stake_info.received, EWithdrawPositionNotReceivedPosition);
        assert!(position_stake_info.from != sui::tx_context::sender(ctx), EWithdrawPositionNotOwnerOfPosition);
        if (position_stake_info.from != sui::tx_context::sender(ctx)) {
            gauge.staked_position_infos.add(position_id, position_stake_info);
        } else {
            let position = gauge.staked_positions.remove(position_id);
            let position_liquidity = position.liquidity();
            if (position_liquidity > 0) {
                let (lower_tick, upper_tick) = position.tick_range();
                pool.unstake_from_magma_distribution(
                    gauge.gauge_cap.borrow(),
                    position_liquidity,
                    lower_tick,
                    upper_tick,
                    clock
                );
            };
            pool.mark_position_unstaked(gauge.gauge_cap.borrow(), position_id);
            sui::transfer::public_transfer<clmm_pool::position::Position>(position, position_stake_info.from);
            let withdraw_position_event = EventWithdrawPosition {
                position_id,
                gauger_id: sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            };
            sui::event::emit<EventWithdrawPosition>(withdraw_position_event);
        };
    }
}


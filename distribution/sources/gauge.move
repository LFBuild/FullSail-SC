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
        ) || clmm_pool::pool::get_magma_distribution_gauger_id<CoinTypeA, CoinTypeB>(
            pool
        ) != sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(
            gauge
        )) && false || true
    }

    fun check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap
    ) {
        let voter_id = distribution::voter_cap::get_voter_id(voter_cap);
        assert!(&voter_id == std::option::borrow<sui::object::ID>(&gauge.voter), EInvalidVoter);
    }

    public fun claim_fees<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        _notify_reward_cap: &distribution::notify_reward_cap::NotifyRewardCap,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool)
    }

    fun claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): (sui::balance::Balance<CoinTypeA>, sui::balance::Balance<CoinTypeB>) {
        let weekCoinPerSecond = clmm_pool::config::week();
        let (fee_a, fee_b) = clmm_pool::pool::collect_magma_distribution_gauger_fees<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap)
        );
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
        sui::balance::destroy_zero<CoinTypeA>(fee_a);
        sui::balance::destroy_zero<CoinTypeB>(fee_b);
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
            sui::object::id<distribution::distribution_config::DistributionConfig>(distribution_config) == gauge.distribution_config,
            EDepositPositionDistributionConfInvalid
        );
        assert!(
            distribution::distribution_config::is_gauge_alive(
                distribution_config,
                sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge)
            ),
            EDepositPositionGaugeNotAlive
        );
        assert!(
            check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool),
            EDepositPositionGaugeDoesNotMatchPool
        );
        assert!(clmm_pool::position::pool_id(&position) == pool_id, EDepositPositionPositionDoesNotMatchPool);
        assert!(
            !clmm_pool::position::is_staked(
                clmm_pool::position::borrow_position_info(
                    clmm_pool::pool::position_manager<CoinTypeA, CoinTypeB>(pool),
                    position_id
                )
            ),
            EDepositPositionPositionAlreadyStaked
        );
        let position_stake = PositionStakeInfo {
            from: sender,
            received: false,
        };
        sui::table::add<sui::object::ID, PositionStakeInfo>(
            &mut gauge.staked_position_infos,
            position_id,
            position_stake
        );
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
        let (lower_tick, upper_tick) = clmm_pool::position::tick_range(&position);
        if (!sui::table::contains<address, vector<sui::object::ID>>(&gauge.stakes, sender)) {
            let mut position_ids = std::vector::empty<sui::object::ID>();
            std::vector::push_back<sui::object::ID>(&mut position_ids, position_id);
            sui::table::add<address, vector<sui::object::ID>>(&mut gauge.stakes, sender, position_ids);
        } else {
            std::vector::push_back<sui::object::ID>(
                sui::table::borrow_mut<address, vector<sui::object::ID>>(&mut gauge.stakes, sender),
                position_id
            );
        };
        let position_liquidity = clmm_pool::position::liquidity(&position);
        sui::object_table::add<sui::object::ID, clmm_pool::position::Position>(
            &mut gauge.staked_positions,
            position_id,
            position
        );
        if (!sui::table::contains<sui::object::ID, RewardProfile>(&gauge.rewards, position_id)) {
            let new_reward_profile = RewardProfile {
                growth_inside: clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                    pool,
                    lower_tick,
                    upper_tick,
                    0
                ),
                amount: 0,
                last_update_time: sui::clock::timestamp_ms(clock) / 1000,
            };
            sui::table::add<sui::object::ID, RewardProfile>(&mut gauge.rewards, position_id, new_reward_profile);
        } else {
            let reward_profile = sui::table::borrow_mut<sui::object::ID, RewardProfile>(
                &mut gauge.rewards,
                position_id
            );
            reward_profile.growth_inside = clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                pool,
                lower_tick,
                upper_tick,
                0
            );
            reward_profile.last_update_time = sui::clock::timestamp_ms(clock) / 1000;
        };
        clmm_pool::pool::mark_position_staked<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            position_id
        );
        sui::table::borrow_mut<sui::object::ID, PositionStakeInfo>(
            &mut gauge.staked_position_infos,
            position_id
        ).received = true;
        clmm_pool::pool::stake_in_magma_distribution<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            position_liquidity,
            lower_tick,
            upper_tick,
            clock
        );
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
            check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool),
            EEarnedByAccountGaugeDoesNotMatchPool
        );
        let position_ids = sui::table::borrow<address, vector<sui::object::ID>>(&gauge.stakes, account);
        let mut i = 0;
        let mut total_earned = 0;
        while (i < std::vector::length<sui::object::ID>(position_ids)) {
            total_earned = total_earned + earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
                gauge,
                pool,
                position_ids[i],
                sui::clock::timestamp_ms(clock) / 1000
            );
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
            check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool),
            EEarnedByPositionGaugeDoesNotMatchPool
        );
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(
                &gauge.staked_positions,
                position_id
            ),
            EEarnedByPositionNotDepositedPosition
        );
        earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
            gauge,
            pool,
            position_id,
            sui::clock::timestamp_ms(clock) / 1000
        )
    }

    fun earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: sui::object::ID,
        time: u64
    ): u64 {
        let time_since_last_update = time - clmm_pool::pool::get_magma_distribution_last_updated<CoinTypeA, CoinTypeB>(
            pool
        );
        let mut current_growth_global = clmm_pool::pool::get_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(
            pool
        );
        let distribution_reseve_x64 = (clmm_pool::pool::get_magma_distribution_reserve<CoinTypeA, CoinTypeB>(
            pool
        ) as u128) * 1 << 64;
        let staked_liquidity = clmm_pool::pool::get_magma_distribution_staked_liquidity<CoinTypeA, CoinTypeB>(pool);
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
        let position = sui::object_table::borrow<sui::object::ID, clmm_pool::position::Position>(
            &gauge.staked_positions,
            position_id
        );
        let (lower_tick, upper_tick) = clmm_pool::position::tick_range(position);
        integer_mate::full_math_u128::mul_div_floor(
            clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
                pool,
                lower_tick,
                upper_tick,
                current_growth_global
            ) - sui::table::borrow<sui::object::ID, RewardProfile>(
                &gauge.rewards,
                position_id
            ).growth_inside,
            clmm_pool::position::liquidity(position),
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
            check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool),
            EGetPositionRewardGaugeDoesNotMatchPool
        );
        assert!(
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(
                &gauge.staked_positions,
                position_id
            ),
            EGetPositionRewardPositionNotStaked
        );
        get_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, position_id, clock, ctx);
    }

    public fun get_reward<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool), EGetRewardGaugeDoesNotMatchPool);
        let sender = sui::tx_context::sender(ctx);
        assert!(
            sui::table::contains<address, vector<sui::object::ID>>(&gauge.stakes, sender),
            EGetRewardSenderHasNoDepositedPositions
        );
        let position_ids = sui::table::borrow<address, vector<sui::object::ID>>(&gauge.stakes, sender);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < std::vector::length<sui::object::ID>(position_ids)) {
            std::vector::push_back<sui::object::ID>(&mut position_ids_copy, position_ids[i]);
            i = i + 1;
        };
        let mut j = 0;
        while (j < std::vector::length<sui::object::ID>(&position_ids_copy)) {
            get_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(
                gauge,
                pool,
                position_ids_copy[j],
                clock,
                ctx
            );
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
        assert!(check_gauger_pool<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool), EGetRewardForGaugeDoesNotMatchPool);
        assert!(
            sui::table::contains<address, vector<sui::object::ID>>(&gauge.stakes, recipient),
            EGetRewardForRecipientHasNoPositions
        );
        let position_ids = sui::table::borrow<address, vector<sui::object::ID>>(&gauge.stakes, recipient);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < std::vector::length<sui::object::ID>(position_ids)) {
            std::vector::push_back<sui::object::ID>(&mut position_ids_copy, position_ids[i]);
            i = i + 1;
        };
        let mut j = 0;
        while (j < std::vector::length<sui::object::ID>(&position_ids_copy)) {
            get_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(
                gauge,
                pool,
                position_ids_copy[j],
                clock,
                ctx
            );
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
        let (lower_tick, upper_tick) = clmm_pool::position::tick_range(
            sui::object_table::borrow<sui::object::ID, clmm_pool::position::Position>(
                &gauge.staked_positions,
                position_id
            )
        );
        let reward = update_reward_internal<CoinTypeA, CoinTypeB, SailCoinType>(
            gauge,
            pool,
            position_id,
            lower_tick,
            upper_tick,
            clock
        );
        if (reward.value<SailCoinType>() > 0) {
            let position_owner = sui::table::borrow<sui::object::ID, PositionStakeInfo>(
                &gauge.staked_position_infos,
                position_id
            ).from;
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
            sui::balance::destroy_zero<SailCoinType>(reward);
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
        check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(gauge, voter_cap);
        let amount = balance.value<SailCoinType>();
        assert!(amount > 0, ENontifyRewardInvalidAmount);
        gauge.reserves_balance.join<SailCoinType>(balance);
        let (fee_a, fee_b) = claim_fees_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool);
        notify_reward_amount_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, amount, clock);
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
        let current_time = sui::clock::timestamp_ms(clock) / 1000;
        let time_until_next_epoch = clmm_pool::config::epoch_next(current_time) - current_time;
        clmm_pool::pool::update_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            clock
        );
        let next_epoch_time = current_time + time_until_next_epoch;
        let total_amount = amount + clmm_pool::pool::get_magma_distribution_rollover<CoinTypeA, CoinTypeB>(pool);
        if (current_time >= gauge.period_finish) {
            gauge.reward_rate = integer_mate::full_math_u128::mul_div_floor(
                total_amount as u128,
                1 << 64,
                time_until_next_epoch as u128
            );
            clmm_pool::pool::sync_magma_distribution_reward<CoinTypeA, CoinTypeB>(
                pool,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
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
            clmm_pool::pool::sync_magma_distribution_reward<CoinTypeA, CoinTypeB>(
                pool,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
                gauge.reward_rate,
                gauge.reserves_balance.value<SailCoinType>() + ((future_rewards / 1 << 64) as u64),
                next_epoch_time
            );
        };
        sui::table::add<u64, u128>(
            &mut gauge.reward_rate_by_epoch,
            clmm_pool::config::epoch_start(current_time),
            gauge.reward_rate
        );
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
            sender: *std::option::borrow<sui::object::ID>(&gauge.voter),
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
        check_voter_cap<CoinTypeA, CoinTypeB, SailCoinType>(gauge, voter_cap);
        let amount = balance.value<SailCoinType>();
        assert!(amount > 0, ENotifyRewardWithoutClaimInvalidAmount);
        gauge.reserves_balance.join<SailCoinType>(balance);
        notify_reward_amount_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, amount, clock);
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
        assert!(gauge.pool_id == gauge_cap::gauge_cap::get_pool_id(&gauge_cap), EReceiveGaugeCapGaugeDoesNotMatch);
        std::option::fill<gauge_cap::gauge_cap::GaugeCap>(&mut gauge.gauge_cap, gauge_cap);
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
        *sui::table::borrow<u64, u128>(&gauge.reward_rate_by_epoch, epoch_start_time)
    }

    public(package) fun set_voter<CoinTypeA, CoinTypeB, SailCoinType>(
        gauge: &mut Gauge<CoinTypeA, CoinTypeB, SailCoinType>,
        voter_id: sui::object::ID
    ) {
        std::option::fill<sui::object::ID>(&mut gauge.voter, voter_id);
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
        let position_ids = sui::table::borrow<address, vector<sui::object::ID>>(&gauge.stakes, owner);
        let mut position_ids_copy = std::vector::empty<sui::object::ID>();
        let mut i = 0;
        while (i < std::vector::length<sui::object::ID>(position_ids)) {
            std::vector::push_back<sui::object::ID>(&mut position_ids_copy, position_ids[i]);
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
        let current_time = sui::clock::timestamp_ms(clock) / 1000;
        let amount_earned = earned_internal<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, position_id, current_time);
        let reward_profile = sui::table::borrow_mut<sui::object::ID, RewardProfile>(&mut gauge.rewards, position_id);
        if (reward_profile.last_update_time >= current_time) {
            reward_profile.amount = 0;
            return gauge.reserves_balance.split<SailCoinType>(reward_profile.amount)
        };
        clmm_pool::pool::update_magma_distribution_growth_global<CoinTypeA, CoinTypeB>(
            pool,
            std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
            clock
        );
        reward_profile.last_update_time = current_time;
        reward_profile.amount = reward_profile.amount + amount_earned;
        reward_profile.growth_inside = clmm_pool::pool::get_magma_distribution_growth_inside<CoinTypeA, CoinTypeB>(
            pool, lower_tick, upper_tick, 0);
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
            sui::object_table::contains<sui::object::ID, clmm_pool::position::Position>(
                &gauge.staked_positions,
                position_id
            ) && sui::table::contains<sui::object::ID, PositionStakeInfo>(&gauge.staked_position_infos, position_id),
            EWithdrawPositionNotDepositedPosition
        );
        if (earned_by_position<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, position_id, clock) > 0) {
            get_position_reward<CoinTypeA, CoinTypeB, SailCoinType>(gauge, pool, position_id, clock, ctx)
        };
        let position_stake_info = sui::table::remove<sui::object::ID, PositionStakeInfo>(
            &mut gauge.staked_position_infos,
            position_id
        );
        assert!(position_stake_info.received, EWithdrawPositionNotReceivedPosition);
        assert!(position_stake_info.from != sui::tx_context::sender(ctx), EWithdrawPositionNotOwnerOfPosition);
        if (position_stake_info.from != sui::tx_context::sender(ctx)) {
            sui::table::add<sui::object::ID, PositionStakeInfo>(
                &mut gauge.staked_position_infos,
                position_id,
                position_stake_info
            );
        } else {
            let position = sui::object_table::remove<sui::object::ID, clmm_pool::position::Position>(
                &mut gauge.staked_positions,
                position_id
            );
            let position_liquidity = clmm_pool::position::liquidity(&position);
            if (position_liquidity > 0) {
                let (lower_tick, upper_tick) = clmm_pool::position::tick_range(&position);
                clmm_pool::pool::unstake_from_magma_distribution<CoinTypeA, CoinTypeB>(
                    pool,
                    std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
                    position_liquidity,
                    lower_tick,
                    upper_tick,
                    clock
                );
            };
            clmm_pool::pool::mark_position_unstaked<CoinTypeA, CoinTypeB>(
                pool,
                std::option::borrow<gauge_cap::gauge_cap::GaugeCap>(&gauge.gauge_cap),
                position_id
            );
            sui::transfer::public_transfer<clmm_pool::position::Position>(position, position_stake_info.from);
            let withdraw_position_event = EventWithdrawPosition {
                position_id,
                gauger_id: sui::object::id<Gauge<CoinTypeA, CoinTypeB, SailCoinType>>(gauge),
            };
            sui::event::emit<EventWithdrawPosition>(withdraw_position_event);
        };
    }
}


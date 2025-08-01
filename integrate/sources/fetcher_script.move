module integrate::fetcher_script {
    public struct FetchTicksResultEvent has copy, drop, store {
        ticks: vector<clmm_pool::tick::Tick>,
    }

    public struct CalculatedSwapResultEvent has copy, drop, store {
        data: clmm_pool::pool::CalculatedSwapResult,
    }

    public struct FetchPositionsEvent has copy, drop, store {
        positions: vector<clmm_pool::position::PositionInfo>,
    }

    public struct FetchPoolsEvent has copy, drop, store {
        pools: vector<clmm_pool::factory::PoolSimpleInfo>,
    }

    public struct FetchPositionRewardsEvent has copy, drop, store {
        data: vector<u64>,
        position_id: ID,
    }

    public struct FetchPositionFeesEvent has copy, drop, store {
        position_id: ID,
        fee_owned_a: u64,
        fee_owned_b: u64,
    }

    public struct FetchPositionPointsEvent has copy, drop, store {
        position_id: ID,
        points_owned: u128,
    }

    public struct FetchPositionFullsailDistributionEvent has copy, drop, store {
        position_id: ID,
        distribution: u64,
    }

    public entry fun fetch_pools(pools: &clmm_pool::factory::Pools, pool_ids: std::option::Option<ID>, limit: u64) {
        let fetched_pools = clmm_pool::factory::fetch_pools(pools, pool_ids, limit);
        let fetch_pools_event = FetchPoolsEvent { pools: fetched_pools, };
        sui::event::emit<FetchPoolsEvent>(fetch_pools_event);
    }

    public entry fun calculate_swap_result<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64
    ) {
        let data = clmm_pool::pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            a2b,
            by_amount_in,
            amount
        );
        let calculate_result_event = CalculatedSwapResultEvent { data };
        sui::event::emit<CalculatedSwapResultEvent>(calculate_result_event);
    }

    public entry fun fetch_positions<CoinTypeA, CoinTypeB>(
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_ids: std::option::Option<ID>,
        limit: u64
    ) {
        let positions = clmm_pool::pool::fetch_positions<CoinTypeA, CoinTypeB>(pool, position_ids, limit);
        let v0 = FetchPositionsEvent { positions };
        sui::event::emit<FetchPositionsEvent>(v0);
    }

    public entry fun fetch_ticks<CoinTypeA, CoinTypeB>(
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        tick_indices: std::option::Option<u32>,
        limit: u64
    ) {
        let ticks = clmm_pool::pool::fetch_ticks<CoinTypeA, CoinTypeB>(pool, tick_indices, limit);
        let fetch_ticks_event = FetchTicksResultEvent { ticks };
        sui::event::emit<FetchTicksResultEvent>(fetch_ticks_event);
    }

    public entry fun fetch_position_fees<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID
    ) {
        let (fee_owned_a, fee_owned_b) = clmm_pool::pool::calculate_and_update_fee<CoinTypeA, CoinTypeB>(global_config, pool, position_id);
        let fetch_position_fees_event = FetchPositionFeesEvent {
            position_id,
            fee_owned_a,
            fee_owned_b,
        };
        sui::event::emit<FetchPositionFeesEvent>(fetch_position_fees_event);
    }

    public entry fun fetch_position_fullsail_distribution<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID
    ) {
        let distribution = clmm_pool::pool::calculate_and_update_fullsail_distribution<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position_id
        );
        let fetch_position_distribution_event = FetchPositionFullsailDistributionEvent {
            position_id,
            distribution,
        };
        sui::event::emit<FetchPositionFullsailDistributionEvent>(fetch_position_distribution_event);
    }

    public entry fun fetch_position_points<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID,
        clock: &sui::clock::Clock
    ) {
        let points_owned = clmm_pool::pool::calculate_and_update_points<CoinTypeA, CoinTypeB>(global_config, vault, pool, position_id, clock);
        let fetch_position_points_event = FetchPositionPointsEvent {
            position_id,
            points_owned,
        };
        sui::event::emit<FetchPositionPointsEvent>(fetch_position_points_event);
    }

    public entry fun fetch_position_rewards<CoinTypeA, CoinTypeB>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut clmm_pool::rewarder::RewarderGlobalVault,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID,
        clock: &sui::clock::Clock
    ) {
        let data = clmm_pool::pool::calculate_and_update_rewards<CoinTypeA, CoinTypeB>(global_config, vault, pool, position_id, clock);
        let fetch_position_rewards_event = FetchPositionRewardsEvent {
            data,
            position_id,
        };
        sui::event::emit<FetchPositionRewardsEvent>(fetch_position_rewards_event);
    }
}


module integrate::fetcher_script {
    struct FetchTicksResultEvent has copy, drop, store {
        ticks: vector<clmm_pool::tick::Tick>,
    }
    
    struct CalculatedSwapResultEvent has copy, drop, store {
        data: clmm_pool::pool::CalculatedSwapResult,
    }
    
    struct FetchPositionsEvent has copy, drop, store {
        positions: vector<clmm_pool::position::PositionInfo>,
    }
    
    struct FetchPoolsEvent has copy, drop, store {
        pools: vector<clmm_pool::factory::PoolSimpleInfo>,
    }
    
    struct FetchPositionRewardsEvent has copy, drop, store {
        data: vector<u64>,
        position_id: sui::object::ID,
    }
    
    struct FetchPositionFeesEvent has copy, drop, store {
        position_id: sui::object::ID,
        fee_owned_a: u64,
        fee_owned_b: u64,
    }
    
    struct FetchPositionPointsEvent has copy, drop, store {
        position_id: sui::object::ID,
        points_owned: u128,
    }
    
    struct FetchPositionMagmaDistributionEvent has copy, drop, store {
        position_id: sui::object::ID,
        distribution: u64,
    }
    
    public entry fun fetch_pools(arg0: &clmm_pool::factory::Pools, arg1: vector<sui::object::ID>, arg2: u64) {
        let v0 = FetchPoolsEvent{pools: clmm_pool::factory::fetch_pools(arg0, arg1, arg2)};
        sui::event::emit<FetchPoolsEvent>(v0);
    }
    
    public entry fun calculate_swap_result<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &clmm_pool::pool::Pool<T0, T1>, arg2: bool, arg3: bool, arg4: u64) {
        let v0 = CalculatedSwapResultEvent{data: clmm_pool::pool::calculate_swap_result<T0, T1>(arg0, arg1, arg2, arg3, arg4)};
        sui::event::emit<CalculatedSwapResultEvent>(v0);
    }
    
    public entry fun fetch_positions<T0, T1>(arg0: &clmm_pool::pool::Pool<T0, T1>, arg1: vector<sui::object::ID>, arg2: u64) {
        let v0 = FetchPositionsEvent{positions: clmm_pool::pool::fetch_positions<T0, T1>(arg0, arg1, arg2)};
        sui::event::emit<FetchPositionsEvent>(v0);
    }
    
    public entry fun fetch_ticks<T0, T1>(arg0: &clmm_pool::pool::Pool<T0, T1>, arg1: vector<u32>, arg2: u64) {
        let v0 = FetchTicksResultEvent{ticks: clmm_pool::pool::fetch_ticks<T0, T1>(arg0, arg1, arg2)};
        sui::event::emit<FetchTicksResultEvent>(v0);
    }
    
    public entry fun fetch_position_fees<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: sui::object::ID) {
        let (v0, v1) = clmm_pool::pool::calculate_and_update_fee<T0, T1>(arg0, arg1, arg2);
        let v2 = FetchPositionFeesEvent{
            position_id : arg2, 
            fee_owned_a : v0, 
            fee_owned_b : v1,
        };
        sui::event::emit<FetchPositionFeesEvent>(v2);
    }
    
    public entry fun fetch_position_magma_distribution<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: sui::object::ID, arg3: &sui::clock::Clock) {
        let v0 = FetchPositionMagmaDistributionEvent{
            position_id  : arg2, 
            distribution : clmm_pool::pool::calculate_and_update_magma_distribution<T0, T1>(arg0, arg1, arg2),
        };
        sui::event::emit<FetchPositionMagmaDistributionEvent>(v0);
    }
    
    public entry fun fetch_position_points<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: sui::object::ID, arg3: &sui::clock::Clock) {
        let v0 = FetchPositionPointsEvent{
            position_id  : arg2, 
            points_owned : clmm_pool::pool::calculate_and_update_points<T0, T1>(arg0, arg1, arg2, arg3),
        };
        sui::event::emit<FetchPositionPointsEvent>(v0);
    }
    
    public entry fun fetch_position_rewards<T0, T1>(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: sui::object::ID, arg3: &sui::clock::Clock) {
        let v0 = FetchPositionRewardsEvent{
            data        : clmm_pool::pool::calculate_and_update_rewards<T0, T1>(arg0, arg1, arg2, arg3), 
            position_id : arg2,
        };
        sui::event::emit<FetchPositionRewardsEvent>(v0);
    }
    
    // decompiled from Move bytecode v6
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
/// 
/// The price_monitor module provides comprehensive protection against oracle compromise
/// through multi-layered anomaly detection and automatic circuit breaker activation.
/// 
/// Core Features:
/// - Multi-Oracle Validation: Compares external oracle prices with internal pool prices
/// - Statistical Anomaly Detection: Analyzes historical price data for anomalies
/// - Circuit Breaker System: Automatically activates protection mechanisms
/// - Real-time monitoring and alerting for security threats
module price_monitor::price_monitor {

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::linked_table::{Self, LinkedTable};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    use switchboard::decimal::{Self, Decimal};
    use switchboard::aggregator::{Self, Aggregator};
    use integer_mate::full_math_u128;
    use integer_mate::math_u128;
    use price_monitor::price_monitor_consts;



    // ===== ERROR CODES =====

    const EInvalidPriceMonitorConfig: u64 = 1001;
    const EPriceHistoryEmpty: u64 = 1002;
    const EInsufficientPriceHistory: u64 = 1003;
    const EInvalidDeviationCalculation: u64 = 1004;
    const EInvalidZScoreCalculation: u64 = 1005;
    const EPriceMonitorAlreadyPaused: u64 = 1006;
    const EPriceMonitorNotPaused: u64 = 1007;
    const EInvalidGaugeCap: u64 = 1008;
    const EInvalidSailPool: u64 = 1009;
    const EInvalidAggregator: u64 = 1010;
    const EZeroPrice: u64 = 1011;

    const EDecimalToQ64NegativeNotSupported: u64 = 440708559177319000;
    const EGetTimeCheckedPriceOutdated: u64 = 286529906002696900;
    const EGetTimeCheckedPriceNegativePrice: u64 = 986261309772136700;

    // ===== STRUCTURES =====

    /// Configuration for price monitoring thresholds and behavior
    public struct PriceMonitorConfig has store, drop {

        // Multi-Oracle validation thresholds (in basis points)
        warning_deviation_bps: u64,
        critical_deviation_bps: u64,
        emergency_deviation_bps: u64,
        
        // Statistical analysis thresholds (Z-Score * 100)
        warning_zscore_threshold: u64,
        critical_zscore_threshold: u64,
        emergency_zscore_threshold: u64,
        
        // Circuit breaker thresholds
        warning_anomaly_threshold: u64,
        critical_anomaly_threshold: u64,
        emergency_anomaly_threshold: u64,
        
        // Time-based configuration
        anomaly_cooldown_period_ms: u64,
        max_price_age_ms: u64,
        
        // History configuration
        max_price_history_size: u64,
        min_prices_for_analysis: u64,
    }

    /// Individual price point with metadata
    public struct PricePoint has store, drop, copy {
        oracle_price_q64: u128,      // Price from external oracle in Q64.64 format
        pool_price_q64: u128,        // Price from internal pool in Q64.64 format
        deviation_bps: u64,          // Deviation in basis points
        z_score: u128,                // Z-Score * 10000 (scaled by BASIS_POINTS_DENOMINATOR)
        timestamp_ms: u64,           // Timestamp in milliseconds
        anomaly_level: u8,           // 0=none, 1=warning, 2=critical, 3=emergency
        anomaly_flags: u8,           // Bit flags for anomaly types
    }

    /// Main price monitor instance
    public struct PriceMonitor has store, key {
        id: UID,
        
        // Configuration
        config: PriceMonitorConfig,
        
        // Oracle to pools mapping
        aggregator_to_pools: Table<ID, vector<ID>>,
        
        // Price history as a linked table for efficient FIFO operations
        price_history: LinkedTable<u64, PricePoint>, // timestamp -> price_point
        max_history_size: u64,
        
        // Anomaly tracking
        anomaly_count: u64,
        consecutive_anomalies: u64,
        
        // Circuit breaker state
        is_emergency_paused: bool,
        pause_timestamp_ms: u64,
        pause_reason: vector<u8>,
        pause_level: u8,             // 0=none, 1=warning, 2=critical, 3=emergency
        last_anomaly_timestamp_ms: u64,
    }

    /// Capability for managing price monitor
    public struct PriceMonitorCap has store, key {
        id: UID,
        monitor_id: ID,
    }

    /// Capability for emergency operations
    public struct EmergencyCap has store, key {
        id: UID,
        monitor_id: ID,
    }

    // ===== EVENTS =====

    /// Event emitted when price anomaly is detected
    public struct EventPriceAnomalyDetected has copy, drop, store {
        monitor_id: ID,
        oracle_price_q64: u128,
        pool_price_q64: u128,
        deviation_bps: u64,
        z_score: u128,
        anomaly_level: u8,
        timestamp_ms: u64,
    }

    /// Event emitted when circuit breaker is activated
    public struct EventCircuitBreakerActivated has copy, drop, store {
        monitor_id: ID,
        level: u8,                   // 1=warning, 2=critical, 3=emergency
        reason: vector<u8>,
        timestamp_ms: u64,
    }

    /// Event emitted when circuit breaker is deactivated
    public struct EventCircuitBreakerDeactivated has copy, drop, store {
        monitor_id: ID,
        level: u8,
        timestamp_ms: u64,
    }

    /// Event emitted when price history is updated
    public struct EventPriceHistoryUpdated has copy, drop, store {
        monitor_id: ID,
        history_length: u64,
        timestamp_ms: u64,
    }

    // ===== INITIALIZATION =====

    /// Initialize the price monitor module
    fun init(ctx: &mut TxContext) {
        let config = PriceMonitorConfig {
            warning_deviation_bps: price_monitor_consts::get_warning_deviation_bps(),
            critical_deviation_bps: price_monitor_consts::get_critical_deviation_bps(),
            emergency_deviation_bps: price_monitor_consts::get_emergency_deviation_bps(),
            warning_zscore_threshold: price_monitor_consts::get_warning_zscore_threshold(),
            critical_zscore_threshold: price_monitor_consts::get_critical_zscore_threshold(),
            emergency_zscore_threshold: price_monitor_consts::get_emergency_zscore_threshold(),
            warning_anomaly_threshold: price_monitor_consts::get_warning_anomaly_threshold(),
            critical_anomaly_threshold: price_monitor_consts::get_critical_anomaly_threshold(),
            emergency_anomaly_threshold: price_monitor_consts::get_emergency_anomaly_threshold(),
            anomaly_cooldown_period_ms: price_monitor_consts::get_anomaly_cooldown_period_ms(),
            max_price_age_ms: price_monitor_consts::get_max_price_age_ms(),
            max_price_history_size: price_monitor_consts::get_max_price_history_size(),
            min_prices_for_analysis: price_monitor_consts::get_min_prices_for_analysis(),
        };

        let monitor = PriceMonitor {
            id: object::new(ctx),
            config,
            aggregator_to_pools: table::new(ctx),
            price_history: linked_table::new(ctx),
            max_history_size: price_monitor_consts::get_max_price_history_size(),
            anomaly_count: 0,
            last_anomaly_timestamp_ms: 0,
            consecutive_anomalies: 0,
            is_emergency_paused: false,
            pause_timestamp_ms: 0,
            pause_reason: vector::empty<u8>(),
            pause_level: 0,

        };

        let monitor_cap = PriceMonitorCap {
            id: object::new(ctx),
            monitor_id: object::id(&monitor),
        };

        transfer::transfer<PriceMonitorCap>(monitor_cap, sui::tx_context::sender(ctx));

        let emergency_cap = EmergencyCap {
            id: object::new(ctx),
            monitor_id: object::id(&monitor),
        };

        transfer::transfer<EmergencyCap>(emergency_cap, sui::tx_context::sender(ctx));

        transfer::share_object<PriceMonitor>(monitor);
    }

    // ===== AGGREGATOR MANAGEMENT =====

    /// Add an aggregator with associated pools
    public fun add_aggregator(
        monitor: &mut PriceMonitor,
        _cap: &PriceMonitorCap,
        aggregator_id: ID,
        pool_ids: vector<ID>,
    ) {
        monitor.aggregator_to_pools.add(aggregator_id, pool_ids);
    }

    /// Remove an aggregator and its associated pools
    public fun remove_aggregator(
        monitor: &mut PriceMonitor,
        _cap: &PriceMonitorCap,
        aggregator_id: ID,
    ) {
        monitor.aggregator_to_pools.remove(aggregator_id);
    }

    /// Add a pool to an existing aggregator
    public fun add_pool_to_aggregator(
        monitor: &mut PriceMonitor,
        _cap: &PriceMonitorCap,
        aggregator_id: ID,
        pool_id: ID,
    ) {
        assert!(monitor.aggregator_to_pools.contains(aggregator_id), EInvalidAggregator);
        // Check if pool is already associated with this aggregator
        assert!(!is_pool_associated_with_aggregator(monitor, aggregator_id, pool_id), EInvalidSailPool);
        let pools = monitor.aggregator_to_pools.borrow_mut(aggregator_id);
        pools.push_back(pool_id);
    }

    /// Remove a pool from an aggregator
    public fun remove_pool_from_aggregator(
        monitor: &mut PriceMonitor,
        _cap: &PriceMonitorCap,
        aggregator_id: ID,
        pool_id: ID,
    ) {
        assert!(monitor.aggregator_to_pools.contains(aggregator_id), EInvalidAggregator);
        assert!(is_pool_associated_with_aggregator(monitor, aggregator_id, pool_id), EInvalidSailPool);
        let pools = monitor.aggregator_to_pools.borrow_mut(aggregator_id);
        let mut i = 0;
        let pools_len = pools.length();
        while (i < pools_len) {
            if (*pools.borrow(i) == pool_id) {
                pools.remove(i);
                break
            };
            i = i + 1;
        };
    }

    // ===== CONFIGURATION MANAGEMENT =====

    /// Update price monitor configuration
    public fun update_config(
        monitor: &mut PriceMonitor,
        _cap: &PriceMonitorCap,
        new_config: PriceMonitorConfig,
    ) {
        monitor.config = new_config;
    }

    /// Get current configuration
    public fun get_config(monitor: &PriceMonitor): &PriceMonitorConfig {
        &monitor.config
    }


    // ===== CORE PRICE MONITORING FUNCTIONS =====

    /// Main function to validate and monitor prices
    /// This is the primary entry point for price validation
    public fun validate_price<CoinTypeA, CoinTypeB>(
        monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &Clock,
    ): PriceValidationResult {
        let aggregator_id = object::id(aggregator);
        let pool_id = object::id(sail_stablecoin_pool);
        
        // Check if pool is associated with this aggregator
        assert!(is_pool_associated_with_aggregator(monitor, aggregator_id, pool_id), EInvalidSailPool);

        let current_time_ms = clock::timestamp_ms(clock);

        let oracle_price_q64 = get_time_checked_price_q64(
            aggregator,
            price_monitor_consts::get_sail_decimals(),
            price_monitor_consts::get_usd_decimals(),
            clock
        );

        let sqrt_price = sail_stablecoin_pool.current_sqrt_price();
        let pool_price_q64 = (integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price) >> 64) as u128;
        assert!(pool_price_q64 > 0, EZeroPrice);

        // 1. Multi-Oracle Validation
        let deviation_result = validate_oracle_pool_deviation(
            monitor,
            oracle_price_q64,
            pool_price_q64
        );
        
        // 2. Statistical Anomaly Detection
        let statistical_result = validate_statistical_anomaly(
            monitor,
            oracle_price_q64
        );
        
        // 3. Update price history
        let price_point = create_price_point(
            oracle_price_q64,
            pool_price_q64,
            deviation_result.deviation_bps,
            statistical_result.z_score,
            current_time_ms,
            deviation_result.anomaly_level,
            deviation_result.anomaly_flags
        );
        
        add_price_to_history(monitor, price_point);
        
        // 4. Circuit Breaker Logic
        let circuit_breaker_result = evaluate_circuit_breaker(
            monitor,
            &deviation_result,
            &statistical_result,
            current_time_ms
        );
        
        // 5. Store values before moving variables
        let deviation_bps = deviation_result.deviation_bps;
        let z_score = statistical_result.z_score;
        let circuit_level = circuit_breaker_result.level;
        let circuit_recommendation = circuit_breaker_result.recommendation;
        
        // 6. Emit events
        emit_validation_events(
            monitor, 
            &deviation_result, 
            &statistical_result, 
            &circuit_breaker_result,
            oracle_price_q64,
            pool_price_q64,
            current_time_ms
        );
        
        // 7. Update monitor state
        update_monitor_state(monitor, circuit_breaker_result, current_time_ms);
        
        PriceValidationResult {
            should_return: circuit_level < price_monitor_consts::get_anomaly_level_emergency(), // Level 3 = Emergency
            price_q64: oracle_price_q64,
        }
    }

    /// Check if a pool is associated with a specific aggregator
    public fun is_pool_associated_with_aggregator(
        monitor: &PriceMonitor,
        aggregator_id: ID,
        pool_id: ID,
    ): bool {
        if (!monitor.aggregator_to_pools.contains(aggregator_id)) {
            return false
        };
        
        let pools = monitor.aggregator_to_pools.borrow(aggregator_id);
        let mut i = 0;
        let pools_len = pools.length();
        while (i < pools_len) {
            if (*pools.borrow(i) == pool_id) {
                return true
            };
            i = i + 1;
        };
        
        false
    }

    // ===== MULTI-ORACLE VALIDATION =====

    /// Validate deviation between oracle and pool prices
    fun validate_oracle_pool_deviation(
        monitor: &PriceMonitor,
        oracle_price_q64: u128,
        pool_price_q64: u128,
    ): DeviationValidationResult {
        let deviation_bps = calculate_deviation_bps(oracle_price_q64, pool_price_q64);
        
        let anomaly_level = if (deviation_bps >= monitor.config.emergency_deviation_bps) {
            price_monitor_consts::get_anomaly_level_emergency()
        } else if (deviation_bps >= monitor.config.critical_deviation_bps) {
            price_monitor_consts::get_anomaly_level_critical()
        } else if (deviation_bps >= monitor.config.warning_deviation_bps) {
            price_monitor_consts::get_anomaly_level_warning()
        } else {
            price_monitor_consts::get_anomaly_level_normal()
        };
        
        let anomaly_flags = if (anomaly_level > price_monitor_consts::get_anomaly_level_normal()) { 
            price_monitor_consts::get_anomaly_flag_deviation() 
        } else { 
            price_monitor_consts::get_anomaly_flag_none()
        };
        
        DeviationValidationResult {
            deviation_bps,
            anomaly_level,
            anomaly_flags,
        }
    }

    /// Calculate deviation between two prices in basis points
    fun calculate_deviation_bps(price1_q64: u128, base_price_q64: u128): u64 {
        if (base_price_q64 == 0) return 0;
        
        let deviation = if (price1_q64 > base_price_q64) {
            price1_q64 - base_price_q64
        } else {
            base_price_q64 - price1_q64
        };
        
        // Convert to basis points: (deviation * BASIS_POINTS_DENOMINATOR) / base_price_q64
        let deviation_bps = full_math_u128::mul_div_floor(
            deviation,
            (price_monitor_consts::get_basis_points_denominator() as u128),
            base_price_q64
        );
        
        (deviation_bps as u64)
    }

    // ===== STATISTICAL ANOMALY DETECTION =====

    /// Validate price using statistical analysis
    fun validate_statistical_anomaly(
        monitor: &PriceMonitor,
        oracle_price_q64: u128,
    ): StatisticalValidationResult {
        let history_length = monitor.price_history.length();
        if (history_length < monitor.config.min_prices_for_analysis) {
            return StatisticalValidationResult {
                z_score: 0,
                anomaly_level: 0,
                anomaly_flags: 0,
            }
        };
        
        let (mean_price, std_dev) = calculate_price_statistics(monitor);
        
        if (std_dev == 0) {
            return StatisticalValidationResult {
                z_score: 0,
                anomaly_level: 0,
                anomaly_flags: 0,
            }
        };
        
        let z_score = calculate_z_score(oracle_price_q64, mean_price, std_dev);
        // z_score is already scaled by BASIS_POINTS_DENOMINATOR (10000)
        // No need for additional scaling
        
        let anomaly_level = if (z_score >= (monitor.config.emergency_zscore_threshold as u128)) {
            price_monitor_consts::get_anomaly_level_emergency()
        } else if (z_score >= (monitor.config.critical_zscore_threshold as u128)) {
            price_monitor_consts::get_anomaly_level_critical()
        } else if (z_score >= (monitor.config.warning_zscore_threshold as u128)) {
            price_monitor_consts::get_anomaly_level_warning()
        } else {
            price_monitor_consts::get_anomaly_level_normal()
        };
        
        let anomaly_flags = if (anomaly_level > 0) {
            price_monitor_consts::get_anomaly_flag_statistical()
        } else {
            price_monitor_consts::get_anomaly_flag_none()
        };
        
        StatisticalValidationResult {
            z_score,
            anomaly_level,
            anomaly_flags,
        }
    }

    /// Calculate mean and standard deviation of historical prices
    fun calculate_price_statistics(monitor: &PriceMonitor): (u128, u128) {
        let history_length = monitor.price_history.length();
        if (history_length == 0) return (0, 0);
        
        let mut sum = 0u128;
        let mut count = 0u64;
        
        // Calculate mean using LinkedTable iteration
        let mut current_key_opt = monitor.price_history.front();
        while (current_key_opt.is_some()) {
            let current_key = current_key_opt.borrow();
            let price_point = monitor.price_history.borrow(*current_key);
            sum = sum + price_point.oracle_price_q64;
            count = count + 1;
            current_key_opt = monitor.price_history.next(*current_key);
        };
        
        if (count == 0) return (0, 0);
        
        let mean = sum / (count as u128);
        
        // Calculate standard deviation using LinkedTable iteration
        let mut sum_squared_diff = 0u128;
        current_key_opt = monitor.price_history.front();
        while (current_key_opt.is_some()) {
            let current_key = current_key_opt.borrow();
            let price_point = monitor.price_history.borrow(*current_key);
            let diff = if (price_point.oracle_price_q64 > mean) {
                price_point.oracle_price_q64 - mean
            } else {
                mean - price_point.oracle_price_q64
            };
            sum_squared_diff = sum_squared_diff + (diff * diff);
            current_key_opt = monitor.price_history.next(*current_key);
        };
        
        let variance = sum_squared_diff / (count as u128);
        let std_dev = integer_sqrt(variance);
        
        (mean, std_dev)
    }

    /// Calculate Z-Score for a price
    fun calculate_z_score(price: u128, mean: u128, std_dev: u128): u128 {
        if (std_dev == 0) return 0;
        
        let diff = if (price > mean) {
            price - mean
        } else {
            mean - price
        };
        
        // Calculate Z-Score with BASIS_POINTS_DENOMINATOR scaling for precision
        // Z-Score = |price - mean| * 10000 / std_dev
        // Return as u128 to avoid potential overflow
        full_math_u128::mul_div_floor(diff, (price_monitor_consts::get_basis_points_denominator() as u128), std_dev)
    }

    /// Integer square root approximation
    fun integer_sqrt(value: u128): u128 {
        if (value == 0) return 0;
        if (value == 1) return 1;
        
        let mut x = value;
        let mut y = (value + 1) / 2;
        
        while (y < x) {
            x = y;
            y = (x + value / x) / 2;
        };
        
        x
    }

    // ===== CIRCUIT BREAKER SYSTEM =====

    /// Evaluate circuit breaker conditions
    fun evaluate_circuit_breaker(
        monitor: &PriceMonitor,
        deviation_result: &DeviationValidationResult,
        statistical_result: &StatisticalValidationResult,
        current_time_ms: u64,
    ): CircuitBreakerResult {
        let max_anomaly_level = math_u128::max(
            deviation_result.anomaly_level as u128,
            statistical_result.anomaly_level as u128
        ) as u8;
        
        let should_escalate = should_escalate_circuit_breaker(
            monitor,
            max_anomaly_level,
            current_time_ms
        );
        
        let new_level = if (should_escalate) {
            math_u128::max(monitor.pause_level as u128, max_anomaly_level as u128) as u8
        } else {
            monitor.pause_level
        };
        
        let recommendation = get_recommendation(new_level);
        
        CircuitBreakerResult {
            level: new_level,
            should_activate: new_level > 0,
            should_escalate,
            recommendation,
        }
    }

    /// Determine if circuit breaker should escalate
    fun should_escalate_circuit_breaker(
        monitor: &PriceMonitor,
        anomaly_level: u8,
        current_time_ms: u64,
    ): bool {
        if (anomaly_level == 0) return false;
        
        // Check cooldown period
        if ((current_time_ms - monitor.last_anomaly_timestamp_ms) < monitor.config.anomaly_cooldown_period_ms) {
            return false
        };
        
        // Check consecutive anomalies
        if (monitor.consecutive_anomalies >= monitor.config.emergency_anomaly_threshold) {
            return true
        };
        
        // Check if anomaly level is higher than current pause level
        anomaly_level > monitor.pause_level
    }

    /// Get recommendation based on anomaly level
    fun get_recommendation(level: u8): vector<u8> {
        // if (level == 0) {
        //     vector::singleton(b"CONTINUE_NORMAL_OPERATIONS")
        // } else if (level == 1) {
        //     vector::singleton(b"INCREASE_MONITORING_FREQUENCY")
        // } else if (level == 2) {
        //     vector::singleton(b"PAUSE_CRITICAL_OPERATIONS")
        // } else if (level == 3) {
        //     vector::singleton(b"EMERGENCY_PAUSE_ALL_OPERATIONS")
        // } else {
        //     vector::singleton(b"UNKNOWN_LEVEL")
        // }
        vector::empty<u8>()
    }

    // ===== PRICE HISTORY MANAGEMENT =====

    /// Create a new price point
    fun create_price_point(
        oracle_price_q64: u128,
        pool_price_q64: u128,
        deviation_bps: u64,
        z_score: u128,
        timestamp_ms: u64,
        anomaly_level: u8,
        anomaly_flags: u8,
    ): PricePoint {
        PricePoint {
            oracle_price_q64,
            pool_price_q64,
            deviation_bps,
            z_score,
            timestamp_ms,
            anomaly_level,
            anomaly_flags,
        }
    }

    /// Add price point to history
    fun add_price_to_history(monitor: &mut PriceMonitor, price_point: PricePoint) {
        // Add new price point to the beginning (head) - most recent first
        monitor.price_history.push_front(price_point.timestamp_ms, price_point);
        
        // Remove oldest entry from the end (tail) if we exceed max size
        if (monitor.price_history.length() > monitor.max_history_size) {
            monitor.price_history.pop_back();
        };
    }



    // ===== STATE MANAGEMENT =====

    /// Update monitor state based on circuit breaker results
    fun update_monitor_state(
        monitor: &mut PriceMonitor,
        circuit_breaker_result: CircuitBreakerResult,
        current_time_ms: u64,
    ) {
        if (circuit_breaker_result.should_activate) {
            monitor.is_emergency_paused = true;
            monitor.pause_timestamp_ms = current_time_ms;
            monitor.pause_level = circuit_breaker_result.level;
            monitor.consecutive_anomalies = monitor.consecutive_anomalies + 1;
        } else {
            monitor.consecutive_anomalies = 0;
        };
    }

    // ===== EVENT EMISSION =====

    /// Emit validation events
    fun emit_validation_events(
        monitor: &PriceMonitor,
        deviation_result: &DeviationValidationResult,
        statistical_result: &StatisticalValidationResult,
        circuit_breaker_result: &CircuitBreakerResult,
        oracle_price_q64: u128,
        pool_price_q64: u128,
        current_time_ms: u64,
    ) {
        // Emit price anomaly event if any anomaly detected
        if (deviation_result.anomaly_level > 0 || statistical_result.anomaly_level > 0) {
            let anomaly_event = EventPriceAnomalyDetected {
                monitor_id: object::id(monitor),
                oracle_price_q64,
                pool_price_q64,
                deviation_bps: deviation_result.deviation_bps,
                z_score: statistical_result.z_score,
                anomaly_level: math_u128::max(
                    deviation_result.anomaly_level as u128,
                    statistical_result.anomaly_level as u128
                ) as u8,
                timestamp_ms: current_time_ms,
            };
            event::emit(anomaly_event);
        };
        
        // Emit circuit breaker events
        if (circuit_breaker_result.should_activate) {
            let circuit_breaker_event = EventCircuitBreakerActivated {
                monitor_id: object::id(monitor),
                level: circuit_breaker_result.level,
                reason: circuit_breaker_result.recommendation,
                timestamp_ms: current_time_ms,
            };
            event::emit(circuit_breaker_event);
        };
        
        // Emit price history updated event
        let history_event = EventPriceHistoryUpdated {
            monitor_id: object::id(monitor),
            history_length: monitor.price_history.length(),
            timestamp_ms: current_time_ms,
        };
        event::emit(history_event);
    }

    // ===== PUBLIC QUERY FUNCTIONS =====

    /// Get current circuit breaker status
    public fun get_circuit_breaker_status(monitor: &PriceMonitor): CircuitBreakerStatus {
        CircuitBreakerStatus {
            is_paused: monitor.is_emergency_paused,
            pause_level: monitor.pause_level,
            pause_timestamp_ms: monitor.pause_timestamp_ms,
            pause_reason: monitor.pause_reason,
            anomaly_count: monitor.anomaly_count,
            consecutive_anomalies: monitor.consecutive_anomalies,
        }
    }

    /// Get price history statistics
    public fun get_price_statistics(monitor: &PriceMonitor): PriceStatistics {
        let history_length = monitor.price_history.length();
        if (history_length < monitor.config.min_prices_for_analysis) {
            return PriceStatistics {
                mean_price_q64: 0,
                std_dev_q64: 0,
                history_length,
                min_prices_required: monitor.config.min_prices_for_analysis,
            }
        };
        
        let (mean_price, std_dev) = calculate_price_statistics(monitor);
        
        PriceStatistics {
            mean_price_q64: mean_price,
            std_dev_q64: std_dev,
            history_length,
            min_prices_required: monitor.config.min_prices_for_analysis,
        }
    }



    // ===== EMERGENCY OPERATIONS =====

    /// Emergency pause activation (requires EmergencyCap)
    public fun emergency_pause(
        monitor: &mut PriceMonitor,
        _emergency_cap: &EmergencyCap,
        reason: vector<u8>,
        clock: &Clock,
    ) {
        monitor.is_emergency_paused = true;
        monitor.pause_timestamp_ms = clock::timestamp_ms(clock);
        monitor.pause_level = price_monitor_consts::get_anomaly_level_emergency(); // Emergency level
        monitor.pause_reason = reason;
        
        let event = EventCircuitBreakerActivated {
            monitor_id: object::id(monitor),
            level: price_monitor_consts::get_anomaly_level_emergency(),
            reason,
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(event);
    }

    /// Emergency pause deactivation (requires EmergencyCap)
    public fun emergency_resume(
        monitor: &mut PriceMonitor,
        _emergency_cap: &EmergencyCap,
        clock: &Clock,
    ) {
        monitor.is_emergency_paused = false;
        monitor.pause_timestamp_ms = 0;
        monitor.pause_level = price_monitor_consts::get_anomaly_level_normal();
        monitor.pause_reason = vector::empty<u8>();
        monitor.consecutive_anomalies = 0;
        
        let event = EventCircuitBreakerDeactivated {
            monitor_id: object::id(monitor),
            level: price_monitor_consts::get_anomaly_level_normal(),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(event);
    }

    // ===== UTILITY FUNCTIONS =====

    /// Get monitor ID
    public fun monitor_id(monitor: &PriceMonitor): ID {
        object::id(monitor)
    }



    // ===== HELPER STRUCTURES =====

    /// Result of deviation validation
    public struct DeviationValidationResult has drop, copy {
        deviation_bps: u64,
        anomaly_level: u8,
        anomaly_flags: u8,
    }

    /// Result of statistical validation
    public struct StatisticalValidationResult has drop {
        z_score: u128,
        anomaly_level: u8,
        anomaly_flags: u8,
    }

    /// Result of circuit breaker evaluation
    public struct CircuitBreakerResult has drop, store {
        level: u8,
        should_activate: bool,
        should_escalate: bool,
        recommendation: vector<u8>,
    }

    /// Public result of price validation
    public struct PriceValidationResult has drop, copy {
        /// Whether the validation should abort early and return (true = abort, false = continue)
        should_return: bool,
        price_q64: u128,
    }

    /// Circuit breaker status information
    public struct CircuitBreakerStatus has drop, copy {
        is_paused: bool,
        pause_level: u8,
        pause_timestamp_ms: u64,
        pause_reason: vector<u8>,
        anomaly_count: u64,
        consecutive_anomalies: u64,
    }

    /// Price statistics information
    public struct PriceStatistics has drop {
        mean_price_q64: u128,
        std_dev_q64: u128,
        history_length: u64,
        min_prices_required: u64,
    }

    public fun get_time_checked_price_q64(
        aggregator: &Aggregator,
        asset_decimals: u8,
        usd_decimals: u8,
        clock: &sui::clock::Clock,
    ): u128 {
        let price_result = aggregator.current_result();
        let current_time = clock.timestamp_ms();
        let price_result_time = price_result.timestamp_ms();

        assert!(price_result_time + price_monitor_consts::get_max_price_age_ms() > current_time, EGetTimeCheckedPriceOutdated);

        let price_result_price = price_result.result();
        assert!(!price_result_price.neg(), EGetTimeCheckedPriceNegativePrice);

        let mut dec = price_result_price.dec();

        if (asset_decimals > usd_decimals) {
            // asset is bigger than USD
            // asset * price = USD
            // so to compensate we need to decrease price therefore increase denominator
            let decimals_delta = asset_decimals - usd_decimals;
            dec = dec + decimals_delta;
        } else {
            // USD is bigger than asset
            // USD / price = asset
            // so to compensate we need to increase price therefore decrease denominator
            let decimals_delta = usd_decimals - asset_decimals;
            dec = dec - decimals_delta;
        };
        let dec_denominator = decimal::pow_10(dec);

        decimal_to_q64_decimals(price_result_price, dec_denominator)
    }


    public fun decimal_to_q64(
        decimal: &Decimal,
    ): u128 {
        let dec = decimal.dec();
        let dec_denominator = decimal::pow_10(dec);

        decimal_to_q64_decimals(decimal, dec_denominator)
    }

    public fun decimal_to_q64_decimals(
        decimal: &Decimal,
        dec_denominator: u128,
    ): u128 {
        assert!(!decimal.neg(), EDecimalToQ64NegativeNotSupported);

        integer_mate::full_math_u128::mul_div_floor(
            decimal.value(),
            price_monitor_consts::get_q64_shift(),
            dec_denominator
        )
    }

    /// Utility function to convert USD amount * 2^64 to asset amount * 2^64
    public fun usd_q64_to_asset_q64(
        usd_amount_q64: u128,
        asset_price_q64: u128,
    ): u128 {
        integer_mate::full_math_u128::mul_div_floor(
            usd_amount_q64,
            price_monitor_consts::get_q64_shift(),
            asset_price_q64
        )
    }

    /// Utility function to convert asset amount * 2^64 to USD amount * 2^64
    public fun asset_q64_to_usd_q64(
        asset_amount_q64: u128,
        asset_price_q64: u128,
        ceil: bool,
    ): u128 {
        if (ceil) {
            integer_mate::full_math_u128::mul_div_ceil(
                asset_amount_q64,
                asset_price_q64,
                price_monitor_consts::get_q64_shift()
            )
        } else {
            integer_mate::full_math_u128::mul_div_floor(
                asset_amount_q64,
                asset_price_q64,
                price_monitor_consts::get_q64_shift()
            )
        }
    }

    // ===== TEST FUNCTIONS =====

    // #[test_only]
    // public fun test_create_price_monitor(ctx: &mut TxContext): (PriceMonitor, PriceMonitorCap, EmergencyCap) {
    //     create_price_monitor(ctx)
    // }

    // #[test_only]
    // public fun test_validate_price(
    //     monitor: &mut PriceMonitor,
    //     oracle_price_q64: u128,
    //     pool_price_q64: u128,
    // ): PriceValidationResult {
    //     let clock = clock::new_for_testing(&mut sui::tx_context::dummy_context());
    //     validate_price(monitor, oracle_price_q64, pool_price_q64, &clock)
    // }
}



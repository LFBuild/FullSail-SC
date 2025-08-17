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

    // Bump the `VERSION` of the package.
    const VERSION: u64 = 1;

    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::linked_table::{Self, LinkedTable};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use sui::coin::{Self, CoinMetadata};
    use std::type_name::{Self, TypeName};

    use switchboard::decimal::{Self, Decimal};
    use switchboard::aggregator::{Self, Aggregator};
    use integer_mate::full_math_u128;
    use integer_mate::math_u128;
    use price_monitor::price_monitor_consts;

    // ===== ERROR CODES =====

    const EInvalidSailPool: u64 = 94979479040750757;
    const EInvalidAggregator: u64 = 96897698040023643;
    const EZeroPrice: u64 = 99740389568845675;
    const EAdminNotWhitelisted: u64 = 93200562390235020;
    const EAddressNotAdmin: u64 = 93002007804597346;
    const EPackageVersionMismatch: u64 = 93406283690864906;
    const EInvalidMetadata: u64 = 99450784701125044;
    const EDecimalToQ64NegativeNotSupported: u64 = 93680623720490712;
    const EGetTimeCheckedPriceOutdated: u64 = 93470312203956742;
    const EGetTimeCheckedPriceNegativePrice: u64 = 92834672437062811;

    // Maximum value for u64 type to prevent overflow
    const MAX_U64: u128 = 0xffffffffffffffff;

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
        critical_anomaly_threshold: u64,
        emergency_anomaly_threshold: u64,
        
        // Time-based configuration
        anomaly_cooldown_period_ms: u64,
        max_price_age_ms: u64,                    // Maximum age of oracle price after its last update in aggregator
        max_price_history_age_ms: u64,            // Maximum age of prices stored in price history
        min_price_interval_ms: u64,               // Minimum interval between price history entries in milliseconds
        
        // History configuration
        max_price_history_size: u64,
        min_prices_for_analysis: u64,
        
        // Validation method toggles
        enable_oracle_pool_validation: bool,      // Enable/disable oracle-pool deviation validation
        enable_oracle_history_validation: bool,   // Enable/disable oracle-history deviation validation
        enable_statistical_validation: bool,      // Enable/disable statistical anomaly detection
        
        // Escalation control toggles
        enable_critical_escalation: bool,         // Enable/disable escalation for critical level anomalies
        enable_emergency_escalation: bool,        // Enable/disable escalation for emergency level anomalies
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
        version: u64,
        
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
        last_anomaly_level: u8,             // 0=none, 1=warning, 2=critical, 3=emergency
        last_anomaly_timestamp_ms: u64,
        
        // Admin management
        admins: VecSet<address>,

        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    /// Capability for emergency operations
    public struct SuperAdminCap has store, key {
        id: UID,
    }

    // ===== EVENTS =====

    /// Event emitted when oracle-pool deviation anomaly is detected
    public struct EventOraclePoolAnomalyDetected has copy, drop, store {
        monitor_id: ID,
        oracle_price_q64: u128,
        pool_price_q64: u128,
        deviation_bps: u64,
        anomaly_level: u8,
        anomaly_flags: u8,
        timestamp_ms: u64,
    }

    /// Event emitted when oracle-history deviation anomaly is detected
    public struct EventOracleHistoryAnomalyDetected has copy, drop, store {
        monitor_id: ID,
        oracle_price_q64: u128,
        deviation_bps: u64,
        anomaly_level: u8,
        anomaly_flags: u8,
        timestamp_ms: u64,
    }

    /// Event emitted when statistical anomaly is detected
    public struct EventStatisticalAnomalyDetected has copy, drop, store {
        monitor_id: ID,
        oracle_price_q64: u128,
        z_score: u128,
        anomaly_level: u8,
        anomaly_flags: u8,
        timestamp_ms: u64,
    }

    /// Event emitted when circuit breaker is activated
    public struct EventCircuitBreakerActivated has copy, drop, store {
        monitor_id: ID,
        level: u8,                   // 1=warning, 2=critical, 3=emergency
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
            critical_anomaly_threshold: price_monitor_consts::get_critical_anomaly_threshold(),
            emergency_anomaly_threshold: price_monitor_consts::get_emergency_anomaly_threshold(),
            anomaly_cooldown_period_ms: price_monitor_consts::get_anomaly_cooldown_period_ms(),
            max_price_age_ms: price_monitor_consts::get_max_price_age_ms(),
            max_price_history_age_ms: price_monitor_consts::get_max_price_history_age_ms(),
            min_price_interval_ms: price_monitor_consts::get_min_price_interval_ms(),
            max_price_history_size: price_monitor_consts::get_max_price_history_size(),
            min_prices_for_analysis: price_monitor_consts::get_min_prices_for_analysis(),
            enable_oracle_pool_validation: price_monitor_consts::get_enable_oracle_pool_validation(),
            enable_oracle_history_validation: price_monitor_consts::get_enable_oracle_history_validation(),
            enable_statistical_validation: price_monitor_consts::get_enable_statistical_validation(),
            enable_critical_escalation: price_monitor_consts::get_enable_critical_escalation(),
            enable_emergency_escalation: price_monitor_consts::get_enable_emergency_escalation(),
        };

        let mut monitor = PriceMonitor {
            id: object::new(ctx),
            version: VERSION,
            config,
            aggregator_to_pools: table::new(ctx),
            price_history: linked_table::new(ctx),
            max_history_size: price_monitor_consts::get_max_price_history_size(),
            anomaly_count: 0,
            last_anomaly_timestamp_ms: 0,
            consecutive_anomalies: 0,
            is_emergency_paused: false,
            pause_timestamp_ms: 0,
            last_anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
            admins: vec_set::empty<address>(),
            bag: sui::bag::new(ctx),
        };

        // Add the first admin (transaction sender)
        monitor.admins.insert(sui::tx_context::sender(ctx));

        let emergency_cap = SuperAdminCap {
            id: object::new(ctx),
        };

        transfer::transfer<SuperAdminCap>(emergency_cap, sui::tx_context::sender(ctx));

        transfer::share_object<PriceMonitor>(monitor);
    }

    /// Checks if the package version matches the expected version.
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to check
    /// 
    /// # Abort Conditions
    /// * If the package version is not a version of price_monitor_v1 (error code: EPackageVersionMismatch)
    public fun checked_package_version(monitor: &PriceMonitor) {
        assert!(monitor.version == VERSION, EPackageVersionMismatch);
    }

    // ===== AGGREGATOR MANAGEMENT =====

    /// Add an aggregator with associated pools
    public fun add_aggregator(
        monitor: &mut PriceMonitor,
        aggregator_id: ID,
        pool_ids: vector<ID>,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        monitor.aggregator_to_pools.add(aggregator_id, pool_ids);
    }

    /// Remove an aggregator and its associated pools
    public fun remove_aggregator(
        monitor: &mut PriceMonitor,
        aggregator_id: ID,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        monitor.aggregator_to_pools.remove(aggregator_id);
    }

    /// Add a pool to an existing aggregator
    public fun add_pool_to_aggregator(
        monitor: &mut PriceMonitor,
        aggregator_id: ID,
        pool_id: ID,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        assert!(monitor.aggregator_to_pools.contains(aggregator_id), EInvalidAggregator);
        // Check if pool is already associated with this aggregator
        assert!(!is_pool_associated_with_aggregator(monitor, aggregator_id, pool_id), EInvalidSailPool);
        let pools = monitor.aggregator_to_pools.borrow_mut(aggregator_id);
        pools.push_back(pool_id);
    }

    /// Remove a pool from an aggregator
    public fun remove_pool_from_aggregator(
        monitor: &mut PriceMonitor,
        aggregator_id: ID,
        pool_id: ID,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
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

    // ===== CORE PRICE MONITORING FUNCTIONS =====

    /// Main function to validate and monitor prices
    /// This is the primary entry point for price validation
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the feed pool
    /// * `CoinTypeB` - Second coin type in the feed pool 
    /// * `BaseCoin` - The base coin whose price is being monitored (e.g., SAIL)
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor instance
    /// * `aggregator` - The price aggregator for oracle data
    /// * `feed_pool` - The CLMM pool containing the trading pair
    /// * `clock` - The clock for timestamp validation
    public fun validate_price<CoinTypeA, CoinTypeB, BaseCoin>(
        monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        feed_pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &Clock,
    ): PriceValidationResult {
        checked_package_version(monitor);
        
        let aggregator_id = object::id(aggregator);
        let pool_id = object::id(feed_pool);
        
        // Check if pool is associated with this aggregator
        assert!(is_pool_associated_with_aggregator(monitor, aggregator_id, pool_id), EInvalidSailPool);

        let current_time_ms = clock::timestamp_ms(clock);

        let oracle_price_q64 = get_time_checked_price_q64(
            aggregator,
            clock
        );

        let pool_price_q64 = get_pool_price_q64<CoinTypeA, CoinTypeB, BaseCoin>(feed_pool);

        // Clean old prices from price history before analysis to ensure data freshness
        clean_old_prices_from_history(monitor, current_time_ms);

        // 1. Multi-Oracle Validation
        let deviation_result = if (monitor.config.enable_oracle_pool_validation) {
            validate_oracle_pool_deviation(
                monitor,
                oracle_price_q64,
                pool_price_q64
            )
        } else {
            DeviationValidationResult {
                deviation_bps: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };

        // 2. Oracle-History Deviation Validation
        let history_deviation_result = if (monitor.config.enable_oracle_history_validation) {
            validate_oracle_history_deviation(
                monitor,
                oracle_price_q64
            )
        } else {
            DeviationValidationResult {
                deviation_bps: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };
        
        // 3. Statistical Anomaly Detection
        let statistical_result = if (monitor.config.enable_statistical_validation) {
            validate_statistical_anomaly(
                monitor,
                oracle_price_q64
            )
        } else {
            StatisticalValidationResult {
                z_score: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };
        
        // 4. Update price history
        let price_point = create_price_point(
            oracle_price_q64,
            pool_price_q64,
            deviation_result.deviation_bps,
            statistical_result.z_score,
            current_time_ms,
            math_u128::max(
                deviation_result.anomaly_level as u128,
                history_deviation_result.anomaly_level as u128
            ) as u8,
            math_u128::max(
                deviation_result.anomaly_flags as u128,
                history_deviation_result.anomaly_flags as u128
            ) as u8
        );
        
        add_price_to_history(monitor, price_point);
        
        // 5. Circuit Breaker Logic
        let circuit_breaker_result = evaluate_circuit_breaker(
            monitor,
            &deviation_result,
            &history_deviation_result,
            &statistical_result,
            current_time_ms
        );
        
        
        // 6. Emit events
        emit_validation_events(
            monitor, 
            &deviation_result, 
            &statistical_result, 
            &history_deviation_result,
            &circuit_breaker_result,
            oracle_price_q64,
            pool_price_q64,
            current_time_ms
        );
        
        // 7. Update monitor state
        update_monitor_state(monitor, &circuit_breaker_result, current_time_ms);
        
        PriceValidationResult {
            is_valid: circuit_breaker_result.level == price_monitor_consts::get_anomaly_level_normal(),
            escalation_activation: circuit_breaker_result.should_escalate,
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

    /// Validate deviation between oracle price and last price from history
    fun validate_oracle_history_deviation(
        monitor: &PriceMonitor,
        oracle_price_q64: u128,
    ): DeviationValidationResult {
        let history_length = monitor.price_history.length();
        if (history_length == 0) {
            return DeviationValidationResult {
                deviation_bps: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };
        
        // Get the most recent price from history (front of LinkedTable)
        let last_price_key_opt = monitor.price_history.front();
        if (last_price_key_opt.is_none()) {
            return DeviationValidationResult {
                deviation_bps: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };
        
        let last_price_key = last_price_key_opt.borrow();
        let last_price_point = monitor.price_history.borrow(*last_price_key);
        let last_price_history_q64 = last_price_point.oracle_price_q64;
        
        let deviation_bps = calculate_deviation_bps(oracle_price_q64, last_price_history_q64);
        
        let anomaly_level = if (deviation_bps >= price_monitor_consts::get_emergency_history_deviation_bps()) {
            price_monitor_consts::get_anomaly_level_emergency()
        } else if (deviation_bps >= price_monitor_consts::get_critical_history_deviation_bps()) {
            price_monitor_consts::get_anomaly_level_critical()
        } else if (deviation_bps >= price_monitor_consts::get_warning_history_deviation_bps()) {
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
        std::debug::print(&b"deviation_bps");
        std::debug::print(&deviation);
        std::debug::print(&price1_q64);
        std::debug::print(&base_price_q64);
        std::debug::print(&deviation_bps);
        
        // Check if deviation_bps exceeds u64::MAX to prevent overflow
        let clamped_deviation_bps = if (deviation_bps > MAX_U64) { MAX_U64 } else { deviation_bps };
        std::debug::print(&clamped_deviation_bps);
        (clamped_deviation_bps as u64)
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
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
            }
        };
        
        let (mean_price, std_dev) = calculate_price_statistics(monitor);
        
        if (std_dev == 0) {
            return StatisticalValidationResult {
                z_score: 0,
                anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
                anomaly_flags: price_monitor_consts::get_anomaly_flag_none(),
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
        
        let anomaly_flags = if (anomaly_level > price_monitor_consts::get_anomaly_level_normal()) {
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
        history_deviation_result: &DeviationValidationResult,
        statistical_result: &StatisticalValidationResult,
        current_time_ms: u64,
    ): CircuitBreakerResult {
        let max_anomaly_level = math_u128::max(
            math_u128::max(
                deviation_result.anomaly_level as u128,
                statistical_result.anomaly_level as u128
            ),
            history_deviation_result.anomaly_level as u128
        ) as u8;
        
        let should_escalate = should_escalate_circuit_breaker(
            monitor,
            max_anomaly_level,
            current_time_ms
        );
                        
        CircuitBreakerResult {
            level: max_anomaly_level,
            should_activate: max_anomaly_level != price_monitor_consts::get_anomaly_level_normal(),
            should_escalate,
        }
    }

    /// Determine if circuit breaker should escalate
    fun should_escalate_circuit_breaker(
        monitor: &PriceMonitor,
        anomaly_level: u8,
        current_time_ms: u64,
    ): bool {
        if (anomaly_level == price_monitor_consts::get_anomaly_level_normal()) return false;
        
        // Check cooldown period
        if ((current_time_ms - monitor.last_anomaly_timestamp_ms) < monitor.config.anomaly_cooldown_period_ms) {
            return false
        };

        // Check critical anomalies
        if (monitor.consecutive_anomalies >= monitor.config.critical_anomaly_threshold && 
            monitor.config.enable_critical_escalation) {
            return true
        };
        
        // Check emergency anomalies
        if (monitor.consecutive_anomalies >= monitor.config.emergency_anomaly_threshold && 
            monitor.config.enable_emergency_escalation) {
            return true
        };
        
        false
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
        // Get the most recent price point key (head of the linked table)
        let front_key_opt = monitor.price_history.front();
        if (front_key_opt.is_some()) {
            let latest_price_point = monitor.price_history.borrow(*front_key_opt.borrow());
            
            // Check if enough time has passed since the last price update
            if (price_point.timestamp_ms < latest_price_point.timestamp_ms + monitor.config.min_price_interval_ms) {
                // Not enough time has passed, skip adding this price point
                return
            };
        };
        
        // Add new price point to the beginning (head) - most recent first
        monitor.price_history.push_front(price_point.timestamp_ms, price_point);
        
        // Remove oldest entry from the end (tail) if we exceed max size
        if (monitor.price_history.length() > monitor.max_history_size) {
            monitor.price_history.pop_back();
        };
    }

    /// Clean old prices from history based on max_price_history_age_ms
    /// This method removes prices that are older than the configured threshold from price history
    fun clean_old_prices_from_history(monitor: &mut PriceMonitor, current_time_ms: u64) {
        let max_age_ms = monitor.config.max_price_history_age_ms;
        if (max_age_ms == 0) return; // Skip if not configured
                
        let mut back_key_opt = monitor.price_history.back();
        while (back_key_opt.is_some()) {
            let oldest_price_point = monitor.price_history.borrow(*back_key_opt.borrow());
            
            // Check if this price is too old
            if (current_time_ms < oldest_price_point.timestamp_ms + max_age_ms) {
                // Found a price that's not too old, stop removing
                break
            };

            // Remove the oldest price
            monitor.price_history.pop_back();
            back_key_opt = monitor.price_history.back();
        };
    }

    // ===== STATE MANAGEMENT =====

    /// Update monitor state based on circuit breaker results
    fun update_monitor_state(
        monitor: &mut PriceMonitor,
        circuit_breaker_result: &CircuitBreakerResult,
        current_time_ms: u64,
    ) {
        if (circuit_breaker_result.should_escalate) {
            monitor.is_emergency_paused = true;
            monitor.pause_timestamp_ms = current_time_ms;
        } else {
            monitor.is_emergency_paused = false;
        };
        
        if (circuit_breaker_result.should_activate) {     
            monitor.consecutive_anomalies = monitor.consecutive_anomalies + 1;
            monitor.anomaly_count = monitor.anomaly_count + 1;
        } else {
            monitor.consecutive_anomalies = 0;
        };
        monitor.last_anomaly_level = circuit_breaker_result.level;
    }

    // ===== EVENT EMISSION =====

    /// Emit validation events
    fun emit_validation_events(
        monitor: &PriceMonitor,
        deviation_result: &DeviationValidationResult,
        statistical_result: &StatisticalValidationResult,
        history_deviation_result: &DeviationValidationResult,
        circuit_breaker_result: &CircuitBreakerResult,
        oracle_price_q64: u128,
        pool_price_q64: u128,
        current_time_ms: u64,
    ) {
        // Emit oracle-pool deviation anomaly event if detected
        if (deviation_result.anomaly_level > price_monitor_consts::get_anomaly_level_normal()) {
            let oracle_pool_event = EventOraclePoolAnomalyDetected {
                monitor_id: object::id(monitor),
                oracle_price_q64,
                pool_price_q64,
                deviation_bps: deviation_result.deviation_bps,
                anomaly_level: deviation_result.anomaly_level,
                anomaly_flags: deviation_result.anomaly_flags,
                timestamp_ms: current_time_ms,
            };
            event::emit(oracle_pool_event);
        };

        // Emit oracle-history deviation anomaly event if detected
        if (history_deviation_result.anomaly_level > price_monitor_consts::get_anomaly_level_normal()) {
            let oracle_history_event = EventOracleHistoryAnomalyDetected {
                monitor_id: object::id(monitor),
                oracle_price_q64,
                deviation_bps: history_deviation_result.deviation_bps,
                anomaly_level: history_deviation_result.anomaly_level,
                anomaly_flags: history_deviation_result.anomaly_flags,
                timestamp_ms: current_time_ms,
            };
            event::emit(oracle_history_event);
        };

        // Emit statistical anomaly event if detected
        if (statistical_result.anomaly_level > price_monitor_consts::get_anomaly_level_normal()) {
            let statistical_event = EventStatisticalAnomalyDetected {
                monitor_id: object::id(monitor),
                oracle_price_q64,
                z_score: statistical_result.z_score,
                anomaly_level: statistical_result.anomaly_level,
                anomaly_flags: statistical_result.anomaly_flags,
                timestamp_ms: current_time_ms,
            };
            event::emit(statistical_event);
        };
        
        // Emit circuit breaker events
        if (circuit_breaker_result.should_activate) {
            let circuit_breaker_event = EventCircuitBreakerActivated {
                monitor_id: object::id(monitor),
                level: circuit_breaker_result.level,
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

    // ===== CONFIGURATION MANAGEMENT =====

    /// Create a new PriceMonitorConfig with specified parameters
    /// 
    /// # Arguments
    /// * `warning_deviation_bps` - Warning deviation threshold in basis points
    /// * `critical_deviation_bps` - Critical deviation threshold in basis points
    /// * `emergency_deviation_bps` - Emergency deviation threshold in basis points
    /// * `warning_zscore_threshold` - Warning Z-Score threshold (scaled by BASIS_POINTS_DENOMINATOR)
    /// * `critical_zscore_threshold` - Critical Z-Score threshold (scaled by BASIS_POINTS_DENOMINATOR)
    /// * `emergency_zscore_threshold` - Emergency Z-Score threshold (scaled by BASIS_POINTS_DENOMINATOR)
    /// * `critical_anomaly_threshold` - Number of consecutive anomalies to trigger critical escalation
    /// * `emergency_anomaly_threshold` - Number of consecutive anomalies to trigger emergency escalation
    /// * `anomaly_cooldown_period_ms` - Cooldown period between anomaly escalations in milliseconds
    /// * `max_price_age_ms` - Maximum age of oracle price after its last update in aggregator in milliseconds
    /// * `max_price_history_age_ms` - Maximum age of prices stored in price history in milliseconds
    /// * `min_price_interval_ms` - Minimum interval between price history entries in milliseconds
    /// * `max_price_history_size` - Maximum number of price points to store in history
    /// * `min_prices_for_analysis` - Minimum number of prices required for statistical analysis
    /// * `enable_oracle_pool_validation` - Enable/disable oracle-pool deviation validation
    /// * `enable_oracle_history_validation` - Enable/disable oracle-history deviation validation
    /// * `enable_statistical_validation` - Enable/disable statistical anomaly detection
    /// * `enable_critical_escalation` - Enable/disable escalation for critical level anomalies
    /// * `enable_emergency_escalation` - Enable/disable escalation for emergency level anomalies
    /// 
    /// # Returns
    /// A new PriceMonitorConfig instance with the specified parameters
    /// 
    /// # Aborts
    /// * If any deviation threshold exceeds BASIS_POINTS_DENOMINATOR (error code: EInvalidDeviationThreshold)
    /// * If any Z-Score threshold exceeds BASIS_POINTS_DENOMINATOR (error code: EInvalidZScoreThreshold)
    public fun create_config(
        warning_deviation_bps: u64,
        critical_deviation_bps: u64,
        emergency_deviation_bps: u64,
        warning_zscore_threshold: u64,
        critical_zscore_threshold: u64,
        emergency_zscore_threshold: u64,
        critical_anomaly_threshold: u64,
        emergency_anomaly_threshold: u64,
        anomaly_cooldown_period_ms: u64,
        max_price_age_ms: u64,
        max_price_history_age_ms: u64,
        min_price_interval_ms: u64,
        max_price_history_size: u64,
        min_prices_for_analysis: u64,
        enable_oracle_pool_validation: bool,
        enable_oracle_history_validation: bool,
        enable_statistical_validation: bool,
        enable_critical_escalation: bool,
        enable_emergency_escalation: bool,
    ): PriceMonitorConfig {
        
        PriceMonitorConfig {
            warning_deviation_bps,
            critical_deviation_bps,
            emergency_deviation_bps,
            warning_zscore_threshold,
            critical_zscore_threshold,
            emergency_zscore_threshold,
            critical_anomaly_threshold,
            emergency_anomaly_threshold,
            anomaly_cooldown_period_ms,
            max_price_age_ms,
            max_price_history_age_ms,
            min_price_interval_ms,
            max_price_history_size,
            min_prices_for_analysis,
            enable_oracle_pool_validation,
            enable_oracle_history_validation,
            enable_statistical_validation,
            enable_critical_escalation,
            enable_emergency_escalation,
        }
    }

    /// Update price monitor configuration
    public fun update_config(
        monitor: &mut PriceMonitor,
        new_config: PriceMonitorConfig,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        monitor.config = new_config;
    }

    /// Get current configuration
    public fun get_config(monitor: &PriceMonitor): &PriceMonitorConfig {
        &monitor.config
    }



    /// Update deviation thresholds (warning, critical, emergency) in basis points
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `warning_deviation_bps` - New warning deviation threshold in basis points
    /// * `critical_deviation_bps` - New critical deviation threshold in basis points
    /// * `emergency_deviation_bps` - New emergency deviation threshold in basis points
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_deviation_thresholds(
        monitor: &mut PriceMonitor,
        warning_deviation_bps: u64,
        critical_deviation_bps: u64,
        emergency_deviation_bps: u64,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.warning_deviation_bps = warning_deviation_bps;
        monitor.config.critical_deviation_bps = critical_deviation_bps;
        monitor.config.emergency_deviation_bps = emergency_deviation_bps;
    }

    /// Update Z-Score thresholds (warning, critical, emergency) scaled by BASIS_POINTS_DENOMINATOR
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `warning_zscore_threshold` - New warning Z-Score threshold
    /// * `critical_zscore_threshold` - New critical Z-Score threshold
    /// * `emergency_zscore_threshold` - New emergency Z-Score threshold
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_zscore_thresholds(
        monitor: &mut PriceMonitor,
        warning_zscore_threshold: u64,
        critical_zscore_threshold: u64,
        emergency_zscore_threshold: u64,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.warning_zscore_threshold = warning_zscore_threshold;
        monitor.config.critical_zscore_threshold = critical_zscore_threshold;
        monitor.config.emergency_zscore_threshold = emergency_zscore_threshold;
    }

    /// Update anomaly escalation thresholds and cooldown period
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `critical_anomaly_threshold` - New number of consecutive anomalies to trigger critical escalation
    /// * `emergency_anomaly_threshold` - New number of consecutive anomalies to trigger emergency escalation
    /// * `anomaly_cooldown_period_ms` - New cooldown period between anomaly escalations in milliseconds
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_anomaly_thresholds(
        monitor: &mut PriceMonitor,
        critical_anomaly_threshold: u64,
        emergency_anomaly_threshold: u64,
        anomaly_cooldown_period_ms: u64,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.critical_anomaly_threshold = critical_anomaly_threshold;
        monitor.config.emergency_anomaly_threshold = emergency_anomaly_threshold;
        monitor.config.anomaly_cooldown_period_ms = anomaly_cooldown_period_ms;
    }

    /// Update time-based configuration parameters
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `max_price_age_ms` - New maximum age for oracle prices after their last update in aggregator in milliseconds
    /// * `max_price_history_age_ms` - New maximum age for prices stored in price history in milliseconds
    /// * `min_price_interval_ms` - New minimum interval between price history entries in milliseconds
    /// * `max_price_history_size` - New maximum number of price points to store in history
    /// * `min_prices_for_analysis` - New minimum number of prices required for statistical analysis
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_time_config(
        monitor: &mut PriceMonitor,
        max_price_age_ms: u64,
        max_price_history_age_ms: u64,
        min_price_interval_ms: u64,
        max_price_history_size: u64,
        min_prices_for_analysis: u64,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.max_price_age_ms = max_price_age_ms;
        monitor.config.max_price_history_age_ms = max_price_history_age_ms;
        monitor.config.min_price_interval_ms = min_price_interval_ms;
        monitor.config.max_price_history_size = max_price_history_size;
        monitor.config.min_prices_for_analysis = min_prices_for_analysis;
        
        // Update the monitor's max_history_size field as well
        monitor.max_history_size = max_price_history_size;
    }

    /// Update validation method toggles
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `enable_oracle_pool_validation` - Enable/disable oracle-pool deviation validation
    /// * `enable_oracle_history_validation` - Enable/disable oracle-history deviation validation
    /// * `enable_statistical_validation` - Enable/disable statistical anomaly detection
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_validation_toggles(
        monitor: &mut PriceMonitor,
        enable_oracle_pool_validation: bool,
        enable_oracle_history_validation: bool,
        enable_statistical_validation: bool,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.enable_oracle_pool_validation = enable_oracle_pool_validation;
        monitor.config.enable_oracle_history_validation = enable_oracle_history_validation;
        monitor.config.enable_statistical_validation = enable_statistical_validation;
    }

    /// Update escalation control toggles
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to update
    /// * `enable_critical_escalation` - Enable/disable escalation for critical level anomalies
    /// * `enable_emergency_escalation` - Enable/disable escalation for emergency level anomalies
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    public fun update_escalation_toggles(
        monitor: &mut PriceMonitor,
        enable_critical_escalation: bool,
        enable_emergency_escalation: bool,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        
        monitor.config.enable_critical_escalation = enable_critical_escalation;
        monitor.config.enable_emergency_escalation = enable_emergency_escalation;
    }

    // ===== PUBLIC QUERY FUNCTIONS =====

    /// Get current circuit breaker status
    public fun get_circuit_breaker_status(monitor: &PriceMonitor): CircuitBreakerStatus {
        CircuitBreakerStatus {
            is_paused: monitor.is_emergency_paused,
            last_anomaly_level: monitor.last_anomaly_level,
            pause_timestamp_ms: monitor.pause_timestamp_ms,
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

    /// Emergency pause activation
    public fun emergency_pause(
        monitor: &mut PriceMonitor,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        monitor.is_emergency_paused = true;
        monitor.pause_timestamp_ms = clock::timestamp_ms(clock);
        monitor.last_anomaly_level = price_monitor_consts::get_anomaly_level_emergency(); // Emergency level
        
        let event = EventCircuitBreakerActivated {
            monitor_id: object::id(monitor),
            level: price_monitor_consts::get_anomaly_level_emergency(),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(event);
    }

    /// Emergency pause deactivation
    public fun emergency_resume(
        monitor: &mut PriceMonitor,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));
        monitor.is_emergency_paused = false;
        monitor.pause_timestamp_ms = 0;
        monitor.last_anomaly_level = price_monitor_consts::get_anomaly_level_normal();
        monitor.consecutive_anomalies = 0;
        
        let event = EventCircuitBreakerDeactivated {
            monitor_id: object::id(monitor),
            level: price_monitor_consts::get_anomaly_level_normal(),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(event);
    }

    // ===== ADMIN MANAGEMENT =====

    /// Check if the provided address is an admin
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to check
    /// * `admin` - The address to check for admin privileges
    /// 
    /// # Abort Conditions
    /// * If the address is not an admin (error code: EAdminNotWhitelisted)
    public fun check_admin(monitor: &PriceMonitor, admin: address) {
        assert!(monitor.admins.contains<address>(&admin), EAdminNotWhitelisted);
    }

    /// Add a new admin to the price monitor
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `monitor` - The price monitor object to add the admin to
    /// * `new_admin` - The address of the admin to add
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    /// * If the new_admin address is already an admin (error code: EAddressNotAdmin)
    public fun add_admin(
        _admin_cap: &SuperAdminCap,
        monitor: &mut PriceMonitor, 
        new_admin: address, 
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));

        assert!(!monitor.admins.contains(&new_admin), EAddressNotAdmin);
        monitor.admins.insert(new_admin);
    }

    /// Remove an admin from the price monitor
    /// 
    /// # Arguments
    /// * `_admin_cap` - Administrative capability for authorization
    /// * `monitor` - The price monitor object to remove the admin from
    /// * `who` - The address of the admin to remove
    /// * `ctx` - The transaction context
    /// 
    /// # Aborts
    /// * If the sender is not an admin (error code: EAdminNotWhitelisted)
    /// * If the who address is not an admin (error code: EAddressNotAdmin)
    public fun remove_admin(
        _admin_cap: &SuperAdminCap,
        monitor: &mut PriceMonitor,
        who: address,
        ctx: &mut TxContext,
    ) {
        checked_package_version(monitor);
        check_admin(monitor, sui::tx_context::sender(ctx));

        assert!(monitor.admins.contains(&who), EAddressNotAdmin);
        monitor.admins.remove(&who); 
    }

    /// Check if the provided address is an admin
    /// 
    /// # Arguments
    /// * `monitor` - The price monitor object to check
    /// * `admin` - The address to check for admin privileges
    /// 
    /// # Returns
    /// Boolean indicating if the address is an admin (true) or not (false)
    public fun is_admin(monitor: &PriceMonitor, admin: address): bool {
        monitor.admins.contains(&admin)
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
    }

    /// Public result of price validation
    /// price_q64 - price in Q64.64 format, i.e USD/asset * 2^64
    public struct PriceValidationResult has drop, copy {
        escalation_activation: bool,
        is_valid: bool,
        price_q64: u128,
    }

    /// Getter for escalation_activation field
    public fun get_escalation_activation(result: &PriceValidationResult): bool {
        result.escalation_activation
    }

    /// Getter for is_valid field
    public fun get_is_valid(result: &PriceValidationResult): bool {
        result.is_valid
    }

    /// Getter for price_q64 field
    public fun get_price_q64(result: &PriceValidationResult): u128 {
        result.price_q64
    }

    /// Circuit breaker status information
    public struct CircuitBreakerStatus has drop, copy {
        is_paused: bool,
        last_anomaly_level: u8,
        pause_timestamp_ms: u64,
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

    /// Utility function to get the current price of an asset from a switchboard aggregator
    /// Asserts that the price is not too old and returns the price.
    /// 
    /// # Arguments
    /// * `aggregator` - The switchboard aggregator to get the price from
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The price in Q64.64 format, i.e USD/asset * 2^64 without decimals
    public fun get_time_checked_price_q64(
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
    ): u128 {
        let price_result = aggregator.current_result();
        let current_time = clock.timestamp_ms();
        let price_result_time = price_result.timestamp_ms();

        assert!(price_result_time + price_monitor_consts::get_max_price_age_ms() > current_time, EGetTimeCheckedPriceOutdated);

        let price_result_price = price_result.result();
        assert!(!price_result_price.neg(), EGetTimeCheckedPriceNegativePrice);

        integer_mate::full_math_u128::mul_div_floor(
            price_result_price.value(),
            1 << 64,
            decimal::pow_10(price_result_price.dec())
        )
    }

    /// Get pool price in Q64.64 format
    /// 
    /// # Type Parameters
    /// * `CoinTypeA` - First coin type in the pool
    /// * `CoinTypeB` - Second coin type in the pool  
    /// * `BaseCoin` - The base coin whose price is being monitored (e.g., SAIL)
    /// 
    /// # Arguments
    /// * `pool` - The CLMM pool containing the trading pair (feed pool)
    /// * `quote_coin_metadata` - Metadata for the quote coin (e.g., USDC metadata)
    /// 
    /// # Returns
    /// Pool price in Q64.64 format
    fun get_pool_price_q64<CoinTypeA, CoinTypeB, BaseCoin>(
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>
    ): u128 {

        let sqrt_price = pool.current_sqrt_price();
        let mut pool_price_q64 = (integer_mate::full_math_u128::full_mul(sqrt_price, sqrt_price) >> 64) as u128;

        if (type_name::get<CoinTypeA>() == type_name::get<BaseCoin>()) {
            pool_price_q64 = integer_mate::full_math_u128::mul_div_floor(
                1 as u128,
                1 as u128,
                pool_price_q64
            );
        };

        assert!(pool_price_q64 > 0, EZeroPrice);
        
        pool_price_q64
    }

    // ===== TEST FUNCTIONS =====

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let config = PriceMonitorConfig {
            warning_deviation_bps: price_monitor_consts::get_warning_deviation_bps(),
            critical_deviation_bps: price_monitor_consts::get_critical_deviation_bps(),
            emergency_deviation_bps: price_monitor_consts::get_emergency_deviation_bps(),
            warning_zscore_threshold: price_monitor_consts::get_warning_zscore_threshold(),
            critical_zscore_threshold: price_monitor_consts::get_critical_zscore_threshold(),
            emergency_zscore_threshold: price_monitor_consts::get_emergency_zscore_threshold(),
            critical_anomaly_threshold: price_monitor_consts::get_critical_anomaly_threshold(),
            emergency_anomaly_threshold: price_monitor_consts::get_emergency_anomaly_threshold(),
            anomaly_cooldown_period_ms: price_monitor_consts::get_anomaly_cooldown_period_ms(),
            max_price_age_ms: price_monitor_consts::get_max_price_age_ms(),
            max_price_history_age_ms: price_monitor_consts::get_max_price_history_age_ms(),
            min_price_interval_ms: price_monitor_consts::get_min_price_interval_ms(),
            max_price_history_size: price_monitor_consts::get_max_price_history_size(),
            min_prices_for_analysis: price_monitor_consts::get_min_prices_for_analysis(),
            enable_oracle_pool_validation: price_monitor_consts::get_enable_oracle_pool_validation(),
            enable_oracle_history_validation: price_monitor_consts::get_enable_oracle_history_validation(),
            enable_statistical_validation: price_monitor_consts::get_enable_statistical_validation(),
            enable_critical_escalation: price_monitor_consts::get_enable_critical_escalation(),
            enable_emergency_escalation: price_monitor_consts::get_enable_emergency_escalation(),
        };

        let mut monitor = PriceMonitor {
            id: object::new(ctx),
            version: 1,
            config,
            aggregator_to_pools: table::new(ctx),
            price_history: linked_table::new(ctx),
            max_history_size: price_monitor_consts::get_max_price_history_size(),
            anomaly_count: 0,
            last_anomaly_timestamp_ms: 0,
            consecutive_anomalies: 0,
            is_emergency_paused: false,
            pause_timestamp_ms: 0,
            last_anomaly_level: price_monitor_consts::get_anomaly_level_normal(),
            admins: vec_set::empty<address>(),
            bag: sui::bag::new(ctx),
        };

        // Add the first admin (transaction sender)
        monitor.admins.insert(sui::tx_context::sender(ctx));

        let emergency_cap = SuperAdminCap {
            id: object::new(ctx),
        };

        transfer::transfer<SuperAdminCap>(emergency_cap, sui::tx_context::sender(ctx));

        transfer::share_object<PriceMonitor>(monitor);
    }

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



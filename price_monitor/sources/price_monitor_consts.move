/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
/// 
/// Constants for the price_monitor module
module price_monitor::price_monitor_consts {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    // ===== ANOMALY LEVELS =====
    
    /// Normal operation - no anomalies detected
    const ANOMALY_LEVEL_NORMAL: u8 = 0;
    
    /// Warning level anomaly
    const ANOMALY_LEVEL_WARNING: u8 = 1;
    
    /// Critical level anomaly
    const ANOMALY_LEVEL_CRITICAL: u8 = 2;
    
    /// Emergency level anomaly
    const ANOMALY_LEVEL_EMERGENCY: u8 = 3;

    // ===== ANOMALY FLAGS =====
    
    /// No anomaly flags
    const ANOMALY_FLAG_NONE: u8 = 0;
    
    /// Deviation anomaly flag
    const ANOMALY_FLAG_DEVIATION: u8 = 1;
    
    /// Statistical anomaly flag
    const ANOMALY_FLAG_STATISTICAL: u8 = 2;

    // ===== BASIS POINTS CONVERSION =====
    
    /// Denominator for basis points calculation (10000 = 100%)
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;

    // ===== Z-SCORE SCALING =====
    
    /// Multiplier for Z-score precision (100 = 2 decimal places)
    const ZSCORE_SCALING_FACTOR: u64 = 100;

    // ===== PRICE HISTORY CONFIGURATION =====
    
    /// Maximum number of price points to store in history
    const MAX_PRICE_HISTORY_SIZE: u64 = 50;
    
    /// Minimum number of prices required for statistical analysis
    const MIN_PRICES_FOR_ANALYSIS: u64 = 10;

    // ===== VALIDATION METHOD TOGGLES =====
    
    /// Enable oracle-pool deviation validation by default
    const ENABLE_ORACLE_POOL_VALIDATION: bool = true;
    
    /// Enable oracle-history deviation validation by default
    const ENABLE_ORACLE_HISTORY_VALIDATION: bool = true;
    
    /// Enable statistical anomaly detection by default
    const ENABLE_STATISTICAL_VALIDATION: bool = true;

    // ===== MULTI-ORACLE VALIDATION THRESHOLDS =====
    
    /// Warning deviation threshold in basis points (2500 = 25% with BASIS_POINTS_DENOMINATOR = 10000)
    const WARNING_DEVIATION_BPS: u64 = 2500;
    
    /// Critical deviation threshold in basis points (5000 = 50% with BASIS_POINTS_DENOMINATOR = 10000)
    const CRITICAL_DEVIATION_BPS: u64 = 5000;
    
    /// Emergency deviation threshold in basis points (7500 = 75% with BASIS_POINTS_DENOMINATOR = 10000)
    const EMERGENCY_DEVIATION_BPS: u64 = 7500;

    // ===== HISTORY DEVIATION THRESHOLDS =====
    
    /// Warning deviation threshold from history in basis points (1000 = 10% with BASIS_POINTS_DENOMINATOR = 10000)
    const WARNING_HISTORY_DEVIATION_BPS: u64 = 1000;
    
    /// Critical deviation threshold from history in basis points (2000 = 20% with BASIS_POINTS_DENOMINATOR = 10000)
    const CRITICAL_HISTORY_DEVIATION_BPS: u64 = 2000;
    
    /// Emergency deviation threshold from history in basis points (3000 = 30% with BASIS_POINTS_DENOMINATOR = 10000)
    const EMERGENCY_HISTORY_DEVIATION_BPS: u64 = 3000;

    // ===== STATISTICAL ANALYSIS THRESHOLDS =====
    
    /// Warning Z-score threshold (25000 = 2.5, scaled by BASIS_POINTS_DENOMINATOR = 10000)
    const WARNING_ZSCORE_THRESHOLD: u64 = 25000;
    
    /// Critical Z-score threshold (30000 = 3.0, scaled by BASIS_POINTS_DENOMINATOR = 10000)
    const CRITICAL_ZSCORE_THRESHOLD: u64 = 30000;
    
    /// Emergency Z-score threshold (40000 = 4.0, scaled by BASIS_POINTS_DENOMINATOR = 10000)
    const EMERGENCY_ZSCORE_THRESHOLD: u64 = 40000;

    // ===== CIRCUIT BREAKER THRESHOLDS =====
    
    /// Critical anomaly threshold (2 anomalies trigger critical)
    const CRITICAL_ANOMALY_THRESHOLD: u64 = 3;
    
    /// Emergency anomaly threshold (3 anomalies trigger emergency)
    const EMERGENCY_ANOMALY_THRESHOLD: u64 = 2;

    // ===== ESCALATION CONTROL =====
    
    /// Enable escalation for critical level anomalies
    const ENABLE_CRITICAL_ESCALATION: bool = false;
    
    /// Enable escalation for emergency level anomalies
    const ENABLE_EMERGENCY_ESCALATION: bool = true;

    // ===== TIME-BASED CONFIGURATION =====
    
    /// Anomaly cooldown period in milliseconds (300000 = 5 minutes)
    const ANOMALY_COOLDOWN_PERIOD_MS: u64 = 300000;
    
    /// Maximum age of oracle price after its last update in aggregator in milliseconds (60000 = 1 minute)
    const MAX_PRICE_AGE_MS: u64 = 60000;
    
    /// Maximum age of prices stored in price history in milliseconds (7200000 = 2 hour)
    const MAX_PRICE_HISTORY_AGE_MS: u64 = 7200000;
    
    /// Minimum interval between price history entries in milliseconds (60000 = 1 minute)
    const MIN_PRICE_INTERVAL_MS: u64 = 60000;

    // ===== Q64 FORMAT CONSTANTS =====
    
    /// Q64 format shift (2^64)
    const Q64_SHIFT: u128 = 1 << 64;

    // ===== GETTER METHODS =====

    /// Get anomaly level normal
    public fun get_anomaly_level_normal(): u8 { ANOMALY_LEVEL_NORMAL }
    
    /// Get anomaly level warning
    public fun get_anomaly_level_warning(): u8 { ANOMALY_LEVEL_WARNING }
    
    /// Get anomaly level critical
    public fun get_anomaly_level_critical(): u8 { ANOMALY_LEVEL_CRITICAL }
    
    /// Get anomaly level emergency
    public fun get_anomaly_level_emergency(): u8 { ANOMALY_LEVEL_EMERGENCY }

    /// Get anomaly flag none
    public fun get_anomaly_flag_none(): u8 { ANOMALY_FLAG_NONE }
    
    /// Get anomaly flag deviation
    public fun get_anomaly_flag_deviation(): u8 { ANOMALY_FLAG_DEVIATION }
    
    /// Get anomaly flag statistical
    public fun get_anomaly_flag_statistical(): u8 { ANOMALY_FLAG_STATISTICAL }

    /// Get basis points denominator
    public fun get_basis_points_denominator(): u64 { BASIS_POINTS_DENOMINATOR }

    /// Get Z-score scaling factor
    public fun get_zscore_scaling_factor(): u64 { ZSCORE_SCALING_FACTOR }

    /// Get max price history size
    public fun get_max_price_history_size(): u64 { MAX_PRICE_HISTORY_SIZE }

    /// Get min prices for analysis
    public fun get_min_prices_for_analysis(): u64 { MIN_PRICES_FOR_ANALYSIS }

    /// Get warning deviation bps
    public fun get_warning_deviation_bps(): u64 { WARNING_DEVIATION_BPS }

    /// Get critical deviation bps
    public fun get_critical_deviation_bps(): u64 { CRITICAL_DEVIATION_BPS }

    /// Get emergency deviation bps
    public fun get_emergency_deviation_bps(): u64 { EMERGENCY_DEVIATION_BPS }

    /// Get warning history deviation bps
    public fun get_warning_history_deviation_bps(): u64 { WARNING_HISTORY_DEVIATION_BPS }

    /// Get critical history deviation bps
    public fun get_critical_history_deviation_bps(): u64 { CRITICAL_HISTORY_DEVIATION_BPS }

    /// Get emergency history deviation bps
    public fun get_emergency_history_deviation_bps(): u64 { EMERGENCY_HISTORY_DEVIATION_BPS }

    /// Get enable oracle pool validation
    public fun get_enable_oracle_pool_validation(): bool { ENABLE_ORACLE_POOL_VALIDATION }

    /// Get enable oracle history validation
    public fun get_enable_oracle_history_validation(): bool { ENABLE_ORACLE_HISTORY_VALIDATION }

    /// Get enable statistical validation
    public fun get_enable_statistical_validation(): bool { ENABLE_STATISTICAL_VALIDATION }

    /// Get warning zscore threshold
    public fun get_warning_zscore_threshold(): u64 { WARNING_ZSCORE_THRESHOLD }

    /// Get critical zscore threshold
    public fun get_critical_zscore_threshold(): u64 { CRITICAL_ZSCORE_THRESHOLD }

    /// Get emergency zscore threshold
    public fun get_emergency_zscore_threshold(): u64 { EMERGENCY_ZSCORE_THRESHOLD }

    /// Get critical anomaly threshold
    public fun get_critical_anomaly_threshold(): u64 { CRITICAL_ANOMALY_THRESHOLD }

    /// Get emergency anomaly threshold
    public fun get_emergency_anomaly_threshold(): u64 { EMERGENCY_ANOMALY_THRESHOLD }

    /// Get enable critical escalation
    public fun get_enable_critical_escalation(): bool { ENABLE_CRITICAL_ESCALATION }

    /// Get enable emergency escalation
    public fun get_enable_emergency_escalation(): bool { ENABLE_EMERGENCY_ESCALATION }

    /// Get anomaly cooldown period ms
    public fun get_anomaly_cooldown_period_ms(): u64 { ANOMALY_COOLDOWN_PERIOD_MS }

    /// Get max price age ms
    public fun get_max_price_age_ms(): u64 { MAX_PRICE_AGE_MS }
    
    /// Get max price history age ms
    public fun get_max_price_history_age_ms(): u64 { MAX_PRICE_HISTORY_AGE_MS }

    /// Get min price interval ms
    public fun get_min_price_interval_ms(): u64 { MIN_PRICE_INTERVAL_MS }

    /// Get Q64 shift
    public fun get_q64_shift(): u128 { Q64_SHIFT }
}

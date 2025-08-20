# 🛡️ Price Monitor Module

## Overview

The `price_monitor` module provides comprehensive protection against oracle compromise through multi-layered anomaly detection and automatic circuit breaker activation.

## Core Features

### 1. Multi-Oracle Validation
- Comparison of external oracle prices with internal pool prices
- Detection of deviations with configurable thresholds
- Thresholds: Warning (25%), Critical (50%), Emergency (75%)

### 2. Statistical Anomaly Detection
- Analysis of historical price data (last 50-70 updates)
- Z-Score analysis for detecting statistical anomalies
- Adaptive thresholds based on market volatility

### 3. Circuit Breaker System
- Automatic activation of protective mechanisms
- Three protection levels: Warning, Critical, Emergency
- Instant response to threats (1-30 seconds)

## Architecture

### Core Structures

**Note**: For gas optimization, `vector<PricePoint>` is used instead of `Table<u64, PricePoint>` because:
- The number of records is small (50-70)
- Vector provides fast access to elements
- Efficient addition of new records and removal of old ones
- Lower gas overhead

```move
// Main price monitor
struct PriceMonitor has store, key {
    config: PriceMonitorConfig,           // Configuration
    price_history: vector<PricePoint>,    // Price history (vector for efficiency)
    max_history_size: u64,                // Maximum history size
    anomaly_count: u64,                   // Anomaly counter
    is_emergency_paused: bool,            // Pause status
    pause_timestamp_ms: u64,              // Pause activation time
    pause_reason: vector<u8>,             // Pause reason
    pause_level: u8,                      // Pause level
}

// Monitoring configuration
struct PriceMonitorConfig has store, drop {
    warning_deviation_bps: u64,           // Warning threshold (25%)
    critical_deviation_bps: u64,          // Critical threshold (50%)
    emergency_deviation_bps: u64,         // Emergency threshold (75%)
    warning_zscore_threshold: u64,        // Warning Z-Score (2.5)
    critical_zscore_threshold: u64,       // Critical Z-Score (3.0)
    emergency_zscore_threshold: u64,      // Emergency Z-Score (4.0)
}

// Price point with metadata
struct PricePoint has store, drop {
    oracle_price_q64: u128,               // Oracle price
    pool_price_q64: u128,                 // Pool price
    deviation_bps: u64,                   // Deviation in basis points
    z_score: u64,                         // Anomaly Z-Score
    timestamp_ms: u64,                    // Timestamp
    anomaly_level: u8,                    // Anomaly level
    anomaly_flags: u8,                    // Anomaly type flags
}
```

### Capabilities

```move
// Capability for managing the monitor
struct PriceMonitorCap has store, key {
    id: UID,
    monitor_id: ID,
}

// Capability for emergency operations
struct EmergencyCap has store, key {
    id: UID,
    monitor_id: ID,
}
```

## Usage

### Creating a Monitor

```move
let (monitor, monitor_cap, emergency_cap) = price_monitor::create_price_monitor(ctx);
```

### Price Validation

```move
let validation_result = price_monitor::validate_price(
    &mut monitor,
    oracle_price_q64,
    pool_price_q64,
    clock
);

if (!validation_result.is_valid) {
    // Activate protective measures
    // validation_result.anomaly_level contains threat level
    // validation_result.recommendation contains recommendations
};
```

### Emergency Operations

```move
// Emergency pause
price_monitor::emergency_pause(
    &mut monitor, 
    &emergency_cap, 
    b"ORACLE_COMPROMISED", 
    clock
);

// Resume operation
price_monitor::emergency_resume(&mut monitor, &emergency_cap, clock);
```

## Events

The module emits the following events for off-chain monitoring:

- `EventPriceAnomalyDetected` - price anomaly detected
- `EventCircuitBreakerActivated` - circuit breaker activated
- `EventCircuitBreakerDeactivated` - circuit breaker deactivated
- `EventPriceValidated` - price successfully validated
- `EventPriceHistoryUpdated` - price history updated

## Configuration

### Default Thresholds

- **Deviation (oracle-pool discrepancy)**:
  - Warning: 25% (2500 basis points)
  - Critical: 50% (5000 basis points)
  - Emergency: 75% (7500 basis points)

- **Z-Score (statistical anomalies)**:
  - Warning: 2.5 (250)
  - Critical: 3.0 (300)
  - Emergency: 4.0 (400)

- **Circuit Breaker**:
  - Warning: 1 anomaly
  - Critical: 2 anomalies
  - Emergency: 3 anomalies

- **Time Parameters**:
  - Minimum interval between price history entries: 1 minute (60000 ms)
  - Maximum price age: 1 minute (60000 ms)
  - Anomaly cooldown period: 5 minutes (300000 ms)

### Threshold Configuration

```move
let new_config = PriceMonitorConfig {
    warning_deviation_bps: 2000,      // 20%
    critical_deviation_bps: 4000,     // 40%
    emergency_deviation_bps: 6000,    // 60%
    // ... other parameters
};

price_monitor::update_config(&mut monitor, &monitor_cap, new_config);
```

### Time Parameter Configuration

```move
// Update time parameters
price_monitor::update_time_config(
    &mut monitor,
    120000,  // max_price_age_ms: 2 minutes
    30000,   // min_price_interval_ms: 30 seconds
    100,     // max_price_history_size: 100 entries
    15,      // min_prices_for_analysis: 15 prices for analysis
    ctx
);
```

## Integration with Existing Contracts

### In gauge.move

```move
// In the sync_o_sail_distribution_price method
let validation_result = price_monitor::validate_price(
    &mut price_monitor,
    oracle_price_q64,
    pool_price_q64,
    clock
);

if (!validation_result.is_valid) {
    // Block price update
    // Activate protective measures
    return;
};

// Continue normal operation
gauge.sync_o_sail_distribution_price_internal(pool, oracle_price_q64, clock);
```

## Security

- **Capabilities**: separation of rights between normal management and emergency operations
- **Isolation**: each monitor operates independently
- **Audit**: all actions are logged through events

## Testing

```bash
# Run tests
sui move test

# Test in devnet
sui move build --skip-dependency-verification
sui client publish --gas-budget 10000000
```

## License

© 2025 Metabyte Labs, Inc. All Rights Reserved.

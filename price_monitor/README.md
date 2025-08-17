# 🛡️ Price Monitor Module

## Обзор

Модуль `price_monitor` предоставляет комплексную защиту от компрометации оракулов через многоуровневое обнаружение аномалий и автоматическую активацию защитных механизмов.

## Основные возможности

### 1. Multi-Oracle Validation
- Сравнение цен внешнего оракула с внутренними ценами пулов
- Выявление расхождений с настраиваемыми порогами
- Пороги: Warning (25%), Critical (50%), Emergency (75%)

### 2. Statistical Anomaly Detection
- Анализ исторических данных цен (последние 50-70 обновлений)
- Z-Score анализ для выявления статистических аномалий
- Адаптивные пороги на основе волатильности рынка

### 3. Circuit Breaker System
- Автоматическая активация защитных механизмов
- Три уровня защиты: Warning, Critical, Emergency
- Мгновенная реакция на угрозы (1-30 секунд)

## Архитектура

### Основные структуры

**Примечание**: Для оптимизации газа используется `vector<PricePoint>` вместо `Table<u64, PricePoint>`, так как:
- Количество записей небольшое (50-70)
- Вектор обеспечивает быстрый доступ к элементам
- Эффективное добавление новых записей и удаление старых
- Меньше накладных расходов на газ

```move
// Основной монитор цен
struct PriceMonitor has store, key {
    config: PriceMonitorConfig,           // Конфигурация
    price_history: vector<PricePoint>,    // История цен (вектор для эффективности)
    max_history_size: u64,                // Максимальный размер истории
    anomaly_count: u64,                   // Счетчик аномалий
    is_emergency_paused: bool,            // Статус паузы
    pause_timestamp_ms: u64,              // Время активации паузы
    pause_reason: vector<u8>,             // Причина паузы
    pause_level: u8,                      // Уровень паузы
}

// Конфигурация мониторинга
struct PriceMonitorConfig has store, drop {
    warning_deviation_bps: u64,           // Порог предупреждения (25%)
    critical_deviation_bps: u64,          // Критический порог (50%)
    emergency_deviation_bps: u64,         // Экстренный порог (75%)
    warning_zscore_threshold: u64,        // Z-Score предупреждения (2.5)
    critical_zscore_threshold: u64,       // Критический Z-Score (3.0)
    emergency_zscore_threshold: u64,      // Экстренный Z-Score (4.0)
}

// Точка цены с метаданными
struct PricePoint has store, drop {
    oracle_price_q64: u128,               // Цена оракула
    pool_price_q64: u128,                 // Цена пула
    deviation_bps: u64,                   // Расхождение в базисных пунктах
    z_score: u64,                         // Z-Score аномалии
    timestamp_ms: u64,                    // Временная метка
    anomaly_level: u8,                    // Уровень аномалии
    anomaly_flags: u8,                    // Флаги типов аномалий
}
```

### Capabilities

```move
// Capability для управления монитором
struct PriceMonitorCap has store, key {
    id: UID,
    monitor_id: ID,
}

// Capability для экстренных операций
struct EmergencyCap has store, key {
    id: UID,
    monitor_id: ID,
}
```

## Использование

### Создание монитора

```move
let (monitor, monitor_cap, emergency_cap) = price_monitor::create_price_monitor(ctx);
```

### Валидация цен

```move
let validation_result = price_monitor::validate_price(
    &mut monitor,
    oracle_price_q64,
    pool_price_q64,
    clock
);

if (!validation_result.is_valid) {
    // Активировать защитные меры
    // validation_result.anomaly_level содержит уровень угрозы
    // validation_result.recommendation содержит рекомендации
};
```



### Экстренные операции

```move
// Экстренная пауза
price_monitor::emergency_pause(
    &mut monitor, 
    &emergency_cap, 
    b"ORACLE_COMPROMISED", 
    clock
);

// Возобновление работы
price_monitor::emergency_resume(&mut monitor, &emergency_cap, clock);
```

## События

Модуль эмитит следующие события для off-chain мониторинга:

- `EventPriceAnomalyDetected` - обнаружена аномалия цены
- `EventCircuitBreakerActivated` - активирован circuit breaker
- `EventCircuitBreakerDeactivated` - деактивирован circuit breaker
- `EventPriceValidated` - цена успешно валидирована
- `EventPriceHistoryUpdated` - обновлена история цен

## Конфигурация

### Пороги по умолчанию

- **Deviation (расхождение оракул-пул)**:
  - Warning: 25% (2500 базисных пунктов)
  - Critical: 50% (5000 базисных пунктов)
  - Emergency: 75% (7500 базисных пунктов)

- **Z-Score (статистические аномалии)**:
  - Warning: 2.5 (250)
  - Critical: 3.0 (300)
  - Emergency: 4.0 (400)

- **Circuit Breaker**:
  - Warning: 1 аномалия
  - Critical: 2 аномалии
  - Emergency: 3 аномалии

### Настройка порогов

```move
let new_config = PriceMonitorConfig {
    warning_deviation_bps: 2000,      // 20%
    critical_deviation_bps: 4000,     // 40%
    emergency_deviation_bps: 6000,    // 60%
    // ... остальные параметры
};

price_monitor::update_config(&mut monitor, &monitor_cap, new_config);
```

## Интеграция с существующими контрактами

### В gauge.move

```move
// В методе sync_o_sail_distribution_price
let validation_result = price_monitor::validate_price(
    &mut price_monitor,
    oracle_price_q64,
    pool_price_q64,
    clock
);

if (!validation_result.is_valid) {
    // Блокировать обновление цены
    // Активировать защитные меры
    return;
};

// Продолжить нормальную работу
gauge.sync_o_sail_distribution_price_internal(pool, oracle_price_q64, clock);
```

## Безопасность

- **Capabilities**: разделение прав между обычным управлением и экстренными операциями
- **Изоляция**: каждый монитор работает независимо
- **Аудит**: все действия логируются через события

## Тестирование

```bash
# Запуск тестов
sui move test

# Тестирование в devnet
sui move build --skip-dependency-verification
sui client publish --gas-budget 10000000
```

## Лицензия

© 2025 Metabyte Labs, Inc. All Rights Reserved.

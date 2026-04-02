module vault::port_oracle {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use pyth::price_info::{Self, PriceInfo, PriceInfoObject};
    use pyth::state::State;
    use pyth::hot_potato_vector::{Self, HotPotatoVector};
    use pyth::pyth::{Self, get_price_no_older_than, update_single_price_feed};
    use switchboard::aggregator::{Aggregator};

    const PYTH_PRICE_DECIMAL: u8 = 10;
    
    public struct PortOracle has key {
        id: sui::object::UID,
        update_price_fee: sui::balance::Balance<sui::sui::SUI>,
        prices: sui::table::Table<std::type_name::TypeName, Price>,
        oracle_infos: sui::table::Table<std::type_name::TypeName, OracleInfo>,
    }
    
    public struct OracleInfo has drop, store {
        // pyth
        price_pyth_feed_id: Option<vector<u8>>,
        price_info_object_id: Option<ID>,

        // switchboard
        price_aggregator_id: Option<ID>,

        usd_price_age: u64, // secs
        coin_decimals: u8,
    }
    
    public struct Price has copy, drop, store {
        price: u64,
        coin_decimals: u8,
        last_update_time: u64,
    }
    
    public struct InitEvent has copy, drop {
        pyth_oracle_id: sui::object::ID,
    }
    
    public struct AddPythOracleInfoEvent has copy, drop {
        type_name: std::type_name::TypeName,
        price_pyth_feed_id: vector<u8>,
        price_info_object_id: sui::object::ID,
        usd_price_age: u64,
    }

    public struct AddSwitchboardOracleInfoEvent has copy, drop {
        type_name: std::type_name::TypeName,
        price_aggregator_id: ID,
        usd_price_age: u64,
    }
    
    public struct RemovePythOracleInfoEvent has copy, drop {
        type_name: std::type_name::TypeName,
    }
    
    public struct UpdateOraclePriceAgeEvent has copy, drop {
        type_name: std::type_name::TypeName,
        old_usd_price_age: u64,
        new_usd_price_age: u64,
    }
    
    public struct DepositFeeEvent has copy, drop {
        amount: u64,
    }
    
    public struct UpdatePriceEvent has copy, drop {
        coin_type: std::type_name::TypeName,
        price: u64,
        last_update_time: u64,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let port_oracle = PortOracle{ 
            id               : sui::object::new(ctx), 
            update_price_fee : sui::balance::zero<sui::sui::SUI>(), 
            prices           : sui::table::new<std::type_name::TypeName, Price>(ctx), 
            oracle_infos     : sui::table::new<std::type_name::TypeName, OracleInfo>(ctx),
        };
        let event = InitEvent{pyth_oracle_id: sui::object::id<PortOracle>(&port_oracle)};
        sui::event::emit<InitEvent>(event);
        sui::transfer::share_object<PortOracle>(port_oracle);
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let port_oracle = PortOracle{ 
            id               : sui::object::new(ctx), 
            update_price_fee : sui::balance::zero<sui::sui::SUI>(), 
            prices           : sui::table::new<std::type_name::TypeName, Price>(ctx), 
            oracle_infos     : sui::table::new<std::type_name::TypeName, OracleInfo>(ctx),
        };
        sui::transfer::share_object<PortOracle>(port_oracle);
    }
    
    public fun get_price<CoinType>(port_oracle: &PortOracle, clock: &sui::clock::Clock) : Price { 
        let type_name = std::type_name::with_defining_ids<CoinType>();
        assert!(port_oracle.prices.contains(type_name), vault::error::price_not_exists());
        let price = *port_oracle.prices.borrow(type_name);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price.last_update_time, vault::error::price_not_updated());
        price
    }

    public fun get_price_by_type(port_oracle: &PortOracle, type_name: std::type_name::TypeName, clock: &sui::clock::Clock) : Price { 
        assert!(port_oracle.prices.contains(type_name), vault::error::price_not_exists()); 
        let price = *port_oracle.prices.borrow(type_name);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price.last_update_time, vault::error::price_not_updated());
        price
    }

    public fun get_sqrt_price_from_oracle<CoinType1, CoinType2>(port_oracle: &PortOracle, clock: &sui::clock::Clock) : u128 {
        let price_1 = port_oracle.get_price<CoinType1>(clock);
        let price_2 = port_oracle.get_price<CoinType2>(clock);
        let (price_1_in_quote, _) = calculate_prices(&price_1, &price_2);
        vault::vault_utils::price_to_sqrt_price(price_1_in_quote, PYTH_PRICE_DECIMAL)
    }

    public fun calculate_prices(price_1: &Price, price_2: &Price) : (u64, u64) {
        calculate_prices_from_base_quote(price_1.price, price_2.price, price_1.coin_decimals, price_2.coin_decimals)
    }
    
    /// Adds Pyth oracle info to the port oracle
    /// 
    /// # Arguments
    /// * `port_oracle` – oracle instance storing cached prices
    /// * `global_config` – global configuration used for version validation
    /// * `state` – state of the Pyth oracle
    /// * `coin_metadata` – metadata of the coin
    /// * `price_pyth_feed_id` – price feed id of the Pyth oracle
    /// * `usd_price_age` – price age in seconds
    /// * `ctx` – transaction context
    public fun add_pyth_oracle_info<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        state: &State, 
        coin_metadata: &sui::coin::CoinMetadata<CoinType>, 
        price_pyth_feed_id: vector<u8>, 
        usd_price_age: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx));
        let type_name = std::type_name::with_defining_ids<CoinType>();
        let price_info_object_id = state.get_price_info_object_id(price_pyth_feed_id);

        let oracle_info = if (port_oracle.oracle_infos.contains(type_name)) {
            let mut _oracle_info = port_oracle.oracle_infos.remove(type_name);
            assert!(_oracle_info.price_aggregator_id.is_none(), vault::error::switchboard_oracle_info_already_exists()); 
            _oracle_info.price_pyth_feed_id = option::some(price_pyth_feed_id);
            _oracle_info.price_info_object_id = option::some(price_info_object_id);
            _oracle_info
        } else {
            OracleInfo{
                price_pyth_feed_id   : option::some(price_pyth_feed_id),
                price_info_object_id : option::some(price_info_object_id), 
                price_aggregator_id  : option::none<ID>(),
                usd_price_age        : usd_price_age,
                coin_decimals        : sui::coin::get_decimals<CoinType>(coin_metadata),
            }
        };
        
        port_oracle.oracle_infos.add(type_name, oracle_info);

        let event = AddPythOracleInfoEvent{
            type_name            : type_name, 
            price_pyth_feed_id        : price_pyth_feed_id, 
            price_info_object_id : price_info_object_id, 
            usd_price_age        : usd_price_age,
        };
        sui::event::emit<AddPythOracleInfoEvent>(event);
    }

    /// Adds switchboard oracle info to the port oracle
    /// 
    /// # Arguments
    /// * `port_oracle` – oracle instance storing cached prices
    /// * `global_config` – global configuration used for version validation
    /// * `coin_metadata` – metadata of the coin
    /// * `aggregator` – aggregator of the switchboard oracle
    /// * `usd_price_age` – price age in seconds
    /// * `ctx` – transaction context
    public fun add_switchboard_oracle_info<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        coin_metadata: &sui::coin::CoinMetadata<CoinType>, 
        aggregator: &Aggregator,
        usd_price_age: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx));
        let type_name = std::type_name::with_defining_ids<CoinType>();
        let oracle_info = if (port_oracle.oracle_infos.contains(type_name)) {

            let mut _oracle_info = port_oracle.oracle_infos.remove(type_name);
            assert!(_oracle_info.price_pyth_feed_id.is_none(), vault::error::pyth_oracle_info_already_exists()); 
            _oracle_info.price_aggregator_id = option::some(object::id(aggregator));
            _oracle_info
        } else {
            OracleInfo{
                price_pyth_feed_id        : option::none<vector<u8>>(),
                price_info_object_id : option::none<ID>(), 
                price_aggregator_id  : option::some(object::id(aggregator)),
                usd_price_age        : usd_price_age,
                coin_decimals        : sui::coin::get_decimals<CoinType>(coin_metadata),
            }
        };

        port_oracle.oracle_infos.add(type_name, oracle_info);

        let event = AddSwitchboardOracleInfoEvent{
            type_name            : type_name, 
            price_aggregator_id  : object::id(aggregator), 
            usd_price_age        : usd_price_age,
        };
        sui::event::emit<AddSwitchboardOracleInfoEvent>(event);
    }

    public fun remove_pyth_oracle_info<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists()); 
        let mut oracle_info = port_oracle.oracle_infos.remove(type_name);

        if (oracle_info.price_aggregator_id.is_some()) {
            oracle_info.price_pyth_feed_id = option::none<vector<u8>>();
            oracle_info.price_info_object_id = option::none<ID>();

            port_oracle.oracle_infos.add(type_name, oracle_info);
        };

        let event = RemovePythOracleInfoEvent{type_name: type_name}; 
        sui::event::emit<RemovePythOracleInfoEvent>(event);
    }

    public fun remove_switchboard_oracle_info<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists()); 
        let mut oracle_info = port_oracle.oracle_infos.remove(type_name);

        if (oracle_info.price_pyth_feed_id.is_some()) {
            oracle_info.price_aggregator_id = option::none<ID>();

            port_oracle.oracle_infos.add(type_name, oracle_info);
        };

        let event = RemovePythOracleInfoEvent{type_name: type_name}; 
        sui::event::emit<RemovePythOracleInfoEvent>(event);
    }
    
    public fun calculate_oracle_prices<CoinType1, CoinType2>(
        port_oracle: &PortOracle, 
        clock: &sui::clock::Clock
    ) : (u64, u64, u64, u64) {
        let type_name_1 = std::type_name::with_defining_ids<CoinType1>(); 
        let type_name_2 = std::type_name::with_defining_ids<CoinType2>();
        assert!(port_oracle.oracle_infos.contains(type_name_1), vault::error::oracle_info_not_exists());
        assert!(port_oracle.oracle_infos.contains(type_name_2), vault::error::oracle_info_not_exists());

        let price_1 = *port_oracle.prices.borrow(type_name_1);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price_1.last_update_time, vault::error::price_not_updated());
        
        let price_2 = *port_oracle.prices.borrow(type_name_2);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price_2.last_update_time, vault::error::price_not_updated());
        
        let (price_1_in_quote, price_2_in_base) = calculate_prices_from_base_quote(
            price_1.price, 
            price_2.price, 
            price_1.coin_decimals, 
            price_2.coin_decimals
        );

        (price_1_in_quote, price_2_in_base, price_1.price, price_2.price)
    }
    
    fun calculate_prices_from_base_quote(
        price_1: u64, 
        price_2: u64, 
        coin_decimals_1: u8, 
        coin_decimals_2: u8
    ) : (u64, u64) {
        let price_1_in_quote = if (PYTH_PRICE_DECIMAL + coin_decimals_2 < coin_decimals_1) {
            let price_u128 = integer_mate::full_math_u128::mul_div_floor(
                integer_mate::full_math_u128::mul_div_floor(
                    (price_1 as u128), 
                    1, 
                    (price_2 as u128)
                ),
                1,
                std::u64::pow(10, coin_decimals_1 - (PYTH_PRICE_DECIMAL + coin_decimals_2)) as u128
            );

            price_u128 as u64
        } else {
            integer_mate::full_math_u64::mul_div_floor(
                price_1, 
                std::u64::pow(10, PYTH_PRICE_DECIMAL + coin_decimals_2 - coin_decimals_1), 
                price_2
            )
        };

        let price_2_in_base = if (PYTH_PRICE_DECIMAL + coin_decimals_1 < coin_decimals_2) {
            let price_u128 = integer_mate::full_math_u128::mul_div_floor(
                integer_mate::full_math_u128::mul_div_floor(
                    (price_2 as u128),
                    1, 
                    (price_1 as u128)
                ),
                1,
                std::u64::pow(10, coin_decimals_2 - (PYTH_PRICE_DECIMAL + coin_decimals_1)) as u128
            );

            price_u128 as u64
        } else {
            integer_mate::full_math_u64::mul_div_floor(
                price_2, 
                std::u64::pow(10, PYTH_PRICE_DECIMAL + coin_decimals_1 - coin_decimals_2), 
                price_1
            )
        };
        (
            price_1_in_quote,
            price_2_in_base
        )
    }
    
    public fun coin_decimals(oracle_info: &OracleInfo) : u8 { 
        oracle_info.coin_decimals
    }
    
    public fun contain_oracle_info(port_oracle: &PortOracle, type_name: std::type_name::TypeName) : bool {
        port_oracle.oracle_infos.contains(type_name)
    }
    
    public fun deposit_fee(
        port_oracle: &mut PortOracle, 
        sui_coin: &mut sui::coin::Coin<sui::sui::SUI>, 
        amount: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        port_oracle.update_price_fee.join(
            sui_coin.split(amount, ctx).into_balance()
        );
        let event = DepositFeeEvent{amount: amount};
        sui::event::emit<DepositFeeEvent>(event);
    }
    
    public fun last_update_time(price: &Price) : u64 {
        price.last_update_time
    }
    
    public fun new_price(price: u64, coin_decimals: u8) : Price {
        Price{
            price            : price, 
            coin_decimals    : coin_decimals, 
            last_update_time : 0,
        }
    }
    
    public fun oracle_info<CoinType>(port_oracle: &PortOracle) : &OracleInfo {
        port_oracle.oracle_infos.borrow(std::type_name::with_defining_ids<CoinType>())
    }
    
    public fun price_coin_decimal(price: &Price) : u8 {
        price.coin_decimals
    }
    
    public fun price_pyth_feed_id(oracle_info: &OracleInfo) : Option<vector<u8>> {
        oracle_info.price_pyth_feed_id
    }

    public fun get_price_pyth_feed_id<CoinType>(port_oracle: &PortOracle) : Option<vector<u8>> {
        port_oracle.oracle_infos.borrow(std::type_name::with_defining_ids<CoinType>()).price_pyth_feed_id
    }

    public fun price_aggregator_id(oracle_info: &OracleInfo) : Option<ID> {
        oracle_info.price_aggregator_id
    }

    public fun get_price_aggregator_id<CoinType>(port_oracle: &PortOracle) : Option<ID> {
        oracle_info<CoinType>(port_oracle).price_aggregator_id
    }
    
    public fun price_info_object_id(oracle_info: &OracleInfo) : Option<ID> {
        oracle_info.price_info_object_id
    }
    
    public fun price_multiplier_decimal() : u8 {
        PYTH_PRICE_DECIMAL
    }
    
    public fun price_value(price: &Price) : u64 {
        price.price
    }
    
    public(package) fun split_fee(port_oracle: &mut PortOracle, amount: u64) : sui::balance::Balance<sui::sui::SUI> {
        assert!(port_oracle.update_price_fee.value() >= amount, vault::error::update_price_fee_not_enough());
        port_oracle.update_price_fee.split(amount)
    }
    
    public fun update_price<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        state: &State, 
        price_info_vector: HotPotatoVector<PriceInfo>, 
        price_info_object: &mut PriceInfoObject, 
        clock: &sui::clock::Clock, 
        ctx: &mut sui::tx_context::TxContext
    ) : HotPotatoVector<PriceInfo> {
        vault::vault_config::checked_package_version(global_config);
        let price_info_vector_update = update_single_price_feed(
            state, 
            price_info_vector, 
            price_info_object, 
            sui::coin::from_balance<sui::sui::SUI>(split_fee(port_oracle, state.get_base_update_fee()), ctx), 
            clock
        );
        let type_name = std::type_name::with_defining_ids<CoinType>();
        if (port_oracle.oracle_infos.contains(type_name)) {
            let price = update_price_from_type<CoinType>(port_oracle, price_info_object, clock);
            let event = UpdatePriceEvent{
                coin_type        : type_name, 
                price            : price.price, 
                last_update_time : price.last_update_time,
            };
            sui::event::emit<UpdatePriceEvent>(event);
        };

        price_info_vector_update
    }

    /// Synchronises the cached price inside `PortOracle` when an off-chain updater
    /// has already refreshed the corresponding `PriceInfoObject` in the same transaction.
    ///
    /// Performs a package version check, verifies that oracle configuration for the
    /// requested coin exists, and ensures the supplied price info is not older than
    /// the configured `usd_price_age`. Emits an `UpdatePriceEvent` so downstream
    /// contracts can safely consume the fresh quote without calling Pyth on-chain.
    ///
    /// # Arguments
    /// * `port_oracle` – oracle instance storing cached prices
    /// * `global_config` – global configuration used for version validation
    /// * `price_info_object` – externally updated price object for the coin
    /// * `clock` – Sui clock providing the current timestamp
    ///
    /// # Type Parameters
    /// * `CoinType` – coin whose cached price should be synchronised
    ///
    /// # Aborts
    /// * if oracle info for the given coin is missing
    /// * if the provided price object is older than `usd_price_age`
    public fun external_update_price_from_pyth<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        price_info_object: &PriceInfoObject, 
        clock: &sui::clock::Clock
    ) {
        vault::vault_config::checked_package_version(global_config);
        let type_name = std::type_name::with_defining_ids<CoinType>();
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());

        let oracle_info = port_oracle.oracle_infos.borrow(type_name);
        let price_info = price_info_object.get_price_info_from_price_info_object();
        let price_feed_ref = price_info.get_price_feed();
        let price_timestamp = price_feed_ref.get_price().get_timestamp();
        let now = sui::clock::timestamp_ms(clock) / 1000;
        let delta = if (now >= price_timestamp) { now - price_timestamp } else { 0 };
        assert!(delta <= oracle_info.usd_price_age, vault::error::price_not_updated());

        let price = update_price_from_type<CoinType>(port_oracle, price_info_object, clock);
        let event = UpdatePriceEvent{
            coin_type        : type_name, 
            price            : price.price, 
            last_update_time : price.last_update_time,
        };
        sui::event::emit<UpdatePriceEvent>(event);
    }

    fun update_price_from_type<CoinType>(
        port_oracle: &mut PortOracle,
        price_info_object: &PriceInfoObject, 
        clock: &sui::clock::Clock
    ) : Price {
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());  
        let oracle_info = port_oracle.oracle_infos.borrow(type_name); 
        assert!(
            oracle_info.price_info_object_id.is_some() &&
            oracle_info.price_info_object_id.borrow() == sui::object::id<PriceInfoObject>(price_info_object), 
            vault::error::price_object_not_match_with_coin_type()
        ); 
        let price = Price{ 
            price            : pyth_price_from_oracle_info(price_info_object, oracle_info, clock), 
            coin_decimals    : oracle_info.coin_decimals, 
            last_update_time : sui::clock::timestamp_ms(clock) / 1000, 
        };
        if (!port_oracle.prices.contains(type_name)) {
            port_oracle.prices.add(type_name, price);
        } else {
            *sui::table::borrow_mut<std::type_name::TypeName, Price>(&mut port_oracle.prices, type_name) = price;
        };

        price
    }

    public fun pyth_price_from_oracle_info(
        price_info_object: &PriceInfoObject, 
        oracle_info: &OracleInfo, 
        clock: &sui::clock::Clock
    ) : u64 {
        let price = get_price_no_older_than(price_info_object, clock, oracle_info.usd_price_age);
        let price_info = price_info_object.get_price_info_from_price_info_object();
        let price_identifier = price_info.get_price_identifier();
        assert!(
            oracle_info.price_pyth_feed_id.is_some() &&
            oracle_info.price_pyth_feed_id.borrow() == price_identifier.get_bytes(), 
            vault::error::invalid_price_feed_id()
        ); 
        let expo = price.get_expo(); 
        let price_value = price.get_price(); 
        let magnitude = if (price_value.get_is_negative()) {
            price_value.get_magnitude_if_negative()
        } else {
            price_value.get_magnitude_if_positive()
        };
        assert!(magnitude != 0, vault::error::invalid_oracle_price());
        let price = if (expo.get_is_negative()) {
            let expo_magnitude = (expo.get_magnitude_if_negative() as u8);
            if (expo_magnitude < PYTH_PRICE_DECIMAL) {
                magnitude * std::u64::pow(10, PYTH_PRICE_DECIMAL - expo_magnitude)
            } else {
                magnitude / std::u64::pow(10, expo_magnitude - PYTH_PRICE_DECIMAL)
            }
        } else {
            magnitude * std::u64::pow(10, (expo.get_magnitude_if_positive() as u8) + PYTH_PRICE_DECIMAL)
        };
        price
    }

    public fun switchboard_price_from_oracle_info(
        aggregator: &Aggregator,
        oracle_info: &OracleInfo,
        clock: &sui::clock::Clock
    ) : u64 {
        assert!(
            oracle_info.price_aggregator_id.is_some() && 
            oracle_info.price_aggregator_id.borrow() == object::id(aggregator), 
            vault::error::switchboard_aggregator_not_match()
        );

        let price_result = aggregator.current_result();
        let price_result_time = price_result.max_timestamp_ms();
        assert!(price_result_time + (oracle_info.usd_price_age*1000) > clock.timestamp_ms(), vault::error::price_not_updated());

        let price_result_price = price_result.result();
        assert!(!price_result_price.neg(), vault::error::invalid_aggregator_price());

        let price_value = price_result_price.value();
        let price_dec = price_result_price.dec();
        assert!(price_value != 0, vault::error::invalid_oracle_price());
        
        let normalized_price = if (price_dec < PYTH_PRICE_DECIMAL) {
            price_value * (std::u64::pow(10, PYTH_PRICE_DECIMAL - price_dec) as u128)
        } else {
            price_value / (std::u64::pow(10, price_dec - PYTH_PRICE_DECIMAL) as u128)
        };
        normalized_price as u64
    }

    public fun external_update_price_from_switchboard<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        aggregator: &Aggregator, 
        clock: &sui::clock::Clock
    ) {
        vault::vault_config::checked_package_version(global_config);
        let type_name = std::type_name::with_defining_ids<CoinType>();
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());

        let oracle_info = port_oracle.oracle_infos.borrow(type_name);
        let normalized_price = switchboard_price_from_oracle_info(aggregator, oracle_info, clock);

        let price = Price{
            price            : normalized_price, 
            coin_decimals    : oracle_info.coin_decimals, 
            last_update_time : sui::clock::timestamp_ms(clock) / 1000, 
        };
        if (!port_oracle.prices.contains(type_name)) {
            port_oracle.prices.add(type_name, price);
        } else {
            *sui::table::borrow_mut<std::type_name::TypeName, Price>(&mut port_oracle.prices, type_name) = price;
        };

        let event = UpdatePriceEvent{
            coin_type        : type_name, 
            price            : price.price, 
            last_update_time : price.last_update_time,
        };
        sui::event::emit<UpdatePriceEvent>(event);
    }
    
    /// Updates the price age for a given coin type
    /// 
    /// # Arguments
    /// * `port_oracle` – oracle instance storing cached prices
    /// * `global_config` – global configuration used for version validation
    /// * `usd_price_age` – new price age in seconds
    /// * `ctx` – transaction context
    public fun update_price_age<CoinType>(
        port_oracle: &mut PortOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        usd_price_age: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(port_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());
        let oracle_info = port_oracle.oracle_infos.borrow_mut(type_name);

        let event = UpdateOraclePriceAgeEvent{ 
            type_name         : type_name, 
            old_usd_price_age : oracle_info.usd_price_age, 
            new_usd_price_age : usd_price_age, 
        };
        sui::event::emit<UpdateOraclePriceAgeEvent>(event);

        oracle_info.usd_price_age = usd_price_age;
    }
    
    public fun usd_price_age(oracle_info: &OracleInfo) : u64 {
        oracle_info.usd_price_age
    }
}
module vault::pyth_oracle {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use pyth::price_info::{Self, PriceInfo, PriceInfoObject};
    use pyth::state::State;
    use pyth::hot_potato_vector::{Self, HotPotatoVector};
    use pyth::pyth::{Self, get_price_no_older_than, update_single_price_feed};

    const PYTH_PRICE_DECIMAL: u8 = 10;
    
    public struct PythOracle has key {
        id: sui::object::UID,
        update_price_fee: sui::balance::Balance<sui::sui::SUI>,
        prices: sui::table::Table<std::type_name::TypeName, Price>,
        oracle_infos: sui::table::Table<std::type_name::TypeName, OracleInfo>,
    }
    
    public struct OracleInfo has drop, store {
        price_feed_id: vector<u8>,
        price_info_object_id: sui::object::ID,
        usd_price_age: u64,
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
    
    public struct AddOracleInfoEvent has copy, drop {
        type_name: std::type_name::TypeName,
        price_feed_id: vector<u8>,
        price_info_object_id: sui::object::ID,
        usd_price_age: u64,
    }
    
    public struct RemoveOracleInfoEvent has copy, drop {
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
        let pyth_oracle = PythOracle{ 
            id               : sui::object::new(ctx), 
            update_price_fee : sui::balance::zero<sui::sui::SUI>(), 
            prices           : sui::table::new<std::type_name::TypeName, Price>(ctx), 
            oracle_infos     : sui::table::new<std::type_name::TypeName, OracleInfo>(ctx),
        };
        let event = InitEvent{pyth_oracle_id: sui::object::id<PythOracle>(&pyth_oracle)};
        sui::event::emit<InitEvent>(event);
        sui::transfer::share_object<PythOracle>(pyth_oracle);
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let pyth_oracle = PythOracle{ 
            id               : sui::object::new(ctx), 
            update_price_fee : sui::balance::zero<sui::sui::SUI>(), 
            prices           : sui::table::new<std::type_name::TypeName, Price>(ctx), 
            oracle_infos     : sui::table::new<std::type_name::TypeName, OracleInfo>(ctx),
        };
        sui::transfer::share_object<PythOracle>(pyth_oracle);
    }
    
    public fun get_price<CoinType>(pyth_oracle: &PythOracle, clock: &sui::clock::Clock) : Price { 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(pyth_oracle.prices.contains(type_name), vault::error::price_not_exists());
        let price = *pyth_oracle.prices.borrow(type_name);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price.last_update_time, vault::error::price_not_updated());
        price
    }

    public fun get_price_by_type(pyth_oracle: &PythOracle, type_name: std::type_name::TypeName, clock: &sui::clock::Clock) : Price { 
        assert!(pyth_oracle.prices.contains(type_name), vault::error::price_not_exists()); 
        let price = *pyth_oracle.prices.borrow(type_name);
        assert!(sui::clock::timestamp_ms(clock) / 1000 == price.last_update_time, vault::error::price_not_updated());
        price
    }

    public fun get_sqrt_price_from_oracle<CoinType1, CoinType2>(pyth_oracle: &PythOracle, clock: &sui::clock::Clock) : u128 {
        let price_1 = pyth_oracle.get_price<CoinType1>(clock);
        let price_2 = pyth_oracle.get_price<CoinType2>(clock);
        let (price_1_in_quote, _) = calculate_prices(&price_1, &price_2);
        vault::vault_utils::price_to_sqrt_price(price_1_in_quote, PYTH_PRICE_DECIMAL)
    }

    public fun calculate_prices(price_1: &Price, price_2: &Price) : (u64, u64) {
        calculate_prices_from_base_quote(price_1.price, price_2.price, price_1.coin_decimals, price_2.coin_decimals)
    }
    
    public fun add_oracle_info<CoinType>(
        pyth_oracle: &mut PythOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        state: &State, 
        coin_metadata: &sui::coin::CoinMetadata<CoinType>, 
        price_feed_id: vector<u8>, 
        usd_price_age: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx));
        let type_name = std::type_name::with_defining_ids<CoinType>();
        assert!(!pyth_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_exists());
        let price_info_object_id = state.get_price_info_object_id(price_feed_id); 
        let oracle_info = OracleInfo{
            price_feed_id        : price_feed_id,
            price_info_object_id : price_info_object_id, 
            usd_price_age        : usd_price_age,
            coin_decimals        : sui::coin::get_decimals<CoinType>(coin_metadata),
        };
        pyth_oracle.oracle_infos.add(type_name, oracle_info);

        let event = AddOracleInfoEvent{
            type_name            : type_name, 
            price_feed_id        : price_feed_id, 
            price_info_object_id : price_info_object_id, 
            usd_price_age        : usd_price_age,
        };
        sui::event::emit<AddOracleInfoEvent>(event);
    }

    public fun remove_oracle_info<CoinType>(
        pyth_oracle: &mut PythOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config);
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(pyth_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists()); 
        pyth_oracle.oracle_infos.remove(type_name);

        let event = RemoveOracleInfoEvent{type_name: type_name}; 
        sui::event::emit<RemoveOracleInfoEvent>(event);
    }
    
    public fun calculate_oracle_prices<CoinType1, CoinType2>(
        pyth_oracle: &PythOracle, 
        price_info_object_1: &PriceInfoObject, 
        price_info_object_2: &PriceInfoObject, 
        clock: &sui::clock::Clock
    ) : (u64, u64, u64, u64) {
        let type_name_1 = std::type_name::with_defining_ids<CoinType1>(); 
        let type_name_2 = std::type_name::with_defining_ids<CoinType2>();
        assert!(pyth_oracle.oracle_infos.contains(type_name_1), vault::error::oracle_info_not_exists());
        assert!(pyth_oracle.oracle_infos.contains(type_name_2), vault::error::oracle_info_not_exists());
        let oracle_info_1 = pyth_oracle.oracle_infos.borrow(type_name_1);
        let oracle_info_2 = pyth_oracle.oracle_infos.borrow(type_name_2); 
        assert!(oracle_info_1.price_info_object_id == sui::object::id<PriceInfoObject>(price_info_object_1), vault::error::price_object_not_match_with_coin_type());
        assert!(oracle_info_2.price_info_object_id == sui::object::id<PriceInfoObject>(price_info_object_2), vault::error::price_object_not_match_with_coin_type());
        let price_1 = pyth_price_from_oracle_info(price_info_object_1, oracle_info_1, clock);
        let price_2 = pyth_price_from_oracle_info(price_info_object_2, oracle_info_2, clock);
        let (price_1_in_quote, price_2_in_base) = calculate_prices_from_base_quote(
            price_1, 
            price_2, 
            oracle_info_1.coin_decimals, 
            oracle_info_2.coin_decimals
        );
        (price_1_in_quote, price_2_in_base, price_1, price_2)
    }
    
    fun calculate_prices_from_base_quote(
        price_1: u64, 
        price_2: u64, 
        coin_decimals_1: u8, 
        coin_decimals_2: u8
    ) : (u64, u64) {
        (
            integer_mate::full_math_u64::mul_div_floor(
                price_1, 
                std::u64::pow(10, PYTH_PRICE_DECIMAL + coin_decimals_2 - coin_decimals_1), 
                price_2
            ), 
            integer_mate::full_math_u64::mul_div_floor(
                price_2, 
                std::u64::pow(10, PYTH_PRICE_DECIMAL + coin_decimals_1 - coin_decimals_2), 
                price_1
            )
        )
    }
    
    public fun coin_decimals(oracle_info: &OracleInfo) : u8 { 
        oracle_info.coin_decimals
    }
    
    public fun contain_oracle_info(pyth_oracle: &PythOracle, type_name: std::type_name::TypeName) : bool {
        pyth_oracle.oracle_infos.contains(type_name)
    }
    
    public fun deposit_fee(
        pyth_oracle: &mut PythOracle, 
        sui_coin: &mut sui::coin::Coin<sui::sui::SUI>, 
        amount: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        pyth_oracle.update_price_fee.join(
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
    
    public fun oracle_info<CoinType>(pyth_oracle: &PythOracle) : &OracleInfo {
        pyth_oracle.oracle_infos.borrow(std::type_name::with_defining_ids<CoinType>())
    }
    
    public fun price_coin_decimal(price: &Price) : u8 {
        price.coin_decimals
    }
    
    public fun price_feed_id(oracle_info: &OracleInfo) : vector<u8> {
        oracle_info.price_feed_id
    }
    
    public fun price_info_object_id(oracle_info: &OracleInfo) : sui::object::ID {
        oracle_info.price_info_object_id
    }
    
    public fun price_multiplier_decimal() : u8 {
        PYTH_PRICE_DECIMAL
    }
    
    public fun price_value(price: &Price) : u64 {
        price.price
    }
    
    public(package) fun split_fee(pyth_oracle: &mut PythOracle, amount: u64) : sui::balance::Balance<sui::sui::SUI> {
        assert!(pyth_oracle.update_price_fee.value() >= amount, vault::error::update_price_fee_not_enough());
        pyth_oracle.update_price_fee.split(amount)
    }
    
    public fun update_price<CoinType>(
        pyth_oracle: &mut PythOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        state: &State, 
        price_info_vector: HotPotatoVector<PriceInfo>, 
        price_info_object: &mut PriceInfoObject, 
        clock: &sui::clock::Clock, 
        ctx: &mut sui::tx_context::TxContext
    ) : HotPotatoVector<PriceInfo> {
        vault::vault_config::checked_package_version(global_config);
        let type_name = std::type_name::with_defining_ids<CoinType>();
        if (pyth_oracle.oracle_infos.contains(type_name)) {
            let price = update_price_from_type<CoinType>(pyth_oracle, price_info_object, clock);
            let event = UpdatePriceEvent{
                coin_type        : type_name, 
                price            : price.price, 
                last_update_time : price.last_update_time,
            };
            sui::event::emit<UpdatePriceEvent>(event);
        };
        update_single_price_feed(
            state, 
            price_info_vector, 
            price_info_object, 
            sui::coin::from_balance<sui::sui::SUI>(split_fee(pyth_oracle, state.get_base_update_fee()), ctx), 
            clock
        )
    }

    /// Synchronises the cached price inside `PythOracle` when an off-chain updater
    /// has already refreshed the corresponding `PriceInfoObject` in the same transaction.
    ///
    /// Performs a package version check, verifies that oracle configuration for the
    /// requested coin exists, and ensures the supplied price info is not older than
    /// the configured `usd_price_age`. Emits an `UpdatePriceEvent` so downstream
    /// contracts can safely consume the fresh quote without calling Pyth on-chain.
    ///
    /// # Arguments
    /// * `pyth_oracle` – oracle instance storing cached prices
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
    public fun external_update_price<CoinType>(
        pyth_oracle: &mut PythOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        price_info_object: &PriceInfoObject, 
        clock: &sui::clock::Clock
    ) {
        vault::vault_config::checked_package_version(global_config);
        let type_name = std::type_name::with_defining_ids<CoinType>();
        assert!(pyth_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());

        let oracle_info = pyth_oracle.oracle_infos.borrow(type_name);
        let price_info = price_info_object.get_price_info_from_price_info_object();
        let price_feed_ref = price_info.get_price_feed();
        let price_timestamp = price_feed_ref.get_price().get_timestamp();
        let now = sui::clock::timestamp_ms(clock) / 1000;
        let delta = if (now >= price_timestamp) { now - price_timestamp } else { 0 };
        assert!(delta <= oracle_info.usd_price_age, vault::error::price_not_updated());

        let price = update_price_from_type<CoinType>(pyth_oracle, price_info_object, clock);
        let event = UpdatePriceEvent{
            coin_type        : type_name, 
            price            : price.price, 
            last_update_time : price.last_update_time,
        };
        sui::event::emit<UpdatePriceEvent>(event);
    }

    fun update_price_from_type<CoinType>(
        pyth_oracle: &mut PythOracle,
        price_info_object: &PriceInfoObject, 
        clock: &sui::clock::Clock
    ) : Price {
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(pyth_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());  
        let oracle_info = pyth_oracle.oracle_infos.borrow(type_name); 
        assert!(oracle_info.price_info_object_id == sui::object::id<PriceInfoObject>(price_info_object), vault::error::price_object_not_match_with_coin_type()); 
        let price = Price{ 
            price            : pyth_price_from_oracle_info(price_info_object, oracle_info, clock), 
            coin_decimals    : oracle_info.coin_decimals, 
            last_update_time : sui::clock::timestamp_ms(clock) / 1000, 
        };
        if (!pyth_oracle.prices.contains(type_name)) {
            pyth_oracle.prices.add(type_name, price);
        } else {
            *sui::table::borrow_mut<std::type_name::TypeName, Price>(&mut pyth_oracle.prices, type_name) = price;
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
        assert!(oracle_info.price_feed_id == price_identifier.get_bytes(), vault::error::invalid_price_feed_id()); 
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
    
    public fun update_price_age<CoinType>(
        pyth_oracle: &mut PythOracle, 
        global_config: &vault::vault_config::GlobalConfig, 
        usd_price_age: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        vault::vault_config::checked_package_version(global_config); 
        vault::vault_config::check_oracle_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        assert!(pyth_oracle.oracle_infos.contains(type_name), vault::error::oracle_info_not_exists());
        let oracle_info = pyth_oracle.oracle_infos.borrow_mut(type_name);

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


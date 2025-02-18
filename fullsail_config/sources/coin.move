module fullsail_config::coin {
    struct CoinList has store, key {
        id: sui::object::UID,
        coins: sui::table::Table<std::type_name::TypeName, Coin>,
    }
    
    struct Coin has copy, drop, store {
        name: std::string::String,
        symbol: std::string::String,
        coingecko_id: std::string::String,
        pyth_id: std::string::String,
        decimals: u8,
        logo_url: std::string::String,
        project_url: std::string::String,
        coin_type: std::type_name::TypeName,
        extension_fields: sui::vec_map::VecMap<std::string::String, std::string::String>,
    }
    
    struct InitCoinListEvent has copy, drop, store {
        coin_list_id: sui::object::ID,
    }
    
    struct AddCoinEvent has copy, drop, store {
        coin_type: std::string::String,
    }
    
    struct UpdateCoinEvent has copy, drop, store {
        coin_type: std::string::String,
    }
    
    struct RemoveCoinEvent has copy, drop, store {
        coin_type: std::string::String,
    }
    
    struct UpdateCoinNameEvent has copy, drop, store {
        coin_type: std::string::String,
        old_coin_name: std::string::String,
        new_coin_name: std::string::String,
    }
    
    struct UpdateCoinSymbolEvent has copy, drop, store {
        coin_type: std::string::String,
        old_coin_symbol: std::string::String,
        new_coin_symbol: std::string::String,
    }
    
    struct UpdateCoingeckoIDEvent has copy, drop, store {
        coin_type: std::string::String,
        old_coingecko_id: std::string::String,
        new_coingecko_id: std::string::String,
    }
    
    struct UpdatePythIDEvent has copy, drop, store {
        coin_type: std::string::String,
        old_pyth_id: std::string::String,
        new_pyth_id: std::string::String,
    }
    
    struct AddExtensionToCoinEvent has copy, drop, store {
        coin_type: std::string::String,
        key: std::string::String,
        value: std::string::String,
    }
    
    struct UpdateExtensionFromCoinEvent has copy, drop, store {
        coin_type: std::string::String,
        key: std::string::String,
        old_value: std::string::String,
        new_value: std::string::String,
    }
    
    struct RemoveExtensionFromCoinEvent has copy, drop, store {
        coin_type: std::string::String,
        key: std::string::String,
    }
    
    public entry fun add_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: std::string::String, arg4: std::string::String, arg5: std::string::String, arg6: u8, arg7: std::string::String, arg8: std::string::String, arg9: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg9));
        let v0 = std::type_name::get<T0>();
        assert!(!sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 0);
        let v1 = Coin{
            name             : arg2, 
            symbol           : arg3, 
            coingecko_id     : arg4, 
            pyth_id          : arg5, 
            decimals         : arg6, 
            logo_url         : arg7, 
            project_url      : arg8, 
            coin_type        : v0, 
            extension_fields : sui::vec_map::empty<std::string::String, std::string::String>(),
        };
        sui::table::add<std::type_name::TypeName, Coin>(&mut arg1.coins, v0, v1);
        let v2 = AddCoinEvent{coin_type: std::string::from_ascii(std::type_name::into_string(v0))};
        sui::event::emit<AddCoinEvent>(v2);
    }
    
    public entry fun add_extension_to_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg4));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        assert!(!sui::vec_map::contains<std::string::String, std::string::String>(&v1.extension_fields, &arg2), 3);
        sui::vec_map::insert<std::string::String, std::string::String>(&mut v1.extension_fields, arg2, arg3);
        let v2 = AddExtensionToCoinEvent{
            coin_type : std::string::from_ascii(std::type_name::into_string(v0)), 
            key       : arg2, 
            value     : arg3,
        };
        sui::event::emit<AddExtensionToCoinEvent>(v2);
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = CoinList{
            id    : sui::object::new(arg0), 
            coins : sui::table::new<std::type_name::TypeName, Coin>(arg0),
        };
        sui::transfer::share_object<CoinList>(v0);
        let v1 = InitCoinListEvent{coin_list_id: sui::object::id<CoinList>(&v0)};
        sui::event::emit<InitCoinListEvent>(v1);
    }
    
    public entry fun remove_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg2));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        sui::table::remove<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        let v1 = RemoveCoinEvent{coin_type: std::string::from_ascii(std::type_name::into_string(v0))};
        sui::event::emit<RemoveCoinEvent>(v1);
    }
    
    public entry fun remove_extension_from_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg3));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        assert!(sui::vec_map::contains<std::string::String, std::string::String>(&v1.extension_fields, &arg2), 2);
        let (_, _) = sui::vec_map::remove<std::string::String, std::string::String>(&mut v1.extension_fields, &arg2);
        let v4 = RemoveExtensionFromCoinEvent{
            coin_type : std::string::from_ascii(std::type_name::into_string(v0)), 
            key       : arg2,
        };
        sui::event::emit<RemoveExtensionFromCoinEvent>(v4);
    }
    
    public entry fun update_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: std::string::String, arg4: std::string::String, arg5: std::string::String, arg6: u8, arg7: std::string::String, arg8: std::string::String, arg9: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg9));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        v1.name = arg2;
        v1.symbol = arg3;
        v1.coingecko_id = arg4;
        v1.pyth_id = arg5;
        v1.decimals = arg6;
        v1.logo_url = arg7;
        v1.project_url = arg8;
        v1.coin_type = v0;
        let v2 = UpdateCoinEvent{coin_type: std::string::from_ascii(std::type_name::into_string(v0))};
        sui::event::emit<UpdateCoinEvent>(v2);
    }
    
    public entry fun update_coin_name<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        v1.name = arg2;
        let v2 = UpdateCoinNameEvent{
            coin_type     : std::string::from_ascii(std::type_name::into_string(v0)), 
            old_coin_name : v1.name, 
            new_coin_name : arg2,
        };
        sui::event::emit<UpdateCoinNameEvent>(v2);
    }
    
    public entry fun update_coin_symbol<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        v1.symbol = arg2;
        let v2 = UpdateCoinSymbolEvent{
            coin_type       : std::string::from_ascii(std::type_name::into_string(v0)), 
            old_coin_symbol : v1.symbol, 
            new_coin_symbol : arg2,
        };
        sui::event::emit<UpdateCoinSymbolEvent>(v2);
    }
    
    public entry fun update_coingecko_id<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        v1.coingecko_id = arg2;
        let v2 = UpdateCoingeckoIDEvent{
            coin_type        : std::string::from_ascii(std::type_name::into_string(v0)), 
            old_coingecko_id : v1.coingecko_id, 
            new_coingecko_id : arg2,
        };
        sui::event::emit<UpdateCoingeckoIDEvent>(v2);
    }
    
    public entry fun update_extension_from_coin<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg4));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        assert!(sui::vec_map::contains<std::string::String, std::string::String>(&v1.extension_fields, &arg2), 2);
        let v2 = sui::vec_map::get_mut<std::string::String, std::string::String>(&mut v1.extension_fields, &arg2);
        *v2 = arg3;
        let v3 = UpdateExtensionFromCoinEvent{
            coin_type : std::string::from_ascii(std::type_name::into_string(v0)), 
            key       : arg2, 
            old_value : *v2, 
            new_value : arg3,
        };
        sui::event::emit<UpdateExtensionFromCoinEvent>(v3);
    }
    
    public entry fun update_pyth_id<T0>(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut CoinList, arg2: std::string::String, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        let v0 = std::type_name::get<T0>();
        assert!(sui::table::contains<std::type_name::TypeName, Coin>(&arg1.coins, v0), 1);
        let v1 = sui::table::borrow_mut<std::type_name::TypeName, Coin>(&mut arg1.coins, v0);
        v1.pyth_id = arg2;
        let v2 = UpdatePythIDEvent{
            coin_type   : std::string::from_ascii(std::type_name::into_string(v0)), 
            old_pyth_id : v1.pyth_id, 
            new_pyth_id : arg2,
        };
        sui::event::emit<UpdatePythIDEvent>(v2);
    }
    
    // decompiled from Move bytecode v6
}


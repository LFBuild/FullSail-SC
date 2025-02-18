module fullsail_config::launchpad_pool {
    struct LaunchpadPools has store, key {
        id: sui::object::UID,
        pools: sui::table::Table<address, Pool>,
    }
    
    struct MediaInfo has drop, store {
        name: std::string::String,
        link: std::string::String,
    }
    
    struct Pool has drop, store {
        pool_address: address,
        is_closed: bool,
        show_settle: bool,
        coin_symbol: std::string::String,
        coin_name: std::string::String,
        coin_icon: std::string::String,
        banners: vector<std::string::String>,
        introduction: std::string::String,
        website: std::string::String,
        tokenomics: std::string::String,
        social_media: sui::vec_map::VecMap<std::string::String, MediaInfo>,
        terms: std::string::String,
        white_list_terms: std::string::String,
        regulation: std::string::String,
        project_details: std::string::String,
        extension_fields: sui::vec_map::VecMap<std::string::String, std::string::String>,
    }
    
    struct InitLaunchpadPoolsEvent has copy, drop, store {
        launchpad_pools_id: sui::object::ID,
    }
    
    struct AddPoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct UpdatePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct RemovePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct AddMediaToPoolEvent has copy, drop, store {
        pool_address: address,
        name: std::string::String,
        link: std::string::String,
    }
    
    struct RemoveMediaFromPoolEvent has copy, drop, store {
        pool_address: address,
        name: std::string::String,
    }
    
    struct ClosePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct OpenPoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct OpenSettleEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct CloseSettleEvent has copy, drop, store {
        pool_address: address,
    }
    
    struct AddExtensionToPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
        value: std::string::String,
    }
    
    struct UpdateExtensionFromPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
        old_value: std::string::String,
        new_value: std::string::String,
    }
    
    struct RemoveExtensionFromPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
    }
    
    public entry fun add_extension_to_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg5));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        assert!(!sui::vec_map::contains<std::string::String, std::string::String>(&v0.extension_fields, &arg3), 3);
        sui::vec_map::insert<std::string::String, std::string::String>(&mut v0.extension_fields, arg3, arg4);
        let v1 = AddExtensionToPoolEvent{
            pool_address : arg2, 
            key          : arg3, 
            value        : arg4,
        };
        sui::event::emit<AddExtensionToPoolEvent>(v1);
    }
    
    public entry fun add_launchpad_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: bool, arg4: bool, arg5: std::string::String, arg6: std::string::String, arg7: std::string::String, arg8: vector<std::string::String>, arg9: std::string::String, arg10: std::string::String, arg11: std::string::String, arg12: std::string::String, arg13: std::string::String, arg14: std::string::String, arg15: std::string::String, arg16: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg16));
        assert!(!sui::table::contains<address, Pool>(&arg1.pools, arg2), 0);
        let v0 = Pool{
            pool_address     : arg2, 
            is_closed        : arg3, 
            show_settle      : arg4, 
            coin_symbol      : arg5, 
            coin_name        : arg6, 
            coin_icon        : arg7, 
            banners          : arg8, 
            introduction     : arg9, 
            website          : arg10, 
            tokenomics       : arg11, 
            social_media     : sui::vec_map::empty<std::string::String, MediaInfo>(), 
            terms            : arg12, 
            white_list_terms : arg13, 
            regulation       : arg14, 
            project_details  : arg15, 
            extension_fields : sui::vec_map::empty<std::string::String, std::string::String>(),
        };
        sui::table::add<address, Pool>(&mut arg1.pools, arg2, v0);
        let v1 = AddPoolEvent{pool_address: arg2};
        sui::event::emit<AddPoolEvent>(v1);
    }
    
    public fun add_media_to_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg5));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        assert!(!sui::vec_map::contains<std::string::String, MediaInfo>(&v0.social_media, &arg3), 3);
        let v1 = MediaInfo{
            name : arg3, 
            link : arg4,
        };
        sui::vec_map::insert<std::string::String, MediaInfo>(&mut v0.social_media, arg3, v1);
        let v2 = AddMediaToPoolEvent{
            pool_address : arg2, 
            name         : arg3, 
            link         : arg4,
        };
        sui::event::emit<AddMediaToPoolEvent>(v2);
    }
    
    public fun close_launchpad_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).is_closed = true;
        let v0 = ClosePoolEvent{pool_address: arg2};
        sui::event::emit<ClosePoolEvent>(v0);
    }
    
    public fun close_settle(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).show_settle = false;
        let v0 = CloseSettleEvent{pool_address: arg2};
        sui::event::emit<CloseSettleEvent>(v0);
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = LaunchpadPools{
            id    : sui::object::new(arg0), 
            pools : sui::table::new<address, Pool>(arg0),
        };
        sui::transfer::share_object<LaunchpadPools>(v0);
        let v1 = InitLaunchpadPoolsEvent{launchpad_pools_id: sui::object::id<LaunchpadPools>(&v0)};
        sui::event::emit<InitLaunchpadPoolsEvent>(v1);
    }
    
    public fun open_launchpad_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).is_closed = false;
        let v0 = OpenPoolEvent{pool_address: arg2};
        sui::event::emit<OpenPoolEvent>(v0);
    }
    
    public fun open_settle(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).show_settle = true;
        let v0 = OpenSettleEvent{pool_address: arg2};
        sui::event::emit<OpenSettleEvent>(v0);
    }
    
    public entry fun remove_extension_from_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg4));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        assert!(sui::vec_map::contains<std::string::String, std::string::String>(&v0.extension_fields, &arg3), 2);
        let (_, _) = sui::vec_map::remove<std::string::String, std::string::String>(&mut v0.extension_fields, &arg3);
        let v3 = RemoveExtensionFromPoolEvent{
            pool_address : arg2, 
            key          : arg3,
        };
        sui::event::emit<RemoveExtensionFromPoolEvent>(v3);
    }
    
    public fun remove_launchpad_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::remove<address, Pool>(&mut arg1.pools, arg2);
        let v0 = RemovePoolEvent{pool_address: arg2};
        sui::event::emit<RemovePoolEvent>(v0);
    }
    
    public fun remove_media_from_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg4));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        assert!(sui::vec_map::contains<std::string::String, MediaInfo>(&v0.social_media, &arg3), 2);
        let (_, _) = sui::vec_map::remove<std::string::String, MediaInfo>(&mut v0.social_media, &arg3);
        let v3 = RemoveMediaFromPoolEvent{
            pool_address : arg2, 
            name         : arg3,
        };
        sui::event::emit<RemoveMediaFromPoolEvent>(v3);
    }
    
    public entry fun update_extension_from_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg5));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        assert!(sui::vec_map::contains<std::string::String, std::string::String>(&v0.extension_fields, &arg3), 2);
        let v1 = sui::vec_map::get_mut<std::string::String, std::string::String>(&mut v0.extension_fields, &arg3);
        *v1 = arg4;
        let v2 = UpdateExtensionFromPoolEvent{
            pool_address : arg2, 
            key          : arg3, 
            old_value    : *v1, 
            new_value    : arg4,
        };
        sui::event::emit<UpdateExtensionFromPoolEvent>(v2);
    }
    
    public fun update_launchpad_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut LaunchpadPools, arg2: address, arg3: bool, arg4: bool, arg5: std::string::String, arg6: std::string::String, arg7: std::string::String, arg8: vector<std::string::String>, arg9: std::string::String, arg10: std::string::String, arg11: std::string::String, arg12: std::string::String, arg13: std::string::String, arg14: std::string::String, arg15: std::string::String, arg16: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg16));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        v0.pool_address = arg2;
        v0.is_closed = arg3;
        v0.show_settle = arg4;
        v0.coin_symbol = arg5;
        v0.coin_name = arg6;
        v0.coin_icon = arg7;
        v0.banners = arg8;
        v0.introduction = arg9;
        v0.website = arg10;
        v0.tokenomics = arg11;
        v0.terms = arg12;
        v0.white_list_terms = arg13;
        v0.regulation = arg14;
        v0.project_details = arg15;
        let v1 = UpdatePoolEvent{pool_address: arg2};
        sui::event::emit<UpdatePoolEvent>(v1);
    }
    
    // decompiled from Move bytecode v6
}


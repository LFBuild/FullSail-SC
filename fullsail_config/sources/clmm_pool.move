module fullsail_config::clmm_pool {
    public struct ClmmPools has store, key {
        id: sui::object::UID,
        pools: sui::table::Table<address, Pool>,
    }
    
    public struct Pool has drop, store {
        pool_address: address,
        pool_type: std::string::String,
        project_url: std::string::String,
        is_closed: bool,
        is_show_rewarder: bool,
        show_rewarder_1: bool,
        show_rewarder_2: bool,
        show_rewarder_3: bool,
        extension_fields: sui::vec_map::VecMap<std::string::String, std::string::String>,
    }
    
    public struct InitClmmPoolsEvent has copy, drop, store {
        pools_id: sui::object::ID,
    }
    
    public struct AddPoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    public struct UpdatePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    public struct RemovePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    public struct ClosePoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    public struct OpenPoolEvent has copy, drop, store {
        pool_address: address,
    }
    
    public struct UpdatePoolTypeEvent has copy, drop, store {
        pool_address: address,
        old_pool_type: std::string::String,
        new_pool_type: std::string::String,
    }
    
    public struct AddExtensionToPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
        value: std::string::String,
    }
    
    public struct UpdateExtensionFromPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
        old_value: std::string::String,
        new_value: std::string::String,
    }
    
    public struct RemoveExtensionFromPoolEvent has copy, drop, store {
        pool_address: address,
        key: std::string::String,
    }
    
    public struct UpdatePoolRewarderDisplayEvent has copy, drop, store {
        pool_address: address,
        rewarder_index: u64,
        is_show_rewarder: bool,
    }
    
    public entry fun add_clmm_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: bool, arg6: bool, arg7: bool, arg8: bool, arg9: bool, arg10: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_add_role(arg0, sui::tx_context::sender(arg10));
        assert!(!sui::table::contains<address, Pool>(&arg1.pools, arg2), 0);
        let v0 = Pool{
            pool_address     : arg2, 
            pool_type        : arg3, 
            project_url      : arg4, 
            is_closed        : arg5, 
            is_show_rewarder : arg6, 
            show_rewarder_1  : arg7, 
            show_rewarder_2  : arg8, 
            show_rewarder_3  : arg9, 
            extension_fields : sui::vec_map::empty<std::string::String, std::string::String>(),
        };
        sui::table::add<address, Pool>(&mut arg1.pools, arg2, v0);
        let v1 = AddPoolEvent{pool_address: arg2};
        sui::event::emit<AddPoolEvent>(v1);
    }
    
    public entry fun add_extension_to_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: &sui::tx_context::TxContext) {
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
    
    public entry fun close_clmm_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).is_closed = true;
        let v0 = ClosePoolEvent{pool_address: arg2};
        sui::event::emit<ClosePoolEvent>(v0);
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = ClmmPools{
            id    : sui::object::new(arg0), 
            pools : sui::table::new<address, Pool>(arg0),
        };
        let pools_id = sui::object::id<ClmmPools>(&v0);
        sui::transfer::share_object<ClmmPools>(v0);
        let v1 = InitClmmPoolsEvent{pools_id};
        sui::event::emit<InitClmmPoolsEvent>(v1);
    }
    
    public entry fun open_clmm_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).is_closed = false;
        let v0 = OpenPoolEvent{pool_address: arg2};
        sui::event::emit<OpenPoolEvent>(v0);
    }
    
    public entry fun remove_clmm_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_delete_role(arg0, sui::tx_context::sender(arg3));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        sui::table::remove<address, Pool>(&mut arg1.pools, arg2);
        let v0 = RemovePoolEvent{pool_address: arg2};
        sui::event::emit<RemovePoolEvent>(v0);
    }
    
    public entry fun remove_extension_from_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
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
    
    public entry fun update_clmm_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: bool, arg6: bool, arg7: bool, arg8: bool, arg9: bool, arg10: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg10));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        v0.pool_address = arg2;
        v0.pool_type = arg3;
        v0.project_url = arg4;
        v0.is_closed = arg5;
        v0.is_show_rewarder = arg6;
        v0.show_rewarder_1 = arg7;
        v0.show_rewarder_2 = arg8;
        v0.show_rewarder_3 = arg9;
        let v1 = UpdatePoolEvent{pool_address: arg2};
        sui::event::emit<UpdatePoolEvent>(v1);
    }
    
    public entry fun update_extension_from_pool(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: std::string::String, arg5: &sui::tx_context::TxContext) {
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
    
    public entry fun update_pool_type(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: std::string::String, arg4: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg4));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2);
        v0.pool_type = arg3;
        let v1 = UpdatePoolTypeEvent{
            pool_address  : arg2, 
            old_pool_type : v0.pool_type, 
            new_pool_type : arg3,
        };
        sui::event::emit<UpdatePoolTypeEvent>(v1);
    }
    
    public entry fun update_rewarder_display(arg0: &fullsail_config::config::GlobalConfig, arg1: &mut ClmmPools, arg2: address, arg3: u64, arg4: bool, arg5: &sui::tx_context::TxContext) {
        fullsail_config::config::checked_package_version(arg0);
        fullsail_config::config::checked_has_update_role(arg0, sui::tx_context::sender(arg5));
        assert!(sui::table::contains<address, Pool>(&arg1.pools, arg2), 1);
        let v0 = if (arg3 == 0) {
            &mut sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).is_show_rewarder
        } else {
            let v1 = if (arg3 == 1) {
                &mut sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).show_rewarder_1
            } else {
                let v2 = if (arg3 == 2) {
                    &mut sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).show_rewarder_2
                } else {
                    assert!(arg3 == 3, 4);
                    &mut sui::table::borrow_mut<address, Pool>(&mut arg1.pools, arg2).show_rewarder_3
                };
                v2
            };
            v1
        };
        *v0 = arg4;
        let v3 = UpdatePoolRewarderDisplayEvent{
            pool_address     : arg2, 
            rewarder_index   : arg3, 
            is_show_rewarder : arg4,
        };
        sui::event::emit<UpdatePoolRewarderDisplayEvent>(v3);
    }
    
    // decompiled from Move bytecode v6
}


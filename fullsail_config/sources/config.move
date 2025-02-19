module fullsail_config::config {
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }
    
    public struct GlobalConfig has store, key {
        id: sui::object::UID,
        acl: fullsail_config::acl::ACL,
        package_version: u64,
    }
    
    public struct InitConfigEvent has copy, drop {
        admin_cap_id: sui::object::ID,
        global_config_id: sui::object::ID,
    }
    
    public struct SetRolesEvent has copy, drop {
        member: address,
        roles: u128,
    }
    
    public struct AddRoleEvent has copy, drop {
        member: address,
        role: u8,
    }
    
    public struct RemoveRoleEvent has copy, drop {
        member: address,
        role: u8,
    }
    
    public struct RemoveMemberEvent has copy, drop {
        member: address,
    }
    
    public entry fun add_role(arg0: &AdminCap, arg1: &mut GlobalConfig, arg2: address, arg3: u8) {
        checked_package_version(arg1);
        fullsail_config::acl::add_role(&mut arg1.acl, arg2, arg3);
        let v0 = AddRoleEvent{
            member : arg2, 
            role   : arg3,
        };
        sui::event::emit<AddRoleEvent>(v0);
    }
    
    public entry fun remove_member(arg0: &AdminCap, arg1: &mut GlobalConfig, arg2: address) {
        checked_package_version(arg1);
        fullsail_config::acl::remove_member(&mut arg1.acl, arg2);
        let v0 = RemoveMemberEvent{member: arg2};
        sui::event::emit<RemoveMemberEvent>(v0);
    }
    
    public entry fun remove_role(arg0: &AdminCap, arg1: &mut GlobalConfig, arg2: address, arg3: u8) {
        checked_package_version(arg1);
        fullsail_config::acl::remove_role(&mut arg1.acl, arg2, arg3);
        let v0 = RemoveRoleEvent{
            member : arg2, 
            role   : arg3,
        };
        sui::event::emit<RemoveRoleEvent>(v0);
    }
    
    public entry fun set_roles(arg0: &AdminCap, arg1: &mut GlobalConfig, arg2: address, arg3: u128) {
        checked_package_version(arg1);
        fullsail_config::acl::set_roles(&mut arg1.acl, arg2, arg3);
        let v0 = SetRolesEvent{
            member : arg2, 
            roles  : arg3,
        };
        sui::event::emit<SetRolesEvent>(v0);
    }
    
    public fun checked_has_add_role(arg0: &GlobalConfig, arg1: address) {
        assert!(fullsail_config::acl::has_role(&arg0.acl, arg1, 0), 2);
    }
    
    public fun checked_has_delete_role(arg0: &GlobalConfig, arg1: address) {
        assert!(fullsail_config::acl::has_role(&arg0.acl, arg1, 2), 4);
    }
    
    public fun checked_has_update_role(arg0: &GlobalConfig, arg1: address) {
        assert!(fullsail_config::acl::has_role(&arg0.acl, arg1, 1), 3);
    }
    
    public fun checked_package_version(arg0: &GlobalConfig) {
        assert!(arg0.package_version == 1, 1);
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = GlobalConfig{
            id              : sui::object::new(arg0), 
            acl             : fullsail_config::acl::new(), 
            package_version : 1,
        };
        let v1 = AdminCap{id: sui::object::new(arg0)};
        let mut v2 = v0;
        let v3 = sui::tx_context::sender(arg0);
        set_roles(&v1, &mut v2, v3, 0 | 1 << 0 | 1 << 1 | 1 << 2);
        sui::transfer::transfer<AdminCap>(v1, v3);
        sui::transfer::share_object<GlobalConfig>(v2);
        let v4 = InitConfigEvent{
            admin_cap_id     : sui::object::id<AdminCap>(&v1), 
            global_config_id : sui::object::id<GlobalConfig>(&v2),
        };
        sui::event::emit<InitConfigEvent>(v4);
    }
    
    // decompiled from Move bytecode v6
}


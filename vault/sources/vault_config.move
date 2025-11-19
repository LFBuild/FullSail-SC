module vault::vault_config {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const VERSION: u64 = 1;

    // Role constants
    const ROLE_PROTOCOL_FEE_CLAIM: u8 = 0;
    const ROLE_REINVEST: u8 = 1;
    const ROLE_REBALANCE: u8 = 2;
    const ROLE_POOL_MANAGER: u8 = 3;
    const ROLE_ORACLE_MANAGER: u8 = 4;

    const DEFAULT_SWAP_SLIPPAGE: u64 = 50; // 0.5%

    public struct AdminCap has store, key {
        id: sui::object::UID,
    }
    
    public struct GlobalConfig has key {
        id: sui::object::UID,
        swap_slippages: sui::vec_map::VecMap<std::type_name::TypeName, u64>,
        protocol_fee_rate: u64,
        max_price_deviation_bps: u64,
        package_version: u64,
        acl: vault::vault_acl::ACL,
    }
    
    public struct InitConfigEvent has copy, drop {
        admin_cap: sui::object::ID,
        global_config: sui::object::ID,
    }
    
    public struct SetPackageVersionEvent has copy, drop {
        new_version: u64,
        old_version: u64,
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
    
    public struct UpdateFeeRateEvent has copy, drop {
        old_fee_rate: u64,
        new_fee_rate: u64,
    }
    
    public struct SetSwapSlippageEvent has copy, drop {
        type_name: std::type_name::TypeName,
        old_slippage: u64,
        new_slippage: u64,
    }
    
    public struct UpdateMaxPriceDeviationEvent has copy, drop {
        old_max_price_deviation_bps: u64,
        new_max_price_deviation_bps: u64,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let admin_cap = AdminCap{id: sui::object::new(ctx)};
        let mut global_config = GlobalConfig{
            id                      : sui::object::new(ctx), 
            swap_slippages          : sui::vec_map::empty<std::type_name::TypeName, u64>(), 
            protocol_fee_rate       : 0, 
            max_price_deviation_bps : 200,
            package_version         : VERSION, 
            acl                     : vault::vault_acl::new(ctx),
        };
        let event = InitConfigEvent{
            admin_cap     : sui::object::id<AdminCap>(&admin_cap),
            global_config : sui::object::id<GlobalConfig>(&global_config),
        };
        sui::event::emit<InitConfigEvent>(event);
        global_config.set_roles( 
            &admin_cap, 
            sui::tx_context::sender(ctx), 
            1 << ROLE_PROTOCOL_FEE_CLAIM | 1 << ROLE_POOL_MANAGER | 1 << ROLE_ORACLE_MANAGER
        );
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object<GlobalConfig>(global_config);
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        let admin_cap = AdminCap{id: sui::object::new(ctx)};
        let mut global_config = GlobalConfig{
            id                      : sui::object::new(ctx), 
            swap_slippages          : sui::vec_map::empty<std::type_name::TypeName, u64>(), 
            protocol_fee_rate       : 0, 
            max_price_deviation_bps : 200,
            package_version         : VERSION, 
            acl                     : vault::vault_acl::new(ctx),
        };
        global_config.set_roles( 
            &admin_cap, 
            sui::tx_context::sender(ctx), 
            1 << ROLE_PROTOCOL_FEE_CLAIM | 1 << ROLE_POOL_MANAGER | 1 << ROLE_ORACLE_MANAGER
        );
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object<GlobalConfig>(global_config);
    }
    
    public fun add_role(global_config: &mut GlobalConfig, _: &AdminCap, member: address, role: u8) {
        checked_package_version(global_config); 
        global_config.acl.add_role(member, role);
        let event = AddRoleEvent{member: member, role: role};
        sui::event::emit<AddRoleEvent>(event);
    }
    
    public fun remove_member(global_config: &mut GlobalConfig, _: &AdminCap, member: address) {
        checked_package_version(global_config); 
        global_config.acl.remove_member(member);
        let event = RemoveMemberEvent{member: member};
        sui::event::emit<RemoveMemberEvent>(event);
    }
    
    public fun remove_role(global_config: &mut GlobalConfig, _: &AdminCap, member: address, role: u8) {
        checked_package_version(global_config);
        global_config.acl.remove_role(member, role);
        let event = RemoveRoleEvent{member: member, role: role};
        sui::event::emit<RemoveRoleEvent>(event);
    }
    
    public fun set_roles(global_config: &mut GlobalConfig, _: &AdminCap, member: address, roles: u128) {
        checked_package_version(global_config);
        global_config.acl.set_roles(member, roles);
        let event = SetRolesEvent{member: member, roles: roles};
        sui::event::emit<SetRolesEvent>(event);
    }
    
    public fun check_operation_role(global_config: &GlobalConfig, member: address) {
        assert!(
            global_config.acl.has_role(member, ROLE_REINVEST) 
            || 
            global_config.acl.has_role(member, ROLE_REBALANCE), 
            vault::error::no_operation_manager_permission()
        );
    }

    public fun is_operation_manager_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_REINVEST) 
        || 
        global_config.acl.has_role(member, ROLE_REBALANCE)
    }
    
    public fun check_oracle_manager_role(global_config: &GlobalConfig, member: address) {
        assert!(global_config.acl.has_role(member, ROLE_ORACLE_MANAGER), vault::error::no_oracle_manager_permission());
    }

    public fun is_oracle_manager_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_ORACLE_MANAGER)
    }

    public fun check_pool_manager_role(global_config: &GlobalConfig, member: address) {
        assert!(global_config.acl.has_role(member, ROLE_POOL_MANAGER), vault::error::no_pool_manager_permission());
    }

    public fun is_pool_manager_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_POOL_MANAGER)
    }
    
    public fun check_protocol_fee_claim_role(global_config: &GlobalConfig, member: address) {
        assert!(global_config.acl.has_role(member, ROLE_PROTOCOL_FEE_CLAIM), vault::error::no_protocol_fee_claim_permission());
    }

    public fun is_protocol_fee_claim_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_PROTOCOL_FEE_CLAIM)
    }
    
    public fun check_rebalance_role(global_config: &GlobalConfig, member: address) {
        assert!(global_config.acl.has_role(member, ROLE_REBALANCE), vault::error::no_operation_manager_permission());
    }

    public fun is_rebalance_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_REBALANCE)
    }
    
    public fun check_reinvest_role(global_config: &GlobalConfig, member: address) {
        assert!(global_config.acl.has_role(member, ROLE_REINVEST), vault::error::no_operation_manager_permission());
    }

    public fun is_reinvest_role(global_config: &GlobalConfig, member: address) : bool {
        global_config.acl.has_role(member, ROLE_REINVEST)
    }

    public fun checked_package_version(global_config: &GlobalConfig) {
        assert!(VERSION >= global_config.package_version, vault::error::package_version_deprecate());
    }
    
    public fun get_max_price_deviation_bps(global_config: &GlobalConfig) : u64 {
        global_config.max_price_deviation_bps
    }
    
    public fun get_max_protocol_fee_rate() : u64 {
        5000
    }
    
    public fun get_protocol_fee_denominator() : u64 {
        10000
    }

    public fun get_swap_slippage_denominator() : u64 {
        10000
    }
    
    public fun get_protocol_fee_rate(global_config: &GlobalConfig) : u64 {
        global_config.protocol_fee_rate
    }
    
    public fun get_swap_slippage<CoinType>(global_config: &GlobalConfig) : u64 {
        let type_name = std::type_name::with_defining_ids<CoinType>();
        if (global_config.swap_slippages.contains(&type_name)) {
            *global_config.swap_slippages.get(&type_name)
        } else {
            DEFAULT_SWAP_SLIPPAGE
        }
    }
    
    public fun package_version() : u64 {
        VERSION
    }
    
    public fun set_swap_slippage<CoinType>(
        global_config: &mut GlobalConfig, 
        new_slippage: u64, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        checked_package_version(global_config);
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(new_slippage <= get_swap_slippage_denominator(), vault::error::invalid_swap_slippage());
        let type_name = std::type_name::with_defining_ids<CoinType>();
        let mut old_slippage = 0;
        if (global_config.swap_slippages.contains(&type_name)) {
            (_, old_slippage) = global_config.swap_slippages.remove(&type_name);
        };

        global_config.swap_slippages.insert(type_name, new_slippage);
        
        let event = SetSwapSlippageEvent{
            type_name    : type_name, 
            old_slippage : old_slippage, 
            new_slippage : new_slippage,
        };
        sui::event::emit<SetSwapSlippageEvent>(event);
    }
    
    public fun update_max_price_deviation_bps(global_config: &mut GlobalConfig, new_max_price_deviation_bps: u64, ctx: &mut sui::tx_context::TxContext) {
        checked_package_version(global_config); 
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx)); 
        let old_max_price_deviation_bps = global_config.max_price_deviation_bps;
        global_config.max_price_deviation_bps = new_max_price_deviation_bps;
        let event = UpdateMaxPriceDeviationEvent{
            old_max_price_deviation_bps : old_max_price_deviation_bps, 
            new_max_price_deviation_bps : new_max_price_deviation_bps,
        };
        sui::event::emit<UpdateMaxPriceDeviationEvent>(event);
    }
    
    public fun update_package_version(global_config: &mut GlobalConfig, _: &AdminCap, new_version: u64) {
        let old_version = global_config.package_version; 
        assert!(new_version > old_version, vault::error::wrong_package_version());
        global_config.package_version = new_version;
        let event = SetPackageVersionEvent{
            new_version : new_version, 
            old_version : old_version,
        };
        sui::event::emit<SetPackageVersionEvent>(event);
    }
    
    public fun update_protocol_fee_rate(global_config: &mut GlobalConfig, new_protocol_fee_rate: u64, ctx: &mut sui::tx_context::TxContext) {
        checked_package_version(global_config);
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(new_protocol_fee_rate <= get_max_protocol_fee_rate(), vault::error::invalid_protocol_fee_rate());
        let old_fee_rate = global_config.protocol_fee_rate;
        global_config.protocol_fee_rate = new_protocol_fee_rate;
        let event = UpdateFeeRateEvent{
            old_fee_rate : old_fee_rate, 
            new_fee_rate : new_protocol_fee_rate,
        };
        sui::event::emit<UpdateFeeRateEvent>(event);
    }

    public fun get_role_protocol_fee_claim() : u8 {
        ROLE_PROTOCOL_FEE_CLAIM
    }

    public fun get_role_reinvest() : u8 {
        ROLE_REINVEST
    }
    
    public fun get_role_rebalance() : u8 {
        ROLE_REBALANCE
    }

    public fun get_role_pool_manager() : u8 {
        ROLE_POOL_MANAGER
    }
    
    public fun get_role_oracle_manager() : u8 {
        ROLE_ORACLE_MANAGER
    }
}


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
        max_price_deviation_bps: u64, // maximum allowed deviation of oracle price from pool price, default is 2%
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
    
    /// Updates the maximum allowed price deviation between oracle price and pool price.
    ///
    /// This method sets the threshold for price validation when adding liquidity to the vault.
    /// Before executing liquidity operations, the protocol compares the oracle price with the
    /// current pool price. If the deviation exceeds this threshold, the operation is aborted
    /// to protect against price manipulation attacks or stale oracle data.
    ///
    /// # Arguments
    /// * `global_config` - mutable reference to the global configuration
    /// * `new_max_price_deviation_bps` - new maximum price deviation in basis points (BPS)
    /// * `ctx` - transaction context
    ///
    /// # Values for new_max_price_deviation_bps
    /// The value must be specified in basis points (BPS), where denominator = 10000:
    /// * `100` = 1% (100 / 10000)
    /// * `200` = 2% (200 / 10000) - default value
    /// * `500` = 5% (500 / 10000)
    /// * `1000` = 10% (1000 / 10000)
    ///
    /// Calculation formula: `max_deviation_percentage = new_max_price_deviation_bps / 10000`
    ///
    /// # How it works
    /// When adding liquidity, the protocol calculates the deviation between:
    /// - Oracle price (from Pyth oracle)
    /// - Pool price (current sqrt_price converted to price)
    ///
    /// If `|oracle_price - pool_price| / oracle_price * 10000 > new_max_price_deviation_bps`,
    /// the operation is rejected.
    ///
    /// # Requirements
    /// * Caller must have the `ROLE_POOL_MANAGER` role
    /// * Package version must be up to date
    ///
    /// # Events
    /// Emits `UpdateMaxPriceDeviationEvent` with the previous and new deviation threshold values.
    ///
    /// # Aborts
    /// * If caller does not have the `ROLE_POOL_MANAGER` role
    /// * If package version is deprecated
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
    
    /// Updates the protocol fee rate in the global configuration.
    ///
    /// This method allows changing the percentage of fees that the protocol charges on operations.
    /// The fee is used to cover protocol maintenance costs and can be distributed to participants
    /// with the ROLE_PROTOCOL_FEE_CLAIM role.
    ///
    /// # Arguments
    /// * `global_config` - mutable reference to the global configuration
    /// * `new_protocol_fee_rate` - new protocol fee rate in basis points (BPS)
    /// * `ctx` - transaction context
    ///
    /// # Values for new_protocol_fee_rate
    /// The value must be specified in basis points (BPS), where denominator = 10000:
    /// * `0` = 0% (no fee)
    /// * `100` = 1% (100 / 10000)
    /// * `500` = 5% (500 / 10000)
    /// * `1000` = 10% (1000 / 10000)
    /// * `5000` = 50% (5000 / 10000) - maximum value
    ///
    /// Calculation formula: `actual_fee_percentage = new_protocol_fee_rate / 10000`
    ///
    /// # Requirements
    /// * Caller must have the `ROLE_POOL_MANAGER` role
    /// * `new_protocol_fee_rate` must not exceed 5000 (maximum 50%)
    /// * Package version must be up to date
    ///
    /// # Events
    /// Emits `UpdateFeeRateEvent` with the previous and new fee rate values.
    ///
    /// # Aborts
    /// * If caller does not have the `ROLE_POOL_MANAGER` role
    /// * If `new_protocol_fee_rate > 5000`
    /// * If package version is deprecated
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


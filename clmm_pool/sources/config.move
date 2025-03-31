module clmm_pool::config {
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct ProtocolFeeClaimCap has store, key {
        id: sui::object::UID,
    }

    public struct FeeTier has copy, drop, store {
        tick_spacing: u32,
        fee_rate: u64,
    }

    public struct GlobalConfig has store, key {
        id: sui::object::UID,
        protocol_fee_rate: u64,
        unstaked_liquidity_fee_rate: u64,
        fee_tiers: sui::vec_map::VecMap<u32, FeeTier>,
        acl: clmm_pool::acl::ACL,
        package_version: u64,
        alive_gauges: sui::vec_set::VecSet<sui::object::ID>,
    }

    public struct InitConfigEvent has copy, drop {
        admin_cap_id: sui::object::ID,
        global_config_id: sui::object::ID,
    }

    public struct UpdateFeeRateEvent has copy, drop {
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    public struct UpdateUnstakedLiquidityFeeRateEvent has copy, drop {
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    public struct AddFeeTierEvent has copy, drop {
        tick_spacing: u32,
        fee_rate: u64,
    }

    public struct UpdateFeeTierEvent has copy, drop {
        tick_spacing: u32,
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    public struct DeleteFeeTierEvent has copy, drop {
        tick_spacing: u32,
        fee_rate: u64,
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

    public struct SetPackageVersion has copy, drop {
        new_version: u64,
        old_version: u64,
    }
    public fun acl(config: &GlobalConfig): &clmm_pool::acl::ACL {
        &config.acl
    }

    public fun add_role(
        _admin_cap: &AdminCap,
        config: &mut GlobalConfig,
        member_addr: address,
        role_id: u8
    ) {
        checked_package_version(config);
        clmm_pool::acl::add_role(&mut config.acl, member_addr, role_id);
        let event = AddRoleEvent {
            member: member_addr,
            role: role_id,
        };
        sui::event::emit<AddRoleEvent>(event);
    }
    public fun get_members(config: &GlobalConfig): vector<clmm_pool::acl::Member> {
        clmm_pool::acl::get_members(&config.acl)
    }

    public fun remove_member(_admin_cap: &AdminCap, config: &mut GlobalConfig, member_addr: address) {
        checked_package_version(config);
        clmm_pool::acl::remove_member(&mut config.acl, member_addr);
        let event = RemoveMemberEvent { member: member_addr };
        sui::event::emit<RemoveMemberEvent>(event);
    }

    public fun remove_role(_admin_cap: &AdminCap, config: &mut GlobalConfig, member_addr: address, role_id: u8) {
        checked_package_version(config);
        clmm_pool::acl::remove_role(&mut config.acl, member_addr, role_id);
        let event = RemoveRoleEvent {
            member: member_addr,
            role: role_id,
        };
        sui::event::emit<RemoveRoleEvent>(event);
    }
    public fun set_roles(admin_cap: &AdminCap, config: &mut GlobalConfig, member: address, roles: u128) {
        checked_package_version(config);
        clmm_pool::acl::set_roles(&mut config.acl, member, roles);
        let event = SetRolesEvent {
            member,
            roles,
        };
        sui::event::emit<SetRolesEvent>(event);
    }

    public fun add_fee_tier(config: &mut GlobalConfig, tick_spacing: u32, fee_rate: u64, ctx: &mut sui::tx_context::TxContext) {
        assert!(fee_rate <= max_fee_rate(), 3);
        assert!(!sui::vec_map::contains<u32, FeeTier>(&config.fee_tiers, &tick_spacing), 1);
        checked_package_version(config);
        check_fee_tier_manager_role(config, sui::tx_context::sender(ctx));
        let fee_tier = FeeTier {
            tick_spacing,
            fee_rate,
        };
        sui::vec_map::insert<u32, FeeTier>(&mut config.fee_tiers, tick_spacing, fee_tier);
        let event = AddFeeTierEvent {
            tick_spacing,
            fee_rate,
        };
        sui::event::emit<AddFeeTierEvent>(event);
    }

    public fun check_fee_tier_manager_role(config: &GlobalConfig, member: address) {
        assert!(clmm_pool::acl::has_role(&config.acl, member, 1), 6);
    }

    public fun check_partner_manager_role(config: &GlobalConfig, member: address) {
        assert!(clmm_pool::acl::has_role(&config.acl, member, 3), 7);
    }

    public fun check_pool_manager_role(config: &GlobalConfig, member: address) {
        assert!(clmm_pool::acl::has_role(&config.acl, member, 0), 5);
    }

    public fun check_protocol_fee_claim_role(config: &GlobalConfig, member: address) {
        assert!(clmm_pool::acl::has_role(&config.acl, member, 2), 9);
    }

    public fun check_rewarder_manager_role(config: &GlobalConfig, member: address) {
        assert!(clmm_pool::acl::has_role(&config.acl, member, 4), 8);
    }

    public fun checked_package_version(config: &GlobalConfig) {
        assert!(config.package_version == 1, 10);
    }

    public fun default_unstaked_fee_rate(): u64 {
        72057594037927935
    }

    public fun delete_fee_tier(config: &mut GlobalConfig, tick_spacing: u32, ctx: &mut sui::tx_context::TxContext) {
        assert!(sui::vec_map::contains<u32, FeeTier>(&config.fee_tiers, &tick_spacing), 2);
        checked_package_version(config);
        check_fee_tier_manager_role(config, sui::tx_context::sender(ctx));
        let (_, fee_tier) = sui::vec_map::remove<u32, FeeTier>(&mut config.fee_tiers, &tick_spacing);
        let removed_tier = fee_tier;
        let event = DeleteFeeTierEvent {
            tick_spacing,
            fee_rate: removed_tier.fee_rate,
        };
        sui::event::emit<DeleteFeeTierEvent>(event);
    }

    public fun epoch(timestamp: u64): u64 {
        timestamp / 604800
    }

    public fun epoch_next(timestamp: u64): u64 {
        timestamp - timestamp % 604800 + 604800
    }

    public fun epoch_start(timestamp: u64): u64 {
        timestamp - timestamp % 604800
    }

    public fun fee_rate(fee_tier: &FeeTier): u64 {
        fee_tier.fee_rate
    }

    public fun fee_rate_denom(): u64 {
        1000000
    }

    public fun fee_tiers(config: &GlobalConfig): &sui::vec_map::VecMap<u32, FeeTier> {
        &config.fee_tiers
    }
    public fun get_fee_rate(tick_spacing: u32, config: &GlobalConfig): u64 {
        assert!(sui::vec_map::contains<u32, FeeTier>(&config.fee_tiers, &tick_spacing), 2);
        sui::vec_map::get<u32, FeeTier>(&config.fee_tiers, &tick_spacing).fee_rate
    }

    public fun get_protocol_fee_rate(config: &GlobalConfig): u64 {
        config.protocol_fee_rate
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let mut global_config = GlobalConfig {
            id: sui::object::new(ctx),
            protocol_fee_rate : 2000, 
            unstaked_liquidity_fee_rate : 0, 
            fee_tiers: sui::vec_map::empty<u32, FeeTier>(),
            acl: clmm_pool::acl::new(ctx),
            package_version: 1,
            alive_gauges: sui::vec_set::empty<sui::object::ID>(),
        };
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        set_roles(&admin_cap, &mut global_config, sui::tx_context::sender(ctx), 27);
        let init_event = InitConfigEvent {
            admin_cap_id: sui::object::id<AdminCap>(&admin_cap),
            global_config_id: sui::object::id<GlobalConfig>(&global_config),
        };
        sui::transfer::transfer<AdminCap>(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object<GlobalConfig>(global_config);
        sui::event::emit<InitConfigEvent>(init_event);
    }

    public fun is_gauge_alive(config: &GlobalConfig, gauge_id: sui::object::ID): bool {
        sui::vec_set::contains<sui::object::ID>(&config.alive_gauges, &gauge_id)
    }

    public fun max_fee_rate(): u64 {
        200000
    }

    public fun max_protocol_fee_rate(): u64 {
        3000
    }

    public fun max_unstaked_liquidity_fee_rate(): u64 {
        10000
    }

    public fun protocol_fee_rate(config: &GlobalConfig): u64 {
        config.protocol_fee_rate
    }

    public fun protocol_fee_rate_denom(): u64 {
        10000
    }

    public fun tick_spacing(fee_tier: &FeeTier): u32 {
        fee_tier.tick_spacing
    }

    public fun unstaked_liquidity_fee_rate(config: &GlobalConfig): u64 {
        config.unstaked_liquidity_fee_rate
    }

    public fun unstaked_liquidity_fee_rate_denom(): u64 {
        10000
    }

    public fun update_fee_tier(
        global_config: &mut GlobalConfig,
        tick_spacing: u32,
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(sui::vec_map::contains<u32, FeeTier>(&global_config.fee_tiers, &tick_spacing), 2);
        assert!(new_fee_rate <= max_fee_rate(), 3);
        checked_package_version(global_config);
        check_fee_tier_manager_role(global_config, sui::tx_context::sender(ctx));
        let fee_tier = sui::vec_map::get_mut<u32, FeeTier>(&mut global_config.fee_tiers, &tick_spacing);
        fee_tier.fee_rate = new_fee_rate;
        let event = UpdateFeeTierEvent {
            tick_spacing,
            old_fee_rate: fee_tier.fee_rate,
            new_fee_rate,
        };
        sui::event::emit<UpdateFeeTierEvent>(event);
    }

    public fun update_gauge_liveness(
        global_config: &mut GlobalConfig,
        gauge_ids: vector<sui::object::ID>,
        is_alive: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let mut index = 0;
        let length = std::vector::length<sui::object::ID>(&gauge_ids);
        checked_package_version(global_config);
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        assert!(length > 0, 9223373316755030015);

        if (is_alive) {
            while (index < length) {
                if (!sui::vec_set::contains<sui::object::ID>(
                    &global_config.alive_gauges,
                    std::vector::borrow<sui::object::ID>(&gauge_ids, index)
                )) {
                    let gauge_id = *std::vector::borrow<sui::object::ID>(&gauge_ids, index);
                    sui::vec_set::insert<sui::object::ID>(&mut global_config.alive_gauges, gauge_id);
                };
                index = index + 1;
            };
        } else {
            while (index < length) {
                if (sui::vec_set::contains<sui::object::ID>(
                    &global_config.alive_gauges,
                    std::vector::borrow<sui::object::ID>(&gauge_ids, index)
                )) {
                    let gauge_id = std::vector::borrow<sui::object::ID>(&gauge_ids, index);
                    sui::vec_set::remove<sui::object::ID>(&mut global_config.alive_gauges, gauge_id);
                };
                index = index + 1;
            };
        };
    }

    public fun update_package_version(admin_cap: &AdminCap, global_config: &mut GlobalConfig, new_version: u64) {
        global_config.package_version = new_version;
        let event = SetPackageVersion {
            new_version,
            old_version: global_config.package_version,
        };
        sui::event::emit<SetPackageVersion>(event);
    }

    public fun update_protocol_fee_rate(global_config: &mut GlobalConfig, new_fee_rate: u64, ctx: &mut sui::tx_context::TxContext) {
        assert!(new_fee_rate <= 3000, 4);
        checked_package_version(global_config);
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        global_config.protocol_fee_rate = new_fee_rate;
        let event = UpdateFeeRateEvent {
            old_fee_rate: global_config.protocol_fee_rate,
            new_fee_rate,
        };
        sui::event::emit<UpdateFeeRateEvent>(event);
    }

    public fun update_unstaked_liquidity_fee_rate(
        global_config: &mut GlobalConfig,
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(new_fee_rate <= max_unstaked_liquidity_fee_rate(), 11);
        checked_package_version(global_config);
        check_pool_manager_role(global_config, sui::tx_context::sender(ctx));
        global_config.unstaked_liquidity_fee_rate = new_fee_rate;
        let event = UpdateUnstakedLiquidityFeeRateEvent {
            old_fee_rate: global_config.unstaked_liquidity_fee_rate,
            new_fee_rate,
        };
        sui::event::emit<UpdateUnstakedLiquidityFeeRateEvent>(event);
    }

    public fun week(): u64 {
        604800
    }

    // decompiled from Move bytecode v6
}


module integrate::config_script {
    public entry fun add_fee_tier(
        global_config: &mut clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::add_fee_tier(global_config, tick_spacing, fee_rate, ctx);
    }

    public entry fun add_role(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &mut clmm_pool::config::GlobalConfig,
        member: address,
        role: u8
    ) {
        clmm_pool::config::add_role(admin_cap, global_config, member, role);
    }

    public entry fun delete_fee_tier(
        global_config: &mut clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::delete_fee_tier(global_config, tick_spacing, ctx);
    }

    public entry fun remove_member(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &mut clmm_pool::config::GlobalConfig,
        member: address
    ) {
        clmm_pool::config::remove_member(admin_cap, global_config, member);
    }

    public entry fun remove_role(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &mut clmm_pool::config::GlobalConfig,
        member: address,
        role: u8
    ) {
        clmm_pool::config::remove_role(admin_cap, global_config, member, role);
    }

    public entry fun set_roles(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &mut clmm_pool::config::GlobalConfig,
        member: address,
        roles: u128
    ) {
        clmm_pool::config::set_roles(admin_cap, global_config, member, roles);
    }

    public entry fun update_fee_tier(
        global_config: &mut clmm_pool::config::GlobalConfig,
        tick_spacing: u32,
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::update_fee_tier(global_config, tick_spacing, new_fee_rate, ctx);
    }

    public entry fun update_protocol_fee_rate(
        global_config: &mut clmm_pool::config::GlobalConfig,
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::update_protocol_fee_rate(global_config, new_fee_rate, ctx);
    }

    public entry fun init_fee_tiers(
        global_config: &mut clmm_pool::config::GlobalConfig,
        _admin_cap: &clmm_pool::config::AdminCap,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::add_fee_tier(global_config, 2, 100, ctx);
        clmm_pool::config::add_fee_tier(global_config, 10, 500, ctx);
        clmm_pool::config::add_fee_tier(global_config, 60, 2500, ctx);
        clmm_pool::config::add_fee_tier(global_config, 200, 10000, ctx);
    }

    public entry fun set_position_display(
        global_config: &clmm_pool::config::GlobalConfig,
        publisher: &sui::package::Publisher,
        description: std::string::String,
        link: std::string::String,
        project_url: std::string::String,
        creator: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::position::set_display(
            global_config,
            publisher,
            description,
            link,
            project_url,
            creator,
            ctx
        );
    }
}


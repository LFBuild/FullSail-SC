module integrate::config_script {
    public entry fun add_fee_tier(arg0: &mut clmm_pool::config::GlobalConfig, arg1: u32, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) {
        clmm_pool::config::add_fee_tier(arg0, arg1, arg2, arg3);
    }
    
    public entry fun add_role(arg0: &clmm_pool::config::AdminCap, arg1: &mut clmm_pool::config::GlobalConfig, arg2: address, arg3: u8) {
        clmm_pool::config::add_role(arg0, arg1, arg2, arg3);
    }
    
    public entry fun delete_fee_tier(arg0: &mut clmm_pool::config::GlobalConfig, arg1: u32, arg2: &mut 0x2::tx_context::TxContext) {
        clmm_pool::config::delete_fee_tier(arg0, arg1, arg2);
    }
    
    public entry fun remove_member(arg0: &clmm_pool::config::AdminCap, arg1: &mut clmm_pool::config::GlobalConfig, arg2: address) {
        clmm_pool::config::remove_member(arg0, arg1, arg2);
    }
    
    public entry fun remove_role(arg0: &clmm_pool::config::AdminCap, arg1: &mut clmm_pool::config::GlobalConfig, arg2: address, arg3: u8) {
        clmm_pool::config::remove_role(arg0, arg1, arg2, arg3);
    }
    
    public entry fun set_roles(arg0: &clmm_pool::config::AdminCap, arg1: &mut clmm_pool::config::GlobalConfig, arg2: address, arg3: u128) {
        clmm_pool::config::set_roles(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_fee_tier(arg0: &mut clmm_pool::config::GlobalConfig, arg1: u32, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) {
        clmm_pool::config::update_fee_tier(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_protocol_fee_rate(arg0: &mut clmm_pool::config::GlobalConfig, arg1: u64, arg2: &mut 0x2::tx_context::TxContext) {
        clmm_pool::config::update_protocol_fee_rate(arg0, arg1, arg2);
    }
    
    public entry fun init_fee_tiers(arg0: &mut clmm_pool::config::GlobalConfig, arg1: &clmm_pool::config::AdminCap, arg2: &mut 0x2::tx_context::TxContext) {
        clmm_pool::config::add_fee_tier(arg0, 2, 100, arg2);
        clmm_pool::config::add_fee_tier(arg0, 10, 500, arg2);
        clmm_pool::config::add_fee_tier(arg0, 60, 2500, arg2);
        clmm_pool::config::add_fee_tier(arg0, 200, 10000, arg2);
    }
    
    public entry fun set_position_display(arg0: &clmm_pool::config::GlobalConfig, arg1: &0x2::package::Publisher, arg2: 0x1::string::String, arg3: 0x1::string::String, arg4: 0x1::string::String, arg5: 0x1::string::String, arg6: &mut 0x2::tx_context::TxContext) {
        clmm_pool::position::set_display(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
    }
    
    // decompiled from Move bytecode v6
}


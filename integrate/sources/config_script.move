module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::config_script {
    public entry fun add_fee_tier(arg0: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: u32, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_fee_tier(arg0, arg1, arg2, arg3);
    }
    
    public entry fun add_role(arg0: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::AdminCap, arg1: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg2: address, arg3: u8) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_role(arg0, arg1, arg2, arg3);
    }
    
    public entry fun delete_fee_tier(arg0: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: u32, arg2: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::delete_fee_tier(arg0, arg1, arg2);
    }
    
    public entry fun remove_member(arg0: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::AdminCap, arg1: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg2: address) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::remove_member(arg0, arg1, arg2);
    }
    
    public entry fun remove_role(arg0: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::AdminCap, arg1: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg2: address, arg3: u8) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::remove_role(arg0, arg1, arg2, arg3);
    }
    
    public entry fun set_roles(arg0: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::AdminCap, arg1: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg2: address, arg3: u128) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::set_roles(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_fee_tier(arg0: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: u32, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::update_fee_tier(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_protocol_fee_rate(arg0: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: u64, arg2: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::update_protocol_fee_rate(arg0, arg1, arg2);
    }
    
    public entry fun init_fee_tiers(arg0: &mut 0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::AdminCap, arg2: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_fee_tier(arg0, 2, 100, arg2);
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_fee_tier(arg0, 10, 500, arg2);
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_fee_tier(arg0, 60, 2500, arg2);
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::add_fee_tier(arg0, 200, 10000, arg2);
    }
    
    public entry fun set_position_display(arg0: &0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::config::GlobalConfig, arg1: &0x2::package::Publisher, arg2: 0x1::string::String, arg3: 0x1::string::String, arg4: 0x1::string::String, arg5: 0x1::string::String, arg6: &mut 0x2::tx_context::TxContext) {
        0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d::position::set_display(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
    }
    
    // decompiled from Move bytecode v6
}


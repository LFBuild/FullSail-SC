module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::partner_script {
    public entry fun claim_ref_fee<T0>(arg0: &clmm_pool::config::GlobalConfig, arg1: &clmm_pool::partner::PartnerCap, arg2: &mut clmm_pool::partner::Partner, arg3: &mut 0x2::tx_context::TxContext) {
        clmm_pool::partner::claim_ref_fee<T0>(arg0, arg1, arg2, arg3);
    }
    
    public entry fun create_partner(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::partner::Partners, arg2: 0x1::string::String, arg3: u64, arg4: u64, arg5: u64, arg6: address, arg7: &0x2::clock::Clock, arg8: &mut 0x2::tx_context::TxContext) {
        clmm_pool::partner::create_partner(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
    }
    
    public entry fun update_partner_ref_fee_rate(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::partner::Partner, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) {
        clmm_pool::partner::update_ref_fee_rate(arg0, arg1, arg2, arg3);
    }
    
    public entry fun update_partner_time_range(arg0: &clmm_pool::config::GlobalConfig, arg1: &mut clmm_pool::partner::Partner, arg2: u64, arg3: u64, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        clmm_pool::partner::update_time_range(arg0, arg1, arg2, arg3, arg4, arg5);
    }
    
    // decompiled from Move bytecode v6
}


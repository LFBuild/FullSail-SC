module integrate::partner_script {

    public entry fun claim_ref_fee<T0>(
        global_config: &clmm_pool::config::GlobalConfig,
        partner_cap: &clmm_pool::partner::PartnerCap,
        partner: &mut clmm_pool::partner::Partner,
        ctx: &mut TxContext
    ) {
        clmm_pool::partner::claim_ref_fee<T0>(global_config, partner_cap, partner, ctx);
    }

    public entry fun create_partner(
        global_config: &clmm_pool::config::GlobalConfig,
        partners: &mut clmm_pool::partner::Partners,
        name: std::string::String,
        ref_fee_rate: u64,
        start_time: u64,
        end_time: u64,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let partner_start_time = if (start_time == 0) {
            clock.timestamp_ms() / 1000
        } else {
            start_time
        };
        clmm_pool::partner::create_partner(
            global_config,
            partners,
            name,
            ref_fee_rate,
            partner_start_time,
            end_time,
            recipient,
            clock,
            ctx
        );
    }

    public entry fun update_partner_ref_fee_rate(
        global_config: &clmm_pool::config::GlobalConfig,
        partner: &mut clmm_pool::partner::Partner,
        new_fee_rate: u64,
        ctx: &mut TxContext
    ) {
        clmm_pool::partner::update_ref_fee_rate(global_config, partner, new_fee_rate, ctx);
    }

    public entry fun update_partner_time_range(
        global_config: &clmm_pool::config::GlobalConfig,
        partner: &mut clmm_pool::partner::Partner,
        start_time: u64,
        end_time: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        clmm_pool::partner::update_time_range(global_config, partner, start_time, end_time, clock, ctx);
    }
}


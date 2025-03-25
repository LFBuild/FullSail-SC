module distribution::distribution_config {

    const EUpdateGaugeLivenessNoGauges: u64 = 9223372148523925503;

    public struct DistributionConfig has store, key {
        id: UID,
        alive_gauges: sui::vec_set::VecSet<ID>,
    }

    fun init(ctx: &mut TxContext) {
        let distribution_config = DistributionConfig {
            id: object::new(ctx),
            alive_gauges: sui::vec_set::empty<ID>(),
        };
        transfer::share_object<DistributionConfig>(distribution_config);
    }

    public fun is_gauge_alive(distribution_config: &DistributionConfig, gauge_id: ID): bool {
        distribution_config.alive_gauges.contains(&gauge_id)
    }

    public(package) fun update_gauge_liveness(
        distribution_config: &mut DistributionConfig,
        gauge_ids: vector<ID>,
        is_alive: bool
    ) {
        let mut i = 0;
        let gauges_length = gauge_ids.length();
        assert!(gauges_length > 0, EUpdateGaugeLivenessNoGauges);
        if (is_alive) {
            while (i < gauges_length) {
                if (!distribution_config.alive_gauges.contains(gauge_ids.borrow(i))) {
                    let gauge_id = *gauge_ids.borrow(i);
                    distribution_config.alive_gauges.insert(gauge_id);
                };
                i = i + 1;
            };
        } else {
            while (i < gauges_length) {
                if (distribution_config.alive_gauges.contains(gauge_ids.borrow(i))) {
                    let gauge_id = gauge_ids.borrow(i);
                    distribution_config.alive_gauges.remove(gauge_id);
                };
                i = i + 1;
            };
        };
    }
}


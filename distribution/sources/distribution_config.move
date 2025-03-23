module distribution::distribution_config {
    public struct DistributionConfig has store, key {
        id: sui::object::UID,
        alive_gauges: sui::vec_set::VecSet<sui::object::ID>,
    }

    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = DistributionConfig {
            id: sui::object::new(arg0),
            alive_gauges: sui::vec_set::empty<sui::object::ID>(),
        };
        sui::transfer::share_object<DistributionConfig>(v0);
    }

    public fun is_gauge_alive(arg0: &DistributionConfig, arg1: sui::object::ID): bool {
        arg0.alive_gauges.contains(&arg1)
    }

    public(package) fun update_gauge_liveness(
        arg0: &mut DistributionConfig,
        arg1: vector<sui::object::ID>,
        arg2: bool,
        _arg3: &mut sui::tx_context::TxContext
    ) {
        let mut v0 = 0;
        let v1 = arg1.length();
        assert!(v1 > 0, 9223372148523925503);
        if (arg2) {
            while (v0 < v1) {
                if (!arg0.alive_gauges.contains(arg1.borrow(v0))) {
                    let v2 = *arg1.borrow(v0);
                    arg0.alive_gauges.insert(v2);
                };
                v0 = v0 + 1;
            };
        } else {
            while (v0 < v1) {
                if (arg0.alive_gauges.contains(arg1.borrow(v0))) {
                    let v3 = arg1.borrow(v0);
                    arg0.alive_gauges.remove(v3);
                };
                v0 = v0 + 1;
            };
        };
    }

    // decompiled from Move bytecode v6
}


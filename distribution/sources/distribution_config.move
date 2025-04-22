/// The distribution_config module manages the tracking of active gauges in the ve(3,3) DEX system.
/// It maintains a list of active gauges that participate in token distribution and rewards.
module distribution::distribution_config {

    /// Error code for attempting to update gauge liveness with an empty list of gauges
    const EUpdateGaugeLivenessNoGauges: u64 = 9223372148523925503;

    /// The main configuration object that tracks active gauges in the distribution system
    /// 
    /// # Fields
    /// * `id` - The unique identifier for this shared object
    /// * `alive_gauges` - A set of gauge IDs that are currently active in the system
    public struct DistributionConfig has store, key {
        id: UID,
        alive_gauges: sui::vec_set::VecSet<ID>,
    }

    /// Initializes the distribution configuration object
    /// This function is called once during module initialization to create and share
    /// the DistributionConfig object
    /// 
    /// # Arguments
    /// * `ctx` - The transaction context
    fun init(ctx: &mut TxContext) {
        let distribution_config = DistributionConfig {
            id: object::new(ctx),
            alive_gauges: sui::vec_set::empty<ID>(),
        };
        transfer::share_object<DistributionConfig>(distribution_config);
    }

    /// Checks if a specific gauge is currently active in the system
    /// 
    /// # Arguments
    /// * `distribution_config` - The distribution configuration object
    /// * `gauge_id` - The ID of the gauge to check
    /// 
    /// # Returns
    /// True if the gauge is active, false otherwise
    public fun is_gauge_alive(distribution_config: &DistributionConfig, gauge_id: ID): bool {
        distribution_config.alive_gauges.contains(&gauge_id)
    }

    /// Updates the liveness status of multiple gauges
    /// This function can either add gauges to the active set or remove them,
    /// depending on the is_alive parameter
    /// 
    /// # Arguments
    /// * `distribution_config` - The distribution configuration object to update
    /// * `gauge_ids` - Vector of gauge IDs to update
    /// * `is_alive` - Boolean flag indicating whether to mark gauges as alive (true) or dead (false)
    /// 
    /// # Aborts
    /// * If the gauge_ids vector is empty
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

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
/// 
/// The distribution_config module manages the tracking of active gauges in the ve(3,3) DEX system.
/// It maintains a list of active gauges that participate in token distribution and rewards.
module governance::distribution_config {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    /// Incremental version of the package.
    const VERSION: u64 = 4;

    use sui::vec_set::{Self, VecSet};
    use switchboard::aggregator::{Aggregator};

    /// Error code for attempting to update gauge liveness with an empty list of gauges
    const EUpdateGaugeLivenessNoGauges: u64 = 9223372148523925503;
    const EInvalidPackageVersion: u64 = 458466182903521300;
    const ESetPackageVersionInvalidPublisher: u64 = 24442067766657028;
    const ESetPackageVersionInvalidVersion: u64 = 326963916733903800;

    const LIQUIDITY_UPDATE_COOLDOWN_KEY: vector<u8> = b"liquidity_update_cooldown";

    public struct DISTRIBUTION_CONFIG has drop {}

    /// The main configuration object that tracks active gauges in the distribution system
    /// 
    /// # Fields
    /// * `id` - The unique identifier for this shared object
    /// * `alive_gauges` - A set of gauge IDs that are currently active in the system
    /// * `liquidity_update_cooldown` - Time interval in seconds after liquidity update during which reward claims return zero (stored in bag for backward compatibility)
    public struct DistributionConfig has store, key {
        id: UID,
        alive_gauges: VecSet<ID>,
        // will probably be the same as sail_price_aggregator_id in practice.
        // But we keep it separate for now to be ready for future changes.
        o_sail_price_aggregator_id: Option<ID>,
        sail_price_aggregator_id: Option<ID>,
        version: u64,
        bag: sui::bag::Bag,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    /// Initializes the distribution configuration object
    /// This function is called once during module initialization to create and share
    /// the DistributionConfig object
    /// 
    /// # Arguments
    /// * `ctx` - The transaction context
    fun init(otw: DISTRIBUTION_CONFIG, ctx: &mut TxContext) {
        sui::package::claim_and_keep<DISTRIBUTION_CONFIG>(otw, ctx);
        let distribution_config = DistributionConfig {
            id: object::new(ctx),
            alive_gauges: vec_set::empty<ID>(),
            o_sail_price_aggregator_id: option::none<ID>(),
            sail_price_aggregator_id: option::none<ID>(),
            version: VERSION,
            bag: sui::bag::new(ctx),
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

    public fun borrow_alive_gauges(distribution_config: &DistributionConfig): &VecSet<ID> {
        &distribution_config.alive_gauges
    }

    public(package) fun set_o_sail_price_aggregator(
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.o_sail_price_aggregator_id = option::some(object::id(aggregator));
    }

    public(package) fun set_sail_price_aggregator(
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.sail_price_aggregator_id = option::some(object::id(aggregator));
    }

    #[test_only]
    public fun test_set_o_sail_price_aggregator(
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.o_sail_price_aggregator_id = option::some(object::id(aggregator));
    }

    #[test_only]
    public fun test_set_sail_price_aggregator(
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.sail_price_aggregator_id = option::some(object::id(aggregator));
    }

    public fun is_valid_o_sail_price_aggregator(
        distribution_config: &DistributionConfig,
        aggregator: &Aggregator,
    ): bool {
        distribution_config.o_sail_price_aggregator_id.is_some() && 
        object::id(aggregator) == distribution_config.o_sail_price_aggregator_id.borrow()
    }

    public fun is_valid_sail_price_aggregator(
        distribution_config: &DistributionConfig,
        aggregator: &Aggregator,
    ): bool {
        distribution_config.sail_price_aggregator_id.is_some() && 
        object::id(aggregator) == distribution_config.sail_price_aggregator_id.borrow()
    }

    public fun checked_package_version(distribution_config: &DistributionConfig) {
        assert!(distribution_config.version == VERSION, EInvalidPackageVersion);
    }

    public fun set_package_version(distribution_config: &mut DistributionConfig, publisher: &sui::package::Publisher, version: u64) {
        assert!(publisher.from_module<DISTRIBUTION_CONFIG>(), ESetPackageVersionInvalidPublisher);
        assert!(version <= VERSION, ESetPackageVersionInvalidVersion);
        distribution_config.version = version;
    }

    /// Returns the current liquidity_update_cooldown value
    /// This is the time interval (in seconds) after a liquidity update during which reward claims return zero.
    /// The value is stored in bag for backward compatibility during package upgrades
    /// 
    /// # Arguments
    /// * `distribution_config` - Reference to the distribution configuration
    /// 
    /// # Returns
    /// The current liquidity_update_cooldown value in seconds (defaults to 0 if not set)
    public fun get_liquidity_update_cooldown(distribution_config: &DistributionConfig): u64 {
        if (sui::bag::contains(&distribution_config.bag, LIQUIDITY_UPDATE_COOLDOWN_KEY)) {
            *sui::bag::borrow(&distribution_config.bag, LIQUIDITY_UPDATE_COOLDOWN_KEY)
        } else {
            0
        }
    }

    /// Updates the liquidity_update_cooldown value
    /// This sets the time interval (in seconds) after a liquidity update during which reward claims return zero.
    /// 
    /// # Arguments
    /// * `distribution_config` - Mutable reference to the distribution configuration
    /// * `new_cooldown` - New cooldown value in seconds (e.g., 600 for 10 minutes)
    public(package) fun set_liquidity_update_cooldown(
        distribution_config: &mut DistributionConfig,
        new_cooldown: u64,
    ) {
        if (distribution_config.bag.contains(LIQUIDITY_UPDATE_COOLDOWN_KEY)) {
            distribution_config.bag.remove<vector<u8>, u64>(LIQUIDITY_UPDATE_COOLDOWN_KEY);
        };
        distribution_config.bag.add(LIQUIDITY_UPDATE_COOLDOWN_KEY, new_cooldown);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(DISTRIBUTION_CONFIG {}, ctx);
    }
}

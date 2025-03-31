module clmm_pool::stats {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use clmm_pool::config::{Self, GlobalConfig};
    use clmm_pool::acl;

    public struct InitStatsEvent has copy, drop {
        stats_id: ID,
    }

    public struct UpdatePriceSupplierEvent has copy, drop {
        new_price_supplier: address,
    }

    public struct Stats has store, key {
        id: UID,
        total_volume: u64,
        price_supplier: address,
    }

    fun init(ctx: &mut TxContext) {
        let stats = Stats {
            id: object::new(ctx),
            total_volume: 0,
            price_supplier: @0x0,
        };
        let init_event = InitStatsEvent {
            stats_id: object::id<Stats>(&stats),
        };
        transfer::share_object<Stats>(stats);
        event::emit<InitStatsEvent>(init_event);
    }

    public fun get_total_volume(stats: &Stats): u64 {
        stats.total_volume
    }

    public fun get_price_supplier(stats: &Stats): address {
        stats.price_supplier
    }

    // Внутренний метод для обновления объема, доступный только внутри пакета
    public(package) fun add_total_volume_internal(stats: &mut Stats, amount: u64) {
        stats.total_volume = stats.total_volume + amount;
    }

    public fun update_price_supplier(
        stats: &mut Stats,
        global_config: &GlobalConfig,
        new_price_supplier: address,
        ctx: &mut TxContext
    ) {
        config::checked_package_version(global_config);
        assert!(acl::has_role(config::acl(global_config), tx_context::sender(ctx), 0), 1);
        stats.price_supplier = new_price_supplier;
        let event = UpdatePriceSupplierEvent {
            new_price_supplier,
        };
        event::emit<UpdatePriceSupplierEvent>(event);
    }
}
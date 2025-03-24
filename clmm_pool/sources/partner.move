module clmm_pool::partner {
    public struct Partners has key {
        id: sui::object::UID,
        partners: sui::vec_map::VecMap<std::string::String, sui::object::ID>,
    }

    public struct PartnerCap has store, key {
        id: sui::object::UID,
        name: std::string::String,
        partner_id: sui::object::ID,
    }

    public struct Partner has store, key {
        id: sui::object::UID,
        name: std::string::String,
        ref_fee_rate: u64,
        start_time: u64,
        end_time: u64,
        balances: sui::bag::Bag,
    }

    public struct InitPartnerEvent has copy, drop {
        partners_id: sui::object::ID,
    }

    public struct CreatePartnerEvent has copy, drop {
        recipient: address,
        partner_id: sui::object::ID,
        partner_cap_id: sui::object::ID,
        ref_fee_rate: u64,
        name: std::string::String,
        start_time: u64,
        end_time: u64,
    }

    public struct UpdateRefFeeRateEvent has copy, drop {
        partner_id: sui::object::ID,
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    public struct UpdateTimeRangeEvent has copy, drop {
        partner_id: sui::object::ID,
        start_time: u64,
        end_time: u64,
    }

    public struct ReceiveRefFeeEvent has copy, drop {
        partner_id: sui::object::ID,
        amount: u64,
        type_name: std::string::String,
    }

    public struct ClaimRefFeeEvent has copy, drop {
        partner_id: sui::object::ID,
        amount: u64,
        type_name: std::string::String,
    }
    public fun balances(partner: &Partner): &sui::bag::Bag {
        &partner.balances
    }

    public fun claim_ref_fee<CoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        partner_cap: &PartnerCap,
        partner: &mut Partner,
        ctx: &mut sui::tx_context::TxContext
    ) {
        clmm_pool::config::checked_package_version(global_config);
        assert!(partner_cap.partner_id == sui::object::id<Partner>(partner), 3);
        let type_name = std::string::from_ascii(std::type_name::into_string(std::type_name::get<CoinType>()));
        assert!(sui::bag::contains<std::string::String>(&partner.balances, type_name), 4);
        let balance = sui::bag::remove<std::string::String, sui::balance::Balance<CoinType>>(&mut partner.balances, type_name);
        let amount = sui::balance::value<CoinType>(&balance);
        sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
            sui::coin::from_balance<CoinType>(balance, ctx),
            sui::tx_context::sender(ctx)
        );
        let event = ClaimRefFeeEvent {
            partner_id: sui::object::id<Partner>(partner),
            amount,
            type_name,
        };
        sui::event::emit<ClaimRefFeeEvent>(event);
    }
    
    public fun create_partner(
        global_config: &clmm_pool::config::GlobalConfig,
        partners: &mut Partners,
        name: std::string::String,
        ref_fee_rate: u64,
        start_time: u64,
        end_time: u64,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(end_time > start_time, 6);
        assert!(start_time >= sui::clock::timestamp_ms(clock) / 1000, 7);
        assert!(ref_fee_rate < 10000, 2);
        assert!(!std::string::is_empty(&name), 5);
        assert!(!partners.partners.contains<std::string::String, sui::object::ID>(&name), 5);
        clmm_pool::config::checked_package_version(global_config);
        clmm_pool::config::check_partner_manager_role(global_config, sui::tx_context::sender(ctx));
        let partner = Partner {
            id: sui::object::new(ctx),
            name,
            ref_fee_rate,
            start_time,
            end_time,
            balances: sui::bag::new(ctx),
        };
        let partner_id = sui::object::id<Partner>(&partner);
        let partner_cap = PartnerCap {
            id: sui::object::new(ctx),
            name,
            partner_id: partner_id,
        };
        partners.partners.insert<std::string::String, sui::object::ID>(name, partner_id);
        sui::transfer::share_object<Partner>(partner);
        let partner_cap_id = sui::object::id<PartnerCap>(&partner_cap);
        sui::transfer::transfer<PartnerCap>(partner_cap, recipient);
        let create_event = CreatePartnerEvent {
            recipient,
            partner_id: partner_id,
            partner_cap_id,
            ref_fee_rate,
            name,
            start_time,
            end_time,
        };
        sui::event::emit<CreatePartnerEvent>(create_event);
    }
    public fun current_ref_fee_rate(partner: &Partner, current_time: u64): u64 {
        if (partner.start_time > current_time || partner.end_time <= current_time) {
            return 0
        };
        partner.ref_fee_rate
    }

    public fun end_time(partner: &Partner): u64 {
        partner.end_time
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let partners = Partners {
            id: sui::object::new(ctx),
            partners: sui::vec_map::empty<std::string::String, sui::object::ID>(),
        };
        let partners_id = sui::object::id<Partners>(&partners);
        sui::transfer::share_object<Partners>(partners);
        let event = InitPartnerEvent { partners_id };
        sui::event::emit<InitPartnerEvent>(event);
    }

    public fun name(partner: &Partner): std::string::String {
        partner.name
    }
    public fun receive_ref_fee<CoinType>(partner: &mut Partner, balance: sui::balance::Balance<CoinType>) {
        let type_name = std::string::from_ascii(std::type_name::into_string(std::type_name::get<CoinType>()));
        let amount = sui::balance::value<CoinType>(&balance);
        if (sui::bag::contains<std::string::String>(&partner.balances, type_name)) {
            sui::balance::join<CoinType>(
                sui::bag::borrow_mut<std::string::String, sui::balance::Balance<CoinType>>(&mut partner.balances, type_name),
                balance
            );
        } else {
            sui::bag::add<std::string::String, sui::balance::Balance<CoinType>>(&mut partner.balances, type_name, balance);
        };
        let event = ReceiveRefFeeEvent {
            partner_id: sui::object::id<Partner>(partner),
            amount,
            type_name,
        };
        sui::event::emit<ReceiveRefFeeEvent>(event);
    }

    public fun ref_fee_rate(partner: &Partner): u64 {
        partner.ref_fee_rate
    }

    public fun start_time(partner: &Partner): u64 {
        partner.start_time
    }

    public fun update_ref_fee_rate(
        global_config: &clmm_pool::config::GlobalConfig,
        partner: &mut Partner,
        new_fee_rate: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(new_fee_rate < 10000, 2);
        clmm_pool::config::checked_package_version(global_config);
        clmm_pool::config::check_partner_manager_role(global_config, sui::tx_context::sender(ctx));
        partner.ref_fee_rate = new_fee_rate;
        let event = UpdateRefFeeRateEvent {
            partner_id: sui::object::id<Partner>(partner),
            old_fee_rate: partner.ref_fee_rate,
            new_fee_rate,
        };
        sui::event::emit<UpdateRefFeeRateEvent>(event);
    }

    public fun update_time_range(
        global_config: &clmm_pool::config::GlobalConfig,
        partner: &mut Partner,
        start_time: u64,
        end_time: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(end_time > start_time, 6);
        assert!(end_time > sui::clock::timestamp_ms(clock) / 1000, 6);
        clmm_pool::config::checked_package_version(global_config);
        clmm_pool::config::check_partner_manager_role(global_config, sui::tx_context::sender(ctx));
        partner.start_time = start_time;
        partner.end_time = end_time;
        let event = UpdateTimeRangeEvent {
            partner_id: sui::object::id<Partner>(partner),
            start_time,
            end_time,
        };
        sui::event::emit<UpdateTimeRangeEvent>(event);
    }

    // decompiled from Move bytecode v6
}

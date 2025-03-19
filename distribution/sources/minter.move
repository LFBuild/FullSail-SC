module distribution::minter {

    const EMinterCapAlreadySet: u64 = 9223372831423725567;

    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct MINTER has drop {}

    public struct EventUpdateEpoch has copy, drop, store {
        new_period: u64,
        new_epoch: u64,
        new_emissions: u64,
    }

    public struct EventPauseEmission has copy, drop, store {
    }

    public struct EventUnpauseEmission has copy, drop, store {
    }

    public struct EventGrantAdmin has copy, drop, store {
        who: address,
        admin_cap: sui::object::ID,
    }

    public struct Minter<phantom T0> has store, key {
        id: sui::object::UID,
        revoked_admins: sui::vec_set::VecSet<sui::object::ID>,
        paused: bool,
        activated_at: u64,
        active_period: u64,
        epoch_count: u64,
        total_emissions: u64,
        last_epoch_update_time: u64,
        epoch_emissions: u64,
        minter_cap: std::option::Option<distribution::fullsail_token::MinterCap<T0>>,
        base_supply: u64,
        epoch_grow_rate: u64,
        epoch_decay_rate: u64,
        grow_epochs: u64,
        decay_epochs: u64,
        tail_emission_rate: u64,
        team_emission_rate: u64,
        team_wallet: address,
        reward_distributor_cap: std::option::Option<distribution::reward_distributor_cap::RewardDistributorCap>,
        notify_reward_cap: std::option::Option<distribution::notify_reward_cap::NotifyRewardCap>,
        nudges: sui::vec_set::VecSet<u64>,
    }

    public fun total_supply<T0>(arg0: &Minter<T0>): u64 {
        distribution::fullsail_token::total_supply<T0>(
            std::option::borrow<distribution::fullsail_token::MinterCap<T0>>(&arg0.minter_cap)
        )
    }

    public fun activate<T0>(
        arg0: &mut Minter<T0>,
        arg1: &AdminCap,
        arg2: &mut distribution::reward_distributor::RewardDistributor<T0>,
        arg3: &sui::clock::Clock
    ) {
        check_admin<T0>(arg0, arg1);
        assert!(!is_active<T0>(arg0, arg3), 9223373106302222346);
        assert!(
            std::option::is_some<distribution::reward_distributor_cap::RewardDistributorCap>(
                &arg0.reward_distributor_cap
            ),
            9223373110598238234
        );
        let v0 = distribution::common::current_timestamp(arg3);
        arg0.activated_at = v0;
        arg0.active_period = distribution::common::to_period(arg0.activated_at);
        arg0.last_epoch_update_time = v0;
        arg0.epoch_emissions = arg0.base_supply;
        distribution::reward_distributor::start<T0>(
            arg2,
            std::option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &arg0.reward_distributor_cap
            ),
            arg0.active_period,
            arg3
        );
    }

    public fun activated_at<T0>(arg0: &Minter<T0>): u64 {
        arg0.activated_at
    }

    public fun active_period<T0>(arg0: &Minter<T0>): u64 {
        arg0.active_period
    }

    public fun base_supply<T0>(arg0: &Minter<T0>): u64 {
        arg0.base_supply
    }

    public fun calculate_epoch_emissions<T0>(arg0: &Minter<T0>): (u64, u64) {
        if (arg0.epoch_emissions < 8969150000000) {
            (integer_mate::full_math_u64::mul_div_ceil(
                distribution::fullsail_token::total_supply<T0>(
                    std::option::borrow<distribution::fullsail_token::MinterCap<T0>>(&arg0.minter_cap)
                ),
                arg0.tail_emission_rate,
                10000
            ), arg0.epoch_emissions)
        } else {
            let (v2, v3) = if (arg0.epoch_count < 14) {
                let v4 = if (arg0.epoch_emissions == 0) {
                    arg0.base_supply
                } else {
                    arg0.epoch_emissions
                };
                (v4, v4 + integer_mate::full_math_u64::mul_div_ceil(v4, arg0.epoch_grow_rate, 10000))
            } else {
                let v5 = arg0.epoch_emissions;
                (v5, v5 - integer_mate::full_math_u64::mul_div_ceil(v5, arg0.epoch_decay_rate, 10000))
            };
            (v2, v3)
        }
    }

    public fun calculate_rebase_growth(arg0: u64, arg1: u64, arg2: u64): u64 {
        integer_mate::full_math_u64::mul_div_ceil(
            integer_mate::full_math_u64::mul_div_ceil(arg0, arg1 - arg2, arg1),
            arg1 - arg2,
            arg1
        ) / 2
    }

    public fun check_admin<T0>(arg0: &Minter<T0>, arg1: &AdminCap) {
        let v0 = sui::object::id<AdminCap>(arg1);
        assert!(!sui::vec_set::contains<sui::object::ID>(&arg0.revoked_admins, &v0), 9223372809948889087);
    }

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        minter_cap: std::option::Option<distribution::fullsail_token::MinterCap<SailCoinType>>,
        ctx: &mut sui::tx_context::TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        let minter = Minter<SailCoinType> {
            id: sui::object::new(ctx),
            revoked_admins: sui::vec_set::empty<sui::object::ID>(),
            paused: false,
            activated_at: 0,
            active_period: 0,
            epoch_count: 0,
            total_emissions: 0,
            last_epoch_update_time: 0,
            epoch_emissions: 0,
            minter_cap,
            base_supply: 10000000000000,
            epoch_grow_rate: 10300,
            epoch_decay_rate: 9900,
            grow_epochs: 14,
            decay_epochs: 67,
            tail_emission_rate: 67,
            team_emission_rate: 500,
            team_wallet: @0x0,
            reward_distributor_cap: std::option::none<distribution::reward_distributor_cap::RewardDistributorCap>(),
            notify_reward_cap: std::option::none<distribution::notify_reward_cap::NotifyRewardCap>(),
            nudges: sui::vec_set::empty<u64>(),
        };
        let admin_cap = AdminCap { id: sui::object::new(ctx) };
        (minter, admin_cap)
    }

    public fun epoch<T0>(arg0: &Minter<T0>): u64 {
        arg0.epoch_count
    }

    public fun epoch_emissions<T0>(arg0: &Minter<T0>): u64 {
        arg0.epoch_emissions
    }

    public fun grant_admin(_arg0: &sui::package::Publisher, arg1: address, arg2: &mut sui::tx_context::TxContext) {
        let v0 = AdminCap { id: sui::object::new(arg2) };
        let v1 = EventGrantAdmin {
            who: arg1,
            admin_cap: sui::object::id<AdminCap>(&v0),
        };
        sui::event::emit<EventGrantAdmin>(v1);
        sui::transfer::transfer<AdminCap>(v0, arg1);
    }

    fun init(arg0: MINTER, arg1: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<MINTER>(arg0, arg1);
    }

    public fun is_active<T0>(arg0: &Minter<T0>, arg1: &sui::clock::Clock): bool {
        if (arg0.activated_at > 0) {
            if (!arg0.paused) {
                distribution::common::current_period(arg1) >= arg0.active_period
            } else {
                false
            }
        } else {
            false
        }
    }

    public fun last_epoch_update_time<T0>(arg0: &Minter<T0>): u64 {
        arg0.last_epoch_update_time
    }

    public fun max_bps(): u64 {
        10000
    }

    public fun revoke_admin<T0>(arg0: &mut Minter<T0>, _arg1: &sui::package::Publisher, arg2: sui::object::ID) {
        sui::vec_set::insert<sui::object::ID>(&mut arg0.revoked_admins, arg2);
    }

    /**
    * Puts FullSail token mintercap into minter object.
    */
    public fun set_minter_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        minter_cap: distribution::fullsail_token::MinterCap<SailCoinType>
    ) {
        check_admin<SailCoinType>(minter, admin_cap);
        assert!(
            std::option::is_none<distribution::fullsail_token::MinterCap<SailCoinType>>(&minter.minter_cap),
            EMinterCapAlreadySet
        );
        std::option::fill<distribution::fullsail_token::MinterCap<SailCoinType>>(&mut minter.minter_cap, minter_cap);
    }

    public fun set_notify_reward_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        notify_reward_cap: distribution::notify_reward_cap::NotifyRewardCap
    ) {
        check_admin<SailCoinType>(minter, admin_cap);
        std::option::fill<distribution::notify_reward_cap::NotifyRewardCap>(
            &mut minter.notify_reward_cap,
            notify_reward_cap
        );
    }

    public fun set_reward_distributor_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        reward_distributor_cap: distribution::reward_distributor_cap::RewardDistributorCap
    ) {
        check_admin<SailCoinType>(minter, admin_cap);
        std::option::fill<distribution::reward_distributor_cap::RewardDistributorCap>(
            &mut minter.reward_distributor_cap,
            reward_distributor_cap
        );
    }

    public fun set_team_emission_rate<T0>(arg0: &mut Minter<T0>, arg1: &AdminCap, arg2: u64) {
        check_admin<T0>(arg0, arg1);
        assert!(arg2 <= 500, 9223372921618038783);
        arg0.team_emission_rate = arg2;
    }

    public fun set_team_wallet<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        team_wallet: address
    ) {
        check_admin<SailCoinType>(minter, admin_cap);
        minter.team_wallet = team_wallet;
    }

    public fun team_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.team_emission_rate
    }

    public fun pause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        check_admin<SailCoinType>(minter, admin_cap);
        minter.paused = true;
        let pause_event = EventPauseEmission { };
        sui::event::emit<EventPauseEmission>(pause_event);
    }

    public fun unpause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        check_admin<SailCoinType>(minter, admin_cap);
        minter.paused = false;
        let unpaused_event = EventUnpauseEmission { };
        sui::event::emit<EventUnpauseEmission>(unpaused_event);
    }

    public fun update_period<T0>(
        arg0: &mut Minter<T0>,
        arg1: &mut distribution::voter::Voter<T0>,
        arg2: &distribution::voting_escrow::VotingEscrow<T0>,
        arg3: &mut distribution::reward_distributor::RewardDistributor<T0>,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        assert!(is_active<T0>(arg0, arg4), 9223373394064900104);
        assert!(
            arg0.active_period + distribution::common::week() < distribution::common::current_timestamp(arg4),
            9223373406950588436
        );
        let (v0, v1) = calculate_epoch_emissions<T0>(arg0);
        let v2 = calculate_rebase_growth(
            v0,
            distribution::fullsail_token::total_supply<T0>(
                std::option::borrow<distribution::fullsail_token::MinterCap<T0>>(&arg0.minter_cap)
            ),
            distribution::voting_escrow::total_locked<T0>(arg2)
        );
        let v3 = sui::object::id_address<Minter<T0>>(arg0);
        if (arg0.team_emission_rate > 0 && arg0.team_wallet != @0x0) {
            sui::transfer::public_transfer<sui::coin::Coin<T0>>(
                distribution::fullsail_token::mint<T0>(
                    std::option::borrow_mut<distribution::fullsail_token::MinterCap<T0>>(&mut arg0.minter_cap),
                    integer_mate::full_math_u64::mul_div_floor(
                        arg0.team_emission_rate,
                        v2 + v0,
                        10000 - arg0.team_emission_rate
                    ),
                    v3,
                    arg5
                ),
                arg0.team_wallet
            );
        };
        distribution::reward_distributor::checkpoint_token<T0>(
            arg3,
            std::option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &arg0.reward_distributor_cap
            ),
            distribution::fullsail_token::mint<T0>(
                std::option::borrow_mut<distribution::fullsail_token::MinterCap<T0>>(&mut arg0.minter_cap),
                v2,
                v3,
                arg5
            ),
            arg4
        );
        let id_address = sui::object::id_address<Minter<T0>>(arg0);
        let minter_cap = std::option::borrow_mut<distribution::fullsail_token::MinterCap<T0>>(&mut arg0.minter_cap);
        let notify_reward_cap = std::option::borrow<distribution::notify_reward_cap::NotifyRewardCap>(
            &arg0.notify_reward_cap
        );
        distribution::voter::notify_rewards<T0>(
            arg1,
            notify_reward_cap,
            distribution::fullsail_token::mint<T0>(minter_cap, v0, id_address, arg5)
        );
        arg0.active_period = distribution::common::current_period(arg4);
        arg0.epoch_count = arg0.epoch_count + 1;
        arg0.epoch_emissions = v1;
        distribution::reward_distributor::update_active_period<T0>(
            arg3,
            std::option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &arg0.reward_distributor_cap
            ),
            arg0.active_period
        );
        let v4 = EventUpdateEpoch {
            new_period: arg0.active_period,
            new_epoch: arg0.epoch_count,
            new_emissions: arg0.epoch_emissions,
        };
        sui::event::emit<EventUpdateEpoch>(v4);
    }

    // decompiled from Move bytecode v6
}


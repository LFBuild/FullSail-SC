module distribution::minter {

    const EActivateMinterAlreadyActive: u64 = 9223373106302222346;
    const EActivateMinterNoDistributorCap: u64 = 9223373110598238234;

    const EMinterCapAlreadySet: u64 = 9223372831423725567;

    public struct AdminCap has store, key {
        id: UID,
    }

    public struct MINTER has drop {}

    public struct EventUpdateEpoch has copy, drop, store {
        new_period: u64,
        new_epoch: u64,
        new_emissions: u64,
    }

    public struct EventPauseEmission has copy, drop, store {}

    public struct EventUnpauseEmission has copy, drop, store {}

    public struct EventGrantAdmin has copy, drop, store {
        who: address,
        admin_cap: ID,
    }

    public struct Minter<phantom SailCoinType> has store, key {
        id: UID,
        revoked_admins: sui::vec_set::VecSet<ID>,
        paused: bool,
        activated_at: u64,
        active_period: u64,
        epoch_count: u64,
        total_emissions: u64,
        last_epoch_update_time: u64,
        epoch_emissions: u64,
        minter_cap: Option<distribution::sail_token::MinterCap<SailCoinType>>,
        base_supply: u64,
        epoch_grow_rate: u64,
        epoch_decay_rate: u64,
        grow_epochs: u64,
        decay_epochs: u64,
        tail_emission_rate: u64,
        team_emission_rate: u64,
        team_wallet: address,
        reward_distributor_cap: Option<distribution::reward_distributor_cap::RewardDistributorCap>,
        notify_reward_cap: Option<distribution::notify_reward_cap::NotifyRewardCap>,
        nudges: sui::vec_set::VecSet<u64>,
    }

    public fun total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        option::borrow<distribution::sail_token::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply()
    }

    public fun activate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        clock: &sui::clock::Clock
    ) {
        minter.check_admin(admin_cap);
        assert!(!minter.is_active(clock), EActivateMinterAlreadyActive);
        assert!(
            option::is_some<distribution::reward_distributor_cap::RewardDistributorCap>(
                &minter.reward_distributor_cap
            ),
            EActivateMinterNoDistributorCap
        );
        let current_time = distribution::common::current_timestamp(clock);
        minter.activated_at = current_time;
        minter.active_period = distribution::common::to_period(minter.activated_at);
        minter.last_epoch_update_time = current_time;
        minter.epoch_emissions = minter.base_supply;
        reward_distributor.start(option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
            &minter.reward_distributor_cap
        ), minter.active_period, clock);
    }

    public fun activated_at<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.activated_at
    }

    public fun active_period<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.active_period
    }

    public fun base_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.base_supply
    }

    /**
    * Calculates current epoch emissions and next epoch emission according to
    * FullSail tokenomics.
    * The function returns (current_epoch_emissions, next_epoch_emissions).
    *
    * The emission schedule is separated into three stages:
    * - Emission starts at 10 million tokens per week. For the first 14 weeks, the emission increases by 3% each week.
    * - After 14 weeks, the emission rate decreases by 1% per week until it falls below 9 million tokens per week.
    * - Once the emission rate drops below 9 million tokens, it becomes fixed at a rate of 0.67% per week and remains unchanged thereafter.
    */
    public fun calculate_epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): (u64, u64) {
        if (minter.epoch_emissions < 8969150000000) {
            // epoch emissions drop under 9M
            // weekly emissions after that stabilize at 0.67%
            (
                integer_mate::full_math_u64::mul_div_ceil(
                    option::borrow<distribution::sail_token::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply(
                    ),
                    minter.tail_emission_rate,
                    10000
                ),
                minter.epoch_emissions
            )
        } else {
            let (current_epoch_emissions, next_epoch_emissions) = if (minter.epoch_count < 14) {
                // take-off phase, emissions increase at 3% per week
                let current_emissions = if (minter.epoch_emissions == 0) {
                    minter.base_supply
                } else {
                    minter.epoch_emissions
                };
                (
                    current_emissions,
                    current_emissions + integer_mate::full_math_u64::mul_div_ceil(
                        current_emissions,
                        minter.epoch_grow_rate,
                        10000
                    )
                )
            } else {
                // cruise phase, emissions decay at 1% per week
                let current_emissions = minter.epoch_emissions;
                (
                    current_emissions,
                    current_emissions - integer_mate::full_math_u64::mul_div_ceil(
                        current_emissions,
                        minter.epoch_decay_rate,
                        10000
                    )
                )
            };
            (current_epoch_emissions, next_epoch_emissions)
        }
    }

    public fun calculate_rebase_growth(epoch_emissions: u64, total_supply: u64, total_locked: u64): u64 {
        // epoch_emissions * ((total_supply - total_locked) / total_supply)^2 / 2
        integer_mate::full_math_u64::mul_div_ceil(
            integer_mate::full_math_u64::mul_div_ceil(epoch_emissions, total_supply - total_locked, total_supply),
            total_supply - total_locked,
            total_supply
        ) / 2
    }

    public fun check_admin<SailCoinType>(minter: &Minter<SailCoinType>, admin_cap: &AdminCap) {
        let v0 = object::id<AdminCap>(admin_cap);
        assert!(!minter.revoked_admins.contains<ID>(&v0), 9223372809948889087);
    }

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        minter_cap: Option<distribution::sail_token::MinterCap<SailCoinType>>,
        ctx: &mut TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        let minter = Minter<SailCoinType> {
            id: object::new(ctx),
            revoked_admins: sui::vec_set::empty<ID>(),
            paused: false,
            activated_at: 0,
            active_period: 0,
            epoch_count: 0,
            total_emissions: 0,
            last_epoch_update_time: 0,
            epoch_emissions: 0,
            minter_cap,
            base_supply: 10000000000000, // 10M coins
            epoch_grow_rate: 300,
            epoch_decay_rate: 100,
            grow_epochs: 14,
            decay_epochs: 67,
            tail_emission_rate: 67,
            team_emission_rate: 500,
            team_wallet: @0x0,
            reward_distributor_cap: option::none<distribution::reward_distributor_cap::RewardDistributorCap>(),
            notify_reward_cap: option::none<distribution::notify_reward_cap::NotifyRewardCap>(),
            nudges: sui::vec_set::empty<u64>(),
        };
        let admin_cap = AdminCap { id: object::new(ctx) };
        (minter, admin_cap)
    }

    public fun epoch<SailCoinType>(arg0: &Minter<SailCoinType>): u64 {
        arg0.epoch_count
    }

    public fun epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.epoch_emissions
    }

    public fun grant_admin(_arg0: &sui::package::Publisher, arg1: address, arg2: &mut TxContext) {
        let v0 = AdminCap { id: object::new(arg2) };
        let v1 = EventGrantAdmin {
            who: arg1,
            admin_cap: object::id<AdminCap>(&v0),
        };
        sui::event::emit<EventGrantAdmin>(v1);
        transfer::transfer<AdminCap>(v0, arg1);
    }

    fun init(arg0: MINTER, arg1: &mut TxContext) {
        sui::package::claim_and_keep<MINTER>(arg0, arg1);
    }

    public fun is_active<SailCoinType>(minter: &Minter<SailCoinType>, clock: &sui::clock::Clock): bool {
        if (minter.activated_at > 0) {
            if (!minter.paused) {
                distribution::common::current_period(clock) >= minter.active_period
            } else {
                false
            }
        } else {
            false
        }
    }

    public fun last_epoch_update_time<SailCoinType>(arg0: &Minter<SailCoinType>): u64 {
        arg0.last_epoch_update_time
    }

    public fun max_bps(): u64 {
        10000
    }

    public fun revoke_admin<SailCoinType>(
        arg0: &mut Minter<SailCoinType>,
        _arg1: &sui::package::Publisher,
        arg2: ID
    ) {
        arg0.revoked_admins.insert(arg2);
    }

    /**
    * Puts FullSail token mintercap into minter object.
    */
    public fun set_minter_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        minter_cap: distribution::sail_token::MinterCap<SailCoinType>
    ) {
        minter.check_admin(admin_cap);
        assert!(
            option::is_none<distribution::sail_token::MinterCap<SailCoinType>>(&minter.minter_cap),
            EMinterCapAlreadySet
        );
        option::fill<distribution::sail_token::MinterCap<SailCoinType>>(&mut minter.minter_cap, minter_cap);
    }

    public fun set_notify_reward_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        notify_reward_cap: distribution::notify_reward_cap::NotifyRewardCap
    ) {
        minter.check_admin(admin_cap);
        option::fill<distribution::notify_reward_cap::NotifyRewardCap>(
            &mut minter.notify_reward_cap,
            notify_reward_cap
        );
    }

    public fun set_reward_distributor_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        reward_distributor_cap: distribution::reward_distributor_cap::RewardDistributorCap
    ) {
        minter.check_admin(admin_cap);
        option::fill<distribution::reward_distributor_cap::RewardDistributorCap>(
            &mut minter.reward_distributor_cap,
            reward_distributor_cap
        );
    }

    public fun set_team_emission_rate<SailCoinType>(arg0: &mut Minter<SailCoinType>, arg1: &AdminCap, arg2: u64) {
        arg0.check_admin(arg1);
        assert!(arg2 <= 500, 9223372921618038783);
        arg0.team_emission_rate = arg2;
    }

    public fun set_team_wallet<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        team_wallet: address
    ) {
        minter.check_admin(admin_cap);
        minter.team_wallet = team_wallet;
    }

    public fun team_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.team_emission_rate
    }

    public fun tail_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>) : u64 {
        minter.tail_emission_rate
    }

    public fun pause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        minter.check_admin(admin_cap);
        minter.paused = true;
        let pause_event = EventPauseEmission {};
        sui::event::emit<EventPauseEmission>(pause_event);
    }

    public fun unpause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        minter.check_admin(admin_cap);
        minter.paused = false;
        let unpaused_event = EventUnpauseEmission {};
        sui::event::emit<EventUnpauseEmission>(unpaused_event);
    }

    public fun update_period<SailCoinType>(
        arg0: &mut Minter<SailCoinType>,
        arg1: &mut distribution::voter::Voter<SailCoinType>,
        arg2: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        arg3: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        assert!(arg0.is_active(arg4), 9223373394064900104);
        assert!(
            arg0.active_period + distribution::common::week() < distribution::common::current_timestamp(arg4),
            9223373406950588436
        );
        let (v0, v1) = arg0.calculate_epoch_emissions();
        let v2 = calculate_rebase_growth(
            v0,
            option::borrow<distribution::sail_token::MinterCap<SailCoinType>>(&arg0.minter_cap).total_supply(),
            arg2.total_locked()
        );
        let v3 = object::id_address<Minter<SailCoinType>>(arg0);
        if (arg0.team_emission_rate > 0 && arg0.team_wallet != @0x0) {
            transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(
                    &mut arg0.minter_cap
                ).mint(integer_mate::full_math_u64::mul_div_floor(
                    arg0.team_emission_rate,
                    v2 + v0,
                    10000 - arg0.team_emission_rate
                ), v3, arg5),
                arg0.team_wallet
            );
        };
        arg3.checkpoint_token(
            option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &arg0.reward_distributor_cap
            ),
            option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(&mut arg0.minter_cap).mint(
                v2, v3, arg5
            ),
            arg4
        );
        let id_address = object::id_address<Minter<SailCoinType>>(arg0);
        let minter_cap = option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(
            &mut arg0.minter_cap
        );
        let notify_reward_cap = option::borrow<distribution::notify_reward_cap::NotifyRewardCap>(
            &arg0.notify_reward_cap
        );
        arg1.notify_rewards(notify_reward_cap, minter_cap.mint(v0, id_address, arg5));
        arg0.active_period = distribution::common::current_period(arg4);
        arg0.epoch_count = arg0.epoch_count + 1;
        arg0.epoch_emissions = v1;
        arg3.update_active_period(option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
            &arg0.reward_distributor_cap
        ), arg0.active_period);
        let v4 = EventUpdateEpoch {
            new_period: arg0.active_period,
            new_epoch: arg0.epoch_count,
            new_emissions: arg0.epoch_emissions,
        };
        sui::event::emit<EventUpdateEpoch>(v4);
    }

    // decompiled from Move bytecode v6
}


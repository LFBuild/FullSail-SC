module distribution::minter {

    const EActivateMinterAlreadyActive: u64 = 9223373106302222346;
    const EActivateMinterNoDistributorCap: u64 = 9223373110598238234;

    const EMinterCapAlreadySet: u64 = 9223372831423725567;
    const ESetTeamEmissionRateTooSmallRate: u64 = 9223372921618038783;

    const EUpdatePeriodMinterNotActive: u64 = 9223373394064900104;
    const EUpdatePeriodNotNotFinishedYet: u64 = 9223373406950588436;

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

    public fun epoch<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.epoch_count
    }

    public fun epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.epoch_emissions
    }

    public fun grant_admin(_publisher: &sui::package::Publisher, who: address, ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        let grant_admin_event = EventGrantAdmin {
            who,
            admin_cap: object::id<AdminCap>(&admin_cap),
        };
        sui::event::emit<EventGrantAdmin>(grant_admin_event);
        transfer::transfer<AdminCap>(admin_cap, who);
    }

    fun init(otw: MINTER, ctx: &mut TxContext) {
        sui::package::claim_and_keep<MINTER>(otw, ctx);
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

    public fun last_epoch_update_time<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.last_epoch_update_time
    }

    public fun max_bps(): u64 {
        10000
    }

    public fun revoke_admin<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        _publisher: &sui::package::Publisher,
        who: ID
    ) {
        minter.revoked_admins.insert(who);
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

    public fun set_team_emission_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        team_emission_rate: u64
    ) {
        minter.check_admin(admin_cap);
        assert!(team_emission_rate <= 500, ESetTeamEmissionRateTooSmallRate);
        minter.team_emission_rate = team_emission_rate;
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

    public fun tail_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
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
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(minter.is_active(clock), EUpdatePeriodMinterNotActive);
        assert!(
            minter.active_period + distribution::common::week() < distribution::common::current_timestamp(clock),
            EUpdatePeriodNotNotFinishedYet
        );
        let (current_epoch_emissions, next_epoch_emissions) = minter.calculate_epoch_emissions();
        let rebase_growth = calculate_rebase_growth(
            current_epoch_emissions,
            option::borrow<distribution::sail_token::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply(),
            voting_escrow.total_locked()
        );
        let minter_address = object::id_address<Minter<SailCoinType>>(minter);
        if (minter.team_emission_rate > 0 && minter.team_wallet != @0x0) {
            transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(
                    &mut minter.minter_cap
                ).mint(integer_mate::full_math_u64::mul_div_floor(
                    minter.team_emission_rate,
                    rebase_growth + current_epoch_emissions,
                    10000 - minter.team_emission_rate
                ), minter_address, ctx),
                minter.team_wallet
            );
        };
        reward_distributor.checkpoint_token(
            option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &minter.reward_distributor_cap
            ),
            option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(&mut minter.minter_cap).mint(
                rebase_growth,
                minter_address,
                ctx
            ),
            clock
        );
        let id_address = object::id_address<Minter<SailCoinType>>(minter);
        let minter_cap = option::borrow_mut<distribution::sail_token::MinterCap<SailCoinType>>(
            &mut minter.minter_cap
        );
        let notify_reward_cap = option::borrow<distribution::notify_reward_cap::NotifyRewardCap>(
            &minter.notify_reward_cap
        );
        voter.notify_rewards(notify_reward_cap, minter_cap.mint(current_epoch_emissions, id_address, ctx));
        minter.active_period = distribution::common::current_period(clock);
        minter.epoch_count = minter.epoch_count + 1;
        minter.epoch_emissions = next_epoch_emissions;
        reward_distributor.update_active_period(
            option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &minter.reward_distributor_cap
            ),
            minter.active_period
        );
        let update_epoch_event = EventUpdateEpoch {
            new_period: minter.active_period,
            new_epoch: minter.epoch_count,
            new_emissions: minter.epoch_emissions,
        };
        sui::event::emit<EventUpdateEpoch>(update_epoch_event);
    }
}


module distribution::minter {
    /**
    * @title Minter Module
    * @notice This module manages the tokenomics and emission schedule for the FullSail protocol.
    *
    * The Minter is a core component of the FullSail protocol responsible for:
    * 1. Token Emission Control - Implements a sophisticated three-phase emission schedule:
    *    - Take-off phase: Starting at 10M tokens/week with 3% weekly increase for 14 weeks
    *    - Cruise phase: 1% weekly decay until emissions fall below 9M tokens
    *    - Tail emission phase: Stabilized at 0.67% of total supply per week
    * 
    * 2. Reward Distribution - Mints and distributes tokens to:
    *    - Stakers/voters through the reward distributor
    *    - Team allocation (configurable percentage)
    *    - Rebase growth calculations based on locked vs circulating supply
    * 
    * 3. Governance Control - Administrative functions for:
    *    - Pausing/unpausing emissions during emergencies
    *    - Setting team emission rates and wallet addresses
    *    - Managing admin capabilities with revocation options
    * 
    * The minter interacts with several other components of the ecosystem:
    * - Voting/staking mechanisms (Voter, VotingEscrow)
    * - Reward distribution systems
    * - Token management (via MinterCap)
    *
    * Epochs progress on a weekly basis, with each epoch potentially adjusting emission rates
    * according to the predefined schedule. This controlled emission approach ensures
    * sustainable tokenomics while incentivizing protocol participation.
    */

    const EActivateMinterAlreadyActive: u64 = 9223373106302222346;
    const EActivateMinterNoDistributorCap: u64 = 9223373110598238234;

    const EMinterCapAlreadySet: u64 = 9223372831423725567;
    const ESetTeamEmissionRateTooBigRate: u64 = 9223372921618038783;

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
        minter_cap: Option<distribution::sail_coin::MinterCap<SailCoinType>>,
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

    /// Returns the total supply of SailCoin managed by this minter.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Total supply of SailCoin
    public fun total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        option::borrow<distribution::sail_coin::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply()
    }

    /// Activates the minter to begin token emissions according to the protocol schedule.
    /// Initializes the active period and sets up the reward distributor. This must be
    /// called before any token emissions can occur.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to activate
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `reward_distributor` - The reward distributor that will distribute tokens
    /// * `clock` - The system clock
    ///
    /// # Aborts
    /// * If the minter is already active
    /// * If the reward distributor capability is not set
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

    /// Returns the timestamp when the minter was activated.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Timestamp when the minter was activated, or 0 if not activated
    public fun activated_at<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.activated_at
    }

    /// Returns the current active period of the minter.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Current active period
    public fun active_period<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.active_period
    }

    /// Returns the base supply rate for emissions.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Base supply value for emissions (10M tokens)
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
    *
    * # Arguments
    * * `minter` - The minter instance to calculate emissions for
    *
    * # Returns
    * A tuple with (current_epoch_emissions, next_epoch_emissions)
    */
    public fun calculate_epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): (u64, u64) {
        if (minter.epoch_emissions < 8969150000000) {
            // epoch emissions drop under 9M
            // weekly emissions after that stabilize at 0.67%
            (
                integer_mate::full_math_u64::mul_div_ceil(
                    option::borrow<distribution::sail_coin::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply(
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

    /// Calculates the rebase growth amount based on the relationship between
    /// locked tokens and total supply, following the ve(3,3) model.
    ///
    /// The rebase growth is proportional to the square of the ratio of circulating tokens
    /// to total supply, ensuring that higher lock rates lead to lower inflation.
    ///
    /// # Arguments
    /// * `epoch_emissions` - Current epoch's emission amount
    /// * `total_supply` - Total supply of SailCoin
    /// * `total_locked` - Amount of SailCoin locked in voting escrow
    ///
    /// # Returns
    /// The calculated rebase growth amount
    public fun calculate_rebase_growth(epoch_emissions: u64, total_supply: u64, total_locked: u64): u64 {
        // epoch_emissions * ((total_supply - total_locked) / total_supply)^2 / 2
        integer_mate::full_math_u64::mul_div_ceil(
            integer_mate::full_math_u64::mul_div_ceil(epoch_emissions, total_supply - total_locked, total_supply),
            total_supply - total_locked,
            total_supply
        ) / 2
    }

    /// Verifies that the provided admin capability is valid and not revoked.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to check against
    /// * `admin_cap` - The admin capability to verify
    ///
    /// # Aborts
    /// * If the admin capability has been revoked
    public fun check_admin<SailCoinType>(minter: &Minter<SailCoinType>, admin_cap: &AdminCap) {
        let v0 = object::id<AdminCap>(admin_cap);
        assert!(!minter.revoked_admins.contains<ID>(&v0), 9223372809948889087);
    }

    /// Creates a new Minter instance with default configuration.
    ///
    /// # Arguments
    /// * `_publisher` - Publisher proving authorization
    /// * `minter_cap` - Optional minter capability for SailCoin
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A tuple with (minter, admin_cap), where admin_cap grants administrative privileges
    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        minter_cap: Option<distribution::sail_coin::MinterCap<SailCoinType>>,
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

    /// Returns the current epoch count.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Current epoch count
    public fun epoch<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.epoch_count
    }

    /// Returns the current epoch emissions amount.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Current epoch emissions amount
    public fun epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.epoch_emissions
    }

    /// Grants administrative capability to a specified address.
    ///
    /// # Arguments
    /// * `_publisher` - Publisher proving authorization
    /// * `who` - Address to receive administrative capability
    /// * `ctx` - Transaction context
    ///
    /// # Effects
    /// * Creates and transfers a new AdminCap to the specified address
    /// * Emits a EventGrantAdmin event
    public fun grant_admin(_publisher: &sui::package::Publisher, who: address, ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        let grant_admin_event = EventGrantAdmin {
            who,
            admin_cap: object::id<AdminCap>(&admin_cap),
        };
        sui::event::emit<EventGrantAdmin>(grant_admin_event);
        transfer::transfer<AdminCap>(admin_cap, who);
    }

    /// Initializes the minter module.
    ///
    /// # Arguments
    /// * `otw` - One-time witness for the minter module
    /// * `ctx` - Transaction context
    fun init(otw: MINTER, ctx: &mut TxContext) {
        sui::package::claim_and_keep<MINTER>(otw, ctx);
    }

    /// Checks if the minter is active.
    ///
    /// A minter is considered active if it has been activated, is not paused,
    /// and the current period is at least the minter's active period.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to check
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// True if the minter is active, false otherwise
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

    /// Returns the timestamp of the last epoch update.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Timestamp of the last epoch update
    public fun last_epoch_update_time<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.last_epoch_update_time
    }

    /// Returns the maximum basis points value (10000 = 100%).
    ///
    /// This is used for percentage-based calculations throughout the module.
    ///
    /// # Returns
    /// The maximum basis points value (10000)
    public fun max_bps(): u64 {
        10000
    }

    /// Revokes administrative capabilities for a specific admin.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `_publisher` - Publisher proving authorization
    /// * `who` - ID of the admin capability to revoke
    public fun revoke_admin<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        _publisher: &sui::package::Publisher,
        who: ID
    ) {
        minter.revoked_admins.insert(who);
    }

    /**
    * Puts FullSail token mintercap into minter object.
    *
    * # Arguments
    * * `minter` - The minter instance to modify
    * * `admin_cap` - Administrative capability proving authorization
    * * `minter_cap` - The token minter capability to set
    *
    * # Aborts
    * * If the minter already has a minter capability
    */
    public fun set_minter_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        minter_cap: distribution::sail_coin::MinterCap<SailCoinType>
    ) {
        minter.check_admin(admin_cap);
        assert!(
            option::is_none<distribution::sail_coin::MinterCap<SailCoinType>>(&minter.minter_cap),
            EMinterCapAlreadySet
        );
        option::fill<distribution::sail_coin::MinterCap<SailCoinType>>(&mut minter.minter_cap, minter_cap);
    }

    /// Sets the notify reward capability for the minter.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `notify_reward_cap` - The notify reward capability to set
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

    /// Sets the reward distributor capability for the minter.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `reward_distributor_cap` - The reward distributor capability to set
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

    /// Sets the team emission rate, which determines what percentage of emissions
    /// are allocated to the team wallet.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `team_emission_rate` - The team emission rate in basis points (max 500 = 5%)
    ///
    /// # Aborts
    /// * If the team emission rate exceeds 500 basis points
    public fun set_team_emission_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        team_emission_rate: u64
    ) {
        minter.check_admin(admin_cap);
        assert!(team_emission_rate <= 500, ESetTeamEmissionRateTooBigRate);
        minter.team_emission_rate = team_emission_rate;
    }

    /// Sets the team wallet address that will receive team emissions.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `team_wallet` - Address of the team wallet
    public fun set_team_wallet<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        team_wallet: address
    ) {
        minter.check_admin(admin_cap);
        minter.team_wallet = team_wallet;
    }

    /// Returns the current team emission rate.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Current team emission rate in basis points
    public fun team_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.team_emission_rate
    }

    /// Returns the tail emission rate applied during the final phase of the emission schedule.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Tail emission rate in basis points
    public fun tail_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.tail_emission_rate
    }

    /// Pauses token emissions from the minter.
    ///
    /// This is an emergency function that can be used to halt token emissions
    /// in case of security issues or other critical situations.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to pause
    /// * `admin_cap` - Administrative capability proving authorization
    ///
    /// # Effects
    /// * Sets the paused flag to true
    /// * Emits a EventPauseEmission event
    public fun pause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        minter.check_admin(admin_cap);
        minter.paused = true;
        let pause_event = EventPauseEmission {};
        sui::event::emit<EventPauseEmission>(pause_event);
    }

    /// Unpauses token emissions from the minter.
    ///
    /// This function re-enables token emissions after they were paused.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to unpause
    /// * `admin_cap` - Administrative capability proving authorization
    ///
    /// # Effects
    /// * Sets the paused flag to false
    /// * Emits a EventUnpauseEmission event
    public fun unpause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        minter.check_admin(admin_cap);
        minter.paused = false;
        let unpaused_event = EventUnpauseEmission {};
        sui::event::emit<EventUnpauseEmission>(unpaused_event);
    }

    /// Updates the active period and processes token emissions for the current epoch.
    ///
    /// This is the core function that drives the tokenomics of the protocol. It:
    /// 1. Calculates emissions for the current epoch
    /// 2. Mints and distributes tokens to the team wallet (if configured)
    /// 3. Handles rebase growth based on locked vs circulating supply
    /// 4. Distributes rewards to voters/stakers
    /// 5. Updates the epoch counters and emission rates for the next epoch
    ///
    /// This function should be called once per week (per epoch) to maintain
    /// the emission schedule.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to update
    /// * `voter` - The voter module that manages gauges and voting
    /// * `voting_escrow` - The voting escrow that tracks locked tokens
    /// * `reward_distributor` - The reward distributor for distributing tokens
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Aborts
    /// * If the minter is not active
    /// * If not enough time has passed since the last update
    ///
    /// # Effects
    /// * Mints and distributes tokens according to the emission schedule
    /// * Updates epoch counters and emission rates
    /// * Emits a EventUpdateEpoch event
    public fun update_period<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
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
            option::borrow<distribution::sail_coin::MinterCap<SailCoinType>>(&minter.minter_cap).total_supply(),
            voting_escrow.total_locked()
        );
        let minter_address = object::id_address<Minter<SailCoinType>>(minter);
        if (minter.team_emission_rate > 0 && minter.team_wallet != @0x0) {
            transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
                option::borrow_mut<distribution::sail_coin::MinterCap<SailCoinType>>(
                    &mut minter.minter_cap
                ).mint(integer_mate::full_math_u64::mul_div_floor(
                    minter.team_emission_rate,
                    rebase_growth + current_epoch_emissions,
                    10000 - minter.team_emission_rate
                ), ctx),
                minter.team_wallet
            );
        };
        reward_distributor.checkpoint_token(
            option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &minter.reward_distributor_cap
            ),
            option::borrow_mut<distribution::sail_coin::MinterCap<SailCoinType>>(&mut minter.minter_cap).mint(
                rebase_growth,
                ctx
            ),
            clock
        );
        let id_address = object::id_address<Minter<SailCoinType>>(minter);
        let minter_cap = option::borrow_mut<distribution::sail_coin::MinterCap<SailCoinType>>(
            &mut minter.minter_cap
        );
        let notify_reward_cap = option::borrow<distribution::notify_reward_cap::NotifyRewardCap>(
            &minter.notify_reward_cap
        );
        voter.notify_rewards(notify_reward_cap, minter_cap.mint(current_epoch_emissions, ctx));
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


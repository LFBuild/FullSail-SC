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
    * - Token management (via TreasuryCap)
    *
    * Epochs progress on a weekly basis, with each epoch potentially adjusting emission rates
    * according to the predefined schedule. This controlled emission approach ensures
    * sustainable tokenomics while incentivizing protocol participation.
    */

    use std::type_name::{Self, TypeName};
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::balance::{Self, Balance};
    use sui::vec_set::{Self, VecSet};
    use sui::bag::{Self, Bag};
    use sui::table::{Self, Table};

    const EActivateMinterAlreadyActive: u64 = 9223373106302222346;
    const EActivateMinterNoDistributorCap: u64 = 9223373110598238234;

    const EMinterCapAlreadySet: u64 = 9223372831423725567;
    const ESetTeamEmissionRateTooBigRate: u64 = 9223372921618038783;
    const ESetProtocolFeeRateTooBigRate: u64 = 8401716227362572000;

    const EUpdatePeriodMinterNotActive: u64 = 9223373394064900104;
    const EUpdatePeriodNotFinishedYet: u64 = 922337340695058843;
    const EUpdatePeriodOSailAlreadyUsed: u64 = 573264404146058900;

    const ECheckAdminRevoked: u64 = 9223372809948889087;

    const ECreateLockFromOSailInvalidToken: u64 = 9162843907639215000;
    const ECreateLockFromOSailInvalidDuraton: u64 = 68567430268160480;

    const EExerciseOSailFreeTooBigPercent: u64 = 4108357525531418600;
    const EExerciseOSailExpired: u64 = 7388437717433252000;
    const EExerciseOSailInvalidOSail: u64 = 3209173623653640700;

    const EBurnOSailInvalidOSail: u64 = 665869556650983200;

    const EExerciseUsdLimitReached: u64 = 4905179424474806000;
    const EExerciseOSailPoolNotWhitelisted: u64 = 2212524000647910700;

    const ETeamWalletNotSet: u64 = 7981414426077109000;
    const EDistributeTeamTokenNotFound: u64 = 9629256792821774000;

    const DAYS_IN_WEEK: u64 = 7;

    /// Possible lock duration available be oSAIL expiry date
    const VALID_O_SAIL_DURATION_DAYS: vector<u64> = vector[
        26 * DAYS_IN_WEEK, // 6 months
        2 * 52 * DAYS_IN_WEEK, // 2 years
        4 * 52 * DAYS_IN_WEEK // 4 years
    ];

    /// After expiration oSAIL can only be locked for 4 years or permanently
    const VALID_EXPIRED_O_SAIL_DURATION_DAYS: u64 =  4 * 52 * 7;

    /// Denominator in rate calculations (i.e. fee percent, team emission percent)
    const RATE_DENOM: u64 = 10000;

    const MAX_TEAM_EMISSIONS_RATE: u64 = 500;
    const MAX_PROTOCOL_FEE_RATE: u64 = 3000;

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
        revoked_admins: VecSet<ID>,
        paused: bool,
        activated_at: u64,
        active_period: u64,
        epoch_count: u64,
        // The oSAIL which will be distributed at the begining of new epoch and during the epoch
        current_epoch_o_sail: Option<TypeName>,
        last_epoch_update_time: u64,
        epoch_emissions: u64,
        sail_cap: Option<TreasuryCap<SailCoinType>>,
        o_sail_caps: Bag,
        // sum of supplies of all o_sail tokens
        o_sail_total_supply: u64,
        o_sail_expiry_dates: Table<TypeName, u64>,
        base_supply: u64,
        epoch_grow_rate: u64,
        epoch_decay_rate: u64,
        tail_emission_rate: u64,
        team_emission_rate: u64,
        protocol_fee_rate: u64,
        team_wallet: address,
        reward_distributor_cap: Option<distribution::reward_distributor_cap::RewardDistributorCap>,
        notify_reward_cap: Option<distribution::notify_reward_cap::NotifyRewardCap>,
        // pools that can be used to exercise oSAIL
        // we don't need whitelisted tokens, cos
        // pool whitelist also determines token whitelist composed of the pools tokens.
        whitelisted_pools: VecSet<ID>,
        // tokens that were used to pay for oSAIL exercise fee
        exercise_fee_tokens: VecSet<TypeName>,
        exercise_fee_team_balances: Bag,
    }

    /// Returns the total supply only of SailCoin managed by this minter.
    public fun sail_total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        option::borrow<TreasuryCap<SailCoinType>>(&minter.sail_cap).total_supply()
    }

    /// Return the sum of total supplies of all oSAIL coins
    public fun o_sail_total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.o_sail_total_supply
    }

    /// Return the total supply of both SAIL an all oSAIL coins
    public fun total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.sail_total_supply() + minter.o_sail_total_supply
    }


    /// Activates the minter to begin token emissions according to the protocol schedule.
    /// Initializes the active period and sets up the reward distributor. This must be
    /// called before any token emissions can occur.
    /// No tokens minted during zero epoch.
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
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        minter.check_admin(admin_cap);
        assert!(!minter.is_active(clock), EActivateMinterAlreadyActive);
        assert!(
            option::is_some(&minter.reward_distributor_cap),
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
                    minter.total_supply(),
                    minter.tail_emission_rate,
                    RATE_DENOM
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
                        RATE_DENOM
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
                        RATE_DENOM
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
        let admin_cap_id = object::id<AdminCap>(admin_cap);
        assert!(!minter.revoked_admins.contains<ID>(&admin_cap_id), ECheckAdminRevoked);
    }

    /// Creates a new Minter instance with default configuration.
    ///
    /// # Arguments
    /// * `_publisher` - Publisher proving authorization
    /// * `treasury_cap` - Optional minter capability for SailCoin
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A tuple with (minter, admin_cap), where admin_cap grants administrative privileges
    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        treasury_cap: Option<TreasuryCap<SailCoinType>>,
        ctx: &mut TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        let minter = Minter<SailCoinType> {
            id: object::new(ctx),
            revoked_admins: vec_set::empty<ID>(),
            paused: false,
            activated_at: 0,
            active_period: 0,
            epoch_count: 0,
            current_epoch_o_sail: option::none<TypeName>(),
            last_epoch_update_time: 0,
            epoch_emissions: 0,
            sail_cap: treasury_cap,
            o_sail_caps: bag::new(ctx),
            o_sail_total_supply: 0,
            o_sail_expiry_dates: table::new<TypeName, u64>(ctx),
            base_supply: 10000000000000, // 10M coins
            epoch_grow_rate: 300,
            epoch_decay_rate: 100,
            tail_emission_rate: 67,
            team_emission_rate: 500,
            protocol_fee_rate: 500,
            team_wallet: @0x0,
            reward_distributor_cap: option::none<distribution::reward_distributor_cap::RewardDistributorCap>(),
            notify_reward_cap: option::none<distribution::notify_reward_cap::NotifyRewardCap>(),
            whitelisted_pools: vec_set::empty<ID>(),
            exercise_fee_tokens: vec_set::empty<TypeName>(),
            exercise_fee_team_balances: bag::new(ctx),
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

    /// Returns the next epoch emissions amount.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to query
    ///
    /// # Returns
    /// Next epoch emissions amount
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

    /// Returns the rate denominator (RATE_DENOM = 100%).
    ///
    /// This is used for percentage-based calculations throughout the module.
    public fun rate_denom(): u64 {
        RATE_DENOM
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


    /// Puts FullSail token mintercap into minter object.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `treasury_cap` - The token treasury capability to set
    ///
    /// # Aborts
    /// * If the minter already has a minter capability
    public fun set_treasury_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<SailCoinType>
    ) {
        minter.check_admin(admin_cap);
        assert!(
            option::is_none<TreasuryCap<SailCoinType>>(&minter.sail_cap),
            EMinterCapAlreadySet
        );
        option::fill<TreasuryCap<SailCoinType>>(&mut minter.sail_cap, treasury_cap);
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
        assert!(team_emission_rate <= MAX_TEAM_EMISSIONS_RATE, ESetTeamEmissionRateTooBigRate);
        minter.team_emission_rate = team_emission_rate;
    }

    public fun set_protocol_fee_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        protocol_fee_rate: u64
    ) {
        minter.check_admin(admin_cap);
        assert!(protocol_fee_rate <= MAX_PROTOCOL_FEE_RATE, ESetProtocolFeeRateTooBigRate);
        minter.protocol_fee_rate = protocol_fee_rate;
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

    /// Distributes the protocol exercise oSAIL fee to the team wallet.
    /// Is public cos team_wallet is predefined
    public fun distribute_team<SailCoinType, ExerciseFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(minter.team_wallet != @0x0, ETeamWalletNotSet);
        let coin_type = type_name::get<ExerciseFeeCoinType>();
        assert!(minter.exercise_fee_team_balances.contains(coin_type), EDistributeTeamTokenNotFound);
        let balance = minter.exercise_fee_team_balances.remove<TypeName, Balance<ExerciseFeeCoinType>>(coin_type);
        transfer::public_transfer<Coin<ExerciseFeeCoinType>>(
            coin::from_balance(balance, ctx), 
            minter.team_wallet
        );
    }

    /// Returns the current team emission rate.
    public fun team_emission_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.team_emission_rate
    }

    /// Returns the current protocol fee rate.
    public fun protocol_fee_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.protocol_fee_rate
    }

    /// Returns the tail emission rate applied during the final phase of the emission schedule.
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

    /// Updates fields related to oSAIL coin
    ///
    /// # Arguments
    /// * `minter` - The minter instance to update oSAIL fields
    /// * `treasury_cap` - oSAIL TreasuryCap that will be used at the end of epoch to mint new tokens
    ///
    /// #Effects
    /// * Updates current_epoch_o_sail
    /// * Update Voter fields related to oSAIL
    fun update_o_sail_token<SailCoinType, EpochOSailCoin>(
        minter: &mut Minter<SailCoinType>,
        treasury_cap: TreasuryCap<EpochOSailCoin>,
        clock: &sui::clock::Clock,
    ) {
        let o_sail_type = type_name::get<EpochOSailCoin>();
        assert!(!minter.o_sail_caps.contains(o_sail_type), EUpdatePeriodOSailAlreadyUsed);
        minter.current_epoch_o_sail.swap_or_fill(o_sail_type);
        minter.o_sail_total_supply = minter.o_sail_total_supply + treasury_cap.total_supply();
        minter.o_sail_caps.add(o_sail_type, treasury_cap);
        // oSAIL is distributed until the end of the active period, so we add extra week to the duration
        // as in some cases users will not be able to claim oSAIL until the end of the week.
        let o_sail_expiry_date = distribution::common::current_period(clock) +
            distribution::common::o_sail_duration() +
            distribution::common::week();
        minter.o_sail_expiry_dates.add(o_sail_type, o_sail_expiry_date);
    }

    /// Updates the active period and processes token emissions for the current epoch.
    ///
    /// This is the core function that drives the tokenomics of the protocol. It:
    /// 1. Sets current epoch oSAIL token
    /// 2. Calculates emissions for the current epoch
    /// 3. Mints and distributes tokens to the team wallet (if configured)
    /// 4. Distributes protocol fee
    /// 5. Handles rebase growth based on locked vs circulating supply
    /// 6. Distributes rewards to voters/stakers
    /// 7. Updates the epoch counters and emission rates for the next epoch
    ///
    /// This function should be called once per week (per epoch) to maintain
    /// the emission schedule.
    ///
    /// # Arguments
    /// * `admin_cap` - Ensures only admin can call this function
    /// * `minter` - The minter instance to update
    /// * `voter` - The voter module that manages gauges and voting
    /// * `voting_escrow` - The voting escrow that tracks locked tokens
    /// * `reward_distributor` - The reward distributor for distributing tokens
    /// * `epoch_o_sail_treasury_cap` - The TreasuryCap which allows minting of new EpochOSail
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
    public fun update_period<SailCoinType, EpochOSail>(
        admin_cap: &AdminCap,
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        minter.check_admin(admin_cap);
        assert!(minter.is_active(clock), EUpdatePeriodMinterNotActive);
        assert!(
            minter.active_period + distribution::common::week() < distribution::common::current_timestamp(clock),
            EUpdatePeriodNotFinishedYet
        );
        minter.update_o_sail_token(epoch_o_sail_treasury_cap, clock);
        let (current_epoch_emissions, next_epoch_emissions) = minter.calculate_epoch_emissions();
        let rebase_growth = calculate_rebase_growth(
            current_epoch_emissions,
            minter.total_supply(),
            voting_escrow.total_locked()
        );
        if (minter.team_emission_rate > 0 && minter.team_wallet != @0x0) {
            let team_emissions = integer_mate::full_math_u64::mul_div_floor(
                minter.team_emission_rate,
                rebase_growth + current_epoch_emissions,
                RATE_DENOM - minter.team_emission_rate
            );
            transfer::public_transfer<Coin<SailCoinType>>(
                minter.mint_sail(team_emissions, ctx),
                minter.team_wallet
            );
        };
        let rebase_emissions = minter.mint_sail(
            rebase_growth,
            ctx
        );
        reward_distributor.checkpoint_token(
            option::borrow<distribution::reward_distributor_cap::RewardDistributorCap>(
                &minter.reward_distributor_cap
            ),
            rebase_emissions,
            clock
        );
        let notify_reward_cap = minter.notify_reward_cap.borrow();
        voter.notify_epoch_token<EpochOSail>(notify_reward_cap, ctx);
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

    public fun distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail, NextEpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): u64 {
        // TODO: calc amount to distribute
        let o_sail_to_distribute = minter.mint_o_sail<SailCoinType, NextEpochOSail>(0, ctx);
        let (claimable_amount, rollover_balance) = voter.distribute_gauge<CoinTypeA, CoinTypeB, CurrentEpochOSail, NextEpochOSail>(
            minter.notify_reward_cap.borrow(),
            distribution_config,
            gauge,
            pool,
            o_sail_to_distribute,
            clock,
            ctx
        );

        // burning coins that were not distributed
        if (rollover_balance.value() > 0) {
            minter.burn_o_sail_balance(rollover_balance, ctx);
        } else {
            rollover_balance.destroy_zero();
        };

        claimable_amount
    }

    /// Borrows current epoch oSAIL token
    public fun borrow_current_epoch_o_sail<SailCoinType>(minter: &Minter<SailCoinType>): &TypeName {
        minter.current_epoch_o_sail.borrow()
    }

    /// Checks if provided oSAIL type is equal to the current epoch oSAIL.
    public fun is_valid_epoch_token<SailCoinType, OSailCoinType>(
        minter: &Minter<SailCoinType>,
    ): bool {
        let o_sail_type = type_name::get<OSailCoinType>();

        *minter.borrow_current_epoch_o_sail() == o_sail_type
    }

    public fun is_valid_o_sail_type<SailCoinType, OSailCoinType>(
        minter: &Minter<SailCoinType>,
    ): bool {
        let o_sail_type = type_name::get<OSailCoinType>();
        minter.o_sail_expiry_dates.contains(o_sail_type)
    }

    /// Mutably borrows oSAIL TreasuryCap by type
    fun borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
    ): &mut TreasuryCap<OSailCoinType> {
        let o_sail_type = type_name::get<OSailCoinType>();

        minter.o_sail_caps.borrow_mut<TypeName, TreasuryCap<OSailCoinType>>(o_sail_type)
    }

    /// Borrows oSAIL TreasuryCap by type
    public fun borrow_o_sail_cap<SailCoinType, OSailCoinType>(
        minter: &Minter<SailCoinType>,
    ): &TreasuryCap<OSailCoinType> {
        let o_sail_type = type_name::get<OSailCoinType>();

        minter.o_sail_caps.borrow<TypeName, TreasuryCap<OSailCoinType>>(o_sail_type)
    }

    /// Mints new oSAIL tokens
    fun mint_o_sail<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<OSailCoinType> {
        minter.o_sail_total_supply = minter.o_sail_total_supply + amount;
        let cap = minter.borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>();

        cap.mint(amount, ctx)
    }

    /// Burning function. Is public because we don't mind if supply is decreased voluntarily
    public fun burn_o_sail<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        coin: Coin<OSailCoinType>,
    ): u64 {
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EBurnOSailInvalidOSail);

        let cap = minter.borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>();
        let burnt = cap.burn(coin);
        minter.o_sail_total_supply = minter.o_sail_total_supply - burnt;

        burnt
    }

    public fun burn_o_sail_balance<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        balance: Balance<OSailCoinType>,
        ctx: &mut TxContext,
    ): u64 {
        minter.burn_o_sail(coin::from_balance(balance, ctx))
    }

    fun mint_sail<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<SailCoinType> {
        let cap = minter.sail_cap.borrow_mut();

        cap.mint(amount, ctx)
    }

    /// Creates a new lock by exercising oSAIL into SAIL and locking it.
    /// Makes a call to create_lock internally.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `o_sail` - oSAIL coin to be exercised and locked
    /// * `lock_duration_days` - The number of days to lock the tokens
    /// * `permanent` - Whether this should be a permanent lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If lock_duration is not one of allowed durations
    public fun create_lock_from_o_sail<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        o_sail: sui::coin::Coin<OSailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), ECreateLockFromOSailInvalidToken);
        let lock_duration_seconds = lock_duration_days * distribution::common::day();
        let o_sail_type = type_name::get<OSailCoinType>();
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = distribution::common::current_timestamp(clock);

        // locking for any duration less than permanent
        let mut valid_duration = false;
        if (current_time >= expiry_date) {
            valid_duration = permanent || lock_duration_days == VALID_EXPIRED_O_SAIL_DURATION_DAYS
        } else {
            if (permanent) {
                valid_duration = true
            } else {
                let mut i = 0;
                let valid_durations = VALID_O_SAIL_DURATION_DAYS;
                let valid_durations_len = valid_durations.length();
                while (i < valid_durations_len) {
                    if (valid_durations[i] == lock_duration_days) {
                        valid_duration = true;
                        break;
                    };
                    i = i + 1;
                };
            };
        };
        assert!(valid_duration, ECreateLockFromOSailInvalidDuraton);

        // received SAIL percent changes from discount percent to 100%
        let percent_to_receive = if (permanent) {
            distribution::common::persent_denominator()
        } else {
            let max_extra_percents = distribution::common::persent_denominator() - distribution::common::o_sail_discount();
            distribution::common::o_sail_discount() + integer_mate::full_math_u64::mul_div_floor(
                lock_duration_seconds,
                max_extra_percents,
                distribution::common::max_lock_time()
            )
        };

        let sail_to_lock = minter.exercise_o_sail_free_internal(o_sail, percent_to_receive, ctx);

        voting_escrow.create_lock<SailCoinType>(
            sail_to_lock,
            lock_duration_days,
            permanent,
            clock,
            ctx
        )
    }

    fun exercise_o_sail_free_internal<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        percent_to_receive: u64,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        assert!(percent_to_receive <= distribution::common::persent_denominator(), EExerciseOSailFreeTooBigPercent);

        let o_sail_amount = o_sail.value();

        let sail_amount_to_receive = integer_mate::full_math_u64::mul_div_floor(
            o_sail_amount,
            percent_to_receive,
            distribution::common::persent_denominator()
        );

        minter.burn_o_sail(o_sail);

        minter.mint_sail(sail_amount_to_receive, ctx)
    }

    #[test_only]
    public fun test_exercise_o_sail_free_internal<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        percent_to_receive: u64,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        exercise_o_sail_free_internal(minter, o_sail, percent_to_receive, ctx)
    }

    


    /// Checks conditions, exercises oSAIL
    public fun exercise_o_sail_ab<SailCoinType, USDCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        _: &clmm_pool::config::GlobalConfig, // in case we want to introduce slippage here in the future
        pool: &mut clmm_pool::pool::Pool<USDCoinType, SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        fee: Coin<USDCoinType>,
        usd_amount_limit: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<USDCoinType>, Coin<SailCoinType>) {
        let o_sail_type = type_name::get<OSailCoinType>();
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExerciseOSailInvalidOSail);
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time < expiry_date, EExerciseOSailExpired);
        assert!(minter.is_whitelisted_pool(pool), EExerciseOSailPoolNotWhitelisted);

        // there is a possibility that different discount percents will be implemented
        let dicount_percent = distribution::common::o_sail_discount();
        minter.exercise_o_sail_ab_internal(
            voter,
            pool,
            o_sail,
            dicount_percent,
            fee,
            usd_amount_limit,
            clock,
            ctx
        )
    }

    /// Checks conditions, exercises oSAIL
    public fun exercise_o_sail_ba<SailCoinType, USDCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        _: &clmm_pool::config::GlobalConfig, // in case we want to introduce slippage here in the future
        pool: &mut clmm_pool::pool::Pool<SailCoinType, USDCoinType>,
        o_sail: Coin<OSailCoinType>,
        fee: Coin<USDCoinType>,
        usd_amount_limit: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<USDCoinType>, Coin<SailCoinType>) {
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExerciseOSailInvalidOSail);
        let o_sail_type = type_name::get<OSailCoinType>();
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = distribution::common::current_timestamp(clock);
        assert!(current_time < expiry_date, EExerciseOSailExpired);
        assert!(minter.is_whitelisted_pool(pool), EExerciseOSailPoolNotWhitelisted);

        // there is a possibility that different discount percents will be implemented
        let dicount_percent = distribution::common::o_sail_discount();
        minter.exercise_o_sail_ba_internal(
            voter,
            pool,
            o_sail,
            dicount_percent,
            fee,
            usd_amount_limit,
            clock,
            ctx
        )
    }

    /// withdraws SAIL from storage and burns oSAIL
    fun exercise_o_sail_process_payment<SailCoinType, USDCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        o_sail: Coin<OSailCoinType>,
        mut usd_in: Coin<USDCoinType>,
        usd_amount_in: u64,
        clock:  &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<USDCoinType>, Coin<SailCoinType>) {
        let sail_amount_out = o_sail.value();
        let mut usd_to_pay = usd_in.split(usd_amount_in, ctx);

        if (minter.protocol_fee_rate > 0 && minter.team_wallet != @0x0) {
            let protocol_fee_amount = integer_mate::full_math_u64::mul_div_floor(
                usd_to_pay.value(),
                minter.protocol_fee_rate,
                RATE_DENOM,
            );
            let protocol_fee = usd_to_pay.split(protocol_fee_amount, ctx);
            let usd_coin_type = type_name::get<USDCoinType>();

            if (!minter.exercise_fee_team_balances.contains<TypeName>(usd_coin_type)) {
                minter.exercise_fee_team_balances.add(usd_coin_type, balance::zero<USDCoinType>());
            };
            let team_fee_balance = minter
                .exercise_fee_team_balances
                .borrow_mut<TypeName, Balance<USDCoinType>>(usd_coin_type);

            team_fee_balance.join(protocol_fee.into_balance());
        };

        voter
            .borrow_exercise_fee_reward_mut()
            .notify_reward_amount(minter.notify_reward_cap.borrow(), usd_to_pay, clock, ctx);

        minter.burn_o_sail(o_sail);
        let sail_out = minter.mint_sail(sail_amount_out, ctx);

        // remaining usd and sail
        (usd_in, sail_out)
    }

    /// Function that calculates amount of usd to be deducted by calculating swap.
    /// Is not changing any state, so it is public
    /// Doesn't check pool for type safety, so use with caution
    /// Returns usd amount to be deducted from user
    public fun exercise_o_sail_calc<OSailCoinType, CoinTypeA, CoinTypeB>(
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        o_sail: &Coin<OSailCoinType>,
        discount_percent: u64,
        a2b: bool, // true if pool is Pool<UsdCoinType, SailCoinType>
    ): u64 {
        let o_sail_amount = o_sail.value();
        let pay_for_percent = distribution::common::persent_denominator() - discount_percent;
        let sail_amount_to_pay_for = integer_mate::full_math_u64::mul_div_floor(
            pay_for_percent,
            o_sail_amount,
            distribution::common::persent_denominator()
        );
        // if Pool<CoinA, CoinB>:
        // amount_b = sqrtPriceX64^2 * amount_a  / 2^128
        // amount_a = amount_b * 2^128 / sqrtPriceX64^2
        let sqrt_price: u256 = pool.current_sqrt_price() as u256;
        let amount_to_pay = if (a2b) {
            (((sail_amount_to_pay_for as u256) << 128) / (sqrt_price * sqrt_price)) as u64
        } else {
            ((sqrt_price * sqrt_price * (sail_amount_to_pay_for as u256)) >> 128) as u64
        };

        amount_to_pay
    }

    /// Exercises oSAIL token and gives you SAIL in return.
    /// The usd coin amount must be greater than (100 - o_sail.discount_percent / 10_000)% of SAIL cost in the pool.
    /// Function is internal, cos discount_percent should be calculated elswhere.
    fun exercise_o_sail_ab_internal<SailCoinType, UsdCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        pool: &clmm_pool::pool::Pool<UsdCoinType, SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        discount_percent: u64,
        usd: Coin<UsdCoinType>,
        usd_amount_limit: u64,
        clock:  &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<UsdCoinType>, Coin<SailCoinType>) {
        let usd_amount_to_pay = exercise_o_sail_calc<OSailCoinType, UsdCoinType, SailCoinType>(
            pool,
            &o_sail,
            discount_percent,
            true,
        );

        assert!(usd_amount_limit >= usd_amount_to_pay, EExerciseUsdLimitReached);

        exercise_o_sail_process_payment(
            minter,
            voter,
            o_sail,
            usd,
            usd_amount_to_pay,
            clock,
            ctx,
        )
    }

    /// Same as `exercise_o_sail_ab_internal` but allows usage of pools with different order of type args.
    /// see `exercise_o_sail_ab_internal` for more information.
    fun exercise_o_sail_ba_internal<SailCoinType, UsdCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        pool: &clmm_pool::pool::Pool<SailCoinType, UsdCoinType>,
        o_sail: Coin<OSailCoinType>,
        discount_percent: u64,
        usd: Coin<UsdCoinType>,
        usd_amount_limit: u64,
        clock:  &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<UsdCoinType>, Coin<SailCoinType>) {
        let usd_amount_to_pay = exercise_o_sail_calc<OSailCoinType, SailCoinType, UsdCoinType>(
            pool,
            &o_sail,
            discount_percent,
            false,
        );

        assert!(usd_amount_limit >= usd_amount_to_pay, EExerciseUsdLimitReached);

        exercise_o_sail_process_payment(
            minter,
            voter,
            o_sail,
            usd,
            usd_amount_to_pay,
            clock,
            ctx,
        )
    }

    public fun whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        list: bool,
    ) {
        minter.check_admin(admin_cap);

        let pool_id = object::id(pool);
        if (minter.whitelisted_pools.contains(&pool_id)) {
            if (!list) {
                minter.whitelisted_pools.remove(&pool_id)
            }
            // never remove exercise fee token, cos they may  stored in the bag even if pool is removed
        } else {
            if (list) {
                minter.whitelisted_pools.insert(pool_id)
            };
            let coin_type_a = type_name::get<CoinTypeA>();
            if (!minter.exercise_fee_tokens.contains(&coin_type_a)) {
                minter.exercise_fee_tokens.insert(coin_type_a);
            };
            let coin_type_b = type_name::get<CoinTypeB>();
            if (!minter.exercise_fee_tokens.contains(&coin_type_b)) {
                minter.exercise_fee_tokens.insert(coin_type_b);
            };
        }
    }

    public fun borrow_exercise_fee_tokens<SailCoinType>(
        minter: &Minter<SailCoinType>,
    ): &VecSet<TypeName> {
        &minter.exercise_fee_tokens
    }

    public fun is_whitelisted_pool<SailCoinType, CoinTypeA, CoinTypeB>(
        minter: &Minter<SailCoinType>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
    ): bool {
        let pool_id = object::id(pool);
        minter.whitelisted_pools.contains(&pool_id)
    }

    public fun borrow_whiteliste_pools<SailCoinType>(
        minter: &Minter<SailCoinType>,
    ): &VecSet<ID> {
        &minter.whitelisted_pools
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
         sui::package::claim<MINTER>(MINTER {}, ctx)
    }
}


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
    use integer_mate::full_math_u128;

    const ECreateMinterInvalidPublisher: u64 = 695309471293028100;

    const EGrantAdminInvalidPublisher: u64 = 198127851942335970;

    const EGrantDistributeGovernorInvalidPublisher: u64 = 49774594592309590;

    const ERevokeAdminInvalidPublisher: u64 = 729123415718822900;

    const ERevokeDistributeGovernorInvalidPublisher: u64 = 639606009071379600;

    const EActivateMinterAlreadyActive: u64 = 922337310630222234;
    const EActivateMinterPaused: u64 = 996659030249798900;
    const EActivateMinterNoDistributorCap: u64 = 922337311059823823;

    const ESetTreasuryCapMinterPaused: u64 = 179209983522842700;
    const EMinterCapAlreadySet: u64 = 922337283142372556;

    const ESetDistributeCapMinterPaused: u64 = 939345375978791600;

    const ESetTeamEmissionRateMinterPaused: u64 = 339140718471350200;

    const ESetProtocolFeeRateMinterPaused: u64 = 548722644715498500;
    const ESetTeamEmissionRateTooBigRate: u64 = 922337292161803878;
    const ESetProtocolFeeRateTooBigRate: u64 = 840171622736257200;

    const ESetTeamWalletMinterPaused: u64 = 587854778781893500;

    const EUpdatePeriodMinterPaused: u64 = 540422149172903100;
    const EUpdatePeriodMinterNotActive: u64 = 922337339406490010;
    const EUpdatePeriodNotFinishedYet: u64 = 922337340695058843;
    const EUpdatePeriodNotAllGaugesDistributed: u64 = 150036217874985900;
    const EUpdatePeriodDistributionConfigInvalid: u64 = 222427100417155840;
    const EUpdatePeriodOSailAlreadyUsed: u64 = 573264404146058900;

    const EDistributeGaugeMinterPaused: u64 = 383966743216827200;
    const EDistributeGaugeInvalidToken: u64 = 802874746577660900;
    const EDistributeGaugeAlreadyDistributed: u64 = 259145126193785820;
    const EDistributeGaugePoolHasNoBaseSupply: u64 = 764215244078886900;
    const EDistributeGaugeDistributionConfigInvalid: u64 = 540205746933504640;
    const EDistributeGaugeMinterNotActive: u64 = 728194857362048571;
    const EDistributeGaugeFirstEpochMetricsInvalid: u64 = 671508139267645600;
    const EDistributeGaugeMetricsInvalid: u64 = 95918619286974770;

    const ECheckAdminRevoked: u64 = 922337280994888908;
    const ECheckDistributeGovernorRevoked: u64 = 369612027923601500;

    const ECreateLockFromOSailMinterPaused: u64 = 345260272869412100;
    const ECreateLockFromOSailInvalidToken: u64 = 916284390763921500;
    const ECreateLockFromOSailInvalidDuraton: u64 = 68567430268160480;

    const EExerciseOSailFreeTooBigPercent: u64 = 410835752553141860;
    const EExerciseOSailExpired: u64 = 738843771743325200;
    const EExerciseOSailInvalidOSail: u64 = 320917362365364070;
    const EExerciseOSailAbMinterPaused: u64 = 295847361920485736;
    const EExerciseOSailBaMinterPaused: u64 = 618394857261038472;

    const EBurnOSailInvalidOSail: u64 = 665869556650983200;
    const EBurnOSailMinterPaused: u64 = 947382564018592637;

    const EExerciseUsdLimitReached: u64 = 490517942447480600;
    const EExerciseOSailPoolNotWhitelisted: u64 = 221252400064791070;

    const ETeamWalletNotSet: u64 = 798141442607710900;
    const EDistributeTeamTokenNotFound: u64 = 962925679282177400;
    const EDistributeTeamMinterPaused: u64 = 482957361048572639;

    const ECreateGaugeMinterPaused: u64 = 173400731963214500;
    const ECreateGaugeZeroBaseEmissions: u64 = 676230237726862100;

    const EResetGaugeMinterPaused: u64 = 412179529765746000;
    const EResetGaugeMinterNotActive: u64 = 125563751493106940;
    const EResetGaugeZeroBaseEmissions: u64 = 777730412186606000;
    const EResetGaugeDistributionConfigInvalid: u64 = 726258387105137800;
    const EResetGaugeGaugeAlreadyAlive: u64 = 452133119942522700;
    const EResetGaugeAlreadyDistributed: u64 = 97456931979148290;

    const EKillGaugeDistributionConfigInvalid: u64 = 401018599948013600;
    const EKillGaugeAlreadyKilled: u64 = 812297136203523100;

    const EReviveGaugeDistributionConfigInvalid: u64 = 211832148784139800;
    const EReviveGaugeAlreadyAlive: u64 = 533150247921935500;
    const EReviveGaugeNotKilledInCurrentEpoch: u64 = 295306155667221200;

    const EWhitelistPoolMinterPaused: u64 = 316161888154524900;

    const EScheduleSailMintPublisherInvalid: u64 = 716204622969124700;
    const EScheduleSailMintMinterPaused: u64 = 849544693573603300;
    const EScheduleSailMintAmountZero: u64 = 520351519384544260;

    const EScheduleOSailMintPublisherInvalid: u64 = 734928593233084000;
    const EScheduleOSailMintMinterPaused: u64 = 621003109924614900;
    const EScheduleOSailMintInvalidOSail: u64 = 348840174999730750;
    const EScheduleOSailMintAmountZero: u64 = 424220271321603000;

    const EExecuteSailMintStillLocked: u64 = 163079933457922500;
    const EExecuteSailMintMinterPaused: u64 = 563287666418746940;

    const EExecuteOSailMintStillLocked: u64 = 151689484412189660;
    const EExecuteOSailMintMinterPaused: u64 = 701790096846469900;
    const EExecuteOSailMintInvalidOSail: u64 = 656291036632650900;

    const DAYS_IN_WEEK: u64 = 7;

    /// Possible lock duration available be oSAIL expiry date
    const VALID_O_SAIL_DURATION_DAYS: vector<u64> = vector[
        26 * DAYS_IN_WEEK, // 6 months
        2 * 52 * DAYS_IN_WEEK, // 2 years
        4 * 52 * DAYS_IN_WEEK // 4 years
    ];

    /// After expiration oSAIL can only be locked for 4 years or permanently
    const VALID_EXPIRED_O_SAIL_DURATION_DAYS: u64 =  4 * 52 * DAYS_IN_WEEK;

    /// Denominator in rate calculations (i.e. fee percent, team emission percent)
    const RATE_DENOM: u64 = 10000;

    const MAX_TEAM_EMISSIONS_RATE: u64 = 500;
    const MAX_PROTOCOL_FEE_RATE: u64 = 3000;

    const MAX_EMISSIONS_CHANGE_RATE: u64 = RATE_DENOM + RATE_DENOM / 10; // +10%
    const MIN_EMISSIONS_CHANGE_RATE: u64 = RATE_DENOM - RATE_DENOM / 10; // -10%

    const MINT_LOCK_TIME_MS: u64 = 24 * 60 * 60 * 1000; // 1 day

    /// Admin is responsible for initialization functions.
    public struct AdminCap has store, key {
        id: UID,
    }

    /// DistributeGovernor is supposed to be a backend service which is responsible for
    /// calling distribute methods, that update oSAIL token, distribute gauges and etc.
    public struct DistributeGovernorCap has store, key {
        id: UID,
    }

    public struct MINTER has drop {}

    public struct EventUpdateEpoch has copy, drop, store {
        new_period: u64,
    }

    public struct EventReviveGauge has copy, drop, store {
        id: ID,
    }

    public struct EventKillGauge has copy, drop, store {
        id: ID,
    }

    public struct EventPauseEmission has copy, drop, store {}

    public struct EventUnpauseEmission has copy, drop, store {}

    public struct EventGrantAdmin has copy, drop, store {
        who: address,
        admin_cap: ID,
    }

    public struct EventGrantDistributeGovernor has copy, drop, store {
        who: address,
        distribute_governor_cap: ID,
    }

    public struct TimeLockedSailMint has key, store {
        id: UID,
        amount: u64,
        unlock_time: u64,
    }

    public struct TimeLockedOSailMint<phantom OSailCoinType> has key, store {
        id: UID,
        amount: u64,
        unlock_time: u64,
    }

    public struct Minter<phantom SailCoinType> has store, key {
        id: UID,
        revoked_admins: VecSet<ID>,
        revoked_distribute_governors: VecSet<ID>,
        paused: bool,
        activated_at: u64,
        active_period: u64,
        // The oSAIL which will be distributed at the begining of new epoch and during the epoch
        current_epoch_o_sail: Option<TypeName>,
        last_epoch_update_time: u64,
        sail_cap: Option<TreasuryCap<SailCoinType>>,
        o_sail_caps: Bag,
        // sum of supplies of all o_sail tokens
        o_sail_total_supply: u64,
        o_sail_expiry_dates: Table<TypeName, u64>,
        team_emission_rate: u64,
        protocol_fee_rate: u64,
        team_wallet: address,
        reward_distributor_cap: Option<distribution::reward_distributor_cap::RewardDistributorCap>,
        distribute_cap: Option<distribution::distribute_cap::DistributeCap>,
        // pools that can be used to exercise oSAIL
        // we don't need whitelisted tokens, cos
        // pool whitelist also determines token whitelist composed of the pools tokens.
        whitelisted_pools: VecSet<ID>,
        exercise_fee_team_balances: Bag,
        // Gauge Id -> oSAil Emissions
        gauge_epoch_emissions: Table<ID, u64>,
        // Gauge Id -> Minter.active_period during which gauge was distributed
        gauge_active_period: Table<ID, u64>,
        // Gauge Id -> number of epochs guage participates in distribution
        gauge_epoch_count: Table<ID, u64>,
        // Sum of emissions for all gauges
        // Epoch start seconds -> sum of emissions for all gauges
        total_epoch_emissions: Table<u64, u64>,
        distribution_config: ID,
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
    /// Initializes the active period, sets up the reward distributor and current epoch oSAIL.
    /// This must be called before any token emissions can occur.
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
    public fun activate<SailCoinType, EpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        admin_cap: &AdminCap,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), EActivateMinterPaused);
        assert!(!minter.is_active(clock), EActivateMinterAlreadyActive);
        assert!(
            option::is_some(&minter.reward_distributor_cap),
            EActivateMinterNoDistributorCap
        );
        minter.update_o_sail_token(epoch_o_sail_treasury_cap, clock);
        let distribute_cap = minter.distribute_cap.borrow();
        voter.notify_epoch_token<EpochOSail>(distribute_cap, ctx);
        let current_time = distribution::common::current_timestamp(clock);
        minter.activated_at = current_time;
        minter.active_period = distribution::common::to_period(minter.activated_at);
        minter.last_epoch_update_time = current_time;
        reward_distributor.start(
            option::borrow(&minter.reward_distributor_cap),
            minter.active_period,
            clock,
        );
    }

    /// Returns the timestamp when the minter was activated.
    public fun activated_at<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.activated_at
    }

    /// Returns the current active period of the minter.
    public fun active_period<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.active_period
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
        if (total_supply == 0) {
            return 0
        };
        // epoch_emissions * ((total_supply - total_locked) / total_supply)^2 / 2
        integer_mate::full_math_u64::mul_div_ceil(
            integer_mate::full_math_u64::mul_div_ceil(epoch_emissions, total_supply - total_locked, total_supply),
            total_supply - total_locked,
            total_supply
        ) / 2
    }

    fun max_emissions_change_x64(): u128 {
        full_math_u128::mul_div_floor(
            MAX_EMISSIONS_CHANGE_RATE as u128,
            1<<64,
            RATE_DENOM as u128,
        )
    }

    fun min_emissions_change_x64(): u128 {
        full_math_u128::mul_div_floor(
            MIN_EMISSIONS_CHANGE_RATE as u128,
            1<<64,
            RATE_DENOM as u128,
        )
    }

    /// Calculates pool emissions according to the formula:
    /// Δ_Pool_Rewards = 0.5 × Δ_ROE + 0.5 × Δ_Vol  ∈ [-10%, +10%]
    /// Where:
    /// Δ_ROE = (ROE_{n-1} / ROE_{n-2}) - 1
    /// Δ_Vol = (Predicted_vol_n / VOL_{n-1}) - 1
    /// Where:
    /// ROE = ((TDVR - TDVE) / TDVE) + 1
    /// TDVE = Total Dollar Value Emitted
    /// TDVR = Total Dollar Value Returned
    public fun calculate_next_pool_emissions(
        epoch_pool_emissions: u64,
        prev_epoch_pool_emissions: u64,
        prev_epoch_pool_fees_usd: u64,
        epoch_pool_emissions_usd: u64,
        epoch_pool_fees_usd: u64,
        epoch_pool_volume_usd: u64,
        epoch_pool_predicted_volume_usd: u64,
    ): u64 {

        // ROE change is 1 for first voting epoch
        let roe_change_x64 = if (prev_epoch_pool_fees_usd > 0 && prev_epoch_pool_emissions > 0) {
            let prev_epoch_roe_x64 = full_math_u128::mul_div_floor(
                prev_epoch_pool_fees_usd as u128,
                1<<64,
                prev_epoch_pool_emissions as u128,
            );
            let current_epoch_roe_x64 = full_math_u128::mul_div_floor(
                epoch_pool_fees_usd as u128,
                1<<64,
                epoch_pool_emissions_usd as u128
            );
            full_math_u128::mul_div_floor(
                current_epoch_roe_x64,
                1<<64,
                prev_epoch_roe_x64
            )
        } else {
            1<<64
        };

        let volume_change_x64 = full_math_u128::mul_div_floor(
            epoch_pool_predicted_volume_usd as u128,
            1<<64,
            epoch_pool_volume_usd as u128
        );

        let mut emissions_change_x64 = (roe_change_x64 + volume_change_x64) / 2;

        let max_emissions_ch = max_emissions_change_x64();
        let min_emissions_ch = min_emissions_change_x64();

        if (emissions_change_x64 > max_emissions_ch) {
            emissions_change_x64 = max_emissions_ch;
        };
        if (emissions_change_x64 < min_emissions_ch) {
            emissions_change_x64 = min_emissions_ch;
        };
        full_math_u128::mul_div_floor(
            epoch_pool_emissions as u128,
            emissions_change_x64,
            1<<64
        ) as u64
    }


    /// Verifies that the provided admin capability is valid and not revoked.
    public fun check_admin<SailCoinType>(minter: &Minter<SailCoinType>, admin_cap: &AdminCap) {
        let admin_cap_id = object::id<AdminCap>(admin_cap);
        assert!(!minter.revoked_admins.contains<ID>(&admin_cap_id), ECheckAdminRevoked);
    }

    /// Verifies that the provided distribute governor capability is valid and not revoked.
    public fun check_distribute_governor<SailCoinType>(minter: &Minter<SailCoinType>, distribute_governor_cap: &DistributeGovernorCap) {
        let distribute_governor_cap_id = object::id<DistributeGovernorCap>(distribute_governor_cap);
        assert!(!minter.revoked_distribute_governors.contains<ID>(&distribute_governor_cap_id), ECheckDistributeGovernorRevoked);
    }

    /// Creates a new Minter instance with default configuration.
    ///
    /// # Arguments
    /// * `publisher` - Publisher proving authorization
    /// * `treasury_cap` - Optional minter capability for SailCoin
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A tuple with (minter, admin_cap), where admin_cap grants administrative privileges
    public fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        treasury_cap: Option<TreasuryCap<SailCoinType>>,
        distribution_config: ID,
        ctx: &mut TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        assert!(publisher.from_module<MINTER>(), ECreateMinterInvalidPublisher);
        let id = object::new(ctx);
        let minter = Minter<SailCoinType> {
            id,
            revoked_admins: vec_set::empty<ID>(),
            revoked_distribute_governors: vec_set::empty<ID>(),
            paused: false,
            activated_at: 0,
            active_period: 0,
            current_epoch_o_sail: option::none<TypeName>(),
            last_epoch_update_time: 0,
            sail_cap: treasury_cap,
            o_sail_caps: bag::new(ctx),
            o_sail_total_supply: 0,
            o_sail_expiry_dates: table::new<TypeName, u64>(ctx),
            team_emission_rate: 500,
            protocol_fee_rate: 500,
            team_wallet: @0x0,
            reward_distributor_cap: option::none<distribution::reward_distributor_cap::RewardDistributorCap>(),
            distribute_cap: option::none<distribution::distribute_cap::DistributeCap>(),
            whitelisted_pools: vec_set::empty<ID>(),
            exercise_fee_team_balances: bag::new(ctx),
            gauge_epoch_emissions: table::new<ID, u64>(ctx),
            gauge_active_period: table::new<ID, u64>(ctx),
            gauge_epoch_count: table::new<ID, u64>(ctx),
            total_epoch_emissions: table::new<u64, u64>(ctx),
            distribution_config,
        };
        let admin_cap = AdminCap { id: object::new(ctx) };
        (minter, admin_cap)
    }

    /// Grants and transfers administrative capability to a specified address.
    /// This function is not protected by is_paused to prevent deadlocks.
    public fun grant_admin(publisher: &sui::package::Publisher, who: address, ctx: &mut TxContext) {
        assert!(publisher.from_module<MINTER>(), EGrantAdminInvalidPublisher);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let grant_admin_event = EventGrantAdmin {
            who,
            admin_cap: object::id<AdminCap>(&admin_cap),
        };
        sui::event::emit<EventGrantAdmin>(grant_admin_event);
        transfer::transfer<AdminCap>(admin_cap, who);
    }

    /// Grants and transfers distribute governor capability to a specified address.
    public fun grant_distribute_governor(publisher: &sui::package::Publisher, who: address, ctx: &mut TxContext) {
        assert!(publisher.from_module<MINTER>(), EGrantDistributeGovernorInvalidPublisher);
        let distribute_governor_cap = DistributeGovernorCap { id: object::new(ctx) };
        let grant_distribute_governor_event = EventGrantDistributeGovernor {
            who,
            distribute_governor_cap: object::id<DistributeGovernorCap>(&distribute_governor_cap),
        };
        sui::event::emit<EventGrantDistributeGovernor>(grant_distribute_governor_event);
        transfer::transfer<DistributeGovernorCap>(distribute_governor_cap, who);
    }

    fun init(otw: MINTER, ctx: &mut TxContext) {
        sui::package::claim_and_keep<MINTER>(otw, ctx);
    }

    /// Checks if the minter is active.
    ///
    /// A minter is considered active if it has been activated,
    /// and the current period is at least the minter's active period.
    public fun is_active<SailCoinType>(minter: &Minter<SailCoinType>, clock: &sui::clock::Clock): bool {
        minter.activated_at > 0 && distribution::common::current_period(clock) >= minter.active_period
    }

    /// Minter is paused during emergency situations to prevent further damage.
    /// This check is separate from the is_active check cos behaviour should be different in
    /// initialization methods.
    ///
    /// Used to protect the functions that change state.
    /// Nearly all functions should be protected by this check for safety.
    public fun is_paused<SailCoinType>(minter: &Minter<SailCoinType>): bool {
        minter.paused
    }

    public fun is_valid_distribution_config<SailCoinType>(
        minter: &Minter<SailCoinType>, 
        distribution_config: &distribution::distribution_config::DistributionConfig
    ): bool {
        minter.distribution_config == object::id(distribution_config)
    }

    /// Returns the timestamp of the last epoch update
    public fun last_epoch_update_time<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.last_epoch_update_time
    }

    /// Returns the rate denominator (RATE_DENOM = 100%).
    /// This is used for percentage-based calculations throughout the module.
    public fun rate_denom(): u64 {
        RATE_DENOM
    }

    /// Revokes administrative capabilities for a specific admin.
    public fun revoke_admin<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &sui::package::Publisher,
        cap_id: ID
    ) {
        assert!(publisher.from_module<MINTER>(), ERevokeAdminInvalidPublisher);
        minter.revoked_admins.insert(cap_id);
    }

    /// Revokes distribute governor capabilities for a specific distribute governor.
    public fun revoke_distribute_governor<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &sui::package::Publisher,
        cap_id: ID
    ) {
        assert!(publisher.from_module<MINTER>(), ERevokeDistributeGovernorInvalidPublisher);
        minter.revoked_distribute_governors.insert(cap_id);
    }


    /// Puts FullSail token mintercap into minter object. This treasury cap
    /// is used to mint new SAIL tokens when oSAIL is exercised.
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
        assert!(!minter.is_paused(), ESetTreasuryCapMinterPaused);
        minter.check_admin(admin_cap);
        assert!(
            option::is_none<TreasuryCap<SailCoinType>>(&minter.sail_cap),
            EMinterCapAlreadySet
        );
        option::fill<TreasuryCap<SailCoinType>>(&mut minter.sail_cap, treasury_cap);
    }

    /// Sets the reward distributor capability for the minter.
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

    /// Sets the distribute capability for the minter.
    public fun set_distribute_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribute_cap: distribution::distribute_cap::DistributeCap
    ) {
        assert!(!minter.is_paused(), ESetDistributeCapMinterPaused);
        minter.check_admin(admin_cap);
        option::fill<distribution::distribute_cap::DistributeCap>(
            &mut minter.distribute_cap,
            distribute_cap
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
        assert!(!minter.is_paused(), ESetTeamEmissionRateMinterPaused);
        assert!(team_emission_rate <= MAX_TEAM_EMISSIONS_RATE, ESetTeamEmissionRateTooBigRate);
        minter.team_emission_rate = team_emission_rate;
    }

    public fun set_protocol_fee_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        protocol_fee_rate: u64
    ) {
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESetProtocolFeeRateMinterPaused);
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
        assert!(!minter.is_paused(), ESetTeamWalletMinterPaused);
        minter.team_wallet = team_wallet;
    }

    /// Distributes the protocol exercise oSAIL fee to the team wallet.
    /// Is public cos team_wallet is predefined
    public fun distribute_team<SailCoinType, ExerciseFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        ctx: &mut TxContext,
    ) {
        assert!(!minter.is_paused(), EDistributeTeamMinterPaused);
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

    /// Pauses token emissions from the minter.
    ///
    /// This is an emergency function that can be used to halt token emissions
    /// in case of security issues or other critical situations.
    public fun pause<SailCoinType>(minter: &mut Minter<SailCoinType>, admin_cap: &AdminCap) {
        minter.check_admin(admin_cap);
        minter.paused = true;
        let pause_event = EventPauseEmission {};
        sui::event::emit<EventPauseEmission>(pause_event);
    }

    /// Unpauses token emissions from the minter.
    ///
    /// This function re-enables token emissions after they were paused.
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

    /// Updates the active period and current epoch oSAIL token.
    ///
    /// This is the core function that drives the tokenomics of the protocol. It:
    /// 1. Sets current epoch oSAIL token
    /// 2. Mints and distributes tokens to the team wallet (if configured)
    /// 3. Distributes protocol fee
    /// 4. Handles rebase growth based on locked vs circulating supply
    /// 5. Updates the epoch oSAIL token in the Voter
    /// 6. Updates the epoch counters and emission rates for the next epoch
    ///
    /// This function should be called once per week (per epoch) to maintain
    /// the emission schedule.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to update
    /// * `voter` - The voter module that manages gauges and voting
    /// * `distribute_governor_cap` - Ensures only distribute governor can call this function
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
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(!minter.is_paused(), EUpdatePeriodMinterPaused);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), EUpdatePeriodDistributionConfigInvalid);
        assert!(minter.is_active(clock), EUpdatePeriodMinterNotActive);
        assert!(
            minter.active_period + distribution::common::week() < distribution::common::current_timestamp(clock),
            EUpdatePeriodNotFinishedYet
        );
        assert!(minter.all_gauges_distributed(distribution_config), EUpdatePeriodNotAllGaugesDistributed);
        let ending_epoch_emissions = minter.epoch_emissions();
        minter.update_o_sail_token(epoch_o_sail_treasury_cap, clock);
        let rebase_growth = calculate_rebase_growth(
            ending_epoch_emissions,
            minter.total_supply(),
            voting_escrow.total_locked()
        );
        if (minter.team_emission_rate > 0 && minter.team_wallet != @0x0) {
            let team_emissions = integer_mate::full_math_u64::mul_div_floor(
                minter.team_emission_rate,
                rebase_growth + ending_epoch_emissions,
                RATE_DENOM - minter.team_emission_rate
            );
            transfer::public_transfer<Coin<SailCoinType>>(
                minter.mint_sail(team_emissions, ctx),
                minter.team_wallet
            );
        };
        if (rebase_growth > 0) {
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
        };
        let distribute_cap = minter.distribute_cap.borrow();
        voter.notify_epoch_token<EpochOSail>(distribute_cap, ctx);
        minter.active_period = distribution::common::current_period(clock);
        reward_distributor.update_active_period(
            option::borrow(&minter.reward_distributor_cap),
            minter.active_period
        );
        let update_epoch_event = EventUpdateEpoch {
            new_period: minter.active_period,
        };
        sui::event::emit<EventUpdateEpoch>(update_epoch_event);
    }


    /// Distributes oSAIL tokens to a gauge based on pool performance metrics.
    /// Calculates and distributes the next epoch's emissions based on current pool metrics
    /// and historical data. For new pools, uses base emissions without performance adjustments.
    ///
    /// # Arguments
    /// * `minter` - The minter instance managing token emissions
    /// * `voter` - The voter instance managing gauge voting
    /// * `distribute_governor_cap` - Capability authorizing distribution
    /// * `distribution_config` - Configuration for token distribution
    /// * `gauge` - The gauge to distribute tokens to
    /// * `pool` - The pool associated with the gauge
    /// * `prev_epoch_pool_emissions` - N-2 epoch's (i.e epoch that ended 1 week ago) emissions for the pool. Zero for gauges younger than 2 weeks.
    /// * `prev_epoch_pool_fees_usd` - N-2 epoch's (i.e epoch that ended 1 week ago) fees in USD. Zero for gauges younger than 2 weeks.
    /// * `epoch_pool_emissions_usd` - N-1 epoch's (i.e epoch that just ended) emissions in USD. Zero for new gauges.
    /// * `epoch_pool_fees_usd` - N-1 epoch's (i.e epoch that just ended) fees in USD. Zero for new gauges.
    /// * `epoch_pool_volume_usd` - N-1 epoch's (i.e epoch that just ended) trading volume in USD. Zero for new gauges.
    /// * `epoch_pool_predicted_volume_usd` - Predicted volume for epoch N (i.e epoch that just started) in USD. Zero for new gauges.
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// The amount of tokens that can be claimed from the distribution
    ///
    /// # Aborts
    /// * If the gauge has already been distributed for the current period
    /// * If the gauge has no base supply
    /// * If pool metrics are invalid for non-initial epochs
    public fun distribute_gauge<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail, NextEpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribute_governor_cap: &DistributeGovernorCap,
        distribution_config: &distribution::distribution_config::DistributionConfig,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        // params related to rewards change calculation
        prev_epoch_pool_emissions: u64,
        prev_epoch_pool_fees_usd: u64,
        epoch_pool_emissions_usd: u64,
        epoch_pool_fees_usd: u64,
        epoch_pool_volume_usd: u64,
        epoch_pool_predicted_volume_usd: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): u64 {
        assert!(!minter.is_paused(), EDistributeGaugeMinterPaused);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_active(clock), EDistributeGaugeMinterNotActive);
        let next_epoch_o_sail_type = type_name::get<NextEpochOSail>();
        assert!(minter.current_epoch_o_sail.borrow() == next_epoch_o_sail_type, EDistributeGaugeInvalidToken);
        
        let gauge_id = object::id(gauge);
        assert!(
            !minter.gauge_active_period.contains(gauge_id) || *minter.gauge_active_period.borrow(gauge_id) < minter.active_period,
             EDistributeGaugeAlreadyDistributed
        );
        assert!(minter.gauge_epoch_emissions.contains(gauge_id), EDistributeGaugePoolHasNoBaseSupply);
        assert!(minter.is_valid_distribution_config(distribution_config), EDistributeGaugeDistributionConfigInvalid);
        
        let gauge_epoch_count = if (minter.gauge_epoch_count.contains(gauge_id)) {
            minter.gauge_epoch_count.remove(gauge_id)
        } else {
            0
        };
        // indicates if this gauges was never distributed before
        let is_initial_epoch = gauge_epoch_count == 0;

        if (is_initial_epoch) {
            // for pools that are new there is no enough data.
            // This extra validation should make sure that our service handles such situations properly
            assert!(
                prev_epoch_pool_emissions == 0 &&
                prev_epoch_pool_fees_usd == 0 &&
                epoch_pool_emissions_usd == 0 &&
                epoch_pool_fees_usd == 0 &&
                epoch_pool_volume_usd == 0 &&
                epoch_pool_predicted_volume_usd == 0,
                EDistributeGaugeFirstEpochMetricsInvalid,
            )
        } else {
            // These values should not be zero, othervise the formula breaks
            // we are not checking prev_epoch_pool_emissions and prev_epoch_pool_fees_usd
            // cos we can make the term with them equal to 1 and the formula will be correct
            assert!(
                epoch_pool_emissions_usd > 0 &&
                epoch_pool_fees_usd > 0 &&
                epoch_pool_volume_usd > 0 &&
                epoch_pool_predicted_volume_usd > 0,
                EDistributeGaugeMetricsInvalid
            )
        };
        // calculate amount of oSAIL to distribute
        let current_epoch_emissions = minter.gauge_epoch_emissions.remove(gauge_id);
        let next_epoch_emissions = if (is_initial_epoch) {
            current_epoch_emissions
        } else {
            calculate_next_pool_emissions(
                current_epoch_emissions,
                prev_epoch_pool_emissions,
                prev_epoch_pool_fees_usd,
                epoch_pool_emissions_usd,
                epoch_pool_fees_usd,
                epoch_pool_volume_usd,
                epoch_pool_predicted_volume_usd
            )
        };

        // distribute oSAIL
        let o_sail_to_distribute = minter.mint_o_sail<SailCoinType, NextEpochOSail>(next_epoch_emissions, ctx);
        let distribute_cap = minter.distribute_cap.borrow();
        let (claimable_amount, rollover_balance) = voter.distribute_gauge<CoinTypeA, CoinTypeB, CurrentEpochOSail, NextEpochOSail>(
            distribute_cap,
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

        // update records related to gauge
        if (minter.gauge_active_period.contains(gauge_id)) {
            minter.gauge_active_period.remove(gauge_id);
        };
        minter.gauge_active_period.add(gauge_id, minter.active_period);
        minter.gauge_epoch_emissions.add(gauge_id, next_epoch_emissions);
        minter.gauge_epoch_count.add(gauge_id, gauge_epoch_count + 1);
        let total_epoch_emissions = if (minter.total_epoch_emissions.contains(minter.active_period)) {
            minter.total_epoch_emissions.remove(minter.active_period)
        } else {
            0
        };
        minter.total_epoch_emissions.add(minter.active_period, total_epoch_emissions + next_epoch_emissions);

        claimable_amount
    }

    public fun all_gauges_distributed<SailCoinType>(
        minter: &Minter<SailCoinType>,
        distribution_config: &distribution::distribution_config::DistributionConfig,
    ): bool {
        let alive_gauges = distribution_config.borrow_alive_gauges().keys();
        let mut i = 0;
        let alive_gauges_len = alive_gauges.length();
        while (i < alive_gauges_len) {
            let gauge_id = *alive_gauges.borrow(i);
            let gauge_active_period = if (minter.gauge_active_period.contains(gauge_id)) {
                *minter.gauge_active_period.borrow(gauge_id)
            } else {
                0
            };

            if (minter.active_period > gauge_active_period) {
                return false
            };
            i = i + 1;
        };

        true
    }

    
    /// Creates a new gauge for a pool with specified base emissions.
    /// The gauge will be used to distribute oSAIL tokens to the pool based on its performance.
    ///
    /// # Arguments
    /// * `minter` - The minter instance managing token emissions
    /// * `voter` - The voter instance managing gauge voting
    /// * `distribution_config` - Configuration for token distribution
    /// * `create_cap` - Capability allowing gauge creation
    /// * `admin_cap` - Capability allowing token distribution
    /// * `voting_escrow` - The voting escrow contract
    /// * `pool` - The pool to create a gauge for
    /// * `gauge_base_emissions` - Base amount of oSAIL tokens to emit per epoch
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A new gauge instance for the specified pool
    public fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut distribution::voter::Voter,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        admin_cap: &AdminCap,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): distribution::gauge::Gauge<CoinTypeA, CoinTypeB> {
        assert!(!minter.is_paused(), ECreateGaugeMinterPaused);
        minter.check_admin(admin_cap);
        assert!(gauge_base_emissions > 0, ECreateGaugeZeroBaseEmissions);

        let distribute_cap = minter.distribute_cap.borrow();
        let gauge = voter.create_gauge(
            distribution_config,
            create_cap,
            distribute_cap,
            voting_escrow,
            pool,
            clock,
            ctx,
        );

        let gauge_id = object::id(&gauge);
        minter.gauge_epoch_emissions.add(gauge_id, gauge_base_emissions);
        
        gauge
    }

    /// Kills (deactivates) a gauge in the system.
    /// This should be used in emergency situations when a gauge needs to be disabled.
    /// Only the emergency council can perform this operation.
    /// Remaining balances should be claimed using another function `claim_killed_gauge`.
    ///
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `distribution_config` - The distribution configuration
    /// * `emergency_council_cap` - The emergency council capability
    /// * `gauge_id` - The ID of the gauge to kill
    /// * `ctx` - The transaction context
    public fun kill_gauge<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        emergency_council_cap.validate_emergency_council_minter_id(object::id(minter));
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EKillGaugeDistributionConfigInvalid
        );
        assert!(
            distribution_config.is_gauge_alive(gauge_id),
            EKillGaugeAlreadyKilled
        );
        distribution_config.update_gauge_liveness(vector<ID>[gauge_id], false);
        let kill_gauge_event = EventKillGauge { id: gauge_id };
        sui::event::emit<EventKillGauge>(kill_gauge_event);
    }


    /// Revives a previously killed gauge, making it active again.
    /// Only the emergency council can perform this operation.
    /// You could revive a gauge only in the same epoch it was killed.
    /// Otherwise you need to reset the gauge to bootstrap it again
    /// with new emissions.
    /// 
    /// # Arguments
    /// * `voter` - The voter contract reference
    /// * `distribution_config` - The distribution configuration
    /// * `emergency_council_cap` - The emergency council capability
    /// * `gauge_id` - The ID of the gauge to revive
    /// * `ctx` - The transaction context
    public fun revive_gauge<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        emergency_council_cap.validate_emergency_council_minter_id(object::id(minter));
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EReviveGaugeDistributionConfigInvalid
        );
        assert!(
            !distribution_config.is_gauge_alive(gauge_id),
            EReviveGaugeAlreadyAlive
        );
        // gauge was distributed in the same epoch it was killed
        // if not use reset_gauge instead
        assert!(
            minter.gauge_active_period.contains(gauge_id) && *minter.gauge_active_period.borrow(gauge_id) == minter.active_period,
            EReviveGaugeNotKilledInCurrentEpoch,
        );
        revive_gauge_internal(distribution_config, gauge_id);
    }

    fun revive_gauge_internal(
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        gauge_id: ID,
    ) {
        distribution_config.update_gauge_liveness(vector<ID>[gauge_id], true);
        let revieve_gauge_event = EventReviveGauge { id: gauge_id };
        sui::event::emit<EventReviveGauge>(revieve_gauge_event);
    }


    // Emergency function to reset a gauge to bootstrap it again.
    // Used when we were not able to revive the gauge in the same epoch it was killed.
    // This function will reset the gauge to the base emissions and start distributing oSAIL again.
    // 
    // # Arguments
    // * `minter` - The minter instance managing token emissions
    // * `voter` - The voter instance managing gauge voting
    // * `distribution_config` - Configuration for token distribution
    public fun reset_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        gauge: &mut distribution::gauge::Gauge<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock
    ) {
        distribution::emergency_council::validate_emergency_council_minter_id(emergency_council_cap, object::id(minter));
        assert!(!minter.is_paused(), EResetGaugeMinterPaused);
        assert!(minter.is_active(clock), EResetGaugeMinterNotActive);
        assert!(gauge_base_emissions > 0, EResetGaugeZeroBaseEmissions);
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EResetGaugeDistributionConfigInvalid
        );
        let gauge_id = object::id(gauge);
        assert!(
            !distribution_config.is_gauge_alive(gauge_id),
            EResetGaugeGaugeAlreadyAlive
        );

        // gauge should not be distributed this epoch
        // if so use revive_gauge instead
        assert!(
            !minter.gauge_active_period.contains(gauge_id) || *minter.gauge_active_period.borrow(gauge_id) < minter.active_period,
             EResetGaugeAlreadyDistributed
        );

        // reset epoch count
        if (minter.gauge_epoch_count.contains(gauge_id)) {
            minter.gauge_epoch_count.remove(gauge_id);
        };
        minter.gauge_epoch_count.add(gauge_id, 0);

        // reset epoch emissions
        if (minter.gauge_epoch_emissions.contains(gauge_id)) {
            minter.gauge_epoch_emissions.remove(gauge_id);
        };
        minter.gauge_epoch_emissions.add(gauge_id, gauge_base_emissions);

        revive_gauge_internal(distribution_config, gauge_id);
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

    /// Checks if provided oSAIL type is valid.
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
    /// not a mutable borrow to prevent public mint
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
        assert!(!minter.is_paused(), EBurnOSailMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EBurnOSailInvalidOSail);

        let cap = minter.borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>();
        let burnt = cap.burn(coin);
        minter.o_sail_total_supply = minter.o_sail_total_supply - burnt;

        burnt
    }

    /// Burning function, the same as burn_o_sail but for balance
    public fun burn_o_sail_balance<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        balance: Balance<OSailCoinType>,
        ctx: &mut TxContext,
    ): u64 {
        minter.burn_o_sail(coin::from_balance(balance, ctx))
    }

    // internal mint function
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
        assert!(!minter.is_paused(), ECreateLockFromOSailMinterPaused);
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
                        break
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

        let sail_to_lock = minter.exercise_o_sail_free_internal(o_sail, percent_to_receive, clock, ctx);

        voting_escrow.create_lock<SailCoinType>(
            sail_to_lock,
            lock_duration_days,
            permanent,
            clock,
            ctx
        )
    }

    // method that burns oSAIL and mints SAIL
    fun exercise_o_sail_free_internal<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        percent_to_receive: u64,
        clock: &sui::clock::Clock,
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
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        exercise_o_sail_free_internal(minter, o_sail, percent_to_receive, clock, ctx)
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
        assert!(!minter.is_paused(), EExerciseOSailAbMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExerciseOSailInvalidOSail);
        let o_sail_type = type_name::get<OSailCoinType>();
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
        assert!(!minter.is_paused(), EExerciseOSailBaMinterPaused);
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

        let distribute_cap = minter.distribute_cap.borrow();

        voter.notify_exercise_fee_reward_amount(
            distribute_cap,
            usd_to_pay,
            clock,
            ctx
        );

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

    /// Gets total emissions for last distributed epoch
    public fun epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        let active_period = minter.active_period;
        minter.emissions_by_epoch(active_period)
    }

    /// Gets emissions for a specific epoch
    /// Returns 0 if the epoch is not found
    public fun emissions_by_epoch<SailCoinType>(minter: &Minter<SailCoinType>, epoch: u64): u64 {
        if (minter.total_epoch_emissions.contains(epoch)) {
            *minter.total_epoch_emissions.borrow(epoch)
        } else {
            0
        }
    }

    /// Returns the table of epoch emissions for each pool. These emissions are valid for last distributed epoch
    /// or will be distributed in initial epoch.
    public fun borrow_pool_epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): &Table<ID, u64> {
        &minter.gauge_epoch_emissions
    }

    /// Allows usage of the pool for oSAIL exercise
    /// Also allows tokens from the pool to be used as exercise fee tokens
    public fun whitelist_pool<SailCoinType, CoinTypeA, CoinTypeB>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        list: bool,
    ) {
        assert!(!minter.is_paused(), EWhitelistPoolMinterPaused);
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
        }
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

    public fun schedule_sail_mint<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &mut sui::package::Publisher,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): TimeLockedSailMint {
        assert!(publisher.from_module<MINTER>(), EScheduleSailMintPublisherInvalid);
        assert!(!minter.is_paused(), EScheduleSailMintMinterPaused);
        assert!(amount > 0, EScheduleSailMintAmountZero);
        let id = object::new(ctx);
        let unlock_time = clock.timestamp_ms() + MINT_LOCK_TIME_MS;
        TimeLockedSailMint {
            id,
            amount,
            unlock_time,
        }
    }

    public fun execute_sail_mint<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        mint: TimeLockedSailMint,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        assert!(!minter.is_paused(), EExecuteSailMintMinterPaused);
        let TimeLockedSailMint {id, amount, unlock_time} = mint;
        object::delete(id);

        assert!(unlock_time <= clock.timestamp_ms(), EExecuteSailMintStillLocked);

        minter.mint_sail(amount, ctx)
    }

    public fun cancel_sail_mint(
        mint: TimeLockedSailMint,
    ) {
        let TimeLockedSailMint {id, amount: _, unlock_time: _} = mint;
        object::delete(id);
    }

    public fun schedule_o_sail_mint<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &mut sui::package::Publisher,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): TimeLockedOSailMint<OSailCoinType> {
        assert!(publisher.from_module<MINTER>(), EScheduleOSailMintPublisherInvalid);
        assert!(!minter.is_paused(), EScheduleOSailMintMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EScheduleOSailMintInvalidOSail);
        assert!(amount > 0, EScheduleOSailMintAmountZero);
        let id = object::new(ctx);
        let unlock_time = clock.timestamp_ms() + MINT_LOCK_TIME_MS;
        TimeLockedOSailMint<OSailCoinType> {
            id,
            amount,
            unlock_time,
        }
    }

    public fun execute_o_sail_mint<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        mint: TimeLockedOSailMint<OSailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<OSailCoinType> {
        assert!(!minter.is_paused(), EExecuteOSailMintMinterPaused);
        let TimeLockedOSailMint {id, amount, unlock_time} = mint;
        object::delete(id);

        assert!(unlock_time <= clock.timestamp_ms(), EExecuteOSailMintStillLocked);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExecuteOSailMintInvalidOSail);

        minter.mint_o_sail<SailCoinType, OSailCoinType>(amount, ctx)
    }

    public fun cancel_o_sail_mint<OSailCoinType>(
        mint: TimeLockedOSailMint<OSailCoinType>,
    ) {
        let TimeLockedOSailMint {id, amount: _, unlock_time: _} = mint;
        object::delete(id);
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
         sui::package::claim<MINTER>(MINTER {}, ctx)
    }
}


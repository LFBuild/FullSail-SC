/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module governance::minter {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use std::type_name::{Self, TypeName};
    use sui::coin::{Self, TreasuryCap, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::vec_set::{Self, VecSet};
    use sui::bag::{Self, Bag};
    use sui::table::{Self, Table};
    use integer_mate::full_math_u128;
    use price_monitor::price_monitor::{Self, PriceMonitor};
    use switchboard::decimal::{Self, Decimal};
    use switchboard::aggregator::{Aggregator};
    use governance::distribution_config::{DistributionConfig};

    const ECreateMinterInvalidPublisher: u64 = 695309471293028100;
    const ECreateMinterInvalidSailDecimals: u64 = 744215000566210300;

    const EGrantAdminInvalidPublisher: u64 = 198127851942335970;

    const EGrantDistributeGovernorInvalidPublisher: u64 = 49774594592309590;

    const ESetMaxEmissionChangeRatioInvalidPublisher: u64 = 716496543415068300;

    const ERevokeAdminInvalidPublisher: u64 = 729123415718822900;

    const ERevokeDistributeGovernorInvalidPublisher: u64 = 639606009071379600;

    const EActivateMinterInvalidOSailDecimals: u64 = 305250931597320450;
    const EActivateMinterAlreadyActive: u64 = 922337310630222234;
    const EActivateMinterPaused: u64 = 996659030249798900;
    const EActivateMinterNoDistributorCap: u64 = 922337311059823823;

    const ESetTreasuryCapMinterPaused: u64 = 179209983522842700;
    const EMinterCapAlreadySet: u64 = 922337283142372556;
    const ESetTreasuryCapInvalidSailDecimals: u64 = 776365075387678700;

    const ESetDistributeCapMinterPaused: u64 = 939345375978791600;

    const ESetTeamEmissionRateMinterPaused: u64 = 339140718471350200;

    const ESetProtocolFeeRateMinterPaused: u64 = 548722644715498500;
    const ESetTeamEmissionRateTooBigRate: u64 = 922337292161803878;
    const ESetProtocolFeeRateTooBigRate: u64 = 840171622736257200;

    const ESetTeamWalletMinterPaused: u64 = 587854778781893500;

    const EUpdatePeriodOSailInvalidDecimals: u64 = 569106921639800800;
    const EUpdatePeriodMinterPaused: u64 = 540422149172903100;
    const EUpdatePeriodMinterNotActive: u64 = 922337339406490010;
    const EUpdatePeriodNotFinishedYet: u64 = 922337340695058843;
    const EUpdatePeriodNoRebaseDistributorCap: u64 = 493364785715856700;
    const EUpdatePeriodDistributionConfigInvalid: u64 = 222427100417155840;
    const EUpdatePeriodOSailAlreadyUsed: u64 = 573264404146058900;

    const EDistributeGaugeMinterPaused: u64 = 383966743216827200;
    const EDistributeGaugeInvalidToken: u64 = 802874746577660900;
    const EDistributeGaugeAlreadyDistributed: u64 = 259145126193785820;
    const EDistributeGaugePoolHasNoBaseSupply: u64 = 764215244078886900;
    const EDistributeGaugeDistributionConfigInvalid: u64 = 540205746933504640;
    const EDistributeGaugeMinterNotActive: u64 = 728194857362048571;
    const EDistributeGaugeFirstEpochEmissionsInvalid: u64 = 671508139267645600;
    const EDistributeGaugeEmissionsZero: u64 = 424941542236535500;
    const EDistributeGaugeEmissionsChangeTooBig: u64 = 95918619286974770;
    const EDistributeGaugeNoPeriodButHasEmissions: u64 = 658460351931005700;

    const EIncreaseEmissionsNotDistributed: u64 = 243036335954370780;
    const EIncreaseEmissionsDistributionConfigInvalid: u64 = 578889065004501400;
    const EIncreaseEmissionsInvalidAggregator: u64 = 371600893769831900;
    const EIncreaseEmissionsMinterNotActive: u64 = 204872681976552500;
    const EIncreaseEmissionsMinterPaused: u64 = 566083930742334200;

    const ENullEmissionsInvalidAggregator: u64 = 615720519320343900;
    const ENullEmissionsMinterNotActive: u64 = 331184800637416260;
    const ENullEmissionsMinterPaused: u64 = 822945392897831400;
    const ENullEmissionsDistributionConfigInvalid: u64 = 999449428985169400;
    const ENullGaugeEmissionsNotDistributed: u64 = 993690112178294400;
    const ENullGaugeEmissionsDeltaTooBigForGauge: u64 = 898366676764968400;
    const ENullGaugeEmissionsDeltaTooBigForTotal: u64 = 608854472762321500;

    const ECheckAdminRevoked: u64 = 922337280994888908;
    const ECheckDistributeGovernorRevoked: u64 = 369612027923601500;

    const ECreateLockFromOSailMinterPaused: u64 = 345260272869412100;
    const ECreateLockFromOSailInvalidToken: u64 = 916284390763921500;
    const ECreateLockFromOSailInvalidDuraton: u64 = 68567430268160480;

    const EDepositOSailMinterPaused: u64 = 817316631458528500;
    const EDepositOSailInvalidToken: u64 = 930930427300172700;
    const EDepositOSailBalanceNotExist: u64 = 4573731802313574;
    const EDepositOSailLockNotPermanent: u64 = 240260341661373800;
    const EDepositOSailZeroAmount: u64 = 581468583996395500;

    const EExerciseOSailFreeTooBigPercent: u64 = 410835752553141860;
    const EExerciseOSailExpired: u64 = 738843771743325200;
    const EExerciseOSailInvalidOSail: u64 = 320917362365364070;
    const EExerciseOSailMinterPaused: u64 = 295847361920485736;
    const EExerciseOSailInvalidDistrConfig: u64 = 156849871586365300;
    const EExerciseOSailInvalidAggregator: u64 = 48171994695305640;
    const EExerciseOSailInvalidUsd: u64 = 953914262470819500;

    const EBurnOSailInvalidOSail: u64 = 665869556650983200;
    const EBurnOSailMinterPaused: u64 = 947382564018592637;

    const EExerciseUsdLimitReached: u64 = 490517942447480600;
    const EExerciseUsdLimitHigherThanOSail: u64 = 601485821599794400;

    const EDistributeProtocolTokenNotFound: u64 = 341757784748534300;
    const EDistributeProtocolMinterPaused: u64 = 410768471077089800;
    const EDistributeProtocolWalletNotSet: u64 = 987893910474538100;

    const EDistributeOperationsTokenNotFound: u64 = 321746203850562500;
    const EDistributeOperationsMinterPaused: u64 = 14616427533564292;
    const EDistributeOperationsWalletNotSet: u64 = 390491624826283500;

    const EDistributeExerciseFeeMinterPaused: u64 = 790727734853938600;

    const ECreateGaugeMinterPaused: u64 = 173400731963214500;
    const ECreateGaugeZeroBaseEmissions: u64 = 676230237726862100;

    const EResetGaugeMinterPaused: u64 = 412179529765746000;
    const EResetGaugeMinterNotActive: u64 = 125563751493106940;
    const EResetGaugeZeroBaseEmissions: u64 = 777730412186606000;
    const EResetGaugeDistributionConfigInvalid: u64 = 726258387105137800;
    const EResetGaugeGaugeAlreadyAlive: u64 = 452133119942522700;
    const EResetGaugeGaugePaused: u64 = 961444105364833700;
    const EResetGaugeAlreadyDistributed: u64 = 97456931979148290;

    const EKillGaugeGaugeDoesNotMatchPool: u64 = 435068472641034750;
    const EKillGaugeDistributionConfigInvalid: u64 = 401018599948013600;
    const EKillGaugeAlreadyKilled: u64 = 812297136203523100;
    const EKillGaugeAlreadyPaused: u64 = 630946245455940700;
    const EKillGaugeUnstakedFeeRateNotZero: u64 = 456637970011596540;

    const EPauseGaugeDistributionConfigInvalid: u64 = 440852511239727200;
    const EPauseGaugeAlreadyPaused: u64 = 183938828687429060;
    const EUnpauseGaugeDistributionConfigInvalid: u64 = 222183394791539940;
    const EUnpauseGaugeNotPaused: u64 = 805756312652419800;

    const ESettleKilledGaugeDistributionConfigInvalid: u64 = 980526521444534400;
    const ESettleKilledGaugeGaugeNotKilled: u64 = 774570594676845700;
    const ESettleKilledGaugeGaugePaused: u64 = 27796803820661076;
    const ESettleKilledGaugeMinterPaused: u64 = 940519593113543700;
    const ESettleKilledGaugeMinterNotActive: u64 = 417539538110257340;
    const ESettleKilledGaugeAlreadyDistributed: u64 = 916506255647727900;

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

    const ESetOsailPriceAggregatorInvalidDistrConfig: u64 = 615700294268918300;

    const ESetSailPriceAggregatorInvalidDistrConfig: u64 = 869469108643585500;

    const EGetPositionRewardInvalidRewardToken: u64 = 779306294896264600;
    const EGetPosDistributionConfInvalid: u64 = 695673975436220400;
    const EGetPosRewardGaugePaused: u64 = 826495068705045200;
    const EGetMultiplePositionRewardInvalidRewardToken: u64 = 785363146605424900;
    const EGetMultiPosRewardDistributionConfInvalid: u64 = 695673975436220400;
    const EGetMultiPosRewardGaugePaused: u64 = 190132400718876700;
    const EClaimUnclaimedOsailInvalidEpochToken: u64 = 934963468982192254;

    const EEmissionStopped: u64 = 123456789012345678;

    const EInvalidSailPool: u64 = 939179427939211244;

    const ESetPassiveVoterFeeRateMinterPaused: u64 = 30404305134543064;
    const ESetPassiveVoterFeeRateTooBig: u64 = 33300079580685040;
    const ECreatePassiveFeeDistributorMinterPaused: u64 = 790683210711862100;
    const ENotifyPassiveFeeMinterPaused: u64 = 844085871921421700;
    const ENotifyPassiveFeeMinterNotActive: u64 = 118762856398482380;

    const EWithdrawPassiveFeeMinterPaused: u64 = 625411062294594000;
    const EWithdrawPassiveFeeTokenNotFound: u64 = 152347212472896830;

    const BAG_KEY_PASSIVE_VOTER_FEE_RATE: u8 = 1;
    const BAG_KEY_PASSIVE_FEE_BALANCES: u8 = 2;

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

    const MAX_EMISSIONS_CHANGE_RATIO: u64 = 20;

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

    public struct EventActivateMinter has copy, drop, store {
        activated_at: u64,
        active_period: u64,
        epoch_o_sail_type: TypeName,
    }

    public struct EventUpdateEpoch has copy, drop, store {
        new_period: u64,
        updated_at: u64,
        prev_prev_epoch_o_sail_emissions: u64,
        team_emissions: u64,
        finished_epoch_growth_rebase: u64,
        epoch_o_sail_type: TypeName,
    }

    public struct EventReviveGauge has copy, drop, store {
        id: ID,
    }

    public struct EventResetGauge has copy, drop, store {
        id: ID,
        gauge_base_emissions: u64,
    }

    public struct EventKillGauge has copy, drop, store {
        id: ID,
    }

    public struct EventSettleKilledGauge has copy, drop, store {
        gauge_id: ID,
        pool_id: ID,
        fee_a_amount: u64,
        fee_b_amount: u64,
        ended_epoch_o_sail_emission: u64,
    }

    public struct EventPauseGauge has copy, drop, store {
        id: ID,
    }

    public struct EventUnpauseGauge has copy, drop, store {
        id: ID,
    }

    public struct EventPauseEmission has copy, drop, store {}

    public struct EventUnpauseEmission has copy, drop, store {}
    public struct EventStopEmission has copy, drop, store {}
    public struct EventResumeEmission has copy, drop, store {}

    public struct EventGrantAdmin has copy, drop, store {
        who: address,
        admin_cap: ID,
    }

    public struct EventRevokeAdmin has copy, drop, store {
        admin_cap: ID,
    }

    public struct EventGrantDistributeGovernor has copy, drop, store {
        who: address,
        distribute_governor_cap: ID,
    }

    public struct EventRevokeDistributeGovernor has copy, drop, store {
        distribute_governor_cap: ID,
    }

    public struct EventSetTreasuryCap has copy, drop, store {
        treasury_cap: ID,
        token_type: TypeName,
    }

    public struct EventSetRebaseDistributorCap has copy, drop, store {
        rebase_distributor_cap: ID,
    }

    public struct EventSetDistributeCap has copy, drop, store {
        admin_cap: ID,
        distribute_cap: ID,
    }

    public struct EventUpdateTeamEmissionRate has copy, drop, store {
        admin_cap: ID,
        team_emission_rate: u64,
    }

    public struct EventUpdateProtocolFeeRate has copy, drop, store {
        admin_cap: ID,
        protocol_fee_rate: u64,
    }

    public struct EventSetTeamWallet has copy, drop, store {
        admin_cap: ID,
        team_wallet: address,
    }

    public struct EventSetProtocolWallet has copy, drop, store {
        admin_cap: ID,
        protocol_wallet: address,
    }

    public struct EventSetOperationsWallet has copy, drop, store {
        admin_cap: ID,
        operations_wallet: address,
    }

    public struct EventDistributeProtocol has copy, drop, store {
        protocol_wallet: address,
        amount: u64,
        token_type: TypeName,
    }

    public struct EventDistributeOperations has copy, drop, store {
        operations_wallet: address,
        amount: u64,
        token_type: TypeName,
    }

    public struct EventDistributeExerciseFeeToReward has copy, drop, store {
        admin_cap_id: ID,
        amount: u64,
        token_type: TypeName,
    }

    public struct EventGaugeCreated has copy, drop, store {
        id: ID,
        pool_id: ID,
        base_emissions: u64,
    }

    public struct EventDistributeGauge has copy, drop, store {
        gauge_id: ID,
        pool_id: ID,
        o_sail_type: TypeName,
        next_epoch_emissions_usd: u64,
        ended_epoch_o_sail_emission: u64,
    }

    public struct EventDistributeGaugeV2 has copy, drop, store {
        gauge_id: ID,
        pool_id: ID,
        o_sail_type: TypeName,
        next_epoch_emissions_usd: u64,
        ended_epoch_o_sail_emission: u64,
        active_voting_fee_a: u64,
        active_voting_fee_b: u64,
        passive_fee_a: u64,
        passive_fee_b: u64,
    }

    public struct EventIncreaseGaugeEmissions has copy, drop, store {
        gauge_id: ID,
        pool_id: ID,
        emissions_increase_usd: u64,
        o_sail_type: TypeName,
    }

    public struct EventNullGaugeEmissions has copy, drop, store {
        gauge_id: ID,
        pool_id: ID,
        rewards_nulled_usd: u64,
        new_gauge_epoch_emissions_usd: u64,
        new_total_epoch_emissions_usd: u64,
    }

    public struct EventCreateLockFromOSail has copy, drop, store {
        o_sail_amount_in: u64,
        o_sail_type: TypeName,
        sail_amount_to_lock: u64,
        o_sail_expired: bool,
        duration: u64,
        permanent: bool,
    }

    public struct EventDepositOSailIntoLock has copy, drop, store {
        o_sail_amount_in: u64,
        o_sail_type: TypeName,
        sail_amount_to_lock: u64,
        lock_id: ID,
    }

    public struct EventExerciseOSail has copy, drop, store {
        o_sail_amount_in: u64,
        sail_amount_out: u64,
        o_sail_type: TypeName,
        exercise_fee_token_type: TypeName,
        exercise_fee_amount: u64,
        // protocol fee amount + fee to distribute = exercise fee amount
        protocol_fee_amount: u64,
        fee_to_distribute: u64,
    }

    public struct EventExerciseOSailFree has copy, drop, store {
        o_sail_amount_in: u64,
        sail_amount_out: u64,
        o_sail_type: TypeName,
    }

    public struct EventWhitelistUSD has copy, drop, store {
        usd_type: TypeName,
        whitelisted: bool,
    }

    public struct EventSetOSailPriceAggregator has copy, drop, store {
        price_aggregator: ID,
    }

    public struct EventSetSailPriceAggregator has copy, drop, store {
        price_aggregator: ID,
    }

    public struct EventSetLiquidityUpdateCooldown has copy, drop, store {
        new_cooldown: u64,
    }

    public struct EventSetEarlyWithdrawalPenaltyPercentage has copy, drop, store {
        new_penalty_percentage: u64,
    }

    public struct EventSetPassiveVoterFeeRate has copy, drop, store {
        admin_cap: ID,
        passive_voter_fee_rate: u64,
    }

    public struct EventCreatePassiveFeeDistributor has copy, drop, store {
        admin_cap: ID,
        passive_fee_distributor: ID,
        fee_coin_type: TypeName,
    }

    public struct EventNotifyPassiveFee has copy, drop, store {
        passive_fee_distributor: ID,
        fee_coin_type: TypeName,
        amount: u64,
    }

    public struct EventWithdrawPassiveFee has copy, drop, store {
        governor_cap: ID,
        fee_coin_type: TypeName,
        amount: u64,
    }

    public struct EventScheduleTimeLockedMint has copy, drop, store {
        amount: u64,
        unlock_time: u64,
        is_osail: bool,
        token_type: TypeName,
    }

    public struct EventCancelTimeLockedMint has copy, drop, store {
        id: ID,
        amount: u64,
        token_type: TypeName,
        is_osail: bool,
    }

    public struct EventMint has copy, drop, store {
        amount: u64,
        token_type: TypeName,
        is_osail: bool,
    }

    public struct EventBurn has copy, drop, store {
        amount: u64,
        token_type: TypeName,
        is_osail: bool,
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

    public struct EventClaimPositionReward has copy, drop, store {
        from: address,
        gauge_id: ID,
        pool_id: ID,
        position_id: ID,
        amount: u64,
        growth_inside: u128,
        token: TypeName,
    }

    public struct Minter<phantom SailCoinType> has store, key {
        id: UID,
        revoked_admins: VecSet<ID>,
        revoked_distribute_governors: VecSet<ID>,
        paused: bool,
        emission_stopped: bool,
        activated_at: u64,
        active_period: u64,
        // The oSAIL which will be distributed at the begining of new epoch and during the epoch
        current_epoch_o_sail: Option<TypeName>,
        last_epoch_update_time: u64,
        sail_cap: Option<TreasuryCap<SailCoinType>>,
        o_sail_caps: Bag,
        // Sum of supplies of all o_sail tokens that were minted.
        // Some of the distributed o_sail tokens may be not minted yet as users may choose not to claim the rewards.
        o_sail_minted_supply: u64,
        o_sail_expiry_dates: Table<TypeName, u64>,
        team_emission_rate: u64,
        protocol_fee_rate: u64,
        // wallet to distribute team emissions to
        team_wallet: address,
        // wallet to distribute protocol fees to
        protocol_wallet: address,
        // wallet that is used to perform operations on behalf of the protocol
        operations_wallet: address,
        // Map Rebase/ExerciseFee Distributor ID -> Capability
        rebase_distributor_cap: Option<governance::rebase_distributor_cap::RebaseDistributorCap>,
        distribute_cap: Option<governance::distribute_cap::DistributeCap>,
        // pools that can be used to exercise oSAIL
        // we don't need whitelisted tokens, cos
        // pool whitelist also determines token whitelist composed of the pools tokens.
        whitelisted_usd: VecSet<TypeName>,
        // Despite the name this is all kind of protocol fees, including
        // both exercise fee and killed gauge fees.
        exercise_fee_protocol_balances: Bag,
        // these balances are supposed to be used to buyback SAIL on a regualar basis
        exercise_fee_operations_balances: Bag,
        // Gauge Id -> oSAil Emissions
        gauge_epoch_emissions_usd: Table<ID, u64>,
        // Gauge Id -> Minter.active_period during which gauge was distributed
        gauge_active_period: Table<ID, u64>,
        // Gauge Id -> number of epochs guage participates in distribution
        gauge_epoch_count: Table<ID, u64>,
        // Sum of expected usd emissions for all gauges
        // Epoch start seconds -> sum of usd emissions for all gauges
        total_epoch_emissions_usd: Table<u64, u64>,
        // Sum of actual oSAIL emissions for all gauges
        // Epoch start seconds -> sum of oSAIL emissions for all gauges
        total_epoch_o_sail_emissions: Table<u64, u64>,
        distribution_config: ID,
        max_emission_change_ratio: u64,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    /// Returns the total supply only of SailCoin managed by this minter.
    public fun sail_total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        option::borrow<TreasuryCap<SailCoinType>>(&minter.sail_cap).total_supply()
    }

    /// Return the sum of total supplies of all oSAIL coins
    public fun o_sail_minted_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.o_sail_minted_supply
    }

    /// Return the total supply of both SAIL an all oSAIL coins
    public fun total_supply<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.sail_total_supply() + minter.o_sail_minted_supply
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
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        epoch_o_sail_metadata: &CoinMetadata<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(epoch_o_sail_metadata.get_decimals() == voting_escrow::common::sail_decimals(), EActivateMinterInvalidOSailDecimals);
        minter.activate_internal(
            voter,
            admin_cap,
            rebase_distributor,
            epoch_o_sail_treasury_cap,
            clock,
            ctx,
        );
    }

    /// Test only method without metadata check as it is impossible to create metadata in test environment.
    #[test_only]
    public fun activate_test<SailCoinType, EpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        admin_cap: &AdminCap,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        minter.activate_internal(
            voter,
            admin_cap,
            rebase_distributor,
            epoch_o_sail_treasury_cap,
            clock,
            ctx,
        );
    }

    fun activate_internal<SailCoinType, EpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        admin_cap: &AdminCap,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), EActivateMinterPaused);
        assert!(!minter.is_active(clock), EActivateMinterAlreadyActive);
        let rebase_distributor_id = object::id(rebase_distributor);
        assert!(
            minter.rebase_distributor_cap.is_some(),
            EActivateMinterNoDistributorCap
        );
        minter.update_o_sail_token(epoch_o_sail_treasury_cap, clock);
        let distribute_cap = minter.distribute_cap.borrow();
        voter.notify_epoch_token<EpochOSail>(distribute_cap, ctx);
        let current_time = voting_escrow::common::current_timestamp(clock);
        minter.activated_at = current_time;
        minter.active_period = voting_escrow::common::to_period(minter.activated_at);
        minter.last_epoch_update_time = current_time;
        let rebase_distributor_cap = minter.rebase_distributor_cap.borrow();
        rebase_distributor.start(
            rebase_distributor_cap,
            minter.active_period,
            clock,
        );

        let event = EventActivateMinter {
            activated_at: current_time,
            active_period: minter.active_period,
            epoch_o_sail_type: type_name::get<EpochOSail>(),
        };
        sui::event::emit<EventActivateMinter>(event);
    }

    /// Returns the timestamp when the minter was activated.
    public fun activated_at<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.activated_at
    }

    /// Returns the current active period of the minter.
    public fun active_period<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        minter.active_period
    }

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
    /// * `metadata` - Metadata for SailCoin
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A tuple with (minter, admin_cap), where admin_cap grants administrative privileges
    public fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        treasury_cap: Option<TreasuryCap<SailCoinType>>,
        metadata: &CoinMetadata<SailCoinType>,
        distribution_config: ID,
        ctx: &mut TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        // method is protected by publisher so we don't need version control here.
        assert!(metadata.get_decimals() == voting_escrow::common::sail_decimals(), ECreateMinterInvalidSailDecimals);
        create_internal(publisher, treasury_cap, distribution_config, ctx)
    }

    /// Test only method without metadata check as it is impossible to create metadata in test environment.
    #[test_only]
    public fun create_test<SailCoinType>(
        publisher: &sui::package::Publisher,
        treasury_cap: Option<TreasuryCap<SailCoinType>>,
        distribution_config: ID,
        ctx: &mut TxContext
    ): (Minter<SailCoinType>, AdminCap) {
        create_internal(publisher, treasury_cap, distribution_config, ctx)
    }

    fun create_internal<SailCoinType>(
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
            emission_stopped: false,
            activated_at: 0,
            active_period: 0,
            current_epoch_o_sail: option::none<TypeName>(),
            last_epoch_update_time: 0,
            sail_cap: treasury_cap,
            o_sail_caps: bag::new(ctx),
            o_sail_minted_supply: 0,
            o_sail_expiry_dates: table::new<TypeName, u64>(ctx),
            team_emission_rate: 0,
            protocol_fee_rate: 1000,
            team_wallet: @0x0,
            protocol_wallet: @0x0,
            operations_wallet: @0x0,
            rebase_distributor_cap: option::none<governance::rebase_distributor_cap::RebaseDistributorCap>(),
            distribute_cap: option::none<governance::distribute_cap::DistributeCap>(),
            whitelisted_usd: vec_set::empty<TypeName>(),
            exercise_fee_protocol_balances: bag::new(ctx),
            exercise_fee_operations_balances: bag::new(ctx),
            gauge_epoch_emissions_usd: table::new<ID, u64>(ctx),
            gauge_active_period: table::new<ID, u64>(ctx),
            gauge_epoch_count: table::new<ID, u64>(ctx),
            total_epoch_emissions_usd: table::new<u64, u64>(ctx),
            total_epoch_o_sail_emissions: table::new<u64, u64>(ctx),
            distribution_config,
            max_emission_change_ratio: MAX_EMISSIONS_CHANGE_RATIO,
            bag: sui::bag::new(ctx),
        };
        let admin_cap = AdminCap { id: object::new(ctx) };
        (minter, admin_cap)
    }

    /// Grants and transfers administrative capability to a specified address.
    /// This function is not protected by is_paused to prevent deadlocks.
    public fun grant_admin(publisher: &sui::package::Publisher, who: address, ctx: &mut TxContext) {
        // method is protected by publisher so we don't need version control here.
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
        // method is protected by publisher so we don't need version control here.
        assert!(publisher.from_module<MINTER>(), EGrantDistributeGovernorInvalidPublisher);
        let distribute_governor_cap = DistributeGovernorCap { id: object::new(ctx) };
        let grant_distribute_governor_event = EventGrantDistributeGovernor {
            who,
            distribute_governor_cap: object::id<DistributeGovernorCap>(&distribute_governor_cap),
        };
        sui::event::emit<EventGrantDistributeGovernor>(grant_distribute_governor_event);
        transfer::transfer<DistributeGovernorCap>(distribute_governor_cap, who);
    }

    public fun set_max_emission_change_ratio<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &sui::package::Publisher,
        distribution_config: &DistributionConfig,
        max_emission_change_ratio: u64
    ) {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<MINTER>(), ESetMaxEmissionChangeRatioInvalidPublisher);
        minter.max_emission_change_ratio = max_emission_change_ratio;
    }

    fun init(otw: MINTER, ctx: &mut TxContext) {
        sui::package::claim_and_keep<MINTER>(otw, ctx);
    }

    /// Checks if the minter is active.
    ///
    /// A minter is considered active if it has been activated,
    /// and the current period is at least the minter's active period.
    public fun is_active<SailCoinType>(minter: &Minter<SailCoinType>, clock: &sui::clock::Clock): bool {
        minter.activated_at > 0 && voting_escrow::common::current_period(clock) >= minter.active_period
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

    /// Checks if emission is stopped due to oracle compromise.
    ///
    /// Used to protect functions that use price aggregators.
    /// When true, all functions requiring price data should be blocked.
    public fun is_emission_stopped<SailCoinType>(minter: &Minter<SailCoinType>): bool {
        minter.emission_stopped
    }

    public fun is_valid_distribution_config<SailCoinType>(
        minter: &Minter<SailCoinType>, 
        distribution_config: &DistributionConfig
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
        // method is protected by publisher so we don't need version control here.
        assert!(publisher.from_module<MINTER>(), ERevokeAdminInvalidPublisher);
        minter.revoked_admins.insert(cap_id);

        let revoke_admin_event = EventRevokeAdmin {
            admin_cap: cap_id,
        };
        sui::event::emit<EventRevokeAdmin>(revoke_admin_event);
    }

    /// Revokes distribute governor capabilities for a specific distribute governor.
    public fun revoke_distribute_governor<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        publisher: &sui::package::Publisher,
        cap_id: ID
    ) {
        // method is protected by publisher so we don't need version control here.
        assert!(publisher.from_module<MINTER>(), ERevokeDistributeGovernorInvalidPublisher);
        minter.revoked_distribute_governors.insert(cap_id);

        let revoke_distribute_governor_event = EventRevokeDistributeGovernor {
            distribute_governor_cap: cap_id,
        };
        sui::event::emit<EventRevokeDistributeGovernor>(revoke_distribute_governor_event);
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
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<SailCoinType>,
        metadata: &CoinMetadata<SailCoinType>
    ) {
        distribution_config.checked_package_version();
        assert!(metadata.get_decimals() == voting_escrow::common::sail_decimals(), ESetTreasuryCapInvalidSailDecimals);
        minter.set_treasury_cap_internal(admin_cap, treasury_cap);
    }

    /// Test only method without metadata check as it is impossible to create metadata in test environment.
    #[test_only]
    public fun set_treasury_cap_test<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<SailCoinType>,
    ) {
        minter.set_treasury_cap_internal(admin_cap, treasury_cap);
    }

    fun set_treasury_cap_internal<SailCoinType>(
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
        let treasury_cap_id = object::id(&treasury_cap);
        option::fill<TreasuryCap<SailCoinType>>(&mut minter.sail_cap, treasury_cap);

        let set_treasury_cap_event = EventSetTreasuryCap {
            treasury_cap: treasury_cap_id,
            token_type: type_name::get<SailCoinType>(),
        };
        sui::event::emit<EventSetTreasuryCap>(set_treasury_cap_event);
    }

    /// Sets the reward distributor capability for the minter.
    public fun set_rebase_distributor_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        rebase_distributor_cap: governance::rebase_distributor_cap::RebaseDistributorCap
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        let rebase_distributor_cap_id = object::id(&rebase_distributor_cap);
        minter.rebase_distributor_cap.fill(rebase_distributor_cap);

        let set_rebase_distributor_cap_event = EventSetRebaseDistributorCap {
            rebase_distributor_cap: rebase_distributor_cap_id,
        };
        sui::event::emit<EventSetRebaseDistributorCap>(set_rebase_distributor_cap_event);
    }

    /// Sets the distribute capability for the minter.
    public fun set_distribute_cap<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        distribute_cap: governance::distribute_cap::DistributeCap
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), ESetDistributeCapMinterPaused);
        minter.check_admin(admin_cap);
        let distribute_cap_id = object::id(&distribute_cap);
        option::fill<governance::distribute_cap::DistributeCap>(
            &mut minter.distribute_cap,
            distribute_cap
        );

        let set_distribute_cap_event = EventSetDistributeCap {
            admin_cap: object::id(admin_cap),
            distribute_cap: distribute_cap_id,
        };
        sui::event::emit<EventSetDistributeCap>(set_distribute_cap_event);
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
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        team_emission_rate: u64
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESetTeamEmissionRateMinterPaused);
        assert!(team_emission_rate <= MAX_TEAM_EMISSIONS_RATE, ESetTeamEmissionRateTooBigRate);
        minter.team_emission_rate = team_emission_rate;

        let update_team_emission_rate_event = EventUpdateTeamEmissionRate {
            admin_cap: object::id(admin_cap),
            team_emission_rate,
        };
        sui::event::emit<EventUpdateTeamEmissionRate>(update_team_emission_rate_event);
    }

    public fun set_protocol_fee_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        protocol_fee_rate: u64
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESetProtocolFeeRateMinterPaused);
        assert!(protocol_fee_rate <= MAX_PROTOCOL_FEE_RATE, ESetProtocolFeeRateTooBigRate);
        minter.protocol_fee_rate = protocol_fee_rate;

        let update_protocol_fee_rate_event = EventUpdateProtocolFeeRate {
            admin_cap: object::id(admin_cap),
            protocol_fee_rate,
        };
        sui::event::emit<EventUpdateProtocolFeeRate>(update_protocol_fee_rate_event);
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
        distribution_config: &DistributionConfig,
        team_wallet: address
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESetTeamWalletMinterPaused);
        minter.team_wallet = team_wallet;

        let set_team_wallet_event = EventSetTeamWallet {
            admin_cap: object::id(admin_cap),
            team_wallet,
        };
        sui::event::emit<EventSetTeamWallet>(set_team_wallet_event);
    }

    /// Sets the protocol wallet address that will receive protocol fees.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `protocol_wallet` - Address of the protocol wallet
    public fun set_protocol_wallet<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        protocol_wallet: address
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.protocol_wallet = protocol_wallet;

        let set_protocol_wallet_event = EventSetProtocolWallet {
            admin_cap: object::id(admin_cap),
            protocol_wallet,
        };
        sui::event::emit<EventSetProtocolWallet>(set_protocol_wallet_event);
    }

    /// Sets the operations wallet address that will perform operations on behalf of the protocol.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `operations_wallet` - Address of the operations wallet
    public fun set_operations_wallet<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        operations_wallet: address
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.operations_wallet = operations_wallet;

        let set_operations_wallet_event = EventSetOperationsWallet {
            admin_cap: object::id(admin_cap),
            operations_wallet,
        };
        sui::event::emit<EventSetOperationsWallet>(set_operations_wallet_event);
    }

    fun deposit_protocol_fee<SailCoinType, ProtocolFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        protocol_fee: Balance<ProtocolFeeCoinType>,
    ) {
        // using deprecated type_name::get<TypeName> cos we already used it in this module, therefore
        // this bag already contains deprecated keys.
        let protocol_fee_coin_type = type_name::get<ProtocolFeeCoinType>();
        if (!minter.exercise_fee_protocol_balances.contains<TypeName>(protocol_fee_coin_type)) {
            minter.exercise_fee_protocol_balances.add(protocol_fee_coin_type, balance::zero<ProtocolFeeCoinType>());
        };
        let protocol_fee_balance = minter
            .exercise_fee_protocol_balances
            .borrow_mut<TypeName, Balance<ProtocolFeeCoinType>>(protocol_fee_coin_type);

        protocol_fee_balance.join(protocol_fee);
    }

    public fun distribute_protocol<SailCoinType, ProtocolFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        ctx: &mut TxContext,
    ) {
         distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDistributeProtocolMinterPaused);
        minter.check_admin(admin_cap);
        assert!(minter.protocol_wallet != @0x0, EDistributeProtocolWalletNotSet);

        let coin_type = type_name::get<ProtocolFeeCoinType>();
        assert!(minter.exercise_fee_protocol_balances.contains(coin_type), EDistributeProtocolTokenNotFound);
        let balance = minter.exercise_fee_protocol_balances.remove<TypeName, Balance<ProtocolFeeCoinType>>(coin_type);
        let amount = balance.value();
        transfer::public_transfer<Coin<ProtocolFeeCoinType>>(
            coin::from_balance(balance, ctx), 
            minter.protocol_wallet
        );

        let event = EventDistributeProtocol {
            protocol_wallet: minter.protocol_wallet,
            amount,
            token_type: coin_type,
        };
        sui::event::emit<EventDistributeProtocol>(event);
    }

    public fun distribute_operations<SailCoinType, ExerciseFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDistributeOperationsMinterPaused);
        minter.check_admin(admin_cap);
        assert!(minter.operations_wallet != @0x0, EDistributeOperationsWalletNotSet);

        let coin_type = type_name::get<ExerciseFeeCoinType>();
        assert!(minter.exercise_fee_operations_balances.contains(coin_type), EDistributeOperationsTokenNotFound);
        let balance = minter.exercise_fee_operations_balances.remove<TypeName, Balance<ExerciseFeeCoinType>>(coin_type);
        let amount = balance.value();
        transfer::public_transfer<Coin<ExerciseFeeCoinType>>(
            coin::from_balance(balance, ctx), 
            minter.operations_wallet
        );

        let event = EventDistributeOperations {
            operations_wallet: minter.operations_wallet,
            amount,
            token_type: coin_type,
        };
        sui::event::emit<EventDistributeOperations>(event);
    }


    /// Distributes the collected exercise fee directly to the voters via exercise fee reward.
    ///
    /// # Arguments
    /// * `minter` - The minter instance to modify
    /// * `admin_cap` - Administrative capability proving authorization
    /// * `distribution_config` - The distribution configuration
    /// * `amount` - The amount of exercise fee to distribute
    /// * `ctx` - The transaction context
    public fun distribute_exercise_fee_to_reward<SailCoinType, ExerciseFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDistributeExerciseFeeMinterPaused);
        minter.check_admin(admin_cap);

        let coin_type = type_name::get<ExerciseFeeCoinType>();
        let balance_mut = minter.exercise_fee_operations_balances.borrow_mut<TypeName, Balance<ExerciseFeeCoinType>>(coin_type);
        let reward_coin = coin::from_balance(balance_mut.split(amount), ctx);

        voter.notify_exercise_fee_reward_amount(
            minter.distribute_cap.borrow(),
            reward_coin,
            clock,
            ctx,
        );

        let event = EventDistributeExerciseFeeToReward {
            admin_cap_id: object::id(admin_cap),
            amount,
            token_type: coin_type,
        };
        sui::event::emit<EventDistributeExerciseFeeToReward>(event);
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
    public fun pause<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.paused = true;
        let pause_event = EventPauseEmission {};
        sui::event::emit<EventPauseEmission>(pause_event);
    }

    /// Unpauses token emissions from the minter.
    ///
    /// This function re-enables token emissions after they were paused.
    public fun unpause<SailCoinType>(
        minter: &mut Minter<SailCoinType>, 
        distribution_config: &DistributionConfig, 
        admin_cap: &AdminCap
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.paused = false;
        let unpaused_event = EventUnpauseEmission {};
        sui::event::emit<EventUnpauseEmission>(unpaused_event);
    }

    /// Stops emission due to oracle compromise.
    ///
    /// This is an emergency function that can be used to halt token emissions
    /// when the price oracle is compromised or provides incorrect data.
    public fun stop_emission<SailCoinType>(
        minter: &mut Minter<SailCoinType>, 
        distribution_config: &DistributionConfig, 
        admin_cap: &AdminCap
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.emission_stopped = true;

        sui::event::emit<EventStopEmission>(EventStopEmission {});
    }

    /// Resumes emission after oracle compromise is resolved.
    ///
    /// This function re-enables token emissions after they were stopped due to oracle issues.
    public fun resume_emission<SailCoinType>(
        minter: &mut Minter<SailCoinType>, 
        distribution_config: &DistributionConfig, 
        admin_cap: &AdminCap
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        minter.emission_stopped = false;

        sui::event::emit<EventResumeEmission>(EventResumeEmission {});
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
        minter.o_sail_minted_supply = minter.o_sail_minted_supply + treasury_cap.total_supply();
        minter.o_sail_caps.add(o_sail_type, treasury_cap);
        // oSAIL is distributed until the end of the active period, so we add extra epoch to the duration
        // as in some cases users will not be able to claim oSAIL until the end of the epoch.
        let o_sail_expiry_date = voting_escrow::common::current_period(clock) +
            voting_escrow::common::o_sail_duration() +
            voting_escrow::common::epoch();
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
    /// This function should be called once per epoch to maintain
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
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        epoch_o_sail_metadata: &CoinMetadata<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        assert!(epoch_o_sail_metadata.get_decimals() == voting_escrow::common::sail_decimals(), EUpdatePeriodOSailInvalidDecimals);
        minter.update_period_internal(
            voter,
            distribution_config,
            distribute_governor_cap,
            voting_escrow,
            rebase_distributor,
            epoch_o_sail_treasury_cap,
            clock,
            ctx,
        );
    }

    /// Test only method without metadata check as it is impossible to create metadata in test environment.
    #[test_only]
    public fun update_period_test<SailCoinType, EpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.update_period_internal(
            voter,
            distribution_config,
            distribute_governor_cap,
            voting_escrow,
            rebase_distributor,
            epoch_o_sail_treasury_cap,
            clock,
            ctx,
        );
    }

    fun update_period_internal<SailCoinType, EpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        rebase_distributor: &mut governance::rebase_distributor::RebaseDistributor<SailCoinType>,
        epoch_o_sail_treasury_cap: TreasuryCap<EpochOSail>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(!minter.is_paused(), EUpdatePeriodMinterPaused);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), EUpdatePeriodDistributionConfigInvalid);
        assert!(minter.is_active(clock), EUpdatePeriodMinterNotActive);
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(
            minter.active_period + voting_escrow::common::epoch() < current_time,
            EUpdatePeriodNotFinishedYet
        );
        assert!(minter.rebase_distributor_cap.is_some(), EUpdatePeriodNoRebaseDistributorCap);

        let prev_prev_epoch_emissions = minter.o_sail_epoch_emissions(distribution_config);
        minter.update_o_sail_token(epoch_o_sail_treasury_cap, clock);
        // rebase is disabled
        let rebase_growth = 0;
        let mut team_emissions = 0;
        if (minter.team_emission_rate > 0 && minter.team_wallet != @0x0) {
            team_emissions = integer_mate::full_math_u64::mul_div_floor(
                minter.team_emission_rate,
                rebase_growth + prev_prev_epoch_emissions,
                RATE_DENOM
            );
            transfer::public_transfer<Coin<SailCoinType>>(
                minter.mint_sail(team_emissions, ctx),
                minter.team_wallet
            );
        };
        let distribute_cap = minter.distribute_cap.borrow();
        voter.notify_epoch_token<EpochOSail>(distribute_cap, ctx);
        minter.active_period = voting_escrow::common::current_period(clock);
        let rebase_distributor_cap = minter.rebase_distributor_cap.borrow();
        rebase_distributor.update_active_period(
            rebase_distributor_cap,
            minter.active_period
        );
        let update_epoch_event = EventUpdateEpoch {
            new_period: minter.active_period,
            updated_at: current_time,
            prev_prev_epoch_o_sail_emissions: prev_prev_epoch_emissions,
            team_emissions,
            finished_epoch_growth_rebase: rebase_growth,
            epoch_o_sail_type: type_name::get<EpochOSail>(),
        };
        sui::event::emit<EventUpdateEpoch>(update_epoch_event);
    }


    /// Distributes oSAIL tokens to a gauge based on pool performance metrics.
    /// Distributes the next epoch's emissions. For new pools, uses base emissions.
    /// IMPORTANT: For all USD values we use 6 decimals.
    ///
    /// # Arguments
    /// * `minter` - The minter instance managing token emissions
    /// * `voter` - The voter instance managing gauge voting
    /// * `distribute_governor_cap` - Capability authorizing distribution
    /// * `distribution_config` - Configuration for token distribution
    /// * `gauge` - The gauge to distribute tokens to
    /// * `pool` - The pool associated with the gauge
    /// * `next_epoch_emissions_usd` - oSAIL usd valuation to be emitted for the next epoch, decimals 6
    /// * `price_monitor` - The price monitor to validate the price
    /// * `sail_stablecoin_pool` - The pool of SAIL token with a stablecoin
    /// * `aggregator` - The aggregator of oSAIL price to fetch the price from
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Aborts
    /// * If the gauge has already been distributed for the current period
    /// * If the gauge has no base supply
    /// * If pool metrics are invalid for non-initial epochs
    public fun distribute_gauge<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType, CurrentEpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribute_governor_cap: &DistributeGovernorCap,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        next_epoch_emissions_usd: u64,
        price_monitor: &mut PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDistributeGaugeMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_active(clock), EDistributeGaugeMinterNotActive);
        assert!(minter.is_valid_distribution_config(distribution_config), EDistributeGaugeDistributionConfigInvalid);
        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EExerciseOSailInvalidAggregator);

        assert!(type_name::get<SailPoolCoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<SailPoolCoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
            price_monitor,
            sail_stablecoin_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return;
        };
        
        minter.distribute_gauge_internal<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail>(
            voter,
            distribution_config,
            gauge,
            pool,
            next_epoch_emissions_usd,
            o_sail_price_q64,
            clock,
            ctx
        )
    }


    // we need this method if pool and sail_stablecoin_pool are the same pool
    public fun distribute_gauge_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribute_governor_cap: &DistributeGovernorCap,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        next_epoch_emissions_usd: u64,
        price_monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDistributeGaugeMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_active(clock), EDistributeGaugeMinterNotActive);
        assert!(minter.is_valid_distribution_config(distribution_config), EDistributeGaugeDistributionConfigInvalid);
        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EExerciseOSailInvalidAggregator);

        assert!(
            type_name::get<CoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<CoinTypeB>() == type_name::get<SailCoinType>(), 
            EInvalidSailPool
        );

        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<CoinTypeA, CoinTypeB, SailCoinType>(
            price_monitor,
            sail_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return;
        };

        minter.distribute_gauge_internal<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail>(
            voter,
            distribution_config,
            gauge,
            sail_pool,
            next_epoch_emissions_usd,
            o_sail_price_q64,
            clock,
            ctx
        )
    }

    fun distribute_gauge_internal<CoinTypeA, CoinTypeB, SailCoinType, CurrentEpochOSail>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        next_epoch_emissions_usd: u64,
        o_sail_price_q64: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        let current_epoch_o_sail_type = type_name::get<CurrentEpochOSail>();
        assert!(minter.current_epoch_o_sail.borrow() == current_epoch_o_sail_type, EDistributeGaugeInvalidToken);
        
        let gauge_id = object::id(gauge);
        assert!(
            !minter.gauge_active_period.contains(gauge_id) || *minter.gauge_active_period.borrow(gauge_id) < minter.active_period,
             EDistributeGaugeAlreadyDistributed
        );
        assert!(minter.gauge_epoch_emissions_usd.contains(gauge_id), EDistributeGaugePoolHasNoBaseSupply);
        let distribute_cap = minter.distribute_cap.borrow();
        distribute_cap.validate_distribute_voter_id(object::id<governance::voter::Voter>(voter));

        let gauge_epoch_count = if (minter.gauge_epoch_count.contains(gauge_id)) {
            minter.gauge_epoch_count.remove(gauge_id)
        } else {
            0
        };
        let prev_epoch_emissions_usd = minter.gauge_epoch_emissions_usd.remove(gauge_id);
        // indicates if this gauges was never distributed before
        let is_initial_epoch = gauge_epoch_count == 0;

        if (is_initial_epoch) {
            // for pools that are new there is no enough data.
            // This extra validation should make sure that our service handles such situations properly
            assert!(next_epoch_emissions_usd == prev_epoch_emissions_usd, EDistributeGaugeFirstEpochEmissionsInvalid);
        } else {
            assert!(next_epoch_emissions_usd > 0, EDistributeGaugeEmissionsZero);
            if (prev_epoch_emissions_usd > next_epoch_emissions_usd) {
                assert!(prev_epoch_emissions_usd <= minter.max_emission_change_ratio * next_epoch_emissions_usd, EDistributeGaugeEmissionsChangeTooBig);
            } else {
                assert!(next_epoch_emissions_usd <= minter.max_emission_change_ratio * prev_epoch_emissions_usd, EDistributeGaugeEmissionsChangeTooBig);
            }
        };
        let (mut fee_a, mut fee_b, ended_epoch_o_sail_emission) = voter.distribute_gauge<CoinTypeA, CoinTypeB, CurrentEpochOSail>(
            distribution_config,
            gauge,
            pool,
            next_epoch_emissions_usd,
            o_sail_price_q64,
            clock,
            ctx
        );
        let passive_fee_rate = minter.passive_voter_fee_rate();
        let passive_fee_amount_a = integer_mate::full_math_u64::mul_div_floor(fee_a.value(), passive_fee_rate, RATE_DENOM);
        let passive_fee_amount_b = integer_mate::full_math_u64::mul_div_floor(fee_b.value(), passive_fee_rate, RATE_DENOM);
        let passive_fee_a = fee_a.split(passive_fee_amount_a);
        let passive_fee_b = fee_b.split(passive_fee_amount_b);
        let active_voting_fee_a = fee_a.value();
        let active_voting_fee_b = fee_b.value();

        // redirect voting fees to active voters
        voter.inject_voting_fee_reward(distribute_cap, gauge_id, coin::from_balance<CoinTypeA>(fee_a, ctx), clock, ctx);
        voter.inject_voting_fee_reward(distribute_cap, gauge_id, coin::from_balance<CoinTypeB>(fee_b, ctx), clock, ctx);

        minter.deposit_passive_fee(passive_fee_a, ctx);
        minter.deposit_passive_fee(passive_fee_b, ctx);

        // update records related to gauge
        let prev_active_period = if (minter.gauge_active_period.contains(gauge_id)) {
            minter.gauge_active_period.remove(gauge_id)
        } else {
            0
        };
        if (prev_active_period > 0) {
            let total_o_sail_emissions = if (minter.total_epoch_o_sail_emissions.contains(prev_active_period)) {
                minter.total_epoch_o_sail_emissions.remove(prev_active_period)
            } else {
                0
            };
            minter.total_epoch_o_sail_emissions.add(prev_active_period, total_o_sail_emissions + ended_epoch_o_sail_emission);
        };
        minter.gauge_active_period.add(gauge_id, minter.active_period);
        minter.gauge_epoch_emissions_usd.add(gauge_id, next_epoch_emissions_usd);
        minter.gauge_epoch_count.add(gauge_id, gauge_epoch_count + 1);
        let total_epoch_emissions = if (minter.total_epoch_emissions_usd.contains(minter.active_period)) {
            minter.total_epoch_emissions_usd.remove(minter.active_period)
        } else {
            0
        };
        minter.total_epoch_emissions_usd.add(minter.active_period, total_epoch_emissions + next_epoch_emissions_usd);

        let pool_id = object::id(pool);
        let event = EventDistributeGauge {
            gauge_id,
            pool_id,
            o_sail_type: current_epoch_o_sail_type,
            next_epoch_emissions_usd,
            ended_epoch_o_sail_emission,
        };
        sui::event::emit<EventDistributeGauge>(event);
        let eventV2 = EventDistributeGaugeV2 {
            gauge_id,
            pool_id,
            o_sail_type: current_epoch_o_sail_type,
            next_epoch_emissions_usd,
            ended_epoch_o_sail_emission,
            active_voting_fee_a,
            active_voting_fee_b,
            passive_fee_a: passive_fee_amount_a,
            passive_fee_b: passive_fee_amount_b,
        };
        sui::event::emit<EventDistributeGaugeV2>(eventV2);
    }

    public fun gauge_distributed<SailCoinType>(
        minter: &Minter<SailCoinType>,
        gauge_id: ID,
    ): bool {
        let gauge_active_period = if (minter.gauge_active_period.contains(gauge_id)) {
            *minter.gauge_active_period.borrow(gauge_id)
        } else {
            0
        };

        if (gauge_active_period == 0 || minter.active_period > gauge_active_period) {
            return false
        };

        true
    }

    /// Increases the emissions of a gauge by a specified amount.
    /// This function is used to increase the emissions of a gauge when the pool performance metrics are higher than expected.
    /// 
    /// # Arguments
    /// * `minter` - The minter instance managing token emissions
    /// * `voter` - The voter instance managing gauge voting
    /// * `distribution_config` - Configuration for token distribution
    /// * `admin_cap` - Capability allowing token distribution
    /// * `gauge` - The gauge to increase emissions for
    /// * `pool` - The pool associated with the gauge
    /// * `emissions_increase_usd` - The amount of emissions to increase in USD. 6 decimals.
    /// * `price_monitor` - The price monitor to validate the price
    /// * `sail_stablecoin_pool` - The pool of SAIL token with a stablecoin
    /// * `aggregator` - The aggregator of oSAIL price to fetch the price from
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    public fun increase_gauge_emissions<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        emissions_increase_usd: u64,
        price_monitor: &mut PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), EIncreaseEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), EIncreaseEmissionsMinterNotActive);
        assert!(!minter.is_paused(), EIncreaseEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EIncreaseEmissionsInvalidAggregator);

        assert!(type_name::get<SailPoolCoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<SailPoolCoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
            price_monitor,
            sail_stablecoin_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return 
        };

        minter.increase_gauge_emissions_internal(
            voter,
            distribution_config,
            gauge,
            pool,
            emissions_increase_usd,
            o_sail_price_q64,
            clock,
            ctx
        );
    }

    /// we need this method if pool and sail_stablecoin_pool are the same pool
    public fun increase_gauge_emissions_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        emissions_increase_usd: u64,
        price_monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), EIncreaseEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), EIncreaseEmissionsMinterNotActive);
        assert!(!minter.is_paused(), EIncreaseEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EIncreaseEmissionsInvalidAggregator);

        assert!(
            type_name::get<CoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<CoinTypeB>() == type_name::get<SailCoinType>(), 
            EInvalidSailPool
        );
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<CoinTypeA, CoinTypeB, SailCoinType>(
            price_monitor,
            sail_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return
        };

        minter.increase_gauge_emissions_internal(
            voter,
            distribution_config,
            gauge,
            sail_pool,
            emissions_increase_usd,
            o_sail_price_q64,
            clock,
            ctx
        );
    }

    fun increase_gauge_emissions_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        emissions_increase_usd: u64,
        o_sail_price_q64: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let gauge_id = object::id(gauge);
        assert!(gauge_distributed(minter, gauge_id), EIncreaseEmissionsNotDistributed);

        let distribute_cap = minter.distribute_cap.borrow();
        distribute_cap.validate_distribute_voter_id(object::id<governance::voter::Voter>(voter));

        let old_gauge_epoch_emissions_usd = minter.gauge_epoch_emissions_usd.remove(gauge_id);
        minter.gauge_epoch_emissions_usd.add(gauge_id, old_gauge_epoch_emissions_usd + emissions_increase_usd);

        let old_total_epoch_emissions = minter.total_epoch_emissions_usd.remove(minter.active_period);
        minter.total_epoch_emissions_usd.add(minter.active_period, old_total_epoch_emissions + emissions_increase_usd);

        voter.notify_gauge_reward_without_claim(
            distribution_config,
            gauge,
            pool,
            emissions_increase_usd,
            o_sail_price_q64,
            clock,
            ctx
        );

        let event = EventIncreaseGaugeEmissions {
            gauge_id,
            pool_id: object::id(pool),
            emissions_increase_usd,
            o_sail_type: *minter.current_epoch_o_sail.borrow(),
        };

        sui::event::emit<EventIncreaseGaugeEmissions>(event);
    }

    public fun null_gauge_emissions<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_monitor: &mut PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ENullEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), ENullEmissionsMinterNotActive);
        assert!(!minter.is_paused(), ENullEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), ENullEmissionsInvalidAggregator);

        assert!(type_name::get<SailPoolCoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<SailPoolCoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
            price_monitor,
            sail_stablecoin_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return 
        };

        minter.null_gauge_emissions_internal(
            voter,
            distribution_config,
            gauge,
            pool,
            o_sail_price_q64,
            clock,
            ctx
        );
    }

    public fun null_gauge_emissions_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ENullEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), ENullEmissionsMinterNotActive);
        assert!(!minter.is_paused(), ENullEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), ENullEmissionsInvalidAggregator);

        assert!(type_name::get<CoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<CoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<CoinTypeA, CoinTypeB, SailCoinType>(
            price_monitor,
            sail_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return 
        };

        minter.null_gauge_emissions_internal(
            voter,
            distribution_config,
            gauge,
            sail_pool,
            o_sail_price_q64,
            clock,
            ctx
        );
    }

    fun null_gauge_emissions_internal<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &governance::voter::Voter,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        o_sail_price_q64: u128,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let gauge_id = object::id(gauge);
        assert!(gauge_distributed(minter, gauge_id), ENullGaugeEmissionsNotDistributed);

        let distribute_cap = minter.distribute_cap.borrow();
        distribute_cap.validate_distribute_voter_id(object::id<governance::voter::Voter>(voter));

        let delta_usd = voter.null_gauge_rewards(
            distribution_config,
            gauge,
            pool,
            o_sail_price_q64,
            clock,
            ctx
        );

        let old_gauge_epoch_emissions_usd = minter.gauge_epoch_emissions_usd.remove(gauge_id);
        assert!(old_gauge_epoch_emissions_usd >= delta_usd, ENullGaugeEmissionsDeltaTooBigForGauge);
        let new_gauge_epoch_emissions_usd = old_gauge_epoch_emissions_usd - delta_usd;
        minter.gauge_epoch_emissions_usd.add(gauge_id, new_gauge_epoch_emissions_usd);

        let old_total_epoch_emissions_usd = minter.total_epoch_emissions_usd.remove(minter.active_period);
        assert!(old_total_epoch_emissions_usd >= delta_usd, ENullGaugeEmissionsDeltaTooBigForTotal);
        let new_total_epoch_emissions_usd = old_total_epoch_emissions_usd - delta_usd;
        minter.total_epoch_emissions_usd.add(minter.active_period, new_total_epoch_emissions_usd);

        let event = EventNullGaugeEmissions {
            gauge_id,
            pool_id: object::id(pool),
            rewards_nulled_usd: delta_usd,
            new_gauge_epoch_emissions_usd,
            new_total_epoch_emissions_usd,
        };
        sui::event::emit<EventNullGaugeEmissions>(event);
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
    /// * `gauge_base_emissions` - Base amount of usd to be emitted per epoch. 6 decimals.
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// A new gauge instance for the specified pool
    public fun create_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &mut DistributionConfig,
        create_cap: &gauge_cap::gauge_cap::CreateCap,
        admin_cap: &AdminCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): governance::gauge::Gauge<CoinTypeA, CoinTypeB> {
        distribution_config.checked_package_version();
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
        minter.gauge_epoch_emissions_usd.add(gauge_id, gauge_base_emissions);

        let event = EventGaugeCreated {
            id: gauge_id,
            pool_id: object::id(pool),
            base_emissions: gauge_base_emissions,
        };
        sui::event::emit<EventGaugeCreated>(event);
        
        gauge
    }

    /// Deprecated. Use kill_gauge_v2 instead.
    public fun kill_gauge<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        emergency_council_cap: &voting_escrow::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        abort 0
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
    public fun kill_gauge_v2<SailCoinType, CoinTypeA, CoinTypeB>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(gauge.check_gauger_pool(pool), EKillGaugeGaugeDoesNotMatchPool);
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EKillGaugeDistributionConfigInvalid
        );
        let gauge_id = object::id(gauge);
        assert!(
            distribution_config.is_gauge_alive(gauge_id),
            EKillGaugeAlreadyKilled
        );
        // paused gauges are not allowed to be killed cos pause means an emergency situation.
        assert!(
            !distribution_config.is_gauge_paused(gauge_id),
            EKillGaugeAlreadyPaused
        );
        let unstaked_liquidity_fee_rate = pool.unstaked_liquidity_fee_rate(); 
        // check unstaked fee rate to prevent us from forgetting to set it to zero when killing a gauge.
        assert!(
            unstaked_liquidity_fee_rate == 0 || unstaked_liquidity_fee_rate == clmm_pool::config::default_unstaked_fee_rate(),
            EKillGaugeUnstakedFeeRateNotZero
        );
        distribution_config.update_gauge_liveness(vector<ID>[gauge_id], false);
        let kill_gauge_event = EventKillGauge { id: gauge_id };
        sui::event::emit<EventKillGauge>(kill_gauge_event);
    }

    /// Pauses a gauge temporarily. Disables all interactions with the gauge.
    /// Supposed to be used in emergency situations when a gauge needs to be disabled.
    ///
    /// # Arguments
    /// * `minter` - The minter instance (used for authorization)
    /// * `distribution_config` - The distribution configuration
    /// * `emergency_council_cap` - The emergency council capability
    /// * `gauge_id` - The ID of the gauge to pause
    public fun pause_gauge<SailCoinType>(
        minter: &Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        emergency_council_cap: &voting_escrow::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        distribution_config.checked_package_version();
        emergency_council_cap.validate_emergency_council_minter_id(object::id(minter));
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EPauseGaugeDistributionConfigInvalid
        );
        assert!(
            !distribution_config.is_gauge_paused(gauge_id),
            EPauseGaugeAlreadyPaused
        );
        distribution_config.pause_gauge(gauge_id);
        let pause_gauge_event = EventPauseGauge { id: gauge_id };
        sui::event::emit<EventPauseGauge>(pause_gauge_event);
    }

    /// Unpauses a previously paused gauge.
    /// Only the emergency council can perform this operation.
    ///
    /// # Arguments
    /// * `minter` - The minter instance (used for authorization)
    /// * `distribution_config` - The distribution configuration
    /// * `emergency_council_cap` - The emergency council capability
    /// * `gauge_id` - The ID of the gauge to unpause
    public fun unpause_gauge<SailCoinType>(
        minter: &Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        emergency_council_cap: &voting_escrow::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        distribution_config.checked_package_version();
        emergency_council_cap.validate_emergency_council_minter_id(object::id(minter));
        assert!(
            minter.is_valid_distribution_config(distribution_config),
            EUnpauseGaugeDistributionConfigInvalid
        );
        assert!(
            distribution_config.is_gauge_paused(gauge_id),
            EUnpauseGaugeNotPaused
        );
        distribution_config.unpause_gauge(gauge_id);
        let unpause_gauge_event = EventUnpauseGauge { id: gauge_id };
        sui::event::emit<EventUnpauseGauge>(unpause_gauge_event);
    }

    /// Supposed to be called instead of distribute_gauge for killed gauges.
    /// Claims fees from a killed gauge redirecting them to the fee voting rewards.
    /// Synchronizes the oSAIL distribution end and o_sail emission counters for the gauge.
    /// Can be called multiple times cos remaining staked positions are still generating fees.
    ///
    /// # Arguments
    /// * `minter` - The minter instance managing token emissions
    /// * `distribution_config` - Configuration for token distribution
    /// * `emergency_council_cap` - The emergency council capability for authorization
    /// * `gauge` - The killed gauge to settle
    /// * `pool` - The pool associated with the gauge
    /// * `price_monitor` - The price monitor to validate the price
    /// * `sail_stablecoin_pool` - The pool of SAIL token with a stablecoin
    /// * `aggregator` - The aggregator of oSAIL price to fetch the price from
    /// * `clock` - The system clock
    public fun settle_killed_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        clock: &sui::clock::Clock
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESettleKilledGaugeMinterPaused);
        assert!(minter.is_active(clock), ESettleKilledGaugeMinterNotActive);
        assert!(minter.is_valid_distribution_config(distribution_config), ESettleKilledGaugeDistributionConfigInvalid);
        assert!(!distribution_config.is_gauge_alive(object::id(gauge)), ESettleKilledGaugeGaugeNotKilled);
        // paused gauges are not allowed to be settled cos pause means an emergency situation.
        assert!(!distribution_config.is_gauge_paused(object::id(gauge)), ESettleKilledGaugeGaugePaused);

        let gauge_id = object::id(gauge);
        assert!(
            !minter.gauge_active_period.contains(gauge_id) || *minter.gauge_active_period.borrow(gauge_id) < minter.active_period,
             ESettleKilledGaugeAlreadyDistributed
        );

        let pool_id = object::id(pool);
        let distribute_cap = minter.distribute_cap.borrow();

        // Claim fees from the killed gauge
        let (fee_a, fee_b) = gauge.claim_fees(distribute_cap, pool);
        let fee_a_amount = fee_a.value();
        let fee_b_amount = fee_b.value();

        minter.deposit_protocol_fee(fee_a);
        minter.deposit_protocol_fee(fee_b);

        // Sync the oSAIL distribution price to update emissions accounting
        let ended_epoch_o_sail_emission = gauge.sync_o_sail_distribution_finish(
            pool,
            clock
        );

        let prev_active_period = if (minter.gauge_active_period.contains(gauge_id)) {
            minter.gauge_active_period.remove(gauge_id)
        } else {
            0
        };

        // only works for the first call of this function for the gauge
        // next time prev active period is zero and total emissions already updated
        if (prev_active_period > 0) {
            let total_o_sail_emissions = if (minter.total_epoch_o_sail_emissions.contains(prev_active_period)) {
                minter.total_epoch_o_sail_emissions.remove(prev_active_period)
            } else {
                0
            };
            minter.total_epoch_o_sail_emissions.add(prev_active_period, total_o_sail_emissions + ended_epoch_o_sail_emission);
        };

        let event = EventSettleKilledGauge {
            gauge_id,
            pool_id,
            fee_a_amount,
            fee_b_amount,
            ended_epoch_o_sail_emission,
        };
        sui::event::emit<EventSettleKilledGauge>(event);
    }


    /// Deprecated. Use reset_gauge_v2 instead.
    public fun revive_gauge<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        emergency_council_cap: &voting_escrow::emergency_council::EmergencyCouncilCap,
        gauge_id: ID,
    ) {
        // there is no reason to revive a gauge that was killed in the same epoch.
        // In case of emergency you are supposed to pause the gauge and unpause it once the emergency situation is over.
        abort 0
    }

    fun revive_gauge_internal(
        distribution_config: &mut DistributionConfig,
        gauge_id: ID,
    ) {
        distribution_config.update_gauge_liveness(vector<ID>[gauge_id], true);
        let revieve_gauge_event = EventReviveGauge { id: gauge_id };
        sui::event::emit<EventReviveGauge>(revieve_gauge_event);
    }

    /// Deprecated. Use reset_gauge_v2 instead.
    public fun reset_gauge<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        emergency_council_cap: &voting_escrow::emergency_council::EmergencyCouncilCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock
    ) {
        abort 0;
    }

    // Emergency function to reset a gauge to bootstrap it again.
    // Used when we were not able to revive the gauge in the same epoch it was killed.
    // This function will reset the gauge to the base emissions and start distributing oSAIL again.
    // 
    // # Arguments
    // * `minter` - The minter instance managing token emissions
    // * `voter` - The voter instance managing gauge voting
    // * `distribution_config` - Configuration for token distribution
    public fun reset_gauge_v2<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        gauge_base_emissions: u64,
        clock: &sui::clock::Clock
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
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
        assert!(!distribution_config.is_gauge_paused(gauge_id), EResetGaugeGaugePaused);

        // gauge should not be distributed this epoch
        // There is no reason to revive a gauge that was killed in the same epoch.
        // In case of emergency you are supposed to pause the gauge and unpause it once the emergency situation is over.
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
        if (minter.gauge_epoch_emissions_usd.contains(gauge_id)) {
            minter.gauge_epoch_emissions_usd.remove(gauge_id);
        };
        minter.gauge_epoch_emissions_usd.add(gauge_id, gauge_base_emissions);

        revive_gauge_internal(distribution_config, gauge_id);

        let reset_gauge_event = EventResetGauge {
            id: gauge_id,
            gauge_base_emissions,
        };
        sui::event::emit<EventResetGauge>(reset_gauge_event);
    }


    /// Syncs the oSAIL distribution price for a gauge.
    /// This function will validate the price and sync the oSAIL distribution price for the gauge.
    /// If the price is invalid, it will stop the emission.
    /// 
    /// # Arguments 
    /// * `minter` - The minter instance managing token emissions
    /// * `distribution_config` - Configuration for token distribution
    /// * `gauge` - The gauge to sync the oSAIL distribution price for
    /// * `pool` - The pool associated with the gauge
    /// * `price_monitor` - The price monitor to validate the price
    /// * `sail_stablecoin_pool` - The pool of SAIL token with a stablecoin
    /// * `aggregator` - The aggregator of oSAIL price to fetch the price from
    /// * `clock` - The system clock
    public fun sync_o_sail_distribution_price<CoinTypeA, CoinTypeB, SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_monitor: &mut PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock
    ) {
        distribution_config.checked_package_version();
        let gauge_id = object::id(gauge);
        assert!(gauge_distributed(minter, gauge_id), EIncreaseEmissionsNotDistributed);
        assert!(minter.is_valid_distribution_config(distribution_config), EIncreaseEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), EIncreaseEmissionsMinterNotActive);
        assert!(!minter.is_paused(), EIncreaseEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EExerciseOSailInvalidAggregator);

        assert!(type_name::get<SailPoolCoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<SailPoolCoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType>(
            price_monitor,
            sail_stablecoin_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return
        };

        gauge.sync_o_sail_distribution_price(
            distribution_config,
            pool,
            o_sail_price_q64,
            clock
        );
    }

    /// we need this method if pool and sail_stablecoin_pool are the same pool
    public fun sync_o_sail_distribution_price_for_sail_pool<CoinTypeA, CoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &mut DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        sail_pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        price_monitor: &mut PriceMonitor,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock
    ) {
        distribution_config.checked_package_version();
        let gauge_id = object::id(gauge);
        assert!(gauge_distributed(minter, gauge_id), EIncreaseEmissionsNotDistributed);
        assert!(minter.is_valid_distribution_config(distribution_config), EIncreaseEmissionsDistributionConfigInvalid);
        assert!(minter.is_active(clock), EIncreaseEmissionsMinterNotActive);
        assert!(!minter.is_paused(), EIncreaseEmissionsMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);

        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EExerciseOSailInvalidAggregator);

        assert!(
            type_name::get<CoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<CoinTypeB>() == type_name::get<SailCoinType>(), 
            EInvalidSailPool
        );
        
        let (o_sail_price_q64, is_price_invalid) = minter.get_aggregator_price_without_decimals<CoinTypeA, CoinTypeB, SailCoinType>(
            price_monitor,
            sail_pool,
            aggregator,
            clock
        );

        if (is_price_invalid) {
            return
        };

        gauge.sync_o_sail_distribution_price(
            distribution_config,
            sail_pool,
            o_sail_price_q64,
            clock
        );
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

        minter.current_epoch_o_sail.is_some() && *minter.borrow_current_epoch_o_sail() == o_sail_type
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
        minter.o_sail_minted_supply = minter.o_sail_minted_supply + amount;
        let cap = minter.borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>();

        let event = EventMint {
            amount,
            token_type: type_name::get<OSailCoinType>(),
            is_osail: true,
        };
        sui::event::emit<EventMint>(event);

        cap.mint(amount, ctx)
    }

    /// Burning function
    fun burn_o_sail<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        coin: Coin<OSailCoinType>,
    ): u64 {
        assert!(!minter.is_paused(), EBurnOSailMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EBurnOSailInvalidOSail);

        let cap = minter.borrow_mut_o_sail_cap<SailCoinType, OSailCoinType>();
        let burnt = cap.burn(coin);
        minter.o_sail_minted_supply = minter.o_sail_minted_supply - burnt;

        let event = EventBurn {
            amount: burnt,
            token_type: type_name::get<OSailCoinType>(),
            is_osail: true,
        };
        sui::event::emit<EventBurn>(event);

        burnt
    }

    // internal mint function
    fun mint_sail<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<SailCoinType> {
        let cap = minter.sail_cap.borrow_mut();

        let event = EventMint {
            amount,
            token_type: type_name::get<SailCoinType>(),
            is_osail: false,
        };
        sui::event::emit<EventMint>(event);

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
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &DistributionConfig,
        o_sail: sui::coin::Coin<OSailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), ECreateLockFromOSailMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), ECreateLockFromOSailInvalidToken);
        let lock_duration_seconds = lock_duration_days * voting_escrow::common::day();
        let o_sail_type = type_name::get<OSailCoinType>();
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = voting_escrow::common::current_timestamp(clock);
        let o_sail_expired = current_time >= expiry_date;

        // locking for any duration less than permanent
        let mut valid_duration = false;
        if (o_sail_expired) {
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
            voting_escrow::common::persent_denominator()
        } else {
            let max_extra_percents = voting_escrow::common::persent_denominator() - voting_escrow::common::o_sail_discount();
            voting_escrow::common::o_sail_discount() + integer_mate::full_math_u64::mul_div_floor(
                lock_duration_seconds,
                max_extra_percents,
                voting_escrow::common::max_lock_time()
            )
        };

        let o_sail_amount_in = o_sail.value();
        let sail_to_lock = minter.exercise_o_sail_free_internal(o_sail, percent_to_receive, clock, ctx);
        let sail_amount_to_lock = sail_to_lock.value();

        voting_escrow.create_lock<SailCoinType>(
            sail_to_lock,
            lock_duration_days,
            permanent,
            clock,
            ctx
        );

        let event = EventCreateLockFromOSail {
            o_sail_amount_in,
            o_sail_type,
            sail_amount_to_lock,
            o_sail_expired,
            duration: lock_duration_days,
            permanent,
        };
        sui::event::emit<EventCreateLockFromOSail>(event);
    }

    public fun deposit_o_sail_into_lock<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voting_escrow: &mut voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &DistributionConfig,
        lock: &mut voting_escrow::voting_escrow::Lock,
        o_sail: Coin<OSailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EDepositOSailMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EDepositOSailInvalidToken);

        let lock_id = object::id(lock);

        let (locked_balance, exist) = voting_escrow.locked(lock_id);
        assert!(exist, EDepositOSailBalanceNotExist);

        // it only makes sense to deposit oSAIL into a permanent lock.
        // Other locks are valid only for 1 second, cos they have exactly 6 or 24 mounths left for 1 second.
        assert!(locked_balance.is_permanent(), EDepositOSailLockNotPermanent);

        // permanent locks provide 100% conversion of oSAIL to SAIL
        let percent_to_receive = voting_escrow::common::persent_denominator();

        let o_sail_amount_in = o_sail.value();
        assert!(o_sail_amount_in > 0, EDepositOSailZeroAmount);
        
        let sail_to_lock = minter.exercise_o_sail_free_internal(o_sail, percent_to_receive, clock, ctx);
        let sail_amount_to_lock = sail_to_lock.value();

        voting_escrow.deposit_for(lock, sail_to_lock, clock, ctx);

        let event = EventDepositOSailIntoLock {
            o_sail_amount_in,
            o_sail_type: type_name::get<OSailCoinType>(),
            sail_amount_to_lock,
            lock_id,
        };

        sui::event::emit<EventDepositOSailIntoLock>(event);
    }

    // method that burns oSAIL and mints SAIL
    fun exercise_o_sail_free_internal<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        o_sail: Coin<OSailCoinType>,
        percent_to_receive: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        assert!(percent_to_receive <= voting_escrow::common::persent_denominator(), EExerciseOSailFreeTooBigPercent);

        let o_sail_amount = o_sail.value();

        let sail_amount_to_receive = integer_mate::full_math_u64::mul_div_floor(
            o_sail_amount,
            percent_to_receive,
            voting_escrow::common::persent_denominator()
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

    /// Exercises oSAIL and pays for it in USD. You are only allowed to exercise oSAIL until the expiration date.
    /// The price is determined by the price aggregator. You pay 50% in USD of the SAIL value you receive.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `distribution_config` - The distribution config instance
    /// * `voter` - The voter instance
    /// * `o_sail` - The oSAIL coin to exercise
    /// * `fee` - The fee coin to pay for the exercise. This is the fee that is paid to the team wallet.
    /// * `usd_amount_limit` - The maximum amount of USD that can be paid for the exercise.
    /// * `price_monitor` - The price monitor to validate the price
    /// * `sail_stablecoin_pool` - The pool of SAIL token with a stablecoin
    /// * `metadata` - The metadata of the stablecoin in sail_stablecoin_pool
    /// * `aggregator` - The aggregator of SAIL price to fetch the price from
    /// * `clock` - The clock instance
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// * `(usd_left, sail_received)` - The unused USD and the amount of SAIL received
    public fun exercise_o_sail<SailPoolCoinTypeA, SailPoolCoinTypeB, SailCoinType, USDCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        voter: &mut governance::voter::Voter,
        o_sail: Coin<OSailCoinType>,
        fee: Coin<USDCoinType>,
        metadata: &CoinMetadata<USDCoinType>,
        usd_amount_limit: u64,
        price_monitor: &mut PriceMonitor,
        sail_stablecoin_pool: &clmm_pool::pool::Pool<SailPoolCoinTypeA, SailPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<USDCoinType>, Coin<SailCoinType>) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EExerciseOSailMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExerciseOSailInvalidOSail);
        let o_sail_type = type_name::get<OSailCoinType>();
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(current_time < expiry_date, EExerciseOSailExpired);
        // check distribution config
        assert!(minter.is_valid_distribution_config(distribution_config), EExerciseOSailInvalidDistrConfig);
        assert!(distribution_config.is_valid_sail_price_aggregator(aggregator), EExerciseOSailInvalidAggregator);
        assert!(minter.is_whitelisted_usd<SailCoinType, USDCoinType>(), EExerciseOSailInvalidUsd);

        assert!(type_name::get<SailPoolCoinTypeA>() == type_name::get<SailCoinType>() || 
            type_name::get<SailPoolCoinTypeB>() == type_name::get<SailCoinType>(), EInvalidSailPool);

        let (o_sail_price_q64_decimals, is_price_invalid) = minter.get_aggregator_price<SailPoolCoinTypeA, SailPoolCoinTypeB, USDCoinType, SailCoinType>(
            price_monitor,
            sail_stablecoin_pool,
            metadata,
            aggregator,
            clock
        );


        if (is_price_invalid) {
            transfer::public_transfer<Coin<OSailCoinType>>(
                o_sail, 
                ctx.sender()
            );

            return (fee, coin::zero<SailCoinType>(ctx))
        };

        // there is a possibility that different discount percents will be implemented
        let discount_percent = voting_escrow::common::o_sail_discount();

        let usd_amount_to_pay = exercise_o_sail_calc<OSailCoinType>(
            &o_sail,
            discount_percent,
            o_sail_price_q64_decimals,
        );

        assert!(fee.value() >= usd_amount_limit, EExerciseUsdLimitHigherThanOSail);
        assert!(usd_amount_limit >= usd_amount_to_pay, EExerciseUsdLimitReached);

        exercise_o_sail_process_payment(
            minter,
            voter,
            o_sail,
            fee,
            usd_amount_to_pay,
            clock,
            ctx,
        )
    }

    public fun exercise_o_sail_free<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        o_sail: Coin<OSailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EExerciseOSailMinterPaused);
        assert!(!minter.is_emission_stopped(), EEmissionStopped);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExerciseOSailInvalidOSail);
        let o_sail_type = type_name::get<OSailCoinType>();
        let expiry_date: u64 = *minter.o_sail_expiry_dates.borrow(o_sail_type);
        let current_time = voting_escrow::common::current_timestamp(clock);
        assert!(current_time < expiry_date, EExerciseOSailExpired);
        // check distribution config
        assert!(minter.is_valid_distribution_config(distribution_config), EExerciseOSailInvalidDistrConfig);

        // the amount of oSAIL to receive for free
        let percent_to_receive = voting_escrow::common::o_sail_discount();

        let o_sail_amount_in = o_sail.value();
        let sail_out = exercise_o_sail_free_internal(minter, o_sail, percent_to_receive, clock, ctx);

        let event = EventExerciseOSailFree {
            o_sail_amount_in,
            sail_amount_out: sail_out.value(),
            o_sail_type,
        };
        sui::event::emit<EventExerciseOSailFree>(event);

        sail_out
    }

    /// withdraws SAIL from storage and burns oSAIL
    fun exercise_o_sail_process_payment<SailCoinType, USDCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        o_sail: Coin<OSailCoinType>,
        mut usd_in: Coin<USDCoinType>,
        usd_amount_in: u64,
        clock:  &sui::clock::Clock,
        ctx: &mut TxContext,
    ): (Coin<USDCoinType>, Coin<SailCoinType>) {
        let sail_amount_out = o_sail.value();
        let mut usd_to_pay = usd_in.split(usd_amount_in, ctx);
        let usd_coin_type = type_name::get<USDCoinType>();

        let mut protocol_fee_amount = 0;
        if (minter.protocol_fee_rate > 0) {
            protocol_fee_amount = integer_mate::full_math_u64::mul_div_floor(
                usd_to_pay.value(),
                minter.protocol_fee_rate,
                RATE_DENOM,
            );
            let protocol_fee = usd_to_pay.split(protocol_fee_amount, ctx);
            minter.deposit_protocol_fee(protocol_fee.into_balance());
        };
        
        let fee_to_distribute = usd_to_pay.value();
        if (!minter.exercise_fee_operations_balances.contains<TypeName>(usd_coin_type)) {
            minter.exercise_fee_operations_balances.add(usd_coin_type, balance::zero<USDCoinType>());
        };
        let operations_fee_balance = minter
            .exercise_fee_operations_balances
            .borrow_mut<TypeName, Balance<USDCoinType>>(usd_coin_type);
        operations_fee_balance.join(usd_to_pay.into_balance());

        minter.burn_o_sail(o_sail);
        let sail_out = minter.mint_sail(sail_amount_out, ctx);

        let event = EventExerciseOSail {
            o_sail_amount_in: sail_amount_out,
            sail_amount_out: sail_amount_out,
            o_sail_type: type_name::get<OSailCoinType>(),
            exercise_fee_token_type: type_name::get<USDCoinType>(),
            exercise_fee_amount: usd_amount_in,
            protocol_fee_amount,
            fee_to_distribute,
        };
        sui::event::emit<EventExerciseOSail>(event);

        // remaining usd and sail
        (usd_in, sail_out)
    }

    /// Function that calculates amount of usd to be deducted from user.
    public fun exercise_o_sail_calc<OSailCoinType>(
        o_sail: &Coin<OSailCoinType>,
        discount_percent: u64,
        sail_price_q64: u128,
    ): u64 {
        let o_sail_amount = o_sail.value();
        let o_sail_amount_q64 = (o_sail_amount as u128) << 64;
        let pay_for_percent = voting_escrow::common::persent_denominator() - discount_percent;
        // round up amount to pay for to avoid rounding abuse
        let sail_amount_to_pay_for_q64 = integer_mate::full_math_u128::mul_div_ceil(
            pay_for_percent as u128,
            o_sail_amount_q64,
            voting_escrow::common::persent_denominator() as u128
        );
        let usd_amount_to_pay_q64 = voting_escrow::common::asset_q64_to_usd_q64(
            sail_amount_to_pay_for_q64,
            sail_price_q64,
            true, // round up payment to avoid rounding abuse
        );
        // round up to avoid rounding abuse
        let usd_amount_to_pay = integer_mate::math_u128::checked_div_round(usd_amount_to_pay_q64, 1<<64, true) as u64;

        usd_amount_to_pay
    }

    /// Gets total usd emissions approximation for last distributed epoch
    public fun usd_epoch_emissions<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        let active_period = minter.active_period;
        minter.usd_emissions_by_epoch(active_period)
    }

    /// Gets usd emissions for a specific epoch
    /// Returns 0 if the epoch is not found
    public fun usd_emissions_by_epoch<SailCoinType>(minter: &Minter<SailCoinType>, epoch_start: u64): u64 {
        if (minter.total_epoch_emissions_usd.contains(epoch_start)) {
            *minter.total_epoch_emissions_usd.borrow(epoch_start)
        } else {
            0
        }
    }

    /// Returns oSAIL emissions for the previous epoch.
    /// Emissions for the current epoch are not available until the next epoch begins and all gauges in the next epoch are distributed.
    public fun o_sail_epoch_emissions<SailCoinType>(
        minter: &Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
    ): u64 {
        let active_period = minter.active_period;
        let prev_active_period = active_period - voting_escrow::common::epoch();
        minter.o_sail_emissions_by_epoch(prev_active_period)
    }

    /// Preferably use o_sail_epoch_emissions instead.
    /// Returns oSAIL emissions for a specific epoch.
    /// IMPORTANT:You can get emissions from previous epoch once all gauges in the current epoch are distributed
    public fun o_sail_emissions_by_epoch<SailCoinType>(minter: &Minter<SailCoinType>, epoch_start: u64): u64 {
        if (minter.total_epoch_o_sail_emissions.contains(epoch_start)) {
            *minter.total_epoch_o_sail_emissions.borrow(epoch_start)
        } else {
            0
        }
    }

    /// Returns the table of epoch emissions for each pool. These emissions are valid for last distributed epoch
    /// or will be distributed in initial epoch.
    public fun borrow_pool_epoch_emissions_usd<SailCoinType>(minter: &Minter<SailCoinType>): &Table<ID, u64> {
        &minter.gauge_epoch_emissions_usd
    }

    public fun gauge_epoch_emissions_usd<SailCoinType>(minter: &Minter<SailCoinType>, gauge_id: ID): u64 {
        *minter.gauge_epoch_emissions_usd.borrow(gauge_id)
    }

    // Allows USD to be used as exercise fee token
    public fun whitelist_usd<SailCoinType, UsdCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        admin_cap: &AdminCap,
        list: bool,
    ) {
        distribution_config.checked_package_version();
        minter.whitelist_usd_internal<SailCoinType, UsdCoinType>(
            admin_cap,
            list,
        );
    }

    fun whitelist_usd_internal<SailCoinType, UsdCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        list: bool,
    ) {
        assert!(!minter.is_paused(), EWhitelistPoolMinterPaused);
        minter.check_admin(admin_cap);

        let usd_type = type_name::get<UsdCoinType>();

        if (minter.whitelisted_usd.contains(&usd_type)) {
            if (!list) {
                minter.whitelisted_usd.remove(&usd_type)
            }
        } else {
            if (list) {
                minter.whitelisted_usd.insert(usd_type)
            };
        };

        let event = EventWhitelistUSD {
            usd_type,
            whitelisted: list,
        };
        sui::event::emit<EventWhitelistUSD>(event);
    }

    public fun is_whitelisted_usd<SailCoinType, UsdCoinType>(
        minter: &Minter<SailCoinType>,
    ): bool {
        let usd_type = type_name::get<UsdCoinType>();
        minter.whitelisted_usd.contains(&usd_type)
    }

    public fun borrow_whitelisted_usd<SailCoinType>(
        minter: &Minter<SailCoinType>,
    ): &VecSet<TypeName> {
        &minter.whitelisted_usd
    }

    public fun schedule_sail_mint<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        publisher: &mut sui::package::Publisher,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): TimeLockedSailMint {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<MINTER>(), EScheduleSailMintPublisherInvalid);
        assert!(!minter.is_paused(), EScheduleSailMintMinterPaused);
        assert!(amount > 0, EScheduleSailMintAmountZero);
        
        let id = object::new(ctx);
        let unlock_time = clock.timestamp_ms() + MINT_LOCK_TIME_MS;
        let event = EventScheduleTimeLockedMint {
            amount,
            unlock_time,
            is_osail: false,
            token_type: type_name::get<SailCoinType>(),
        };
        sui::event::emit<EventScheduleTimeLockedMint>(event);

        TimeLockedSailMint {
            id,
            amount,
            unlock_time,
        }
    }

    public fun execute_sail_mint<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        mint: TimeLockedSailMint,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<SailCoinType> {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EExecuteSailMintMinterPaused);
        let TimeLockedSailMint {id, amount, unlock_time} = mint;
        object::delete(id);

        assert!(unlock_time <= clock.timestamp_ms(), EExecuteSailMintStillLocked);

        minter.mint_sail(amount, ctx)
    }

    public fun cancel_sail_mint<SailCoinType>(
        _: &Minter<SailCoinType>, // minter is needed to make sure the coin type is valid
        mint: TimeLockedSailMint,
    ) {
        let TimeLockedSailMint {id, amount, unlock_time: _} = mint;
        let inner_id = id.uid_to_inner();
        let event = EventCancelTimeLockedMint {
            id: inner_id,
            amount,
            token_type: type_name::get<SailCoinType>(),
            is_osail: false,
        };
        sui::event::emit<EventCancelTimeLockedMint>(event);
        object::delete(id);
    }

    public fun schedule_o_sail_mint<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        publisher: &mut sui::package::Publisher,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): TimeLockedOSailMint<OSailCoinType> {
        distribution_config.checked_package_version();
        assert!(publisher.from_module<MINTER>(), EScheduleOSailMintPublisherInvalid);
        assert!(!minter.is_paused(), EScheduleOSailMintMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EScheduleOSailMintInvalidOSail);
        assert!(amount > 0, EScheduleOSailMintAmountZero);

        let id = object::new(ctx);
        let unlock_time = clock.timestamp_ms() + MINT_LOCK_TIME_MS;
        let event = EventScheduleTimeLockedMint {
            amount,
            unlock_time,
            is_osail: true,
            token_type: type_name::get<OSailCoinType>(),
        };
        sui::event::emit<EventScheduleTimeLockedMint>(event);

        TimeLockedOSailMint<OSailCoinType> {
            id,
            amount,
            unlock_time,
        }
    }

    public fun execute_o_sail_mint<SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        mint: TimeLockedOSailMint<OSailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): Coin<OSailCoinType> {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EExecuteOSailMintMinterPaused);
        assert!(minter.is_valid_o_sail_type<SailCoinType, OSailCoinType>(), EExecuteOSailMintInvalidOSail);
        let TimeLockedOSailMint {id, amount, unlock_time} = mint;
        object::delete(id);

        assert!(unlock_time <= clock.timestamp_ms(), EExecuteOSailMintStillLocked);

        minter.mint_o_sail<SailCoinType, OSailCoinType>(amount, ctx)
    }

    public fun cancel_o_sail_mint<OSailCoinType>(
        distribution_config: &DistributionConfig,
        mint: TimeLockedOSailMint<OSailCoinType>,
    ) {
        distribution_config.checked_package_version();
        let TimeLockedOSailMint {id, amount, unlock_time: _} = mint;
        let inner_id = id.uid_to_inner();
        let event = EventCancelTimeLockedMint {
            id: inner_id,
            amount,
            token_type: type_name::get<OSailCoinType>(),
            is_osail: true,
        };
        sui::event::emit<EventCancelTimeLockedMint>(event);
        object::delete(id);
    }

    /// Sets the aggregator that is used to calculate the price of oSAIL in USD
    /// In practice it is the same as sail_price_aggregator, but for future compatibility we keep it separate.
    public fun set_o_sail_price_aggregator<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ESetOsailPriceAggregatorInvalidDistrConfig);
        distribution_config.set_o_sail_price_aggregator(aggregator);

        let event = EventSetOSailPriceAggregator {
            price_aggregator: object::id(aggregator),
        };
        sui::event::emit<EventSetOSailPriceAggregator>(event);
    }

    /// Sets the aggregator that is used to calculate the price of SAIL in USD
    public fun set_sail_price_aggregator<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &mut DistributionConfig,
        aggregator: &Aggregator,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ESetSailPriceAggregatorInvalidDistrConfig);
        distribution_config.set_sail_price_aggregator(aggregator);

        let event = EventSetSailPriceAggregator {
            price_aggregator: object::id(aggregator),
        };
        sui::event::emit<EventSetSailPriceAggregator>(event);
    }

    /// Sets the time interval in seconds after a liquidity update during which reward claims return zero.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `admin_cap` - The admin capability
    /// * `distribution_config` - The distribution configuration
    /// * `new_liquidity_update_cooldown` - The new time interval in SECONDS
    public fun set_liquidity_update_cooldown<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &mut DistributionConfig,
        new_liquidity_update_cooldown: u64,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ESetSailPriceAggregatorInvalidDistrConfig);
        distribution_config.set_liquidity_update_cooldown(new_liquidity_update_cooldown);

        let event = EventSetLiquidityUpdateCooldown {
            new_cooldown: new_liquidity_update_cooldown,
        };
        sui::event::emit<EventSetLiquidityUpdateCooldown>(event);
    }

    /// Sets the early withdrawal penalty percentage.
    /// The percentage should be provided multiplied by EARLY_WITHDRAWAL_PENALTY_MULTIPLIER (e.g., 500 for 5.00%).
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `admin_cap` - The admin capability
    /// * `distribution_config` - The distribution configuration
    /// * `new_penalty_percentage` - The new penalty percentage multiplied by multiplier (e.g., 500 for 5.00%)
    public fun set_early_withdrawal_penalty_percentage<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &mut DistributionConfig,
        new_penalty_percentage: u64,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_distribution_config(distribution_config), ESetSailPriceAggregatorInvalidDistrConfig);
        distribution_config.set_early_withdrawal_penalty_percentage(new_penalty_percentage);

        let event = EventSetEarlyWithdrawalPenaltyPercentage {
            new_penalty_percentage: new_penalty_percentage,
        };
        sui::event::emit<EventSetEarlyWithdrawalPenaltyPercentage>(event);
    }

    /// Sets the passive voter fee rate — the ratio of trading fees redirected to passive voters.
    /// The rate uses `RATE_DENOM` as the denominator (i.e. RATE_DENOM = 100%).
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `admin_cap` - The admin capability
    /// * `distribution_config` - The distribution configuration
    /// * `passive_voter_fee_rate` - The new passive voter fee rate (must be <= RATE_DENOM)
    public fun set_passive_voter_fee_rate<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        admin_cap: &AdminCap,
        distribution_config: &DistributionConfig,
        passive_voter_fee_rate: u64,
    ) {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ESetPassiveVoterFeeRateMinterPaused);
        assert!(
            passive_voter_fee_rate <= RATE_DENOM,
            ESetPassiveVoterFeeRateTooBig
        );

        if (minter.bag.contains<u8>(BAG_KEY_PASSIVE_VOTER_FEE_RATE)) {
            let existing: &mut u64 = minter.bag.borrow_mut<u8, u64>(BAG_KEY_PASSIVE_VOTER_FEE_RATE);
            *existing = passive_voter_fee_rate;
        } else {
            minter.bag.add<u8, u64>(BAG_KEY_PASSIVE_VOTER_FEE_RATE, passive_voter_fee_rate);
        };

        sui::event::emit<EventSetPassiveVoterFeeRate>(EventSetPassiveVoterFeeRate {
            admin_cap: object::id(admin_cap),
            passive_voter_fee_rate,
        });
    }

    /// Returns the passive voter fee rate stored in the minter's bag.
    /// Returns 0 if the value has not been set yet.
    /// The denominator is `RATE_DENOM`.
    public fun passive_voter_fee_rate<SailCoinType>(minter: &Minter<SailCoinType>): u64 {
        if (minter.bag.contains<u8>(BAG_KEY_PASSIVE_VOTER_FEE_RATE)) {
            *minter.bag.borrow<u8, u64>(BAG_KEY_PASSIVE_VOTER_FEE_RATE)
        } else {
            0
        }
    }

    /// Creates a new PassiveFeeDistributor.
    /// The distributor is used to redirect a portion of trading fees to passive voters.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `admin_cap` - The admin capability
    /// * `distribution_config` - The distribution configuration
    /// * `clock` - The system clock
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// The newly created PassiveFeeDistributor
    public fun create_and_start_passive_fee_distributor<SailCoinType, FeeCoinType>(
        minter: &Minter<SailCoinType>,
        admin_cap: &AdminCap,
        voting_escrow: &voting_escrow::voting_escrow::VotingEscrow<SailCoinType>,
        distribution_config: &DistributionConfig,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): governance::passive_fee_distributor::PassiveFeeDistributor<FeeCoinType> {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(!minter.is_paused(), ECreatePassiveFeeDistributorMinterPaused);

        let mut distributor = governance::passive_fee_distributor::create<FeeCoinType>(object::id(voting_escrow), clock, ctx);

        distributor.start(clock);

        sui::event::emit<EventCreatePassiveFeeDistributor>(EventCreatePassiveFeeDistributor {
            admin_cap: object::id(admin_cap),
            passive_fee_distributor: object::id(&distributor),
            fee_coin_type: type_name::get<FeeCoinType>(),
        });

        distributor
    }

    /// Notifies the passive fee distributor of collected trading fees.
    /// Checkpoints the fee coin into the distributor so it becomes claimable by passive voters.
    /// Distribute governor is supposed to swap different passive fee tokens into the target fee coin.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `distribute_governor_cap` - Capability authorizing distribution
    /// * `distribution_config` - Configuration for token distribution
    /// * `passive_fee_distributor` - The passive fee distributor to notify
    /// * `fee_coin` - The fee coin to distribute
    /// * `clock` - The system clock
    public fun notify_passive_fee<SailCoinType, FeeCoinType>(
        minter: &Minter<SailCoinType>,
        distribute_governor_cap: &DistributeGovernorCap,
        distribution_config: &DistributionConfig,
        passive_fee_distributor: &mut governance::passive_fee_distributor::PassiveFeeDistributor<FeeCoinType>,
        fee_coin: Coin<FeeCoinType>,
        clock: &sui::clock::Clock,
    ) {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), ENotifyPassiveFeeMinterPaused);
        minter.check_distribute_governor(distribute_governor_cap);
        assert!(minter.is_active(clock), ENotifyPassiveFeeMinterNotActive);

        sui::event::emit<EventNotifyPassiveFee>(EventNotifyPassiveFee {
            passive_fee_distributor: object::id(passive_fee_distributor),
            fee_coin_type: type_name::get<FeeCoinType>(),
            amount: fee_coin.value(),
        });

        passive_fee_distributor.checkpoint_token(fee_coin, clock);
    }

    fun deposit_passive_fee<SailCoinType, FeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        fee: Balance<FeeCoinType>,
        ctx: &mut TxContext,
    ) {
        if (!minter.bag.contains<u8>(BAG_KEY_PASSIVE_FEE_BALANCES)) {
            minter.bag.add<u8, Bag>(BAG_KEY_PASSIVE_FEE_BALANCES, bag::new(ctx));
        };
        let fee_coin_type = type_name::get<FeeCoinType>();
        let balances_bag = minter.bag.borrow_mut<u8, Bag>(BAG_KEY_PASSIVE_FEE_BALANCES);
        if (!balances_bag.contains<TypeName>(fee_coin_type)) {
            balances_bag.add(fee_coin_type, balance::zero<FeeCoinType>());
        };
        let existing_balance = balances_bag.borrow_mut<TypeName, Balance<FeeCoinType>>(fee_coin_type);
        existing_balance.join(fee);
    }

    public fun passive_fee_balance<SailCoinType, FeeCoinType>(
        minter: &Minter<SailCoinType>,
    ): u64 {
        if (!minter.bag.contains<u8>(BAG_KEY_PASSIVE_FEE_BALANCES)) {
            return 0
        };
        let fee_coin_type = type_name::get<FeeCoinType>();
        let balances_bag = minter.bag.borrow<u8, Bag>(BAG_KEY_PASSIVE_FEE_BALANCES);
        if (!balances_bag.contains<TypeName>(fee_coin_type)) {
            return 0
        };
        balances_bag.borrow<TypeName, Balance<FeeCoinType>>(fee_coin_type).value()
    }

    public fun withdraw_passive_fee<SailCoinType, FeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribute_governor_cap: &DistributeGovernorCap,
        distribution_config: &DistributionConfig,
        ctx: &mut TxContext,
    ): Coin<FeeCoinType> {
        distribution_config.checked_package_version();
        assert!(!minter.is_paused(), EWithdrawPassiveFeeMinterPaused);
        minter.check_distribute_governor(distribute_governor_cap);
        let fee_coin_type = type_name::get<FeeCoinType>();
        assert!(
            minter.bag.contains<u8>(BAG_KEY_PASSIVE_FEE_BALANCES),
            EWithdrawPassiveFeeTokenNotFound
        );
        let balances_bag = minter.bag.borrow_mut<u8, Bag>(BAG_KEY_PASSIVE_FEE_BALANCES);
        assert!(
            balances_bag.contains<TypeName>(fee_coin_type),
            EWithdrawPassiveFeeTokenNotFound
        );
        let balance = balances_bag.remove<TypeName, Balance<FeeCoinType>>(fee_coin_type);
        let amount = balance.value();
        sui::event::emit<EventWithdrawPassiveFee>(EventWithdrawPassiveFee {
            governor_cap: object::id(distribute_governor_cap),
            fee_coin_type,
            amount,
        });
        coin::from_balance(balance, ctx)
    }

    /// Calculates the rewards in RewardCoinType earned by all staked positions.
    /// Successfull only when previous coin rewards are claimed.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `gauge` - The gauge instance
    /// * `pool` - The associated pool
    /// * `staked_positions` - The staked positions to check rewards for
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// The total amount of rewards earned by the staked positions. 0 if the epoch token is not valid.
    public fun earned_by_staked_position<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        minter: &Minter<SailCoinType>,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_positions: &vector<governance::gauge::StakedPosition>,
        clock: &sui::clock::Clock
    ): u64 {
        if (!minter.is_valid_epoch_token<SailCoinType, RewardCoinType>()) {
            return 0
        };
        // we don't need to check if the epoch token is valid here cos validity of the epoch token is defined by minter
        let mut i = 0;
        let mut total_earned = 0;
        while (i < staked_positions.length()) {
            let earned_i = gauge.earned<CoinTypeA, CoinTypeB>(
                pool, 
                staked_positions[i].position_id(), 
                clock
            );
            total_earned = total_earned + earned_i;

            i = i + 1;
        };
        total_earned
    }

    /// Calculates the rewards in RewardCoinType earned by all positions with given IDs.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `gauge` - The gauge instance
    /// * `pool` - The associated pool
    /// * `position_ids` - The IDs of the positions to check
    /// * `clock` - The system clock
    /// 
    /// # Returns
    /// The total amount of rewards earned by the positions. 0 if the epoch token is not valid.
    public fun earned_by_position_ids<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        minter: &Minter<SailCoinType>,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_ids: &vector<ID>,
        clock: &sui::clock::Clock
    ): u64 {
        if (!minter.is_valid_epoch_token<SailCoinType, RewardCoinType>()) {
            return 0
        };
        let mut i = 0;
        let mut total_earned = 0;
        while (i < position_ids.length()) {
            let earned_i = gauge.earned<CoinTypeA, CoinTypeB>(
                pool, 
                position_ids[i], 
                clock
            );
            total_earned = total_earned + earned_i;

            i = i + 1;
        };
        total_earned
    }

    /// Calculates the rewards in RewardCoinType earned by a specific position.
    ///
    /// # Arguments
    /// * `minter` - The minter instance
    /// * `gauge` - The gauge instance
    /// * `pool` - The associated pool
    /// * `position_id` - ID of the position to check
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// The amount of rewards earned by the position. 0 if the epoch token is not valid.
    public fun earned_by_position<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        minter: &Minter<SailCoinType>,
        gauge: &governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        if (!minter.is_valid_epoch_token<SailCoinType, RewardCoinType>()) {
            return 0
        };

        gauge.earned<CoinTypeA, CoinTypeB>(pool, position_id, clock)
    }

    /// Claims rewards in current epoch oSAIL for a specific position.
    /// Returns freshly minted oSAIL coins.
    /// RewardCoinType is supposed to be the current epoch oSAIL.
    public fun get_position_reward<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_position: &governance::gauge::StakedPosition,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): Coin<RewardCoinType> {
        distribution_config.checked_package_version();
        assert!(
            !distribution_config.is_gauge_paused(object::id(gauge)),
            EGetPosRewardGaugePaused
        );
        assert!(minter.is_valid_epoch_token<SailCoinType, RewardCoinType>(), EGetPositionRewardInvalidRewardToken);
        assert!(
            object::id(distribution_config) == minter.distribution_config,
            EGetPosDistributionConfInvalid
        );
        // we allow to claim rewards for killed gauges, cos position may have earnings before 
        // the gauge is killed.
        
        let reward_amount = get_position_reward_internal<CoinTypeA, CoinTypeB, RewardCoinType>(
            gauge,
            distribution_config,
            pool,
            staked_position.position_id(),
            clock,
            ctx
        );

        minter.mint_o_sail<SailCoinType, RewardCoinType>(reward_amount, ctx)
    }

    /// Claims rewards in current epoch oSAIL for multiple positions.
    /// Returns freshly minted oSAIL coins.
    /// RewardCoinType is supposed to be the current epoch oSAIL.
    public fun get_multiple_position_rewards<CoinTypeA, CoinTypeB, SailCoinType, RewardCoinType>(
        minter: &mut Minter<SailCoinType>,
        distribution_config: &DistributionConfig,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        staked_positions: &vector<governance::gauge::StakedPosition>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): Coin<RewardCoinType> {
        distribution_config.checked_package_version();
        assert!(
            !distribution_config.is_gauge_paused(object::id(gauge)),
            EGetMultiPosRewardGaugePaused
        );
        assert!(minter.is_valid_epoch_token<SailCoinType, RewardCoinType>(), EGetMultiplePositionRewardInvalidRewardToken);
        assert!(
            object::id(distribution_config) == minter.distribution_config,
            EGetMultiPosRewardDistributionConfInvalid
        );
        // we allow to claim rewards for killed gauges, cos position may have earnings before 
        // the gauge is killed.

        let mut i = 0;
        let mut total_earned = 0;
        while (i < staked_positions.length()) {
            let earned_i = get_position_reward_internal<CoinTypeA, CoinTypeB, RewardCoinType>(
                gauge,
                distribution_config,
                pool, 
                staked_positions[i].position_id(), 
                clock,
                ctx
            );
            total_earned = total_earned + earned_i;

            i = i + 1;
        };

        minter.mint_o_sail<SailCoinType, RewardCoinType>(total_earned, ctx)
    }

    /// Internal function to get position reward.
    fun get_position_reward_internal<CoinTypeA, CoinTypeB, RewardCoinType>(
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        distribution_config: &DistributionConfig,
        pool: &mut clmm_pool::pool::Pool<CoinTypeA, CoinTypeB>,
        position_id: ID,
        clock: &sui::clock::Clock,
        ctx: &TxContext
    ): u64 {
        let (reward_amount, growth_inside) = gauge.update_reward_internal<CoinTypeA, CoinTypeB>(
            distribution_config,
            pool,
            position_id,
            clock,
            ctx
        );

        let event = EventClaimPositionReward {
            from: tx_context::sender(ctx),
            gauge_id: object::id(gauge),
            pool_id: object::id(pool),
            position_id,
            amount: reward_amount,
            growth_inside,
            token: type_name::get<RewardCoinType>(),
        };
        sui::event::emit<EventClaimPositionReward>(event);

        reward_amount
    }

    // A method that is supposed to be called by the backend voting service to update voted weights.
    // The weights are updated to match accuracy of the volume prediction.
    public fun update_voted_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        weights: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_voted_weights(
            distribute_cap,
            gauge_id,
            weights,
            lock_ids,
            for_epoch_start,
            false,
            clock,
            ctx
        )
    }

    public fun update_voted_weights_ignore_supply<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        weights: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_voted_weights_ignore_supply(
            distribute_cap,
            gauge_id,
            weights,
            lock_ids,
            for_epoch_start,
            clock,
            ctx
        )
    }

    // A method to finalize voted weights for a specific gauge.
    // Users will be able to claim rewards only after the epoch is finalized.
    public fun finalize_voted_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_voted_weights(
            distribute_cap,
            gauge_id,
            vector::empty(),
            vector::empty(),
            for_epoch_start,
            true,
            clock,
            ctx
        )
    }

    public fun reset_final_voted_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        for_epoch_start: u64,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.reset_final_voted_weights(
            distribute_cap,
            gauge_id,
            for_epoch_start,
            ctx
        );
    }

    public fun update_supply_voted_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        for_epoch_start: u64,
        total_supply: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_supply_voted_weights(
            distribute_cap,
            gauge_id,
            for_epoch_start,
            total_supply,
            clock,
            ctx
        );
    }

    /// A method that is supposed to be called by the backend voting service to null unvoted lock weigths.
    /// In turn unvoted locks are not earning exercise fee rewards.
    public fun null_exercise_fee_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();
        let mut weights = vector::empty();
        let mut i = 0;
        while (i < lock_ids.length()) {
            weights.push_back(0);
            i = i + 1;
        };

        voter.update_exercise_fee_weights(
            distribute_cap,
            weights,
            lock_ids,
            for_epoch_start,
            false,
            clock,
            ctx,
        )
    }

    public fun null_exercise_fee_weights_ignore_supply<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();
        let mut weights = vector::empty();
        let mut i = 0;
        while (i < lock_ids.length()) {
            weights.push_back(0);
            i = i + 1;
        };

        voter.update_exercise_fee_weights_ignore_supply(
            distribute_cap,
            weights,
            lock_ids,
            for_epoch_start,
            clock,
            ctx,
        )
    }

    // A method to finalize epoch for exercise fee weights. 
    // After calling this method the exercise fee would be available for claiming.
    public fun finalize_exercise_fee_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        for_epoch_start: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_exercise_fee_weights(
            distribute_cap,
            vector::empty(),
            vector::empty(),
            for_epoch_start,
            true,
            clock,
            ctx
        )
    }

    public fun reset_final_exercise_fee_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        for_epoch_start: u64,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.reset_final_exercise_fee_weights(
            distribute_cap,
            for_epoch_start,
            ctx
        );
    }

    public fun update_supply_exercise_fee_weights<SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        for_epoch_start: u64,
        total_supply: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        let distribute_cap = minter.distribute_cap.borrow();

        voter.update_supply_exercise_fee_weights(
            distribute_cap,
            for_epoch_start,
            total_supply,
            clock,
            ctx
        );
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
         sui::package::claim<MINTER>(MINTER {}, ctx)
    }

    public fun inject_voting_fee_reward<SailCoinType, FeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        gauge_id: ID,
        reward: Coin<FeeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        voter.inject_voting_fee_reward(
            minter.distribute_cap.borrow(),
            gauge_id,
            reward,
            clock,
            ctx
        );
    }

    /// Used to notify exercise fee. Supposed to be used by operations wallet
    /// to deposit freshly bought SAIL into the reward contract.
    public fun notify_exercise_fee_reward<SailCoinType, ExerciseFeeCoinType>(
        minter: &mut Minter<SailCoinType>,
        voter: &mut governance::voter::Voter,
        distribution_config: &DistributionConfig,
        distribute_governor_cap: &DistributeGovernorCap,
        reward: Coin<ExerciseFeeCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        distribution_config.checked_package_version();
        minter.check_distribute_governor(distribute_governor_cap);

        voter.notify_exercise_fee_reward_amount(
            minter.distribute_cap.borrow(),
            reward,
            clock,
            ctx,
        );
    }

    

    public fun exercise_fee_protocol_balance<SailCoinType, ExerciseFeeCoinType>(
        minter: &Minter<SailCoinType>,
    ): u64 {
        let coin_type = type_name::get<ExerciseFeeCoinType>();
        if (minter.exercise_fee_protocol_balances.contains<TypeName>(coin_type)) {
            minter.exercise_fee_protocol_balances.borrow<TypeName, Balance<ExerciseFeeCoinType>>(coin_type).value()
        } else {
            0
        }
    }

    public fun exercise_fee_operations_balance<SailCoinType, ExerciseFeeCoinType>(
        minter: &Minter<SailCoinType>,
    ): u64 {
        let coin_type = type_name::get<ExerciseFeeCoinType>();
        if (minter.exercise_fee_operations_balances.contains<TypeName>(coin_type)) {
            minter.exercise_fee_operations_balances.borrow<TypeName, Balance<ExerciseFeeCoinType>>(coin_type).value()
        } else {
            0
        }
    }

    #[test_only]
    public fun test_get_aggregator_price<FeedPoolCoinTypeA, FeedPoolCoinTypeB, FeedCoin, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        price_monitor: &mut PriceMonitor,
        feed_pool: &clmm_pool::pool::Pool<FeedPoolCoinTypeA, FeedPoolCoinTypeB>,
        metadata: &CoinMetadata<FeedCoin>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
    ): (u128, bool) {
        minter.get_aggregator_price(price_monitor, feed_pool, metadata, aggregator, clock)
    }


    /// Gets the price from the aggregator.
    /// 
    /// This method expects that the aggregator provides a price that corresponds to the price
    /// from the feed_pool. The feed_pool contains FeedPoolCoinTypeA and FeedPoolCoinTypeB,
    /// but we don't know in advance which token the aggregator is pricing relative to.
    /// 
    /// Therefore, we use abstract coin types A and B for the pool, and specify FeedCoin
    /// for the CoinMetadata, as it corresponds to either FeedPoolCoinTypeA or FeedPoolCoinTypeB.
    /// 
    /// The returned price is in decimals of the token for which we're getting the price.
    /// For example, if using a SAIL/USDC pool, the price will be in SAIL decimals.
    /// 
    /// Returns: price in Q64.64 format with respect to decimals and a validation flag (true if invalid, false if valid).
    fun get_aggregator_price<FeedPoolCoinTypeA, FeedPoolCoinTypeB, FeedCoin, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        price_monitor: &mut PriceMonitor,
        feed_pool: &clmm_pool::pool::Pool<FeedPoolCoinTypeA, FeedPoolCoinTypeB>,
        metadata: &CoinMetadata<FeedCoin>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
    ): (u128, bool) {

        let (mut aggregator_price_q64, is_invalid) = minter.get_aggregator_price_without_decimals<FeedPoolCoinTypeA, FeedPoolCoinTypeB, SailCoinType>(
            price_monitor,
            feed_pool,
            aggregator,
            clock
        );

        if (is_invalid) {
            return (0, true)
        };

        let asset_decimals = voting_escrow::common::sail_decimals();
        let usd_decimals = metadata.get_decimals();

        if (asset_decimals > usd_decimals) {
            // asset is bigger than USD
            // asset * price = USD
            // so to compensate we need to decrease price therefore increase denominator
            let decimals_delta = asset_decimals - usd_decimals;
            aggregator_price_q64 = integer_mate::full_math_u128::mul_div_floor(
                aggregator_price_q64,
                1,
                decimal::pow_10(decimals_delta)
            );
        } else {
            if (usd_decimals != asset_decimals) {
                // USD is bigger than asset
                // USD / price = asset
                // so to compensate we need to increase price therefore decrease denominator
                let decimals_delta = usd_decimals - asset_decimals;
                aggregator_price_q64 = aggregator_price_q64 * decimal::pow_10(decimals_delta);
            }
        };

        (aggregator_price_q64, false)
    }

    /// # Returns
    /// The price in Q64.64 format, i.e USD/asset * 2^64 without decimals
    fun get_aggregator_price_without_decimals<FeedPoolCoinTypeA, FeedPoolCoinTypeB, SailCoinType>(
        minter: &mut Minter<SailCoinType>,
        price_monitor: &mut PriceMonitor,
        feed_pool: &clmm_pool::pool::Pool<FeedPoolCoinTypeA, FeedPoolCoinTypeB>,
        aggregator: &Aggregator,
        clock: &sui::clock::Clock,
    ): (u128, bool) {

        let price_validation_result = price_monitor.validate_price<FeedPoolCoinTypeA, FeedPoolCoinTypeB, SailCoinType>(
            aggregator, 
            feed_pool,
            clock
        );

        if (price_validation_result.get_escalation_activation()) {

            minter.emission_stopped = true;
            sui::event::emit<EventStopEmission>(EventStopEmission {});

            return (0, true)
        };

        (price_validation_result.get_price_q64(), false)
    }

    public fun claim_unclaimed_o_sail<CoinTypeA, CoinTypeB, SailCoinType, OSailCoinType>(
        minter: &mut Minter<SailCoinType>, 
        distribution_config: &DistributionConfig, 
        admin_cap: &AdminCap,
        gauge: &mut governance::gauge::Gauge<CoinTypeA, CoinTypeB>,
        ctx: &mut TxContext,
    ): Coin<OSailCoinType> {
        distribution_config.checked_package_version();
        minter.check_admin(admin_cap);
        assert!(minter.is_valid_epoch_token<SailCoinType, OSailCoinType>(), EClaimUnclaimedOsailInvalidEpochToken);

        let unclaimed_o_sail = gauge.remove_unclaimed_o_sail();
        if (unclaimed_o_sail == 0) {
            return sui::coin::zero<OSailCoinType>(ctx)
        };

        minter.mint_o_sail<SailCoinType, OSailCoinType>(unclaimed_o_sail, ctx)
    }
}
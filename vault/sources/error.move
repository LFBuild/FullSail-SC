module vault::error {

    const AMOUNT_IN_ABOVE_MAX_LIMIT: u64 = 1;
    const ASSETS_AND_PRICES_SIZE_NOT_MATCH: u64 = 37;
    const AUM_DONE_ERR: u64 = 20;
    const CLMM_POOL_NOT_MATCH: u64 = 23;
    const FEE_CLAIM_ERR: u64 = 18;
    const HARD_CAP_REACHED: u64 = 5;
    const INCORRECT_REPAY_PORT_ID: u64 = 6;
    const INCORRECT_REPAY_TYPE: u64 = 7;
    const INCORRECT_REPAY_AMOUNT: u64 = 63;
    const INVALID_LIQUIDITY_RANGE: u64 = 16;
    const INVALID_ORACLE_PRICE: u64 = 29;
    const INVALID_PRICE_FEED_ID: u64 = 28;
    const INVALID_PROTOCOL_FEE_RATE: u64 = 13;
    const LIQUIDITY_RANGE_NOT_CHANGE: u64 = 38;
    const MINING_CLAIM_ERR: u64 = 19;
    const NO_OPERATION_MANAGER_PERMISSION: u64 = 9;
    const NO_ORACLE_MANAGER_PERMISSION: u64 = 11;
    const NO_POOL_MANAGER_PERMISSION: u64 = 10;
    const NO_PROTOCOL_FEE_CLAIM_PERMISSION: u64 = 8;
    const OPERATION_NOT_ALLOWED: u64 = 25;
    const ORACLE_INFO_EXISTS: u64 = 26;
    const ORACLE_INFO_NOT_EXISTS: u64 = 27;
    const PACKAGE_VERSION_DEPRECATE: u64 = 12;
    const PORT_IS_PAUSE: u64 = 17;
    const POOL_NOT_NEED_REBALANCE: u64 = 21;
    const PRICE_ERR: u64 = 32;
    const PRICE_NOT_EXISTS: u64 = 35;
    const PRICE_NOT_UPDATED: u64 = 34;
    const PRICE_OBJECT_NOT_MATCH_WITH_COIN_TYPE: u64 = 30;
    const QUOTE_TYPE_ERROR: u64 = 31;
    const REMOVE_ASSETS_NOT_EMPTY: u64 = 22;
    const TOKEN_AMOUNT_IS_ZERO: u64 = 3;
    const TOKEN_AMOUNT_NOT_ENOUGH: u64 = 4;
    const TOKEN_AMOUNT_OVERFLOW: u64 = 2;
    const TREASURY_CAP_ILLEGAL: u64 = 14;
    const UPDATE_PRICE_FEE_NOT_ENOUGH: u64 = 33;
    const PORT_ENTRY_NOT_MATCH: u64 = 36;
    const PORT_ENTRY_PORT_ID_NOT_MATCH: u64 = 24;
    const WRONG_PACKAGE_VERSION: u64 = 15;
    const INVALID_LIQUIDITY: u64 = 39;
    const INVALID_LAST_AUM: u64 = 40;
    const NOT_UPDATED_REWARD_GROWTH_TIME: u64 = 41;
    const NOT_UPDATED_OSAIL_GROWTH_TIME: u64 = 42;
    const REWARD_GROWTH_NOT_MATCH: u64 = 43;
    const OSAIL_GROWTH_NOT_MATCH: u64 = 44;
    const PORT_ENTRY_VOLUME_NOT_EMPTY: u64 = 45;
    const PORT_ENTRY_VOLUME_EMPTY: u64 = 46;
    const PORT_ENTRY_VOLUME_NOT_MATCH: u64 = 47;
    const OSAIL_WITHDRAW_CERT_POOL_ID_NOT_MATCH: u64 = 48;
    const OSAIL_WITHDRAW_CERT_NOT_MATCH: u64 = 49;
    const OSAIL_REWARD_EMPTY: u64 = 50;
    const OSAIL_REWARD_NOT_ENOUGH: u64 = 51;
    const PORT_ENTRY_TIME_NOT_MATCH: u64 = 52;
    const BUFFER_ASSETS_NOT_EMPTY: u64 = 53;
    const REWARD_EMPTY: u64 = 54;
    const NO_AVAILABLE_OSAIL_REWARD: u64 = 55;
    const NOT_CLAIMED_PREVIOUS_OSAIL_REWARD: u64 = 56;
    const OSAIL_REWARD_NOT_CLAIMED: u64 = 57;
    const GROWTH_OVERFLOW: u64 = 58;
    const REWARD_TYPES_NOT_MATCH: u64 = 59;
    const VAULT_STOPPED: u64 = 60;
    const VAULT_STARTED: u64 = 61;
    const INVALID_SWAP_SLIPPAGE: u64 = 62;
    const NOT_OWNER: u64 = 63;
    const NO_PORT_CREATOR_PERMISSION: u64 = 64;
    const SWITCHBOARD_AGGREGATOR_NOT_MATCH: u64 = 65;
    const SWITCHBOARD_ORACLE_INFO_ALREADY_EXISTS: u64 = 66;
    const PYTH_ORACLE_INFO_ALREADY_EXISTS: u64 = 67;
    const INVALID_AGGREGATOR_PRICE: u64 = 68;
    const VAULT_IS_STOPPED: u64 = 69;
    const VAULT_NOT_STOPPED: u64 =70;
    const NOT_UPDATED_INCENTIVE_REWARD_GROWTH_TIME: u64 = 71;
    const INVALID_TIME: u64 = 72;
    const INSUFFICIENT_INCENTIVE_BALANCE: u64 = 73;
    const INCENTIVE_REWARD_NOT_FOUND: u64 = 74;
    const AVAILABLE_BALANCE_OVERFLOW: u64 = 75;
    const INCORRECT_WITHDRAW_AMOUNT: u64 = 76;
    const INCENTIVE_REWARD_NOT_CLAIMED: u64 = 77;

    public fun amount_in_above_max_limit() : u64 {
        abort AMOUNT_IN_ABOVE_MAX_LIMIT
    }
    
    public fun assets_and_prices_size_not_match() : u64 {
        abort ASSETS_AND_PRICES_SIZE_NOT_MATCH
    }
    
    public fun aum_done_err() : u64 {
        abort AUM_DONE_ERR
    }
    
    public fun clmm_pool_not_match() : u64 {
        abort CLMM_POOL_NOT_MATCH
    }
    
    public fun fee_claim_err() : u64 {
        abort FEE_CLAIM_ERR
    }
    
    public fun hard_cap_reached() : u64 {
        abort HARD_CAP_REACHED
    }
    
    public fun incorrect_repay_port_id() : u64 {
        abort INCORRECT_REPAY_PORT_ID
    }
    
    public fun incorrect_repay_type() : u64 {
        abort INCORRECT_REPAY_TYPE
    }

    public fun incorrect_repay_amount() : u64 {
        abort INCORRECT_REPAY_AMOUNT
    }
    
    public fun invalid_liquidity_range() : u64 {
        abort INVALID_LIQUIDITY_RANGE
    }
    
    public fun invalid_oracle_price() : u64 {
        abort INVALID_ORACLE_PRICE
    }
    
    public fun invalid_price_feed_id() : u64 {
        abort INVALID_PRICE_FEED_ID
    }
    
    public fun invalid_protocol_fee_rate() : u64 {
        abort INVALID_PROTOCOL_FEE_RATE
    }
    
    public fun liquidity_range_not_change() : u64 {
        abort LIQUIDITY_RANGE_NOT_CHANGE
    }
    
    public fun mining_claim_err() : u64 {
        abort MINING_CLAIM_ERR
    }
    
    public fun no_operation_manager_permission() : u64 {
        abort NO_OPERATION_MANAGER_PERMISSION
    }
    
    public fun no_oracle_manager_permission() : u64 {
        abort NO_ORACLE_MANAGER_PERMISSION
    }
    
    public fun no_pool_manager_permission() : u64 {
        abort NO_POOL_MANAGER_PERMISSION
    }
    
    public fun no_protocol_fee_claim_permission() : u64 {
        abort NO_PROTOCOL_FEE_CLAIM_PERMISSION
    }
    
    public fun operation_not_allowed() : u64 {
        abort OPERATION_NOT_ALLOWED
    }
    
    public fun oracle_info_exists() : u64 {
        abort ORACLE_INFO_EXISTS
    }
    
    public fun oracle_info_not_exists() : u64 {
        abort ORACLE_INFO_NOT_EXISTS
    }
    
    public fun package_version_deprecate() : u64 {
        abort PACKAGE_VERSION_DEPRECATE
    }
    
    public fun port_is_pause() : u64 {
        abort PORT_IS_PAUSE
    }
    
    public fun pool_not_need_rebalance() : u64 {
        abort POOL_NOT_NEED_REBALANCE
    }
    
    public fun price_err() : u64 {
        abort PRICE_ERR
    }
    
    public fun price_not_exists() : u64 {
        abort PRICE_NOT_EXISTS
    }
    
    public fun price_not_updated() : u64 {
        abort PRICE_NOT_UPDATED
    }
    
    public fun price_object_not_match_with_coin_type() : u64 {
        abort PRICE_OBJECT_NOT_MATCH_WITH_COIN_TYPE
    }
    
    public fun quote_type_error() : u64 {
        abort QUOTE_TYPE_ERROR
    }
    
    public fun remove_assets_not_empty() : u64 {
        abort REMOVE_ASSETS_NOT_EMPTY
    }
    
    public fun token_amount_is_zero() : u64 {
        abort TOKEN_AMOUNT_IS_ZERO
    }
    
    public fun token_amount_not_enough() : u64 {
        abort TOKEN_AMOUNT_NOT_ENOUGH
    }
    
    public fun token_amount_overflow() : u64 {
        abort TOKEN_AMOUNT_OVERFLOW
    }
    
    public fun treasury_cap_illegal() : u64 {
        abort TREASURY_CAP_ILLEGAL
    }
    
    public fun update_price_fee_not_enough() : u64 {
        abort UPDATE_PRICE_FEE_NOT_ENOUGH
    }
    
    public fun port_entry_not_match() : u64 { 
        abort PORT_ENTRY_NOT_MATCH
    }
    
    public fun port_entry_port_id_not_match() : u64 {
        abort PORT_ENTRY_PORT_ID_NOT_MATCH
    }
    
    public fun wrong_package_version() : u64 {
        abort WRONG_PACKAGE_VERSION
    }

    public fun invalid_liquidity() : u64 {
        abort INVALID_LIQUIDITY
    }

    public fun invalid_last_aum() : u64 {
        abort INVALID_LAST_AUM
    }

    public fun not_updated_reward_growth_time() : u64 {
        abort NOT_UPDATED_REWARD_GROWTH_TIME
    }

    public fun not_updated_osail_growth_time() : u64 {
        abort NOT_UPDATED_OSAIL_GROWTH_TIME
    }

    public fun reward_growth_not_match() : u64 {
        abort REWARD_GROWTH_NOT_MATCH
    }

    public fun osail_growth_not_match() : u64 {
        abort OSAIL_GROWTH_NOT_MATCH
    }

    public fun port_entry_volume_not_empty() : u64 {
        abort PORT_ENTRY_VOLUME_NOT_EMPTY
    }

    public fun port_entry_volume_empty() : u64 {
        abort PORT_ENTRY_VOLUME_EMPTY
    }

    public fun port_entry_volume_not_match() : u64 {
        abort PORT_ENTRY_VOLUME_NOT_MATCH
    }

    public fun osail_withdraw_cert_pool_id_not_match() : u64 {
        abort OSAIL_WITHDRAW_CERT_POOL_ID_NOT_MATCH
    }

    public fun osail_withdraw_cert_not_match() : u64 {
        abort OSAIL_WITHDRAW_CERT_NOT_MATCH
    }

    public fun osail_reward_empty() : u64 {
        abort OSAIL_REWARD_EMPTY
    }

    public fun osail_reward_not_enough() : u64 {
        abort OSAIL_REWARD_NOT_ENOUGH
    }

    public fun port_entry_time_not_match() : u64 {
        abort PORT_ENTRY_TIME_NOT_MATCH
    }

    public fun buffer_assets_not_empty() : u64 {
        abort BUFFER_ASSETS_NOT_EMPTY
    }

    public fun reward_empty() : u64 {
        abort REWARD_EMPTY
    }

    public fun no_available_osail_reward() : u64 {
        abort NO_AVAILABLE_OSAIL_REWARD
    }

    public fun not_claimed_previous_osail_reward() : u64 {
        abort NOT_CLAIMED_PREVIOUS_OSAIL_REWARD
    }

    public fun osail_reward_not_claimed() : u64 {
        abort OSAIL_REWARD_NOT_CLAIMED
    }

    public fun growth_overflow() : u64 {
        abort GROWTH_OVERFLOW
    }

    public fun reward_types_not_match() : u64 {
        abort REWARD_TYPES_NOT_MATCH
    }

    public fun vault_stopped() : u64 {
        abort VAULT_STOPPED
    }

    public fun vault_started() : u64 {
        abort VAULT_STARTED
    }

    public fun invalid_swap_slippage() : u64 {
        abort INVALID_SWAP_SLIPPAGE
    }

    public fun not_owner() : u64 {
        abort NOT_OWNER
    }

    public fun no_port_creator_permission() : u64 {
        abort NO_PORT_CREATOR_PERMISSION
    }

    public fun switchboard_aggregator_not_match() : u64 {
        abort SWITCHBOARD_AGGREGATOR_NOT_MATCH
    }

    public fun switchboard_oracle_info_already_exists() : u64 {
        abort SWITCHBOARD_ORACLE_INFO_ALREADY_EXISTS
    }

    public fun pyth_oracle_info_already_exists() : u64 {
        abort PYTH_ORACLE_INFO_ALREADY_EXISTS
    }

    public fun invalid_aggregator_price() : u64 {
        abort INVALID_AGGREGATOR_PRICE
    }

    public fun vault_is_stopped() : u64 {
        abort VAULT_IS_STOPPED
    }

    public fun vault_not_stopped() : u64 {
        abort VAULT_NOT_STOPPED
    }

    public fun not_updated_incentive_reward_growth_time() : u64 {
        abort NOT_UPDATED_INCENTIVE_REWARD_GROWTH_TIME
    }

    public fun invalid_time() : u64 {
        abort INVALID_TIME
    }

    public fun insufficient_incentive_balance() : u64 {
        abort INSUFFICIENT_INCENTIVE_BALANCE
    }

    public fun incentive_reward_not_found() : u64 {
        abort INCENTIVE_REWARD_NOT_FOUND
    }

    public fun available_balance_overflow() : u64 {
        abort AVAILABLE_BALANCE_OVERFLOW
    }

    public fun incorrect_withdraw_amount() : u64 {
        abort INCORRECT_WITHDRAW_AMOUNT
    }

    public fun incentive_reward_not_claimed() : u64 {
        abort INCENTIVE_REWARD_NOT_CLAIMED
    }
}


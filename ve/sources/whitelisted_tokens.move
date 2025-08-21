/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module ve::whitelisted_tokens {
    use sui::table::{Self, Table};

    /// Event emitted when a token is whitelisted or de-whitelisted
    public struct EventWhitelistToken has copy, drop, store {
        sender: address,
        token: std::type_name::TypeName,
        listed: bool,
    }

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    const EInvalidVoter: u64 = 9223372260193075199;
    const EInvalidToken: u64 = 9223372268783140867;
    const EInvalidManagerCap: u64 = 190299737184899550;
    const ETokenNotWhitelisted: u64 = 555057717258834400;

    /// A proof that a token is whitelisted. Can be used in other modules to verify
    /// that a token is allowed for certain operations.
    public struct WhitelistedToken {
        voter: ID,
        token: std::type_name::TypeName,
    }

    /// Manages a whitelist of tokens for a given `voter` module instance.
    /// This is used to control which tokens can be used for rewards.
    public struct WhitelistManager has store, key {
        id: UID,
        voter: ID,
        // Coins that allowed to be used as bribe rewards or free managed rewards
        is_whitelisted_token: Table<std::type_name::TypeName, bool>,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    /// A capability that grants administrative rights over a `WhitelistManager`.
    public struct WhitelistManagerCap has store, key {
        id: UID,
        whitelist_manager: ID,
    }

    /// Validates that the provided `WhitelistManagerCap` is valid for the given `WhitelistManager` ID.
    /// Aborts if the cap is invalid.
    public fun validate_manager_cap(cap: &WhitelistManagerCap, manager_id: ID) {
        assert!(cap.whitelist_manager == manager_id, EInvalidManagerCap);
    }

    /// Creates a new `WhitelistManager` and its corresponding `WhitelistManagerCap`.
    public fun create(voter: ID, ctx: &mut TxContext): (WhitelistManager, WhitelistManagerCap) {
        let id = object::new(ctx);
        let inner_id = id.uid_to_inner();
        let manager = WhitelistManager {
            id,
            voter,
            is_whitelisted_token: table::new<std::type_name::TypeName, bool>(ctx),
            bag: sui::bag::new(ctx),
        };
        let cap = WhitelistManagerCap {
            id: object::new(ctx),
            whitelist_manager: inner_id,
        };
        (manager, cap)
    }

    fun create_proof<CoinType>(manager: &WhitelistManager): WhitelistedToken {
        WhitelistedToken {
            voter: manager.voter,
            token: std::type_name::get<CoinType>(),
        }
    }

    /// Validates a `WhitelistedToken` proof.
    /// Aborts if the voter ID does not match or if the token type is incorrect.
    public fun validate<CoinType>(whitelisted_token: WhitelistedToken, voter_id: ID) {
        let WhitelistedToken {
            voter,
            token,
        } = whitelisted_token;
        assert!(voter == voter_id, EInvalidVoter);
        if (token != std::type_name::get<CoinType>()) {
            abort EInvalidToken
        };
    }

    /// Checks if a token type is present in the whitelist table.
    ///
    /// # Arguments
    /// * `manager` - The WhitelistManager object reference
    ///
    /// # Returns
    /// True if the token type is in the `is_whitelisted_token` table, regardless of its boolean value.
    /// False if it is not in the table.
    public fun is_whitelisted_token<CoinToCheckType>(manager: &WhitelistManager): bool {
        let coin_type_name = std::type_name::get<CoinToCheckType>();
        
        manager.is_whitelisted_token.contains(coin_type_name)
    }

    /// Proves that a specific token is whitelisted in the system.
    /// Used to verify tokens for various operations.
    ///
    /// # Arguments
    /// * `manager` - The WhitelistManager object reference
    ///
    /// # Returns
    /// A capability proving that the token is whitelisted
    public fun prove_token_whitelisted<CoinToCheckType>(
        manager: &WhitelistManager
    ): WhitelistedToken {
        assert!(is_whitelisted_token<CoinToCheckType>(manager), ETokenNotWhitelisted);
        create_proof<CoinToCheckType>(manager)
    }

    /// Adds or updates a token's status in the whitelist.
    /// Note that `is_whitelisted_token` only checks for a token's presence, not its `listed` status.
    ///
    /// # Arguments
    /// * `manager` - The WhitelistManager object reference
    /// * `manager_cap` - The capability to manage the whitelist
    /// * `token` - The type name of the token to add or update
    /// * `listed` - The boolean status to associate with the token.
    /// * `sender` - The address of the sender for the event
    ///
    /// # Emits
    /// * `EventWhitelistToken` with whitelist information
    public fun whitelist_token(
        manager: &mut WhitelistManager,
        manager_cap: &WhitelistManagerCap,
        token: std::type_name::TypeName,
        listed: bool,
        sender: address
    ) {
        validate_manager_cap(manager_cap, object::id(manager));
        if (manager.is_whitelisted_token.contains(token)) {
            manager.is_whitelisted_token.remove(token);
        };
        manager.is_whitelisted_token.add(token, listed);
        let whitelist_token_event = EventWhitelistToken {
            sender,
            token,
            listed,
        };
        sui::event::emit<EventWhitelistToken>(whitelist_token_event);
    }
}


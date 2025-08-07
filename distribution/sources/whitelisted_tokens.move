/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module distribution::whitelisted_tokens {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    const EInvalidVoter: u64 = 9223372260193075199;
    const EInvalidToken: u64 = 9223372268783140867;
    const EPairInvalidVoter: u64 = 9223372204358500351;
    const EPairInvalidTokenA: u64 = 9223372212948434945;
    const EPairInvalidTokenB: u64 = 9223372230128304129;

    public struct WhitelistedToken {
        voter: ID,
        token: std::type_name::TypeName,
    }

    public(package) fun create<CoinType>(voter_id: ID): WhitelistedToken {
        WhitelistedToken {
            voter: voter_id,
            token: std::type_name::get<CoinType>(),
        }
    }

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
}


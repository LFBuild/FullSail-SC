module distribution::whitelisted_tokens {

    const EInvalidVoter: u64 = 9223372260193075199;
    const EInvalidToken: u64 = 9223372268783140867;
    const EPairInvalidVoter: u64 = 9223372204358500351;
    const EPairInvalidTokenA: u64 = 9223372212948434945;
    const EPairInvalidTokenB: u64 = 9223372230128304129;

    public struct WhitelistedTokenPair {
        voter: ID,
        token0: std::type_name::TypeName,
        token1: std::type_name::TypeName,
    }

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

    public(package) fun create_pair<CoinTypeA, CoinTypeB>(voter_id: ID): WhitelistedTokenPair {
        WhitelistedTokenPair {
            voter: voter_id,
            token0: std::type_name::get<CoinTypeA>(),
            token1: std::type_name::get<CoinTypeB>(),
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

    public fun validate_pair<CoinTypeA, CoinTypeB>(whitelisted_token_pair: WhitelistedTokenPair, voter_id: ID) {
        let WhitelistedTokenPair {
            voter,
            token0,
            token1,
        } = whitelisted_token_pair;
        assert!(voter == voter_id, EPairInvalidVoter);
        let coin_type_a = std::type_name::get<CoinTypeA>();
        if (token0 != coin_type_a && token1 != coin_type_a) {
            abort EPairInvalidTokenA
        };
        let coin_type_b = std::type_name::get<CoinTypeB>();
        if (token0 != coin_type_b && token1 != coin_type_b) {
            abort EPairInvalidTokenB
        };
    }
}


module distribution::whitelisted_tokens {
    public struct WhitelistedTokenPair {
        voter: ID,
        token0: std::type_name::TypeName,
        token1: std::type_name::TypeName,
    }

    public struct WhitelistedToken {
        voter: ID,
        token: std::type_name::TypeName,
    }

    public(package) fun create<T0>(arg0: ID): WhitelistedToken {
        WhitelistedToken {
            voter: arg0,
            token: std::type_name::get<T0>(),
        }
    }

    public(package) fun create_pair<T0, T1>(arg0: ID): WhitelistedTokenPair {
        WhitelistedTokenPair {
            voter: arg0,
            token0: std::type_name::get<T0>(),
            token1: std::type_name::get<T1>(),
        }
    }

    public fun validate<T0>(arg0: WhitelistedToken, arg1: ID) {
        let WhitelistedToken {
            voter: v0,
            token: v1,
        } = arg0;
        assert!(v0 == arg1, 9223372260193075199);
        if (v1 != std::type_name::get<T0>()) {
            abort 9223372268783140867
        };
    }

    public fun validate_pair<T0, T1>(arg0: WhitelistedTokenPair, arg1: ID) {
        let WhitelistedTokenPair {
            voter: v0,
            token0: v1,
            token1: v2,
        } = arg0;
        assert!(v0 == arg1, 9223372204358500351);
        let v3 = std::type_name::get<T0>();
        if (v1 != v3 && v2 != v3) {
            abort 9223372212948434945
        };
        let v4 = std::type_name::get<T1>();
        if (v1 != v4 && v2 != v4) {
            abort 9223372230128304129
        };
    }

    // decompiled from Move bytecode v6
}


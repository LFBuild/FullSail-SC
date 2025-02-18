module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::setup_distribution {
    public entry fun create<T0>(arg0: &0x2::package::Publisher, arg1: address, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let (v0, v1) = 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::create<T0>(arg0, 0x1::option::none<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::magma_token::MinterCap<T0>>(), arg3);
        let v2 = v1;
        let v3 = v0;
        let v4 = 0x1::vector::empty<0x1::type_name::TypeName>();
        0x1::vector::push_back<0x1::type_name::TypeName>(&mut v4, 0x1::type_name::get<T0>());
        let (v5, v6) = 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::voter::create<T0>(arg0, v4, arg3);
        let v7 = v5;
        let (v8, v9) = 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::reward_distributor::create<T0>(arg0, arg2, arg3);
        0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::set_notify_reward_cap<T0>(&mut v3, &v2, v6);
        0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::set_reward_distributor_cap<T0>(&mut v3, &v2, v9);
        0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::set_team_wallet<T0>(&mut v3, &v2, arg1);
        0x2::transfer::public_transfer<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::AdminCap>(v2, 0x2::tx_context::sender(arg3));
        0x2::transfer::public_share_object<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::reward_distributor::RewardDistributor<T0>>(v8);
        0x2::transfer::public_share_object<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::voting_escrow::VotingEscrow<T0>>(0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::voting_escrow::create<T0>(arg0, 0x2::object::id<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::voter::Voter<T0>>(&v7), arg2, arg3));
        0x2::transfer::public_share_object<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::voter::Voter<T0>>(v7);
        0x2::transfer::public_share_object<0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::minter::Minter<T0>>(v3);
    }
    
    // decompiled from Move bytecode v6
}


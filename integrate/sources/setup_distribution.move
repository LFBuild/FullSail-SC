module integrate::setup_distribution {
    public entry fun create<T0>(arg0: &sui::package::Publisher, arg1: address, arg2: &sui::clock::Clock, arg3: &mut sui::tx_context::TxContext) {
        let (v0, v1) = distribution::minter::create<T0>(arg0, std::option::none<distribution::fullsail_token::MinterCap<T0>>(), arg3);
        let v2 = v1;
        let v3 = v0;
        let v4 = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut v4, std::type_name::get<T0>());
        let (v5, v6) = distribution::voter::create<T0>(arg0, v4, arg3);
        let v7 = v5;
        let (v8, v9) = distribution::reward_distributor::create<T0>(arg0, arg2, arg3);
        distribution::minter::set_notify_reward_cap<T0>(&mut v3, &v2, v6);
        distribution::minter::set_reward_distributor_cap<T0>(&mut v3, &v2, v9);
        distribution::minter::set_team_wallet<T0>(&mut v3, &v2, arg1);
        sui::transfer::public_transfer<distribution::minter::AdminCap>(v2, sui::tx_context::sender(arg3));
        sui::transfer::public_share_object<distribution::reward_distributor::RewardDistributor<T0>>(v8);
        sui::transfer::public_share_object<distribution::voting_escrow::VotingEscrow<T0>>(distribution::voting_escrow::create<T0>(arg0, sui::object::id<distribution::voter::Voter<T0>>(&v7), arg2, arg3));
        sui::transfer::public_share_object<distribution::voter::Voter<T0>>(v7);
        sui::transfer::public_share_object<distribution::minter::Minter<T0>>(v3);
    }
    
    // decompiled from Move bytecode v6
}


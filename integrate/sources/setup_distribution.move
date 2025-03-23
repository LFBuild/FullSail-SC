module integrate::setup_distribution {
    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        global_config: &clmm_pool::config::GlobalConfig,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        team_wallet: address,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (minter_immut, admin_cap) = distribution::minter::create<SailCoinType>(
            publisher,
            std::option::none<distribution::fullsail_token::MinterCap<SailCoinType>>(),
            ctx
        );
        let mut minter = minter_immut;
        let mut supported_coins = std::vector::empty<std::type_name::TypeName>();
        supported_coins.push_back(std::type_name::get<SailCoinType>());
        let (voter, notify_reward_cap) = distribution::voter::create<SailCoinType>(
            publisher,
            sui::object::id(global_config),
            sui::object::id(distribtuion_config),
            supported_coins,
            ctx
        );
        let (reward_distributor, reward_distributor_cap) = distribution::reward_distributor::create<SailCoinType>(
            publisher,
            clock,
            ctx
        );
        minter.set_notify_reward_cap(&admin_cap, notify_reward_cap);
        minter.set_reward_distributor_cap(&admin_cap, reward_distributor_cap);
        minter.set_team_wallet(&admin_cap, team_wallet);
        sui::transfer::public_transfer<distribution::minter::AdminCap>(
            admin_cap,
            sui::tx_context::sender(ctx)
        );
        sui::transfer::public_share_object<distribution::reward_distributor::RewardDistributor<SailCoinType>>(
            reward_distributor
        );
        sui::transfer::public_share_object<distribution::voting_escrow::VotingEscrow<SailCoinType>>(
            distribution::voting_escrow::create<SailCoinType>(
                publisher,
                sui::object::id<distribution::voter::Voter<SailCoinType>>(&voter),
                clock,
                ctx
            )
        );
        sui::transfer::public_share_object<distribution::voter::Voter<SailCoinType>>(voter);
        sui::transfer::public_share_object<distribution::minter::Minter<SailCoinType>>(minter);
    }
}


module integrate::setup_distribution {
    public entry fun create<FirstSailOptionCoinType>(
        publisher: &sui::package::Publisher,
        global_config: &clmm_pool::config::GlobalConfig,
        distribtuion_config: &distribution::distribution_config::DistributionConfig,
        team_wallet: address,
        treasury_cap: sui::coin::TreasuryCap<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (minter_immut, admin_cap) = distribution::minter::create<FirstSailOptionCoinType>(
            publisher,
            option::some(treasury_cap),
            ctx
        );
        let mut minter = minter_immut;
        let first_option_coin = std::type_name::get<FirstSailOptionCoinType>();
        let (voter, notify_reward_cap) = distribution::voter::create(
            publisher,
            object::id(global_config),
            object::id(distribtuion_config),
            first_option_coin,
            ctx
        );
        let (reward_distributor, reward_distributor_cap) = distribution::reward_distributor::create<FirstSailOptionCoinType>(
            publisher,
            clock,
            ctx
        );
        minter.set_notify_reward_cap(&admin_cap, notify_reward_cap);
        minter.set_reward_distributor_cap(&admin_cap, reward_distributor_cap);
        minter.set_team_wallet(&admin_cap, team_wallet);
        transfer::public_transfer<distribution::minter::AdminCap>(
            admin_cap,
            tx_context::sender(ctx)
        );
        transfer::public_share_object<distribution::reward_distributor::RewardDistributor<FirstSailOptionCoinType>>(
            reward_distributor
        );
        transfer::public_share_object<distribution::voting_escrow::VotingEscrow<FirstSailOptionCoinType>>(
            distribution::voting_escrow::create<FirstSailOptionCoinType>(
                publisher,
                object::id<distribution::voter::Voter>(&voter),
                clock,
                ctx
            )
        );
        transfer::public_share_object<distribution::voter::Voter>(voter);
        transfer::public_share_object<distribution::minter::Minter<FirstSailOptionCoinType>>(minter);
    }
}


module integrate::setup_distribution {
    public entry fun create<FirstSailOptionCoinType, SailCoinType>(
        publisher: &sui::package::Publisher,
        global_config: &clmm_pool::config::GlobalConfig,
        distribtuion_config: &mut distribution::distribution_config::DistributionConfig,
        team_wallet: address,
        treasury_cap: sui::coin::TreasuryCap<SailCoinType>,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (minter_immut, admin_cap) = distribution::minter::create<SailCoinType>(
            publisher,
            option::some(treasury_cap),
            object::id(distribtuion_config),
            ctx
        );
        let mut minter = minter_immut;
        let (voter, distribute_cap) = distribution::voter::create(
            publisher,
            object::id(global_config),
            object::id(distribtuion_config),
            ctx
        );
        let (reward_distributor, reward_distributor_cap) = distribution::reward_distributor::create<FirstSailOptionCoinType>(
            publisher,
            clock,
            ctx
        );
        minter.set_distribute_cap(&admin_cap, distribute_cap);
        minter.set_reward_distributor_cap(&admin_cap, reward_distributor_cap);
        minter.set_team_wallet(&admin_cap, team_wallet);
        minter.set_o_sail_price_aggregator(&admin_cap, distribtuion_config, aggregator);
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
        transfer::public_share_object<distribution::minter::Minter<SailCoinType>>(minter);
    }
}


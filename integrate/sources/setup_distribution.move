module integrate::setup_distribution {
    public entry fun create<SailCoinType>(
        minter_publisher: &sui::package::Publisher,
        voter_publisher: &sui::package::Publisher,
        rebase_distributor_publisher: &sui::package::Publisher,
        voting_escrow_publisher: &sui::package::Publisher,
        global_config: &clmm_pool::config::GlobalConfig,
        distribution_config: &mut distribution::distribution_config::DistributionConfig,
        team_wallet: address,
        treasury_cap: sui::coin::TreasuryCap<SailCoinType>,
        metadata: &sui::coin::CoinMetadata<SailCoinType>,
        aggregator: &switchboard::aggregator::Aggregator,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (minter_immut, admin_cap) = distribution::minter::create<SailCoinType>(
            minter_publisher,
            option::some(treasury_cap),
            metadata,
            object::id(distribution_config),
            ctx
        );
        let mut minter = minter_immut;
        let (mut voter, distribute_cap) = distribution::voter::create(
            voter_publisher,
            object::id(global_config),
            object::id(distribution_config),
            ctx
        );
        let (rebase_distributor, rebase_distributor_cap) = distribution::rebase_distributor::create<SailCoinType>(
            rebase_distributor_publisher,
            clock,
            ctx
        );
        minter.set_distribute_cap(&admin_cap, distribution_config, distribute_cap);
        minter.set_rebase_distributor_cap(&admin_cap, distribution_config,  rebase_distributor_cap);
        minter.set_team_wallet(&admin_cap, distribution_config, team_wallet);
        minter.set_o_sail_price_aggregator(&admin_cap, distribution_config, aggregator);
        minter.set_sail_price_aggregator(&admin_cap, distribution_config, aggregator);
        transfer::public_transfer<distribution::minter::AdminCap>(
            admin_cap,
            tx_context::sender(ctx)
        );
        transfer::public_share_object(rebase_distributor);
        let (voting_escrow, voting_escrow_cap) = ve::voting_escrow::create<SailCoinType>(
            voting_escrow_publisher,
            object::id<distribution::voter::Voter>(&voter),
            clock,
            ctx
        );
        transfer::public_share_object<ve::voting_escrow::VotingEscrow<SailCoinType>>(voting_escrow);
        voter.set_voting_escrow_cap(voter_publisher, voting_escrow_cap);
        transfer::public_share_object<distribution::voter::Voter>(voter);
        transfer::public_share_object<distribution::minter::Minter<SailCoinType>>(minter);
    }
}


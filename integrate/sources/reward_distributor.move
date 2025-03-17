module integrate::reward_distributor {
    public struct Claimable has copy, drop, store {
        lock_id: sui::object::ID,
        amount: u64,
    }

    public struct ClaimAndLock has copy, drop, store {
        lock_id: sui::object::ID,
        amount: u64,
    }

    public entry fun claimable<SailCoinType>(
        reward_distributor: &distribution::reward_distributor::RewardDistributor<SailCoinType>,
        voting_escrow: &distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: sui::object::ID
    ) {
        let claimable_event = Claimable {
            lock_id,
            amount: distribution::reward_distributor::claimable<SailCoinType>(
                reward_distributor,
                voting_escrow,
                lock_id
            ),
        };
        sui::event::emit<Claimable>(claimable_event);
    }

    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (reward_distributor, reward_distributor_cap) = distribution::reward_distributor::create<SailCoinType>(
            publisher,
            clock,
            ctx
        );
        sui::transfer::public_transfer<distribution::reward_distributor_cap::RewardDistributorCap>(
            reward_distributor_cap,
            sui::tx_context::sender(ctx)
        );
        sui::transfer::public_share_object<distribution::reward_distributor::RewardDistributor<SailCoinType>>(reward_distributor);
    }

    public entry fun claim_and_lock<SailCoinType>(
        reward_distributor: &mut distribution::reward_distributor::RewardDistributor<SailCoinType>,
        voting_escrow: &mut distribution::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut distribution::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let claim_and_lock_event = ClaimAndLock {
            lock_id: sui::object::id<distribution::voting_escrow::Lock>(lock),
            amount: distribution::reward_distributor::claim<SailCoinType>(
                reward_distributor,
                voting_escrow,
                lock,
                clock,
                ctx
            ),
        };
        sui::event::emit<ClaimAndLock>(claim_and_lock_event);
    }
}

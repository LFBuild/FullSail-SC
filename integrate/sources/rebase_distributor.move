module integrate::reward_distributor {
    public struct Claimable has copy, drop, store {
        lock_id: ID,
        amount: u64,
    }

    public struct ClaimAndLock has copy, drop, store {
        lock_id: ID,
        amount: u64,
    }

    public entry fun claimable<SailCoinType>(
        rebase_distributor: &distribution::rebase_distributor::RebaseDistributor<SailCoinType>,
        voting_escrow: &ve::voting_escrow::VotingEscrow<SailCoinType>,
        lock_id: ID
    ) {
        let claimable_event = Claimable {
            lock_id,
            amount: rebase_distributor.claimable(voting_escrow, lock_id),
        };
        sui::event::emit<Claimable>(claimable_event);
    }

    public entry fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let (rebase_distributor, rebase_distributor_cap) = distribution::rebase_distributor::create<SailCoinType>(
            publisher,
            clock,
            ctx
        );
        transfer::public_transfer<distribution::rebase_distributor_cap::RebaseDistributorCap>(
            rebase_distributor_cap,
            tx_context::sender(ctx)
        );
        transfer::public_share_object(rebase_distributor);
    }

    public entry fun claim_and_lock<SailCoinType>(
        rebase_distributor: &mut distribution::rebase_distributor::RebaseDistributor<SailCoinType>,
        voting_escrow: &mut ve::voting_escrow::VotingEscrow<SailCoinType>,
        lock: &mut ve::voting_escrow::Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let claim_and_lock_event = ClaimAndLock {
            lock_id: object::id<ve::voting_escrow::Lock>(lock),
            amount: rebase_distributor.claim(voting_escrow, lock, clock, ctx),
        };
        sui::event::emit<ClaimAndLock>(claim_and_lock_event);
    }
}

module 0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df::reward_distributor {
    struct Claimable has copy, drop, store {
        lock_id: 0x2::object::ID,
        amount: u64,
    }
    
    struct ClaimAndLock has copy, drop, store {
        lock_id: 0x2::object::ID,
        amount: u64,
    }
    
    public entry fun claimable<T0>(arg0: &distribution::reward_distributor::RewardDistributor<T0>, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: 0x2::object::ID) {
        let v0 = Claimable{
            lock_id : arg2, 
            amount  : distribution::reward_distributor::claimable<T0>(arg0, arg1, arg2),
        };
        0x2::event::emit<Claimable>(v0);
    }
    
    public entry fun create<T0>(arg0: &0x2::package::Publisher, arg1: &0x2::clock::Clock, arg2: &mut 0x2::tx_context::TxContext) {
        let (v0, v1) = distribution::reward_distributor::create<T0>(arg0, arg1, arg2);
        0x2::transfer::public_transfer<distribution::reward_distributor_cap::RewardDistributorCap>(v1, 0x2::tx_context::sender(arg2));
        0x2::transfer::public_share_object<distribution::reward_distributor::RewardDistributor<T0>>(v0);
    }
    
    public entry fun claim_and_lock<T0>(arg0: &mut distribution::reward_distributor::RewardDistributor<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &mut distribution::voting_escrow::Lock, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = ClaimAndLock{
            lock_id : 0x2::object::id<distribution::voting_escrow::Lock>(arg2), 
            amount  : distribution::reward_distributor::claim<T0>(arg0, arg1, arg2, arg3, arg4),
        };
        0x2::event::emit<ClaimAndLock>(v0);
    }
    
    // decompiled from Move bytecode v6
}

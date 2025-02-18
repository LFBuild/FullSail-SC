module integrate::reward_distributor {
    struct Claimable has copy, drop, store {
        lock_id: sui::object::ID,
        amount: u64,
    }
    
    struct ClaimAndLock has copy, drop, store {
        lock_id: sui::object::ID,
        amount: u64,
    }
    
    public entry fun claimable<T0>(arg0: &distribution::reward_distributor::RewardDistributor<T0>, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: sui::object::ID) {
        let v0 = Claimable{
            lock_id : arg2, 
            amount  : distribution::reward_distributor::claimable<T0>(arg0, arg1, arg2),
        };
        sui::event::emit<Claimable>(v0);
    }
    
    public entry fun create<T0>(arg0: &sui::package::Publisher, arg1: &sui::clock::Clock, arg2: &mut sui::tx_context::TxContext) {
        let (v0, v1) = distribution::reward_distributor::create<T0>(arg0, arg1, arg2);
        sui::transfer::public_transfer<distribution::reward_distributor_cap::RewardDistributorCap>(v1, sui::tx_context::sender(arg2));
        sui::transfer::public_share_object<distribution::reward_distributor::RewardDistributor<T0>>(v0);
    }
    
    public entry fun claim_and_lock<T0>(arg0: &mut distribution::reward_distributor::RewardDistributor<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &mut distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = ClaimAndLock{
            lock_id : sui::object::id<distribution::voting_escrow::Lock>(arg2), 
            amount  : distribution::reward_distributor::claim<T0>(arg0, arg1, arg2, arg3, arg4),
        };
        sui::event::emit<ClaimAndLock>(v0);
    }
    
    // decompiled from Move bytecode v6
}

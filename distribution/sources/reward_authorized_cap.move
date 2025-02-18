module distribution::reward_authorized_cap {
    public struct RewardAuthorizedCap has store, key {
        id: sui::object::UID,
        authorized: sui::object::ID,
    }
    
    public(package) fun create(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : RewardAuthorizedCap {
        RewardAuthorizedCap{
            id         : sui::object::new(arg1), 
            authorized : arg0,
        }
    }
    
    public fun validate(arg0: &RewardAuthorizedCap, arg1: sui::object::ID) {
        assert!(arg0.authorized == arg1, 9223372109869219839);
    }
    
    // decompiled from Move bytecode v6
}


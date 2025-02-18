module 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::reward_authorized_cap {
    struct RewardAuthorizedCap has store, key {
        id: 0x2::object::UID,
        authorized: 0x2::object::ID,
    }
    
    public(friend) fun create(arg0: 0x2::object::ID, arg1: &mut 0x2::tx_context::TxContext) : RewardAuthorizedCap {
        RewardAuthorizedCap{
            id         : 0x2::object::new(arg1), 
            authorized : arg0,
        }
    }
    
    public fun validate(arg0: &RewardAuthorizedCap, arg1: 0x2::object::ID) {
        assert!(arg0.authorized == arg1, 9223372109869219839);
    }
    
    // decompiled from Move bytecode v6
}


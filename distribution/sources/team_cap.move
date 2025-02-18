module 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::team_cap {
    struct TeamCap has store, key {
        id: 0x2::object::UID,
        target: 0x2::object::ID,
    }
    
    public(friend) fun create(arg0: 0x2::object::ID, arg1: &mut 0x2::tx_context::TxContext) : TeamCap {
        TeamCap{
            id     : 0x2::object::new(arg1), 
            target : arg0,
        }
    }
    
    public(friend) fun validate(arg0: &TeamCap, arg1: 0x2::object::ID) {
        assert!(arg0.target == arg1, 9223372118459154433);
    }
    
    // decompiled from Move bytecode v6
}


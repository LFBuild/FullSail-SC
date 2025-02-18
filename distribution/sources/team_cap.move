module distribution::team_cap {
    struct TeamCap has store, key {
        id: sui::object::UID,
        target: sui::object::ID,
    }
    
    public(friend) fun create(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : TeamCap {
        TeamCap{
            id     : sui::object::new(arg1), 
            target : arg0,
        }
    }
    
    public(friend) fun validate(arg0: &TeamCap, arg1: sui::object::ID) {
        assert!(arg0.target == arg1, 9223372118459154433);
    }
    
    // decompiled from Move bytecode v6
}


module distribution::team_cap {
    public struct TeamCap has store, key {
        id: sui::object::UID,
        target: sui::object::ID,
    }
    
    public(package) fun create(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : TeamCap {
        TeamCap{
            id     : sui::object::new(arg1), 
            target : arg0,
        }
    }
    
    public(package) fun validate(arg0: &TeamCap, arg1: sui::object::ID) {
        assert!(arg0.target == arg1, 9223372118459154433);
    }
    
    // decompiled from Move bytecode v6
}


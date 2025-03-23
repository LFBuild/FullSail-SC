module distribution::team_cap {
    public struct TeamCap has store, key {
        id: UID,
        target: ID,
    }

    public(package) fun create(arg0: ID, arg1: &mut TxContext): TeamCap {
        TeamCap {
            id: object::new(arg1),
            target: arg0,
        }
    }

    public(package) fun validate(arg0: &TeamCap, arg1: ID) {
        assert!(arg0.target == arg1, 9223372118459154433);
    }

    // decompiled from Move bytecode v6
}


module distribution::team_cap {
    const ETeamCapInvalid: u64 = 9223372118459154433;

    public struct TeamCap has store, key {
        id: UID,
        target: ID,
    }

    public(package) fun create(target: ID, ctx: &mut TxContext): TeamCap {
        TeamCap {
            id: object::new(ctx),
            target,
        }
    }

    public(package) fun validate(team_cap: &TeamCap, arg1: ID) {
        assert!(team_cap.target == arg1, ETeamCapInvalid);
    }

    // decompiled from Move bytecode v6
}


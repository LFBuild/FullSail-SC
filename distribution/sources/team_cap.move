/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module distribution::team_cap {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

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

    public(package) fun validate(team_cap: &TeamCap, target: ID) {
        assert!(team_cap.target == target, ETeamCapInvalid);
    }

}


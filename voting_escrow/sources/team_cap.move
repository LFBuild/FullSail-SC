/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::team_cap {
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ETeamCapInvalid: u64 = 9223372118459154433;

    public struct TeamCap has store, key {
        id: UID,
        target: ID,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
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


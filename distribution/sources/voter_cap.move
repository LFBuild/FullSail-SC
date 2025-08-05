/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module distribution::voter_cap {

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    const EEpochGovernorVoterIdInvalid: u64 = 9223372307437715457;
    const EGovernorVoterIdInvalid: u64 = 9223372200063533057;

    public struct VoterCap has store, key {
        id: UID,
        voter_id: ID,
    }

    public struct GovernorCap has store, key {
        id: UID,
        voter_id: ID,
        who: ID,
    }

    public struct EpochGovernorCap has store, key {
        id: UID,
        voter_id: ID,
    }

    public(package) fun create_epoch_governor_cap(
        voter_id: ID,
        ctx: &mut TxContext
    ): EpochGovernorCap {
        EpochGovernorCap {
            id: object::new(ctx),
            voter_id,
        }
    }

    public(package) fun create_governor_cap(
        voter_id: ID,
        who: address,
        ctx: &mut TxContext
    ): GovernorCap {
        GovernorCap {
            id: object::new(ctx),
            voter_id,
            who: object::id_from_address(who),
        }
    }

    public(package) fun create_voter_cap(voter_id: ID, ctx: &mut TxContext): VoterCap {
        VoterCap {
            id: object::new(ctx),
            voter_id,
        }
    }

    public fun drop_epoch_governor_cap(epoch_governor_cap: EpochGovernorCap) {
        let EpochGovernorCap {
            id       ,
            voter_id : _,
        } = epoch_governor_cap;
        object::delete(id);
    }

    public fun drop_governor_cap(governor_cap: GovernorCap) {
        let GovernorCap {
            id,
            voter_id: _,
            who: _,
        } = governor_cap;
        object::delete(id);
    }

    public fun epoch_governor_voter_id(epoch_governor_cap: &EpochGovernorCap): ID {
        epoch_governor_cap.voter_id
    }

    public fun get_voter_id(voter_cap: &VoterCap): ID {
        voter_cap.voter_id
    }

    public fun governor_voter_id(governor_cap: &GovernorCap): ID {
        governor_cap.voter_id
    }

    public fun validate_epoch_governor_voter_id(epoch_governor_cap: &EpochGovernorCap, voter_id: ID) {
        assert!(epoch_governor_cap.voter_id == voter_id, EEpochGovernorVoterIdInvalid);
    }

    public fun validate_governor_voter_id(governor_cap: &GovernorCap, voter_id: ID) {
        assert!(governor_cap.voter_id == voter_id, EGovernorVoterIdInvalid);
    }

    public fun who(governor_cap: &GovernorCap): ID {
        governor_cap.who
    }
}


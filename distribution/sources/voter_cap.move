module distribution::voter_cap {
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
        arg0: ID,
        arg1: &mut TxContext
    ): EpochGovernorCap {
        EpochGovernorCap {
            id: object::new(arg1),
            voter_id: arg0,
        }
    }

    public(package) fun create_governor_cap(
        arg0: ID,
        arg1: address,
        arg2: &mut TxContext
    ): GovernorCap {
        GovernorCap {
            id: object::new(arg2),
            voter_id: arg0,
            who: object::id_from_address(arg1),
        }
    }

    public(package) fun create_voter_cap(arg0: ID, arg1: &mut TxContext): VoterCap {
        VoterCap {
            id: object::new(arg1),
            voter_id: arg0,
        }
    }

    public fun drop_epoch_governor_cap(arg0: EpochGovernorCap) {
        let EpochGovernorCap {
            id       : v0,
            voter_id : _,
        } = arg0;
        object::delete(v0);
    }

    public fun drop_governor_cap(arg0: GovernorCap) {
        let GovernorCap {
            id: v0,
            voter_id: _,
            who: _,
        } = arg0;
        object::delete(v0);
    }

    public fun epoch_governor_voter_id(arg0: &EpochGovernorCap): ID {
        arg0.voter_id
    }

    public fun get_voter_id(arg0: &VoterCap): ID {
        arg0.voter_id
    }

    public fun governor_voter_id(arg0: &GovernorCap): ID {
        arg0.voter_id
    }

    public fun validate_epoch_governor_voter_id(arg0: &EpochGovernorCap, arg1: ID) {
        assert!(arg0.voter_id == arg1, 9223372307437715457);
    }

    public fun validate_governor_voter_id(arg0: &GovernorCap, arg1: ID) {
        assert!(arg0.voter_id == arg1, 9223372200063533057);
    }

    public fun who(arg0: &GovernorCap): ID {
        arg0.who
    }

    // decompiled from Move bytecode v6
}


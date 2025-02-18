module distribution::voter_cap {
    struct VoterCap has store, key {
        id: sui::object::UID,
        voter_id: sui::object::ID,
    }
    
    struct GovernorCap has store, key {
        id: sui::object::UID,
        voter_id: sui::object::ID,
        who: sui::object::ID,
    }
    
    struct EpochGovernorCap has store, key {
        id: sui::object::UID,
        voter_id: sui::object::ID,
    }
    
    public(friend) fun create_epoch_governor_cap(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : EpochGovernorCap {
        EpochGovernorCap{
            id       : sui::object::new(arg1), 
            voter_id : arg0,
        }
    }
    
    public(friend) fun create_governor_cap(arg0: sui::object::ID, arg1: address, arg2: &mut sui::tx_context::TxContext) : GovernorCap {
        GovernorCap{
            id       : sui::object::new(arg2), 
            voter_id : arg0, 
            who      : sui::object::id_from_address(arg1),
        }
    }
    
    public(friend) fun create_voter_cap(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : VoterCap {
        VoterCap{
            id       : sui::object::new(arg1), 
            voter_id : arg0,
        }
    }
    
    public fun drop_epoch_grovernor_cap(arg0: EpochGovernorCap) {
        let EpochGovernorCap {
            id       : v0,
            voter_id : _,
        } = arg0;
        sui::object::delete(v0);
    }
    
    public fun drop_governor_cap(arg0: GovernorCap) {
        let GovernorCap {
            id       : v0,
            voter_id : _,
            who      : _,
        } = arg0;
        sui::object::delete(v0);
    }
    
    public fun epoch_governor_voter_id(arg0: &EpochGovernorCap) : sui::object::ID {
        arg0.voter_id
    }
    
    public fun get_voter_id(arg0: &VoterCap) : sui::object::ID {
        arg0.voter_id
    }
    
    public fun governor_voter_id(arg0: &GovernorCap) : sui::object::ID {
        arg0.voter_id
    }
    
    public fun validate_epoch_governor_voter_id(arg0: &EpochGovernorCap, arg1: sui::object::ID) {
        assert!(arg0.voter_id == arg1, 9223372307437715457);
    }
    
    public fun validate_governor_voter_id(arg0: &GovernorCap, arg1: sui::object::ID) {
        assert!(arg0.voter_id == arg1, 9223372200063533057);
    }
    
    public fun who(arg0: &GovernorCap) : sui::object::ID {
        arg0.who
    }
    
    // decompiled from Move bytecode v6
}


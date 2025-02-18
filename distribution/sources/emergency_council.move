module distribution::emergency_council {
    struct EmergencyCouncilCap has store, key {
        id: sui::object::UID,
        voter: sui::object::ID,
    }
    
    public fun validate_emergency_council_voter_id(arg0: &EmergencyCouncilCap, arg1: sui::object::ID) {
        assert!(arg0.voter == arg1, 9223372084099416065);
    }
    
    // decompiled from Move bytecode v6
}


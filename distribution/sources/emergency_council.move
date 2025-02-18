module 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::emergency_council {
    struct EmergencyCouncilCap has store, key {
        id: 0x2::object::UID,
        voter: 0x2::object::ID,
    }
    
    public fun validate_emergency_council_voter_id(arg0: &EmergencyCouncilCap, arg1: 0x2::object::ID) {
        assert!(arg0.voter == arg1, 9223372084099416065);
    }
    
    // decompiled from Move bytecode v6
}


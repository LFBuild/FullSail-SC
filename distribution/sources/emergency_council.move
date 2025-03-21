module distribution::emergency_council {

    const EEmergencyCouncilDoesNotMatchVoter: u64 = 9223372084099416065;

    public struct EmergencyCouncilCap has store, key {
        id: sui::object::UID,
        voter: sui::object::ID,
    }

    public fun validate_emergency_council_voter_id(emergency_council_cap: &EmergencyCouncilCap, voter_id: sui::object::ID) {
        assert!(emergency_council_cap.voter == voter_id, EEmergencyCouncilDoesNotMatchVoter);
    }
}


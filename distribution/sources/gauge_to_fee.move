module distribution::gauge_to_fee {
    public struct GaugeToFeeProof {
        voter: sui::object::ID,
        gauge: sui::object::ID,
        reward: sui::object::ID,
    }
    
    public fun consume(arg0: GaugeToFeeProof) : (sui::object::ID, sui::object::ID, sui::object::ID) {
        let GaugeToFeeProof {
            voter  : v0,
            gauge  : v1,
            reward : v2,
        } = arg0;
        (v0, v1, v2)
    }
    
    public(package) fun issue(arg0: sui::object::ID, arg1: sui::object::ID, arg2: sui::object::ID) : GaugeToFeeProof {
        GaugeToFeeProof{
            voter  : arg0, 
            gauge  : arg1, 
            reward : arg2,
        }
    }
    
    // decompiled from Move bytecode v6
}


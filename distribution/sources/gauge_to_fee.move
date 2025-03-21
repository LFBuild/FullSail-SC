module distribution::gauge_to_fee {
    public struct GaugeToFeeProof {
        voter: sui::object::ID,
        gauge: sui::object::ID,
        reward: sui::object::ID,
    }

    public fun consume(gauge_to_fee_proof: GaugeToFeeProof): (sui::object::ID, sui::object::ID, sui::object::ID) {
        let GaugeToFeeProof {
            voter,
            gauge,
            reward,
        } = gauge_to_fee_proof;
        (voter, gauge, reward)
    }

    public(package) fun issue(voter: sui::object::ID, gauge: sui::object::ID, reward: sui::object::ID): GaugeToFeeProof {
        GaugeToFeeProof {
            voter,
            gauge,
            reward,
        }
    }
}


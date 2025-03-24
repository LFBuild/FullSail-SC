module distribution::gauge_to_fee {
    public struct GaugeToFeeProof {
        voter: ID,
        gauge: ID,
        reward: ID,
    }

    public fun consume(gauge_to_fee_proof: GaugeToFeeProof): (ID, ID, ID) {
        let GaugeToFeeProof {
            voter,
            gauge,
            reward,
        } = gauge_to_fee_proof;
        (voter, gauge, reward)
    }

    public(package) fun issue(voter: ID, gauge: ID, reward: ID): GaugeToFeeProof {
        GaugeToFeeProof {
            voter,
            gauge,
            reward,
        }
    }
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module distribution::gauge_to_fee {

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

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


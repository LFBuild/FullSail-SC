/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::reward_distributor_cap {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ERewardDistributorInvalid: u64 = 9223372105574252543;

    public struct RewardDistributorCap has store, key {
        id: UID,
        reward_distributor: ID,
    }

    public(package) fun create(reward_distributor_id: ID, ctx: &mut TxContext): RewardDistributorCap {
        RewardDistributorCap {
            id: object::new(ctx),
            reward_distributor: reward_distributor_id,
        }
    }

    public fun validate(reward_distributor_cap: &RewardDistributorCap, reward_distributor_id: ID) {
        assert!(reward_distributor_cap.reward_distributor == reward_distributor_id, ERewardDistributorInvalid);
    }
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::reward_cap {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ERewardCapInvalid: u64 = 938607256488826100;

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    public struct RewardCap has store, key {
        id: UID,
        reward_id: ID,
    }

    public(package) fun create(reward_id: ID, ctx: &mut TxContext): RewardCap {
        RewardCap {
            id: object::new(ctx),
            reward_id,
        }
    }

    public fun validate(reward_cap: &RewardCap, reward_id: ID) {
        assert!(reward_cap.reward_id == reward_id, ERewardCapInvalid);
    }
}


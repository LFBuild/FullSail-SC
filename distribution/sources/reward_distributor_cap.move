module distribution::reward_distributor_cap {
    public struct RewardDistributorCap has store, key {
        id: UID,
        reward_distributor: ID,
    }

    public(package) fun create(arg0: ID, arg1: &mut TxContext): RewardDistributorCap {
        RewardDistributorCap {
            id: object::new(arg1),
            reward_distributor: arg0,
        }
    }

    public fun validate(arg0: &RewardDistributorCap, arg1: ID) {
        assert!(arg0.reward_distributor == arg1, 9223372105574252543);
    }

    // decompiled from Move bytecode v6
}


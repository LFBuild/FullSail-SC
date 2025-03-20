module distribution::reward_distributor_cap {
    public struct RewardDistributorCap has store, key {
        id: sui::object::UID,
        reward_distributor: sui::object::ID,
    }

    public(package) fun create(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext): RewardDistributorCap {
        RewardDistributorCap {
            id: sui::object::new(arg1),
            reward_distributor: arg0,
        }
    }

    public fun validate(arg0: &RewardDistributorCap, arg1: sui::object::ID) {
        assert!(arg0.reward_distributor == arg1, 9223372105574252543);
    }

    // decompiled from Move bytecode v6
}


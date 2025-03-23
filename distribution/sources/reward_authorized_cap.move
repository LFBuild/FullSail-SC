module distribution::reward_authorized_cap {
    public struct RewardAuthorizedCap has store, key {
        id: UID,
        authorized: ID,
    }

    public(package) fun create(arg0: ID, arg1: &mut TxContext): RewardAuthorizedCap {
        RewardAuthorizedCap {
            id: object::new(arg1),
            authorized: arg0,
        }
    }

    public fun validate(arg0: &RewardAuthorizedCap, arg1: ID) {
        assert!(arg0.authorized == arg1, 9223372109869219839);
    }

    // decompiled from Move bytecode v6
}


module distribution::notify_reward_cap {
    public struct NOTIFY_REWARD_CAP has drop {}

    public struct NotifyRewardCap has store, key {
        id: UID,
        voter_id: ID,
        who: ID,
    }

    public fun create(
        _arg0: &sui::package::Publisher,
        arg1: ID,
        arg2: ID,
        arg3: &mut TxContext
    ): NotifyRewardCap {
        NotifyRewardCap {
            id: object::new(arg3),
            voter_id: arg1,
            who: arg2,
        }
    }

    public(package) fun create_internal(arg0: ID, arg1: &mut TxContext): NotifyRewardCap {
        NotifyRewardCap {
            id: object::new(arg1),
            voter_id: arg0,
            who: object::id_from_address(tx_context::sender(arg1)),
        }
    }

    public fun grant(
        _arg0: &sui::package::Publisher,
        arg1: ID,
        arg2: address,
        arg3: &mut TxContext
    ) {
        assert!(arg2 != @0x0, 9223372191473598463);
        let v0 = NotifyRewardCap {
            id: object::new(arg3),
            voter_id: arg1,
            who: object::id_from_address(arg2),
        };
        transfer::transfer<NotifyRewardCap>(v0, arg2);
    }

    fun init(arg0: NOTIFY_REWARD_CAP, arg1: &mut TxContext) {
        sui::package::claim_and_keep<NOTIFY_REWARD_CAP>(arg0, arg1);
    }

    public fun validate_notify_reward_voter_id(arg0: &NotifyRewardCap, arg1: ID) {
        assert!(arg0.voter_id == arg1, 9223372135639023617);
    }

    public fun who(arg0: &NotifyRewardCap): ID {
        arg0.who
    }

    // decompiled from Move bytecode v6
}


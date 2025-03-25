module distribution::notify_reward_cap {
    const EGrantInvalidWho: u64 = 9223372191473598463;
    const EValidateNotifyRewardInvalidVoter: u64 = 9223372135639023617;

    public struct NOTIFY_REWARD_CAP has drop {}

    public struct NotifyRewardCap has store, key {
        id: UID,
        voter_id: ID,
        who: ID,
    }

    public fun create(
        _publisher: &sui::package::Publisher,
        voter_id: ID,
        who: ID,
        ctx: &mut TxContext
    ): NotifyRewardCap {
        NotifyRewardCap {
            id: object::new(ctx),
            voter_id,
            who,
        }
    }

    public(package) fun create_internal(voter_id: ID, arg1: &mut TxContext): NotifyRewardCap {
        NotifyRewardCap {
            id: object::new(arg1),
            voter_id,
            who: object::id_from_address(tx_context::sender(arg1)),
        }
    }

    public fun grant(
        _arg0: &sui::package::Publisher,
        voter_id: ID,
        who: address,
        ctx: &mut TxContext
    ) {
        assert!(who != @0x0, EGrantInvalidWho);
        let notify_reward_cap = NotifyRewardCap {
            id: object::new(ctx),
            voter_id,
            who: object::id_from_address(who),
        };
        transfer::transfer<NotifyRewardCap>(notify_reward_cap, who);
    }

    fun init(otw: NOTIFY_REWARD_CAP, ctx: &mut TxContext) {
        sui::package::claim_and_keep<NOTIFY_REWARD_CAP>(otw, ctx);
    }

    public fun validate_notify_reward_voter_id(notify_reward_cap: &NotifyRewardCap, voter_id: ID) {
        assert!(notify_reward_cap.voter_id == voter_id, EValidateNotifyRewardInvalidVoter);
    }

    public fun who(notify_reward_cap: &NotifyRewardCap): ID {
        notify_reward_cap.who
    }
}


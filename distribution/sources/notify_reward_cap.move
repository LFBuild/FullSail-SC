module distribution::notify_reward_cap {
    public struct NOTIFY_REWARD_CAP has drop {
        dummy_field: bool,
    }
    
    public struct NotifyRewardCap has store, key {
        id: sui::object::UID,
        voter_id: sui::object::ID,
        who: sui::object::ID,
    }
    
    public fun create(arg0: &sui::package::Publisher, arg1: sui::object::ID, arg2: sui::object::ID, arg3: &mut sui::tx_context::TxContext) : NotifyRewardCap {
        NotifyRewardCap{
            id       : sui::object::new(arg3), 
            voter_id : arg1, 
            who      : arg2,
        }
    }
    
    public(package) fun create_internal(arg0: sui::object::ID, arg1: &mut sui::tx_context::TxContext) : NotifyRewardCap {
        NotifyRewardCap{
            id       : sui::object::new(arg1), 
            voter_id : arg0, 
            who      : sui::object::id_from_address(sui::tx_context::sender(arg1)),
        }
    }
    
    public fun grant(arg0: &sui::package::Publisher, arg1: sui::object::ID, arg2: address, arg3: &mut sui::tx_context::TxContext) {
        assert!(arg2 != @0x0, 9223372191473598463);
        let v0 = NotifyRewardCap{
            id       : sui::object::new(arg3), 
            voter_id : arg1, 
            who      : sui::object::id_from_address(arg2),
        };
        sui::transfer::transfer<NotifyRewardCap>(v0, arg2);
    }
    
    fun init(arg0: NOTIFY_REWARD_CAP, arg1: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<NOTIFY_REWARD_CAP>(arg0, arg1);
    }
    
    public fun validate_notify_reward_voter_id(arg0: &NotifyRewardCap, arg1: sui::object::ID) {
        assert!(arg0.voter_id == arg1, 9223372135639023617);
    }
    
    public fun who(arg0: &NotifyRewardCap) : sui::object::ID {
        arg0.who
    }
    
    // decompiled from Move bytecode v6
}


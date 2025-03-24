module distribution::voting_dao {
    public struct VotingDAO has store {
        delegates: sui::table::Table<ID, ID>,
        nonces: sui::table::Table<address, u64>,
        num_checkpoints: sui::table::Table<ID, u64>,
        checkpoints: sui::table::Table<ID, sui::table::Table<u64, Checkpoint>>,
    }

    public struct Checkpoint has copy, drop, store {
        from_timestamp: u64,
        owner: address,
        delegated_balance: u64,
        delegatee: ID,
    }

    public(package) fun checkpoint_delegatee(
        arg0: &mut VotingDAO,
        arg1: ID,
        arg2: u64,
        arg3: bool,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        if (arg1 == object::id_from_address(@0x0)) {
            return
        };
        let v0 = if (arg0.num_checkpoints.contains(arg1)) {
            *arg0.num_checkpoints.borrow(arg1)
        } else {
            0
        };
        let v1 = if (v0 > 0) {
            *arg0.checkpoints.borrow(arg1).borrow(v0 - 1)
        } else {
            if (!arg0.checkpoints.contains(arg1)) {
                arg0.checkpoints.add(arg1, sui::table::new<u64, Checkpoint>(arg5));
            };
            arg0.checkpoints.borrow_mut(arg1).add(0, create_checkpoint());
            *arg0.checkpoints.borrow(arg1).borrow(0)
        };
        let v2 = v1;
        let mut v3 = create_checkpoint();
        v3.from_timestamp = get_block_timestamp(arg4);
        v3.owner = v2.owner;
        let v4 = if (arg3) {
            v2.delegated_balance + arg2
        } else {
            let v5 = if (arg2 < v2.delegated_balance) {
                v2.delegated_balance - arg2
            } else {
                0
            };
            v5
        };
        v3.delegated_balance = v4;
        v3.delegatee = v2.delegatee;
        if (arg0.is_checkpoint_in_new_block(arg1, get_block_timestamp(arg4))) {
            let v6 = if (arg0.num_checkpoints.contains(arg1)) {
                arg0.num_checkpoints.remove(arg1)
            } else {
                0
            };
            let v7 = v6 + 1;
            arg0.num_checkpoints.add(arg1, v7);
            if (!arg0.checkpoints.contains(arg1)) {
                arg0.checkpoints.add(arg1, sui::table::new<u64, Checkpoint>(arg5));
            };
            arg0.checkpoints.borrow_mut(arg1).add(v7, v3);
        } else {
            let v8 = arg0.checkpoints.borrow_mut(arg1);
            v8.remove(v0 - 1);
            v8.add(v0 - 1, v3);
        };
    }

    public(package) fun checkpoint_delegator(
        arg0: &mut VotingDAO,
        arg1: ID,
        arg2: u64,
        arg3: ID,
        arg4: address,
        arg5: &sui::clock::Clock,
        arg6: &mut TxContext
    ) {
        let v0 = if (arg0.num_checkpoints.contains(arg1)) {
            *arg0.num_checkpoints.borrow(arg1)
        } else {
            arg0.num_checkpoints.add(arg1, 0);
            0
        };
        let v1 = if (v0 > 0) {
            *arg0.checkpoints.borrow(arg1).borrow(v0 - 1)
        } else {
            if (!arg0.checkpoints.contains(arg1)) {
                arg0.checkpoints.add(arg1, sui::table::new<u64, Checkpoint>(arg6));
            };
            create_checkpoint()
        };
        let v2 = v1;
        assert!(
            arg0.checkpoints.borrow(arg1).length() == v0,
            9223372642445164543
        );
        arg0.checkpoint_delegatee(v2.delegatee, arg2, false, arg5, arg6);
        let mut v3 = create_checkpoint();
        v3.from_timestamp = get_block_timestamp(arg5);
        v3.delegated_balance = v2.delegated_balance;
        v3.delegatee = arg3;
        v3.owner = arg4;
        if (arg0.is_checkpoint_in_new_block(arg1, get_block_timestamp(arg5))) {
            let num_checkpoints_new = arg0.num_checkpoints.remove(arg1) + 1;
            arg0.num_checkpoints.add(arg1, num_checkpoints_new);
            arg0.checkpoints.borrow_mut(arg1).add(v0, v3);
        } else {
            arg0.checkpoints.borrow_mut(arg1).remove(v0 - 1);
            arg0.checkpoints.borrow_mut(arg1).add(v0 - 1, v3);
        };
        if (arg0.delegates.contains(arg1)) {
            arg0.delegates.remove(arg1);
        };
        arg0.delegates.add(arg1, arg3);
    }

    public(package) fun create(arg0: &mut TxContext): VotingDAO {
        VotingDAO {
            delegates: sui::table::new<ID, ID>(arg0),
            nonces: sui::table::new<address, u64>(arg0),
            num_checkpoints: sui::table::new<ID, u64>(arg0),
            checkpoints: sui::table::new<ID, sui::table::Table<u64, Checkpoint>>(arg0),
        }
    }

    fun create_checkpoint(): Checkpoint {
        Checkpoint {
            from_timestamp: 0,
            owner: @0x0,
            delegated_balance: 0,
            delegatee: object::id_from_address(@0x0),
        }
    }

    public(package) fun delegatee(arg0: &VotingDAO, arg1: ID): ID {
        *arg0.delegates.borrow(arg1)
    }

    public fun get_block_timestamp(arg0: &sui::clock::Clock): u64 {
        arg0.timestamp_ms()
    }

    fun is_checkpoint_in_new_block(arg0: &VotingDAO, arg1: ID, arg2: u64): bool {
        let v0 = if (arg0.num_checkpoints.contains(arg1)) {
            *arg0.num_checkpoints.borrow(arg1)
        } else {
            0
        };
        let v1 = v0 > 0 && arg2 - arg0.checkpoints.borrow(arg1).borrow(
            v0 - 1
        ).from_timestamp < distribution::common::get_time_to_finality();
        !v1
    }

    // decompiled from Move bytecode v6
}


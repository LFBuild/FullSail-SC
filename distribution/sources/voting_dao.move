module distribution::voting_dao {
    public struct VotingDAO has store {
        delegates: sui::table::Table<sui::object::ID, sui::object::ID>,
        nonces: sui::table::Table<address, u64>,
        num_checkpoints: sui::table::Table<sui::object::ID, u64>,
        checkpoints: sui::table::Table<sui::object::ID, sui::table::Table<u64, Checkpoint>>,
    }
    
    public struct Checkpoint has copy, drop, store {
        from_timestamp: u64,
        owner: address,
        delegated_balance: u64,
        delegatee: sui::object::ID,
    }
    
    public(package) fun checkpoint_delegatee(arg0: &mut VotingDAO, arg1: sui::object::ID, arg2: u64, arg3: bool, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        if (arg1 == sui::object::id_from_address(@0x0)) {
            return
        };
        let v0 = if (sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
            *sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)
        } else {
            0
        };
        let v1 = if (v0 > 0) {
            *sui::table::borrow<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1), v0 - 1)
        } else {
            if (!sui::table::contains<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1)) {
                sui::table::add<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1, sui::table::new<u64, Checkpoint>(arg5));
            };
            sui::table::add<u64, Checkpoint>(sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1), 0, create_checkpoint());
            *sui::table::borrow<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1), 0)
        };
        let v2 = v1;
        assert!(sui::table::length<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1)) == v0, 9223372307437715455);
        let mut v3 = create_checkpoint();
        v3.from_timestamp = get_block_timestamp(arg4);
        assert!(v2.owner != @0x0, 9223372346092421119);
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
        if (is_checkpoint_in_new_block(arg0, arg1, get_block_timestamp(arg4))) {
            let checkpoint_value = sui::table::remove<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1) + 1;
            sui::table::add<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1, checkpoint_value);
            sui::table::add<u64, Checkpoint>(sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1), v0, v3);
        } else {
            let v6 = sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1);
            sui::table::remove<u64, Checkpoint>(v6, v0 - 1);
            sui::table::add<u64, Checkpoint>(v6, v0 - 1, v3);
        };
    }
    
    public(package) fun checkpoint_delegator(arg0: &mut VotingDAO, arg1: sui::object::ID, arg2: u64, arg3: sui::object::ID, arg4: address, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        let v0 = if (sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
            *sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)
        } else {
            sui::table::add<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1, 0);
            0
        };
        let v1 = if (v0 > 0) {
            *sui::table::borrow<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1), v0 - 1)
        } else {
            if (!sui::table::contains<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1)) {
                sui::table::add<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1, sui::table::new<u64, Checkpoint>(arg6));
            };
            create_checkpoint()
        };
        let v2 = v1;
        assert!(sui::table::length<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1)) == v0, 9223372608085426175);
        checkpoint_delegatee(arg0, v2.delegatee, arg2, false, arg5, arg6);
        let mut v3 = create_checkpoint();
        v3.from_timestamp = get_block_timestamp(arg5);
        v3.delegated_balance = v2.delegated_balance;
        v3.delegatee = arg3;
        v3.owner = arg4;
        if (is_checkpoint_in_new_block(arg0, arg1, get_block_timestamp(arg5))) {
            let checkpoint_value = sui::table::remove<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1) + 1;
            sui::table::add<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1, checkpoint_value);
            sui::table::add<u64, Checkpoint>(sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1), v0, v3);
        } else {
            sui::table::remove<u64, Checkpoint>(sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1), v0 - 1);
            sui::table::add<u64, Checkpoint>(sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&mut arg0.checkpoints, arg1), v0 - 1, v3);
        };
        if (sui::table::contains<sui::object::ID, sui::object::ID>(&arg0.delegates, arg1)) {
            sui::table::remove<sui::object::ID, sui::object::ID>(&mut arg0.delegates, arg1);
        };
        sui::table::add<sui::object::ID, sui::object::ID>(&mut arg0.delegates, arg1, arg3);
    }
    
    public(package) fun create(arg0: &mut sui::tx_context::TxContext) : VotingDAO {
        VotingDAO{
            delegates       : sui::table::new<sui::object::ID, sui::object::ID>(arg0), 
            nonces          : sui::table::new<address, u64>(arg0), 
            num_checkpoints : sui::table::new<sui::object::ID, u64>(arg0), 
            checkpoints     : sui::table::new<sui::object::ID, sui::table::Table<u64, Checkpoint>>(arg0),
        }
    }
    
    fun create_checkpoint() : Checkpoint {
        Checkpoint{
            from_timestamp    : 0, 
            owner             : @0x0, 
            delegated_balance : 0, 
            delegatee         : sui::object::id_from_address(@0x0),
        }
    }
    
    public(package) fun delegatee(arg0: &VotingDAO, arg1: sui::object::ID) : sui::object::ID {
        *sui::table::borrow<sui::object::ID, sui::object::ID>(&arg0.delegates, arg1)
    }
    
    fun get_block_timestamp(arg0: &sui::clock::Clock) : u64 {
        sui::clock::timestamp_ms(arg0)
    }
    
    fun is_checkpoint_in_new_block(arg0: &VotingDAO, arg1: sui::object::ID, arg2: u64) : bool {
        let v0 = if (sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
            *sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)
        } else {
            0
        };
        let v1 = v0 > 0 && arg2 - sui::table::borrow<u64, Checkpoint>(sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1), v0 - 1).from_timestamp < distribution::common::get_time_to_finality();
        !v1
    }
    
    // decompiled from Move bytecode v6
}


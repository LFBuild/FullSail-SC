/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module voting_escrow::voting_dao {
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    public struct VotingDAO has store {
        delegates: sui::table::Table<ID, ID>,
        nonces: sui::table::Table<address, u64>,
        num_checkpoints: sui::table::Table<ID, u64>,
        checkpoints: sui::table::Table<ID, sui::table::Table<u64, Checkpoint>>,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public struct Checkpoint has copy, drop, store {
        from_timestamp: u64,
        owner: address,
        delegated_balance: u64,
        delegatee: ID,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    public(package) fun checkpoint_delegator(
        voting_dao: &mut VotingDAO,
        lock_id: ID,
        balance_amount: u64,
        delegatee: ID,
        owner_of_lock: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let num_checkpoint = if (voting_dao.num_checkpoints.contains(lock_id)) {
            *voting_dao.num_checkpoints.borrow(lock_id)
        } else {
            voting_dao.num_checkpoints.add(lock_id, 0);
            0
        };
        let _checkpoint = if (num_checkpoint > 0) {
            *voting_dao.checkpoints.borrow(lock_id).borrow(num_checkpoint - 1)
        } else {
            if (!voting_dao.checkpoints.contains(lock_id)) {
                voting_dao.checkpoints.add(lock_id, sui::table::new<u64, Checkpoint>(ctx));
            };
            create_checkpoint()
        };
        let checkpoint = _checkpoint;
        assert!(
            voting_dao.checkpoints.borrow(lock_id).length() == num_checkpoint,
            9223372642445164543
        );
        voting_dao.checkpoint_delegatee(checkpoint.delegatee, balance_amount, false, clock, ctx);
        let mut new_checkpoint = create_checkpoint();
        new_checkpoint.from_timestamp = get_block_timestamp(clock);
        new_checkpoint.delegated_balance = checkpoint.delegated_balance;
        new_checkpoint.delegatee = delegatee;
        new_checkpoint.owner = owner_of_lock;
        if (voting_dao.is_checkpoint_in_new_block(lock_id, get_block_timestamp(clock))) {
            let num_checkpoints_new = voting_dao.num_checkpoints.remove(lock_id) + 1;
            voting_dao.num_checkpoints.add(lock_id, num_checkpoints_new);
            voting_dao.checkpoints.borrow_mut(lock_id).add(num_checkpoint, new_checkpoint);
        } else {
            voting_dao.checkpoints.borrow_mut(lock_id).remove(num_checkpoint - 1);
            voting_dao.checkpoints.borrow_mut(lock_id).add(num_checkpoint - 1, new_checkpoint);
        };
        if (voting_dao.delegates.contains(lock_id)) {
            voting_dao.delegates.remove(lock_id);
        };
        voting_dao.delegates.add(lock_id, delegatee);
    }

    public(package) fun checkpoint_delegatee(
        voting_dao: &mut VotingDAO,
        delegatee: ID,
        balance_amount: u64,
        is_increase: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        if (delegatee == object::id_from_address(@0x0)) {
            return
        };
        let num_checkpoint = if (voting_dao.num_checkpoints.contains(delegatee)) {
            *voting_dao.num_checkpoints.borrow(delegatee)
        } else {
            0
        };
        let _checkpoint = if (num_checkpoint > 0) {
            *voting_dao.checkpoints.borrow(delegatee).borrow(num_checkpoint - 1)
        } else {
            if (!voting_dao.checkpoints.contains(delegatee)) {
                voting_dao.checkpoints.add(delegatee, sui::table::new<u64, Checkpoint>(ctx));
            };
            voting_dao.checkpoints.borrow_mut(delegatee).add(0, create_checkpoint());
            *voting_dao.checkpoints.borrow(delegatee).borrow(0)
        };
        let checkpoint = _checkpoint;
        let mut new_checkpoint = create_checkpoint();
        new_checkpoint.from_timestamp = get_block_timestamp(clock);
        new_checkpoint.owner = checkpoint.owner;
        let new_delegated_balance = if (is_increase) {
            checkpoint.delegated_balance + balance_amount
        } else {
            let remaining_balance = if (balance_amount < checkpoint.delegated_balance) {
                checkpoint.delegated_balance - balance_amount
            } else {
                0
            };
            remaining_balance
        };
        new_checkpoint.delegated_balance = new_delegated_balance;
        new_checkpoint.delegatee = checkpoint.delegatee;
        if (voting_dao.is_checkpoint_in_new_block(delegatee, get_block_timestamp(clock))) {
            let num_checkpoints_new = if (voting_dao.num_checkpoints.contains(delegatee)) {
                voting_dao.num_checkpoints.remove(delegatee)
            } else {
                0
            };
            let num_checkpoints_new_next = num_checkpoints_new + 1;
            voting_dao.num_checkpoints.add(delegatee, num_checkpoints_new_next);
            if (!voting_dao.checkpoints.contains(delegatee)) {
                voting_dao.checkpoints.add(delegatee, sui::table::new<u64, Checkpoint>(ctx));
            };
            voting_dao.checkpoints.borrow_mut(delegatee).add(num_checkpoints_new_next, new_checkpoint);
        } else {
            let checkpoints = voting_dao.checkpoints.borrow_mut(delegatee);
            checkpoints.remove(num_checkpoint - 1);
            checkpoints.add(num_checkpoint - 1, new_checkpoint);
        };
    }

    public(package) fun create(ctx: &mut TxContext): VotingDAO {
        VotingDAO {
            delegates: sui::table::new<ID, ID>(ctx),
            nonces: sui::table::new<address, u64>(ctx),
            num_checkpoints: sui::table::new<ID, u64>(ctx),
            checkpoints: sui::table::new<ID, sui::table::Table<u64, Checkpoint>>(ctx),
            // bag to be preapred for future updates
            bag: sui::bag::new(ctx),
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

    public(package) fun delegatee(voting_dao: &VotingDAO, lock_id: ID): ID {
        *voting_dao.delegates.borrow(lock_id)
    }

    public fun get_block_timestamp(clock: &sui::clock::Clock): u64 {
        clock.timestamp_ms()
    }

    fun is_checkpoint_in_new_block(voting_dao: &VotingDAO, delegatee: ID, timestamp: u64): bool {
        let num_checkpoint = if (voting_dao.num_checkpoints.contains(delegatee)) {
            *voting_dao.num_checkpoints.borrow(delegatee)
        } else {
            0
        };
        let is_checkpoint_in_new_block = num_checkpoint > 0 && timestamp - voting_dao.checkpoints.borrow(delegatee).borrow(
            num_checkpoint - 1
        ).from_timestamp < voting_escrow::common::get_time_to_finality_ms();
        !is_checkpoint_in_new_block
    }
}


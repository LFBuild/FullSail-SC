/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module distribution::voting_escrow {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    
    // Error constants
    const ECreateVotingEscrowInvalidPublisher: u64 = 184812403570428600;
    const ESplitOwnerNotFound: u64 = 922337599252162153;
    const ESplitNotAllowed: u64 = 922337600111090075;
    const ESplitNotNormalEscrow: u64 = 922337600540613020; 
    const ESplitPositionVoted: u64 = 922337600970122857;
    const ESplitAmountZero: u64 = 922337603117462323;
    const ESplitAmountExceedsLocked: u64 = 922337603547116342;
    const ETransferInvalidEscrow: u64 = 922337686439801651;
    const ETransferLockedPosition: u64 = 922337688587377051;
    const ETransferNotOwner: u64 = 922337689875775487;
    const EWithdrawPositionVoted: u64 = 922337640483821980;
    const EAddAllowedManagerInvalidPublisher: u64 = 277556739040212930;
    const EWithdrawPositionNotNormalEscrow: u64 = 922337640913305602;
    const EWithdrawPermanentPosition: u64 = 922337642201861328;
    const EWithdrawBeforeEndTime: u64 = 922337643060684391;
    const ECreateLockAmountZero: u64 = 922337438190718157;
    const ECreateLockAmountMismatch: u64 = 922337441626665779;
    const ECreateLockForAmountZero: u64 = 922337425735312998;
    const ECreateLockForAmountMismatch: u64 = 922337428741763891;
    const ECreateLockPerpetualMustBePermanent: u64 = 833590534380215700;
    const ECreateLockOwnerExists: u64 = 922337417145352191;
    const ECreateLockLockedExists: u64 = 922337417574848921;
    const ECreateManagedNotAllowedManager: u64 = 922337773627768834;
    const EDepositForDeactivatedLock: u64 = 422370226116838300;
    const EDelegateNotPermanent: u64 = 922337565751338600;
    const EDelegateInvalidDelegatee: u64 = 922337566180861544;
    const EDelegateOwnershipChangeTooRecent: u64 = 922337568328410729;
    const EDepositManagedInvalidVoter: u64 = 922337783935559270;
    const EDepositManagedNotManagedType: u64 = 922337784794827985;
    const EDepositManagedDeactivated: u64 = 922337785224429573;
    const EDepositManagedNotNormalEscrow: u64 = 922337785653703477;
    const EDepositManagedNoBalance: u64 = 922337786512565862;
    const EIncreaseAmountDeactivatedLock: u64 = 686510248139248600;
    const EIncreaseAmountZero: u64 = 922337446351156019;
    const EIncreaseAmountLockedEscrow: u64 = 922337447210215015;
    const EIncreaseAmountNotExists: u64 = 922337448498613452;
    const EIncreaseAmountNoBalance: u64 = 922337448498718312;
    const EIncreaseTimeNotNormalEscrow: u64 = 922337630175887362;
    const EIncreaseTimePermanent: u64 = 922337631464443088;
    const EIncreaseTimeExpired: u64 = 922337633182246503;
    const EIncreaseTimeNoBalance: u64 = 922337633611808769;
    const EIncreaseTimeNotLater: u64 = 922337634041436573;
    const EIncreaseTimeTooLong: u64 = 922337634470946410;
    const ELockPermanentNotNormalEscrow: u64 = 922337652509717301;
    const ELockPermanentAlreadyPermanent: u64 = 922337653798273027;
    const ELockPermanentExpired: u64 = 922337654227586253;
    const ELockPermanentNoBalance: u64 = 922337654657148520;
    const EMergePositionVoted: u64 = 922337607412573801;
    const EMergeSourceNotNormalEscrow: u64 = 922337607842057423;
    const EMergeTargetNotNormalEscrow: u64 = 922337608271554152;
    const ERemoveAllowedManagerInvalidPublisher: u64 = 695214134516513500;
    const EMergeSamePosition: u64 = 922337608701247493;
    const EMergeSourcePermanent: u64 = 922337611707593526;
    const EMergeSourcePerpetual: u64 = 464558058800800260;
    const ESetManagedLockNotManagedType: u64 = 922337850078330884;
    const EGrantTeamCapInvalidPublisher: u64 = 823241689916894800;
    const ESetManagedLockAlreadySet: u64 = 922337850507893150;
    const EUnlockPermanentNotNormalEscrow: u64 = 922337666683109378;
    const EUnlockPermanentPositionVoted: u64 = 922337667112619215;
    const EUnlockPermanentNotPermanent: u64 = 922337667971560245;
    const EUnlockPermanentIsPerpetual: u64 = 625787259881230500;
    const EValidateLockInvalidEscrow: u64 = 922337605264919756;
    const EVotingInvalidVoter: u64 = 922337407696424140;
    const EWithdrawManagedInvalidVoter: u64 = 922337808417161220;
    const EWithdrawManagedNotManaged: u64 = 922337808846671057;
    const EWithdrawManagedNotLockedType: u64 = 922337809276180894;
    const EWithdrawManagedInvalidManagedLock: u64 = 922337810564657975;
    const EOwnerProofNotOwner: u64 = 922337320938084761;
    const EValidateLockDurationInvalid: u64 = 922337411132463514;
    const EGetPastPowerPointError: u64 = 922337711780108697;
    const EGetVotingPowerOwnershipChangeTooRecent: u64 = 922337699754409987;
    const EPointHistoryInvalid: u64 = 999;

    public struct VOTING_ESCROW has drop {}

    public struct DistributorCap has store, key {
        id: UID,
        ve: ID,
    }

    public struct Lock has key {
        id: UID,
        escrow: ID,
        amount: u64,
        start: u64,
        end: u64,
        // permanent can be toggled to true or false, therefore permanent locks can be unlocked
        permanent: bool,
        // perpetual locks cannot be unlocked, they are locked forever
        perpetual: bool,
    }

    public struct CreateLockReceipt {
        amount: u64,
    }

    public struct LockedBalance has copy, drop, store {
        amount: u64,
        end: u64,
        is_permanent: bool,
        is_perpetual: bool,
    }

    public struct GlobalPoint has copy, drop, store {
        bias: integer_mate::i128::I128,
        slope: integer_mate::i128::I128,
        ts: u64,
        permanent_lock_balance: u64,
    }

    public struct EventCreateLock has copy, drop, store {
        lock_id: ID,
        owner: address,
        start: u64,
        end: u64,
        amount: u64,
        permanent: bool,
        perpetual: bool,
    }

    public struct EventDeposit has copy, drop, store {
        lock_id: ID,
        deposit_type: DepositType,
        amount: u64,
        unlock_time: u64,
    }

    public struct EventSupply has copy, drop, store {
        before: u64,
        after: u64,
    }

    public struct EventDelegateChanged has copy, drop, store {
        old: ID,
        new: ID,
    }

    public struct EventMetadataUpdate has copy, drop, store {
        lock_id: ID,
    }

    public struct EventToggleSplit has copy, drop, store {
        who: address,
        allowed: bool,
    }

    public struct EventSplit has copy, drop, store {
        original_id: ID,
        new_id1: ID,
        new_id2: ID,
        amount1: u64,
        amount2: u64,
    }

    public struct EventWithdraw has copy, drop, store {
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventLockPermanent has copy, drop, store {
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventUnlockPermanent has copy, drop, store {
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventCreateManaged has copy, drop, store {
        owner: address,
        lock_id: ID,
        sender: address,
        locked_managed_reward: ID,
        free_managed_reward: ID,
    }

    public struct EventDepositManaged has copy, drop, store {
        owner: address,
        lock_id: ID,
        managed_lock_id: ID,
        amount: u64,
    }

    public struct EventWithdrawManaged has copy, drop, store {
        owner: address,
        lock_id: ID,
        managed_lock_id: ID,
        amount: u64,
        perpetual: bool,
    }

    public struct EventMerge has copy, drop, store {
        sender: address,
        from: ID,
        to: ID,
        from_amount: u64,
        to_amount: u64,
        new_amount: u64,
        new_end: u64,
    }

    public struct EventTransfer has copy, drop, store {
        from: address,
        to: address,
        lock: ID,
    }

    public struct VotingEscrow<phantom SailCoinType> has store, key {
        id: UID,
        voter: ID,
        balance: sui::balance::Balance<SailCoinType>,
        total_locked: u64,
        point_history: sui::table::Table<u64, GlobalPoint>,
        epoch: u64,
        lock_durations: sui::vec_set::VecSet<u64>,
        deactivated: sui::table::Table<ID, bool>,
        ownership_change_at: sui::table::Table<ID, u64>,
        user_point_epoch: sui::table::Table<ID, u64>,
        user_point_history: sui::table::Table<ID, sui::table::Table<u64, UserPoint>>,
        voted: sui::table::Table<ID, bool>,
        locked: sui::table::Table<ID, LockedBalance>,
        owner_of: sui::table::Table<ID, address>,
        slope_changes: sui::table::Table<u64, integer_mate::i128::I128>,
        permanent_lock_balance: u64,
        escrow_type: sui::table::Table<ID, EscrowType>,
        voting_dao: distribution::voting_dao::VotingDAO,
        can_split: sui::table::Table<address, bool>,
        managed_locks: sui::vec_set::VecSet<ID>,
        allowed_managers: sui::vec_set::VecSet<address>,
        managed_weights: sui::table::Table<ID, sui::table::Table<ID, u64>>,
        managed_to_locked: sui::table::Table<ID, distribution::locked_managed_reward::LockedManagedReward>,
        managed_to_free: sui::table::Table<ID, distribution::free_managed_reward::FreeManagedReward>,
        id_to_managed: sui::table::Table<ID, ID>,
        locked_managed_reward_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        free_managed_reward_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public struct UserPoint has copy, drop, store {
        bias: integer_mate::i128::I128,
        slope: integer_mate::i128::I128,
        ts: u64,
        permanent: u64,
    }
    public enum DepositType has copy, drop, store {
            DEPOSIT_FOR_TYPE,
            CREATE_LOCK_TYPE,
            INCREASE_LOCK_AMOUNT,
            INCREASE_UNLOCK_TIME,
    }
    public enum EscrowType has copy, drop, store {
            NORMAL,
            LOCKED,
            MANAGED,
    }

    /// Split a lock into two separate locks with different amounts. This is useful for dividing
    /// a position to sell or delegate part of it while keeping the rest.
    /// 
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to split
    /// * `amount` - The amount to split into the second lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    /// 
    /// # Returns
    /// Returns a tuple of the two new lock IDs created from the split
    ///
    /// # Aborts
    /// * If the lock is not owned by anyone
    /// * If the sender is not allowed to split
    /// * If the lock is not a normal escrow type
    /// * If the lock has been used to vote
    /// * If the amount to split is zero or exceeds the locked amount
    public fun split<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: Lock,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (ID, ID) {
        voting_escrow.validate_lock(&lock);
        let lock_id = object::id<Lock>(&lock);
        assert!(voting_escrow.owner_of.contains(lock_id), ESplitOwnerNotFound);
        let owner_of_lock = *voting_escrow.owner_of.borrow(lock_id);
        assert!(
            voting_escrow.is_split_allowed(owner_of_lock) || voting_escrow.is_split_allowed(tx_context::sender(ctx)),
            ESplitNotAllowed
        );
        let mut is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, ESplitNotNormalEscrow);
        let lock_has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!lock_has_voted, ESplitPositionVoted);
        let locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(
            locked_balance.end > distribution::common::current_timestamp(clock) || locked_balance.is_permanent,
            ESplitAmountZero
        );
        assert!(amount > 0, ESplitAmountZero);
        assert!(locked_balance.amount > amount, ESplitAmountExceedsLocked);
        let lock_escrow_id = lock.escrow;
        let lock_start = lock.start;
        let lock_end = lock.end;
        voting_escrow.burn_lock_internal(lock, locked_balance, clock, ctx);

        let split_lock_a = voting_escrow.create_split_internal(
            owner_of_lock,
            lock_escrow_id,
            lock_start,
            lock_end,
            locked_balance(
                locked_balance.amount - amount,
                locked_balance.end,
                locked_balance.is_permanent,
                locked_balance.is_perpetual
            ),
            clock,
            ctx
        );

        let split_lock_b = voting_escrow.create_split_internal(
            owner_of_lock,
            lock_escrow_id,
            lock_start,
            lock_end,
            locked_balance(
                amount,
                locked_balance.end,
                locked_balance.is_permanent,
                locked_balance.is_perpetual
            ),
            clock,
            ctx
        );
        let split_lock_a_id = object::id<Lock>(&split_lock_a);
        let split_lock_b_id = object::id<Lock>(&split_lock_b);
        let split_event = EventSplit {
            original_id: lock_id,
            new_id1: split_lock_a_id,
            new_id2: split_lock_b_id,
            amount1: split_lock_a.amount,
            amount2: split_lock_b.amount,
        };
        sui::event::emit<EventSplit>(split_event);
        split_lock_a.transfer(voting_escrow, owner_of_lock, clock, ctx);
        split_lock_b.transfer(voting_escrow, owner_of_lock, clock, ctx);
        (split_lock_a_id, split_lock_b_id)
    }

    /// Transfer a lock to a different address. This allows users to sell or gift their lock positions.
    /// The lock must be a NORMAL or MANAGED type - LOCKED types cannot be transferred.
    ///
    /// # Arguments
    /// * `lock` - The lock object to transfer
    /// * `voting_escrow` - The voting escrow instance
    /// * `recipient` - The address of the recipient
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock does not belong to the voting escrow
    /// * If the lock is a LOCKED type
    /// * If the sender is not the owner of the lock
    public fun transfer<SailCoinType>(
        lock: Lock,
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(lock.escrow == object::id<VotingEscrow<SailCoinType>>(voting_escrow), ETransferInvalidEscrow);
        let lock_id = object::id<Lock>(&lock);
        if (recipient == voting_escrow.owner_of(lock_id) && recipient == tx_context::sender(ctx)) {
            transfer::transfer<Lock>(lock, recipient);
        } else {
            assert!(voting_escrow.escrow_type(lock_id) != EscrowType::LOCKED, ETransferLockedPosition);
            let owner_of_lock = voting_escrow.owner_of.remove(lock_id);
            assert!(owner_of_lock == tx_context::sender(ctx), ETransferNotOwner);
            voting_escrow.voting_dao.checkpoint_delegator(
                lock_id,
                0,
                object::id_from_address(@0x0),
                recipient,
                clock,
                ctx
            );
            voting_escrow.owner_of.add(lock_id, recipient);
            if (voting_escrow.ownership_change_at.contains(lock_id)) {
                voting_escrow.ownership_change_at.remove(lock_id);
            };
            voting_escrow.ownership_change_at.add(lock_id, clock.timestamp_ms());
            transfer::transfer<Lock>(lock, recipient);
            let transfer_event = EventTransfer {
                from: owner_of_lock,
                to: recipient,
                lock: lock_id,
            };
            sui::event::emit<EventTransfer>(transfer_event);
        };
    }

    /// Creates a new VotingEscrow instance. This is the main container that manages all locked tokens
    /// and voting power calculations.
    ///
    /// # Arguments
    /// * `publisher` - The publisher of the module
    /// * `voter_id` - The ID of the associated voter
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A new VotingEscrow instance
    public fun create<SailCoinType>(
        publisher: &sui::package::Publisher,
        voter_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): VotingEscrow<SailCoinType> {
        assert!(publisher.from_module<VOTING_ESCROW>(), ECreateVotingEscrowInvalidPublisher);
        let uid = object::new(ctx);
        let inner_id = object::uid_to_inner(&uid);
        let mut voting_escrow = VotingEscrow<SailCoinType> {
            id: uid,
            voter: voter_id,
            balance: sui::balance::zero<SailCoinType>(),
            total_locked: 0,
            point_history: sui::table::new<u64, GlobalPoint>(ctx),
            epoch: 0,
            lock_durations: sui::vec_set::empty<u64>(),
            deactivated: sui::table::new<ID, bool>(ctx),
            ownership_change_at: sui::table::new<ID, u64>(ctx),
            user_point_epoch: sui::table::new<ID, u64>(ctx),
            user_point_history: sui::table::new<ID, sui::table::Table<u64, UserPoint>>(ctx),
            voted: sui::table::new<ID, bool>(ctx),
            locked: sui::table::new<ID, LockedBalance>(ctx),
            owner_of: sui::table::new<ID, address>(ctx),
            slope_changes: sui::table::new<u64, integer_mate::i128::I128>(ctx),
            permanent_lock_balance: 0,
            escrow_type: sui::table::new<ID, EscrowType>(ctx),
            voting_dao: distribution::voting_dao::create(ctx),
            can_split: sui::table::new<address, bool>(ctx),
            managed_locks: sui::vec_set::empty<ID>(),
            allowed_managers: sui::vec_set::empty<address>(),
            managed_weights: sui::table::new<ID, sui::table::Table<ID, u64>>(ctx),
            managed_to_locked: sui::table::new<ID, distribution::locked_managed_reward::LockedManagedReward>(
                ctx
            ),
            managed_to_free: sui::table::new<ID, distribution::free_managed_reward::FreeManagedReward>(
                ctx
            ),
            id_to_managed: sui::table::new<ID, ID>(ctx),
            locked_managed_reward_authorized_cap: distribution::reward_authorized_cap::create(inner_id, ctx),
            free_managed_reward_authorized_cap: distribution::reward_authorized_cap::create(inner_id, ctx),
            // bag to be preapred for future updates
            bag: sui::bag::new(ctx),
        };
        let global_point = GlobalPoint {
            bias: integer_mate::i128::from(0),
            slope: integer_mate::i128::from(0),
            ts: distribution::common::current_timestamp(clock),
            permanent_lock_balance: 0,
        };
        voting_escrow.point_history.add(0, global_point);
        voting_escrow
    }

    /// Withdraw tokens from a lock after the lock duration has expired. This allows users to reclaim
    /// their locked tokens once the locking period is over.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock containing the tokens to withdraw
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock is currently used for voting
    /// * If the lock is not a NORMAL escrow type
    /// * If the lock is permanent
    /// * If the lock end time has not been reached
    public fun withdraw<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let lock_id = object::id<Lock>(&lock);
        let lock_has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!lock_has_voted, EWithdrawPositionVoted);
        assert!(
            !voting_escrow.escrow_type.contains(lock_id) || *voting_escrow.escrow_type.borrow(
                lock_id
            ) == EscrowType::NORMAL,
            EWithdrawPositionNotNormalEscrow
        );
        let locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(!locked_balance.is_permanent, EWithdrawPermanentPosition);
        assert!(distribution::common::current_timestamp(clock) >= locked_balance.end, EWithdrawBeforeEndTime);
        let current_total_locked = voting_escrow.total_locked;
        voting_escrow.total_locked = voting_escrow.total_locked - locked_balance.amount;
        voting_escrow.burn_lock_internal(lock, locked_balance, clock, ctx);
        transfer::public_transfer<sui::coin::Coin<SailCoinType>>(
            sui::coin::from_balance<SailCoinType>(
                voting_escrow.balance.split(locked_balance.amount),
                ctx
            ),
            sender
        );
        let withdraw_event = EventWithdraw {
            sender,
            lock_id,
            amount: locked_balance.amount,
        };
        sui::event::emit<EventWithdraw>(withdraw_event);
        let supply_event = EventSupply {
            before: current_total_locked,
            after: current_total_locked - locked_balance.amount,
        };
        sui::event::emit<EventSupply>(supply_event);
    }

    /// Adds an address to the list of allowed managers that can create managed locks.
    /// Only allowed managers can create managed locks in the voting escrow system.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `publisher` - The publisher of the module
    /// * `who` - The address to add as an allowed manager
    public fun add_allowed_manager<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        publisher: &sui::package::Publisher,
        who: address
    ) {
        assert!(publisher.from_module<VOTING_ESCROW>(), EAddAllowedManagerInvalidPublisher);
        voting_escrow.allowed_managers.insert(who);
    }

    /// Returns the token amount in a locked balance.
    ///
    /// # Arguments
    /// * `locked_balance` - The locked balance to query
    ///
    /// # Returns
    /// The amount of tokens in the locked balance
    public fun amount(locked_balance: &LockedBalance): u64 {
        locked_balance.amount
    }

    /// Returns the voting power of an NFT (lock) at a specific timestamp.
    /// This is a public wrapper around the internal implementation.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to query
    /// * `time` - The timestamp in seconds at which to calculate voting power
    ///
    /// # Returns
    /// The voting power of the lock at the specified time
    public fun balance_of_nft_at<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        time: u64
    ): u64 {
        voting_escrow.balance_of_nft_at_internal(lock_id, time)
    }

    /// Internal implementation to calculate the voting power of a lock at a specific timestamp.
    /// Voting power decays linearly over time until it reaches zero at the end of the lock period.
    /// For permanent locks, the voting power is constant and equal to the locked amount.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to query
    /// * `time` - The timestamp in seconds at which to calculate voting power
    ///
    /// # Returns
    /// The voting power of the lock at the specified time
    fun balance_of_nft_at_internal<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        time: u64
    ): u64 {
        let past_power_point = voting_escrow.get_past_power_point_index(lock_id, time);
        if (past_power_point == 0) {
            return 0
        };
        let mut user_points = *voting_escrow.user_point_history.borrow(lock_id).borrow(past_power_point);
        if (user_points.permanent > 0) {
            user_points.permanent
        } else {
            user_points.bias = user_points.bias.sub(
                user_points.slope.mul(
                    integer_mate::i128::from((time as u128))
                        .sub(integer_mate::i128::from((user_points.ts as u128)))
                ).div(integer_mate::i128::from(1 << 64))
            );
            if (user_points.bias.is_neg()) {
                user_points.bias = integer_mate::i128::from(0);
            };
            (user_points.bias.as_u128() as u64)
        }
    }

    /// Returns a reference to the set of allowed managers.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    ///
    /// # Returns
    /// A reference to the set of allowed manager addresses
    public fun borrow_allowed_managers<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>
    ): &sui::vec_set::VecSet<address> {
        &voting_escrow.allowed_managers
    }

    /// Returns a reference to the set of managed locks.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    ///
    /// # Returns
    /// A reference to the set of managed lock IDs
    public fun borrow_managed_locks<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>
    ): &sui::vec_set::VecSet<ID> {
        &voting_escrow.managed_locks
    }

    /// Internal function to burn a lock and update the voting escrow state.
    /// This is used when removing a lock completely from the system.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to burn
    /// * `current_locked_balance` - The current locked balance of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    fun burn_lock_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: Lock,
        current_locked_balance: LockedBalance,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(&lock);
        voting_escrow.voting_dao.checkpoint_delegator(
            lock_id,
            current_locked_balance.amount,
            object::id_from_address(@0x0),
            @0x0,
            clock,
            ctx
        );
        voting_escrow.owner_of.remove(lock_id);
        voting_escrow.locked.remove(lock_id);
        voting_escrow.checkpoint_internal(
            option::some<ID>(lock_id),
            current_locked_balance,
            locked_balance(0, 0, false, false),
            clock,
            ctx
        );
        let Lock {
            id,
            escrow: _,
            amount: _,
            start: _,
            end: _,
            permanent: _,
            perpetual: _,
        } = lock;
        object::delete(id);
    }

    /// Updates the global checkpoint for the voting escrow.
    /// This records the current state of the system and is used for accurate
    /// voting power calculations at different points in time.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun checkpoint<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.checkpoint_internal(
            option::none<ID>(),
            locked_balance(0, 0, false, false),
            locked_balance(0, 0, false, false),
            clock,
            ctx
        );
    }

    /// Internal implementation of the checkpoint mechanism.
    /// This complex function updates the state of the voting escrow system to record
    /// changes in locked balances and to correctly track voting power over time.
    /// The algorithm handles both permanent locks and time-decaying locks.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id_opt` - An optional lock ID if this checkpoint is for a specific lock
    /// * `old_locked_balance` - The previous locked balance
    /// * `next_locked_balance` - The new locked balance
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    fun checkpoint_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id_opt: Option<ID>,
        old_locked_balance: LockedBalance,
        next_locked_balance: LockedBalance,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let mut old_user_point = create_user_point();
        let mut next_user_point = create_user_point();
        let mut old_slope_change = integer_mate::i128::from(0);
        let mut next_slope_change = integer_mate::i128::from(0);
        let current_epoch = voting_escrow.epoch;
        let mut new_epoch = current_epoch;
        let current_timestamp = distribution::common::current_timestamp(clock);
        if (lock_id_opt.is_some()) {
            let permanent_amount = if (next_locked_balance.is_permanent) {
                next_locked_balance.amount
            } else {
                0
            };
            next_user_point.permanent = permanent_amount;
            if (old_locked_balance.end > current_timestamp && old_locked_balance.amount > 0) {
                old_user_point.slope = integer_mate::i128::from(
                    integer_mate::full_math_u128::mul_div_floor(
                        (old_locked_balance.amount as u128),
                        1 << 64,
                        (distribution::common::max_lock_time() as u128)
                    )
                );
                old_user_point.bias = old_user_point.slope.mul(
                    integer_mate::i128::from(((old_locked_balance.end - current_timestamp) as u128))
                ).div(
                    integer_mate::i128::from(1 << 64)
                );
            };
            if (next_locked_balance.end > current_timestamp && next_locked_balance.amount > 0) {
                next_user_point.slope = integer_mate::i128::from(
                    integer_mate::full_math_u128::mul_div_floor(
                        (next_locked_balance.amount as u128),
                        1 << 64,
                        (distribution::common::max_lock_time() as u128)
                    )
                );
                next_user_point.bias = next_user_point.slope.mul(
                    integer_mate::i128::from(((next_locked_balance.end - current_timestamp) as u128))
                ).div(
                    integer_mate::i128::from(1 << 64)
                );
            };
            let existing_old_slope_change = if (voting_escrow.slope_changes.contains(old_locked_balance.end)) {
                *voting_escrow.slope_changes.borrow(old_locked_balance.end)
            } else {
                integer_mate::i128::from(0)
            };
            old_slope_change = existing_old_slope_change;
            if (next_locked_balance.end != 0) {
                if (next_locked_balance.end == old_locked_balance.end) {
                    next_slope_change = existing_old_slope_change;
                } else {
                    let existing_next_slop_change = if (voting_escrow.slope_changes.contains(next_locked_balance.end)) {
                        *voting_escrow.slope_changes.borrow(next_locked_balance.end)
                    } else {
                        integer_mate::i128::from(0)
                    };
                    next_slope_change = existing_next_slop_change;
                };
            };
        };
        let last_point = if (current_epoch > 0) {
            *voting_escrow.point_history.borrow(current_epoch)
        } else {
            GlobalPoint {
                bias: integer_mate::i128::from(0), slope: integer_mate::i128::from(
                    0
                ), ts: current_timestamp, permanent_lock_balance: 0
            }
        };
        let mut current_point = last_point;
        let mut last_point_timestamp = current_point.ts;
        let mut period_timestamp = distribution::common::to_period(last_point_timestamp);
        let mut i = 0;
        while (i < 255) {
            let next_epoch_timestamp = period_timestamp + distribution::common::epoch();
            period_timestamp = next_epoch_timestamp;
            let mut slope_change = integer_mate::i128::from(0);
            if (next_epoch_timestamp > current_timestamp) {
                period_timestamp = current_timestamp;
            } else {
                let existing_slope_change = if (voting_escrow.slope_changes.contains(next_epoch_timestamp)) {
                    *voting_escrow.slope_changes.borrow(next_epoch_timestamp)
                } else {
                    integer_mate::i128::from(0)
                };
                slope_change = existing_slope_change;
            };
            current_point.bias = current_point.bias.sub(
                current_point.slope.mul(
                    integer_mate::i128::from(((period_timestamp - last_point_timestamp) as u128))
                ).div(
                    integer_mate::i128::from(1 << 64)
                )
            );
            current_point.slope = current_point.slope.add(slope_change);
            if (current_point.bias.is_neg()) {
                current_point.bias = integer_mate::i128::from(0);
            };
            if (current_point.slope.is_neg()) {
                current_point.slope = integer_mate::i128::from(0);
            };
            current_point.ts = period_timestamp;
            last_point_timestamp = period_timestamp;
            let incremented_epoch = new_epoch + 1;
            new_epoch = incremented_epoch;
            if (period_timestamp == current_timestamp) {
                break
            };
            voting_escrow.set_point_history(incremented_epoch, current_point);
            i = i + 1;
        };
        if (lock_id_opt.is_some()) {
            current_point.slope = current_point.slope.add(next_user_point.slope.sub(old_user_point.slope));
            current_point.bias = current_point.bias.add(next_user_point.bias.sub(old_user_point.bias));
            if (current_point.slope.is_neg()) {
                current_point.slope = integer_mate::i128::from(0);
            };
            if (current_point.bias.is_neg()) {
                current_point.bias = integer_mate::i128::from(0);
            };
            current_point.permanent_lock_balance = voting_escrow.permanent_lock_balance;
        };
        let should_update_last_point = if (new_epoch != 1) {
            if (voting_escrow.point_history.contains(new_epoch - 1)) {
                voting_escrow.point_history.borrow(new_epoch - 1).ts == current_timestamp
            } else {
                false
            }
        } else {
            false
        };
        if (should_update_last_point) {
            voting_escrow.set_point_history(new_epoch - 1, current_point);
        } else {
            voting_escrow.epoch = new_epoch;
            voting_escrow.set_point_history(new_epoch, current_point);
        };
        if (lock_id_opt.is_some()) {
            if (old_locked_balance.end > current_timestamp) {
                let updated_old_slope_change = old_slope_change.add(old_user_point.slope);
                old_slope_change = updated_old_slope_change;
                if (next_locked_balance.end == old_locked_balance.end) {
                    old_slope_change = updated_old_slope_change.sub(next_user_point.slope);
                };
                voting_escrow.set_slope_changes(old_locked_balance.end, old_slope_change);
            };
            if (next_locked_balance.end > current_timestamp) {
                if (next_locked_balance.end > old_locked_balance.end) {
                    voting_escrow.set_slope_changes(
                        next_locked_balance.end,
                        next_slope_change.sub(next_user_point.slope)
                    );
                };
            };
            let lock_id = *lock_id_opt.borrow();
            next_user_point.ts = current_timestamp;
            let user_point_epoch = if (voting_escrow.user_point_epoch.contains(lock_id)) {
                *voting_escrow.user_point_epoch.borrow(lock_id)
            } else {
                0
            };
            let should_update_existing_point = if (user_point_epoch != 0) {
                if (voting_escrow.user_point_history.borrow(lock_id).contains(user_point_epoch)) {
                    voting_escrow.user_point_history.borrow(lock_id).borrow(user_point_epoch).ts == current_timestamp
                } else {
                    false
                }
            } else {
                false
            };
            if (should_update_existing_point) {
                voting_escrow.set_user_point_history(lock_id, user_point_epoch, next_user_point, ctx);
            } else {
                voting_escrow.set_user_point_epoch(lock_id, user_point_epoch + 1);
                voting_escrow.set_user_point_history(lock_id, user_point_epoch + 1, next_user_point, ctx);
            };
        };
    }

    /// Recommended way to create a lock.
    /// Creates a new lock by locking tokens for a specified duration.
    /// This is the main entry point for users to lock their tokens and gain voting power.
    /// Voting power depends on the amount locked and duration of the lock.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `coin_to_lock` - The tokens to lock
    /// * `lock_duration_days` - The number of days to lock the tokens
    /// * `permanent` - Whether this should be a permanent lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock duration is invalid
    /// * If the lock amount is zero
    /// * If the created lock amount doesn't match the expected amount
    public fun create_lock<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        coin_to_lock: sui::coin::Coin<SailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.create_lock_advanced(
            coin_to_lock,
            lock_duration_days,
            permanent,
            false,
            clock,
            ctx
        )
    }


    /// Creates a lock with more options available. Allows creation of perpetual locks,
    /// that can never be withdrawn.
    /// Creates a new lock by locking tokens for a specified duration.
    /// This is the main entry point for users to lock their tokens and gain voting power.
    /// Voting power depends on the amount locked and duration of the lock. This function allows you to create a perpetual lock.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `coin_to_lock` - The tokens to lock
    /// * `lock_duration_days` - The number of days to lock the tokens
    /// * `permanent` - Whether this should be a permanent lock
    /// * `perpetual` - Whether this should be a perpetual lock, i.e. lock that can never be withdrawn
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock duration is invalid
    /// * If the lock amount is zero
    /// * If the created lock amount doesn't match the expected amount
    public fun create_lock_advanced<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        coin_to_lock: sui::coin::Coin<SailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        perpetual: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.validate_lock_duration(lock_duration_days);
        let lock_amount = coin_to_lock.value();
        assert!(lock_amount > 0, ECreateLockAmountZero);
        let current_time = distribution::common::current_timestamp(clock);
        let sender = tx_context::sender(ctx);
        let end_time = if (permanent || perpetual) {
            0
        } else {
            distribution::common::to_period(current_time + lock_duration_days * distribution::common::day())
        };
        let (lock_immut, create_lock_receipt) = voting_escrow.create_lock_internal(
            sender,
            lock_amount,
            current_time,
            end_time,
            permanent,
            perpetual,
            clock,
            ctx
        );
        let mut lock = lock_immut;
        let CreateLockReceipt { amount: amout } = create_lock_receipt;
        assert!(amout == lock_amount, ECreateLockAmountMismatch);
        voting_escrow.balance.join(coin_to_lock.into_balance());
        if (permanent) {
            voting_escrow.lock_permanent_internal(&mut lock, clock, ctx);
        };
        transfer::transfer<Lock>(lock, sender);
    }

    /// Creates a lock on behalf of another address.
    /// This allows one user to create a lock for another user, which can be useful
    /// for distributing locks to team members, incentives, or other situations.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `owner` - The address that will own the lock
    /// * `coin` - The tokens to lock
    /// * `duration_days` - The number of days to lock the tokens
    /// * `permanent` - Whether this should be a permanent lock
    /// * `perpetual` - Whether this should be a perpetual lock, i.e. lock that can never be withdrawn
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock duration is invalid
    /// * If the lock amount is zero
    /// * If the created lock amount doesn't match the expected amount
    public fun create_lock_for<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        coin: sui::coin::Coin<SailCoinType>,
        duration_days: u64,
        permanent: bool,
        perpetual: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.validate_lock_duration(duration_days);
        let lock_amount = coin.value();
        assert!(lock_amount > 0, ECreateLockForAmountZero);
        let start_time = distribution::common::current_timestamp(clock);
        let end_time = if (permanent || perpetual) {
            0
        } else {
            distribution::common::to_period(start_time + duration_days * distribution::common::day())
        };
        let (lock_immut, create_lock_receipt) = voting_escrow.create_lock_internal(
            owner,
            lock_amount,
            start_time,
            end_time,
            permanent,
            perpetual,
            clock,
            ctx
        );
        let mut lock = lock_immut;
        let CreateLockReceipt { amount } = create_lock_receipt;
        assert!(amount == lock_amount, ECreateLockForAmountMismatch);
        voting_escrow.balance.join(coin.into_balance());
        if (permanent) {
            voting_escrow.lock_permanent_internal(&mut lock, clock, ctx);
        };
        transfer::transfer<Lock>(lock, owner);
    }

    /// Internal function to create a lock. Shared implementation for both create_lock and create_lock_for.
    /// This sets up the lock object, records ownership, and initializes the voting power calculation.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `owner` - The address that will own the lock
    /// * `lock_amount` - The amount of tokens to lock
    /// * `start_time` - The start timestamp of the lock
    /// * `end_time` - The end timestamp of the lock
    /// * `permanent` - Whether this is a permanent lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// A tuple containing the created lock and a receipt with the lock amount
    ///
    /// # Aborts
    /// * If a lock with the same ID already exists
    /// * If there's already a locked balance for this lock ID
    fun create_lock_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        lock_amount: u64,
        start_time: u64,
        end_time: u64,
        permanent: bool,
        perpetual: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (Lock, CreateLockReceipt) {
        assert!(!perpetual || permanent, ECreateLockPerpetualMustBePermanent);
        let lock = Lock {
            id: object::new(ctx),
            escrow: object::id<VotingEscrow<SailCoinType>>(voting_escrow),
            amount: lock_amount,
            start: start_time,
            end: end_time,
            permanent,
            perpetual,
        };
        let lock_id = object::id<Lock>(&lock);
        assert!(!voting_escrow.owner_of.contains(lock_id), ECreateLockOwnerExists);
        assert!(!voting_escrow.locked.contains(lock_id), ECreateLockLockedExists);
        voting_escrow.owner_of.add(lock_id, owner);
        voting_escrow.ownership_change_at.add(lock_id, clock.timestamp_ms());
        voting_escrow.voting_dao.checkpoint_delegator(
            lock_id,
            lock_amount,
            object::id_from_address(@0x0),
            owner,
            clock,
            ctx
        );
        voting_escrow.deposit_for_internal(
            lock_id,
            lock_amount,
            end_time,
            locked_balance(0, 0, permanent, perpetual),
            DepositType::CREATE_LOCK_TYPE,
            clock,
            ctx
        );
        let create_lock_event = EventCreateLock {
            lock_id,
            owner,
            start: start_time,
            end: end_time,
            amount: lock_amount,
            permanent,
            perpetual,
        };
        sui::event::emit<EventCreateLock>(create_lock_event);
        let create_lock_receipt = CreateLockReceipt { amount: lock_amount };
        (lock, create_lock_receipt)
    }

    /// Creates a managed lock for a specified address.
    /// Managed locks are special locks that are managed by approved managers and can receive
    /// deposits from other users' locks. This is useful for implementing delegation pools
    /// or other advanced staking mechanisms.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `owner` - The address that will own the managed lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The ID of the created managed lock
    ///
    /// # Aborts
    /// * If the sender is not an allowed manager
    public fun create_managed_lock_for<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): ID {
        let sender = tx_context::sender(ctx);
        assert!(voting_escrow.allowed_managers.contains(&sender), ECreateManagedNotAllowedManager);
        let (lock, create_lock_receipt) = voting_escrow.create_lock_internal(
            owner,
            0,
            distribution::common::current_timestamp(clock),
            0,
            true,
            false,
            clock,
            ctx
        );
        let CreateLockReceipt { amount: _ } = create_lock_receipt;
        let lock_id = object::id<Lock>(&lock);
        voting_escrow.managed_locks.insert(lock_id);
        voting_escrow.escrow_type.add(lock_id, EscrowType::MANAGED);
        let sail_coin_type = std::type_name::get<SailCoinType>();
        let lock_managed_reward = distribution::locked_managed_reward::create(
            voting_escrow.voter,
            object::id<VotingEscrow<SailCoinType>>(voting_escrow),
            sail_coin_type,
            ctx
        );
        let free_managed_reward = distribution::free_managed_reward::create(
            voting_escrow.voter,
            object::id<VotingEscrow<SailCoinType>>(voting_escrow),
            sail_coin_type,
            ctx
        );
        let create_managed_event = EventCreateManaged {
            owner,
            lock_id,
            sender,
            locked_managed_reward: object::id<distribution::locked_managed_reward::LockedManagedReward>(
                &lock_managed_reward
            ),
            free_managed_reward: object::id<distribution::free_managed_reward::FreeManagedReward>(&free_managed_reward),
        };
        sui::event::emit<EventCreateManaged>(create_managed_event);
        voting_escrow.managed_to_locked.add(lock_id, lock_managed_reward);
        voting_escrow.managed_to_free.add(lock_id, free_managed_reward);
        transfer::share_object<Lock>(lock);
        lock_id
    }

    /// Internal function to create a lock as part of the split operation.
    /// This creates a new lock with the specified parameters and initializes the
    /// relevant voting escrow state.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `owner` - The address that will own the lock
    /// * `lock_escrow_id` - The ID of the escrow this lock belongs to
    /// * `lock_start` - The start timestamp of the lock
    /// * `lock_end` - The end timestamp of the lock
    /// * `current_locked_balance` - The locked balance to assign to this lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The newly created Lock object
    fun create_split_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        lock_escrow_id: ID,
        lock_start: u64,
        lock_end: u64,
        current_locked_balance: LockedBalance,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): Lock {
        let lock = Lock {
            id: object::new(ctx),
            escrow: lock_escrow_id,
            amount: current_locked_balance.amount,
            start: lock_start,
            end: lock_end,
            permanent: current_locked_balance.is_permanent,
            perpetual: current_locked_balance.is_perpetual,
        };
        let lock_id = object::id<Lock>(&lock);
        voting_escrow.locked.add(lock_id, current_locked_balance);
        voting_escrow.owner_of.add(lock_id, owner);
        voting_escrow.ownership_change_at.add(lock_id, clock.timestamp_ms());
        voting_escrow.voting_dao.checkpoint_delegator(
            lock_id,
            current_locked_balance.amount,
            object::id_from_address(@0x0),
            owner,
            clock,
            ctx
        );
        voting_escrow.checkpoint_internal(
            option::some<ID>(object::id<Lock>(&lock)),
            locked_balance(0, 0, false, false),
            current_locked_balance,
            clock,
            ctx
        );
        lock
    }

    /// Creates a new UserPoint with default values.
    /// UserPoint objects track the voting power calculation parameters for a specific lock.
    ///
    /// # Returns
    /// A new UserPoint object with zero values
    fun create_user_point(): UserPoint {
        UserPoint {
            bias: integer_mate::i128::from(0),
            slope: integer_mate::i128::from(0),
            ts: 0,
            permanent: 0,
        }
    }

    /// Checks if a lock is deactivated.
    /// Deactivated locks cannot be used for new deposits.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to check
    ///
    /// # Returns
    /// True if the lock is deactivated, false otherwise
    public fun deactivated<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): bool {
        voting_escrow.deactivated.contains(lock_id) && *voting_escrow.deactivated.borrow(lock_id)
    }

    /// Delegates voting power from a permanent lock to another lock.
    /// This allows users to give their voting power to another user without transferring ownership.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock from which to delegate voting power
    /// * `delegatee` - The ID of the lock to delegate voting power to
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock doesn't belong to the voting escrow
    public fun delegate<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &Lock,
        delegatee: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.validate_lock(lock);
        voting_escrow.delegate_internal(lock, delegatee, clock, ctx);
    }

    /// Internal implementation of delegation logic.
    /// Handles the complex logic of updating delegator and delegatee state when
    /// changing delegation relationships.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock from which to delegate voting power 
    /// * `delegatee` - The ID of the lock to delegate voting power to
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock is not a permanent lock
    /// * If the delegatee is invalid
    /// * If the lock ownership changed too recently
    fun delegate_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &Lock,
        mut delegatee: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let (current_locked_balance, _) = voting_escrow.locked(lock_id);
        assert!(current_locked_balance.is_permanent, EDelegateNotPermanent);
        assert!(
            delegatee == object::id_from_address(@0x0) || voting_escrow.owner_of.contains(delegatee),
            EDelegateInvalidDelegatee
        );
        if (object::id<Lock>(lock) == delegatee) {
            delegatee = object::id_from_address(@0x0);
        };
        assert!(
            clock.timestamp_ms() - *voting_escrow.ownership_change_at.borrow(
                lock_id
            ) >= distribution::common::get_time_to_finality_ms(),
            EDelegateOwnershipChangeTooRecent
        );
        let current_delegatee = voting_escrow.voting_dao.delegatee(lock_id);
        if (current_delegatee == delegatee) {
            return
        };
        voting_escrow.voting_dao.checkpoint_delegator(
            lock_id,
            current_locked_balance.amount,
            delegatee,
            *voting_escrow.owner_of.borrow(lock_id),
            clock,
            ctx
        );
        voting_escrow.voting_dao.checkpoint_delegatee(delegatee, current_locked_balance.amount, true, clock, ctx);
        let delegatee_changed_event = EventDelegateChanged {
            old: current_delegatee,
            new: delegatee,
        };
        sui::event::emit<EventDelegateChanged>(delegatee_changed_event);
    }

    /// Deposits additional tokens into an existing lock.
    /// This increases the amount locked without changing the lock duration.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to deposit tokens into
    /// * `coin` - The tokens to deposit
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun deposit_for<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id(lock);
        assert!(!voting_escrow.deactivated(lock_id), EDepositForDeactivatedLock);
        let deposit_amount = coin.value<SailCoinType>();
        voting_escrow.balance.join<SailCoinType>(coin.into_balance());
        voting_escrow.increase_amount_for_internal(
            lock_id,
            deposit_amount,
            DepositType::DEPOSIT_FOR_TYPE,
            clock,
            ctx
        );
        lock.amount = lock.amount + deposit_amount;
    }

    /// Internal implementation for depositing tokens into a lock.
    /// Updates the locked balance and the system state to reflect the new deposit.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to deposit into
    /// * `lock_amount` - The amount of tokens to deposit
    /// * `end_time` - The new end time for the lock, if changing
    /// * `current_locked_balance` - The current locked balance of the lock
    /// * `deposit_type` - The type of deposit being made
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    fun deposit_for_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID,
        lock_amount: u64,
        end_time: u64,
        current_locked_balance: LockedBalance,
        deposit_type: DepositType,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let current_total_locked = voting_escrow.total_locked;
        voting_escrow.total_locked = voting_escrow.total_locked + lock_amount;
        let mut new_locked_balance = locked_balance(
            current_locked_balance.amount,
            current_locked_balance.end,
            current_locked_balance.is_permanent,
            current_locked_balance.is_perpetual,
        );
        new_locked_balance.amount = new_locked_balance.amount + lock_amount;
        if (end_time != 0) {
            new_locked_balance.end = end_time;
        };
        voting_escrow.set_locked(lock_id, new_locked_balance);
        voting_escrow.checkpoint_internal(
            option::some<ID>(lock_id),
            current_locked_balance,
            new_locked_balance,
            clock,
            ctx
        );
        let deposit_event = EventDeposit {
            lock_id,
            deposit_type,
            amount: lock_amount,
            unlock_time: new_locked_balance.end,
        };
        sui::event::emit<EventDeposit>(deposit_event);
        let supply_event = EventSupply {
            before: current_total_locked,
            after: voting_escrow.total_locked,
        };
        sui::event::emit<EventSupply>(supply_event);
    }

    /// Deposits a lock's tokens into a managed lock.
    /// This is used for delegation pools or other systems where users can contribute
    /// their locked tokens to a collectively managed position.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `voter_cap` - The voter capability to authorize the operation
    /// * `lock` - The lock containing tokens to deposit
    /// * `managed_lock` - The managed lock to deposit into
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the voter capability doesn't match the voting escrow
    /// * If the managed lock is not of type MANAGED
    /// * If the managed lock is deactivated
    /// * If the source lock is not of type NORMAL
    /// * If the source lock has no balance
    public fun deposit_managed<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock: &mut Lock,
        managed_lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(voter_cap.get_voter_id() == voting_escrow.voter, EDepositManagedInvalidVoter);
        let lock_id = object::id<Lock>(lock);
        let managed_lock_id = object::id<Lock>(managed_lock);
        assert!(voting_escrow.escrow_type(managed_lock_id) == EscrowType::MANAGED, EDepositManagedNotManagedType);
        assert!(!voting_escrow.deactivated(managed_lock_id), EDepositManagedDeactivated);
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::NORMAL, EDepositManagedNotNormalEscrow);
        assert!(
            voting_escrow.balance_of_nft_at_internal(lock_id, distribution::common::current_timestamp(clock)) > 0,
            EDepositManagedNoBalance
        );
        let current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        let current_locked_amount = current_locked_balance.amount;
        if (current_locked_balance.is_permanent) {
            voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance - current_locked_balance.amount;
            voting_escrow.delegate_internal(lock, object::id_from_address(@0x0), clock, ctx);
        };
        voting_escrow.checkpoint_internal(option::some<ID>(lock_id),
            current_locked_balance, locked_balance(0, 0, false, false), clock, ctx);
        voting_escrow.locked.remove(lock_id);
        voting_escrow.locked.add(lock_id, locked_balance(0, 0, false, false));
        voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance + current_locked_amount;
        let mut managed_locked_balance = *voting_escrow.locked.borrow(managed_lock_id);
        managed_locked_balance.amount = managed_locked_balance.amount + current_locked_amount;
        let delegatee_id = voting_escrow.voting_dao.delegatee(managed_lock_id);
        voting_escrow.voting_dao.checkpoint_delegatee(delegatee_id, current_locked_amount, true, clock, ctx);
        let old_managed_locked_balance = voting_escrow.locked.remove(managed_lock_id);
        voting_escrow.checkpoint_internal(
            option::some<ID>(managed_lock_id),
            old_managed_locked_balance,
            managed_locked_balance,
            clock,
            ctx
        );
        voting_escrow.locked.add(managed_lock_id, managed_locked_balance);
        if (!voting_escrow.managed_weights.contains(lock_id)) {
            voting_escrow.managed_weights.add(lock_id, sui::table::new<ID, u64>(ctx));
        };
        voting_escrow.managed_weights.borrow_mut(lock_id).add(managed_lock_id, current_locked_amount);
        voting_escrow.id_to_managed.add(lock_id, managed_lock_id);
        voting_escrow.escrow_type.add(lock_id, EscrowType::LOCKED);
        voting_escrow.managed_to_locked.borrow_mut(managed_lock_id).deposit(
            &voting_escrow.locked_managed_reward_authorized_cap,
            current_locked_amount,
            lock_id,
            clock,
            ctx
        );
        voting_escrow.managed_to_free.borrow_mut(managed_lock_id).deposit(
            &voting_escrow.free_managed_reward_authorized_cap,
            current_locked_amount,
            lock_id,
            clock,
            ctx
        );
        let deposit_managed_event = EventDepositManaged {
            owner: *voting_escrow.owner_of.borrow(lock_id),
            lock_id,
            managed_lock_id,
            amount: current_locked_amount,
        };
        sui::event::emit<EventDepositManaged>(deposit_managed_event);
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
        managed_lock.amount = managed_lock.amount + current_locked_amount;
    }

    /// Returns the end timestamp of a locked balance.
    ///
    /// # Arguments
    /// * `current_locked_balance` - The locked balance to query
    ///
    /// # Returns
    /// The timestamp when the lock ends
    public fun end(current_locked_balance: &LockedBalance): u64 {
        current_locked_balance.end
    }

    /// Returns the type of a lock (NORMAL, LOCKED, or MANAGED).
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to query
    ///
    /// # Returns
    /// The EscrowType of the lock
    public fun escrow_type<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): EscrowType {
        if (voting_escrow.escrow_type.contains(lock_id)) {
            *voting_escrow.escrow_type.borrow(lock_id)
        } else {
            EscrowType::NORMAL
        }
    }

    /// Returns the amount of rewards earned by a lock in a managed reward system.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to check rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Returns
    /// The amount of rewards earned
    public fun free_managed_reward_earned<SailCoinType, RewardCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        _ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<Lock>(lock);
        voting_escrow.managed_to_free.borrow(*voting_escrow.id_to_managed.borrow(lock_id)).earned<RewardCoinType>(
            lock_id,
            clock
        )
    }

    /// Claims rewards for a lock from the free managed reward system.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to claim rewards for
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun free_managed_reward_get_reward<SailCoinType, RewardCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let owner_proof = voting_escrow.owner_proof(lock, ctx);
        voting_escrow.managed_to_free.borrow_mut(
            *voting_escrow.id_to_managed.borrow(object::id<Lock>(lock))
        ).get_reward<RewardCoinType>(
            owner_proof,
            clock,
            ctx
        );
    }

    /// Adds new rewards to the free managed reward system for distribution.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `whitelisted_token` - Optional whitelisted token capability
    /// * `coin` - The reward tokens to distribute
    /// * `managed_lock_id` - The ID of the managed lock to associate rewards with
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    public fun free_managed_reward_notify_reward<SailCoinType, RewardCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        whitelisted_token: Option<distribution::whitelisted_tokens::WhitelistedToken>,
        coin: sui::coin::Coin<RewardCoinType>,
        managed_lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow
            .managed_to_free
            .borrow_mut(managed_lock_id)
            .notify_reward_amount(
                whitelisted_token,
                coin,
                clock,
                ctx
            );
    }

    /// Returns a list of reward token types available in the free managed reward system.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to check rewards for
    ///
    /// # Returns
    /// A vector of type names representing the available reward tokens
    public fun free_managed_reward_token_list<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID
    ): vector<std::type_name::TypeName> {
        voting_escrow
            .managed_to_free
            .borrow(*voting_escrow.id_to_managed.borrow(lock_id))
            .rewards_list()
    }

    fun get_past_global_point_index<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, mut epoch: u64, point_time: u64): u64 {
        if (epoch == 0) {
            return 0
        };
        if (!voting_escrow.point_history.contains(epoch) || voting_escrow.point_history.borrow(
            epoch
        ).ts <= point_time) {
            return epoch
        };
        if (voting_escrow.point_history.contains(1) && voting_escrow.point_history.borrow(1).ts > point_time) {
            return 0
        };
        let mut lower_bound = 0;
        while (epoch > lower_bound) {
            let middle_epoch = epoch - (epoch - lower_bound) / 2;
            assert!(voting_escrow.point_history.contains(middle_epoch), EPointHistoryInvalid);
            let middle_point = voting_escrow.point_history.borrow(middle_epoch);
            if (middle_point.ts == point_time) {
                return middle_epoch
            };
            if (middle_point.ts < point_time) {
                lower_bound = middle_epoch;
                continue
            };
            epoch = middle_epoch - 1;
        };
        lower_bound
    }

    fun get_past_power_point_index<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        time: u64
    ): u64 {
        if (!voting_escrow.user_point_epoch.contains(lock_id)) {
            return 0
        };
        let mut user_point_epoch = *voting_escrow.user_point_epoch.borrow(lock_id);
        if (user_point_epoch == 0) {
            return 0
        };
        if (voting_escrow.user_point_history.borrow(lock_id).borrow(user_point_epoch).ts <= time) {
            return user_point_epoch
        };
        if (
            voting_escrow.user_point_history.borrow(lock_id).contains(1) &&
                voting_escrow.user_point_history.borrow(lock_id).borrow(1).ts > time
        ) {
            return 0
        };
        let mut lower_bound_epoch = 0;
        while (user_point_epoch > lower_bound_epoch) {
            let middle_epoch = user_point_epoch - (user_point_epoch - lower_bound_epoch) / 2;
            assert!(
                voting_escrow.user_point_history.borrow(lock_id).contains(middle_epoch),
                EGetPastPowerPointError
            );
            let middle_epoch_points = voting_escrow.user_point_history.borrow(lock_id).borrow(middle_epoch);
            if (middle_epoch_points.ts == time) {
                return middle_epoch
            };
            if (middle_epoch_points.ts < time) {
                lower_bound_epoch = middle_epoch;
                continue
            };
            user_point_epoch = middle_epoch - 1;
        };
        lower_bound_epoch
    }

    public fun get_voting_power<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        clock: &sui::clock::Clock
    ): u64 {
        assert!(
            clock.timestamp_ms() - *voting_escrow.ownership_change_at.borrow(
                lock_id
            ) >= distribution::common::get_time_to_finality_ms(),
            EGetVotingPowerOwnershipChangeTooRecent
        );
        voting_escrow.balance_of_nft_at_internal(lock_id, distribution::common::current_timestamp(clock))
    }

    /// Returns the ID of the managed lock associated with a locked lock.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the locked lock
    ///
    /// # Returns
    /// The ID of the associated managed lock
    public fun id_to_managed<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): ID {
        *voting_escrow.id_to_managed.borrow(lock_id)
    }

    public fun increase_amount<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id(lock);
        assert!(!voting_escrow.deactivated(lock_id), EIncreaseAmountDeactivatedLock);
        let amount = coin.value();
        voting_escrow.balance.join(coin.into_balance());
        voting_escrow.increase_amount_for_internal(
            lock_id,
            amount,
            DepositType::INCREASE_LOCK_AMOUNT,
            clock,
            ctx
        );
        lock.amount = lock.amount + amount;
    }

    /// Internal implementation for increasing the amount of tokens in a lock.
    /// Handles the complex logic of updating voting power and rewards when adding tokens.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to increase the amount for
    /// * `amount_to_add` - The amount of tokens to add
    /// * `deposit_type` - The type of deposit being made
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the amount to add is zero
    /// * If the lock is of type LOCKED
    /// * If the lock doesn't exist
    /// * If the lock has no balance
    /// * If the lock has expired and is not permanent
    fun increase_amount_for_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID,
        amount_to_add: u64,
        deposit_type: DepositType,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(amount_to_add > 0, EIncreaseAmountZero);
        let escrow_type = voting_escrow.escrow_type(lock_id);
        assert!(escrow_type != EscrowType::LOCKED, EIncreaseAmountLockedEscrow);
        let (current_locked_balance, exists) = voting_escrow.locked(lock_id);
        assert!(exists, EIncreaseAmountNotExists);
        assert!(current_locked_balance.amount > 0, EIncreaseAmountNoBalance);
        assert!(
            current_locked_balance.end > distribution::common::current_timestamp(
                clock
            ) || current_locked_balance.is_permanent,
            EIncreaseTimeNotNormalEscrow
        );
        if (current_locked_balance.is_permanent) {
            voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance + amount_to_add;
        };
        let delegatee = voting_escrow.voting_dao.delegatee(lock_id);
        voting_escrow.voting_dao.checkpoint_delegatee(
            delegatee,
            amount_to_add,
            true,
            clock,
            ctx
        );
        voting_escrow.deposit_for_internal(
            lock_id,
            amount_to_add,
            0,
            current_locked_balance,
            deposit_type,
            clock,
            ctx
        );
        if (escrow_type == EscrowType::MANAGED) {
            voting_escrow.managed_to_locked.borrow_mut(lock_id).notify_reward_amount(
                &voting_escrow.locked_managed_reward_authorized_cap,
                sui::coin::from_balance<SailCoinType>(voting_escrow.balance.split(amount_to_add), ctx),
                clock,
                ctx
            );
        };
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
    }

    public fun increase_unlock_time<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        new_lock_duration_days: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, EIncreaseTimeNotNormalEscrow);
        let current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(!current_locked_balance.is_permanent, EIncreaseTimePermanent);
        let current_time = distribution::common::current_timestamp(clock);
        let lock_end_epoch_time = distribution::common::to_period(
            current_time + new_lock_duration_days * distribution::common::day()
        );
        assert!(current_locked_balance.end > current_time, EIncreaseTimeExpired);
        assert!(current_locked_balance.amount > 0, EIncreaseTimeNoBalance);
        assert!(lock_end_epoch_time > current_locked_balance.end, EIncreaseTimeNotLater);
        assert!(
            lock_end_epoch_time < current_time + (distribution::common::max_lock_time() as u64),
            EIncreaseTimeTooLong
        );
        voting_escrow.deposit_for_internal(
            lock_id,
            0,
            lock_end_epoch_time,
            current_locked_balance,
            DepositType::INCREASE_UNLOCK_TIME,
            clock,
            ctx
        );
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
        lock.start = current_time;
        lock.end = lock_end_epoch_time;
    }

    fun init(voting_escrow: VOTING_ESCROW, ctx: &mut TxContext) {
        let publisher = sui::package::claim<VOTING_ESCROW>(voting_escrow, ctx);
        set_display(&publisher, ctx);
        transfer::public_transfer<sui::package::Publisher>(publisher, tx_context::sender(ctx));
    }

    /// Checks if an escrow type is LOCKED.
    ///
    /// # Arguments
    /// * `escrow_type` - The escrow type to check
    ///
    /// # Returns
    /// True if the escrow type is LOCKED, false otherwise
    public fun is_locked(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::LOCKED
    }

    /// Checks if an escrow type is MANAGED.
    ///
    /// # Arguments
    /// * `escrow_type` - The escrow type to check
    ///
    /// # Returns
    /// True if the escrow type is MANAGED, false otherwise
    public fun is_managed(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::MANAGED
    }

    /// Checks if an escrow type is NORMAL.
    ///
    /// # Arguments
    /// * `escrow_type` - The escrow type to check
    ///
    /// # Returns
    /// True if the escrow type is NORMAL, false otherwise
    public fun is_normal(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::NORMAL
    }

    /// Checks if a locked balance is permanent.
    ///
    /// # Arguments
    /// * `is_permanent` - The locked balance to check
    ///
    /// # Returns
    /// True if the locked balance is permanent, false otherwise
    public fun is_permanent(is_permanent: &LockedBalance): bool {
        is_permanent.is_permanent
    }

    /// Checks if an address is allowed to split locks.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `who` - The address to check
    ///
    /// # Returns
    /// True if the address is allowed to split locks, false otherwise
    public fun is_split_allowed<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, who: address): bool {
        let can_user_split = if (voting_escrow.can_split.contains(who)) {
            *voting_escrow.can_split.borrow(who) == true
        } else {
            false
        };

        can_user_split || (
            voting_escrow.can_split.contains(@0x0) &&
                *voting_escrow.can_split.borrow(@0x0) == true
        )
    }

    public fun lock_has_voted<SailCoinType>(voting_escrow: &mut VotingEscrow<SailCoinType>, lock_id: ID): bool {
        if (voting_escrow.voted.contains(lock_id)) {
            let v1 = true;
            voting_escrow.voted.borrow(lock_id) == &v1
        } else {
            false
        }
    }

    /// Converts a normal lock into a permanent lock.
    /// Permanent locks never expire and maintain constant voting power.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to make permanent
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock is not of type NORMAL
    /// * If the lock is already permanent
    /// * If the lock has expired
    /// * If the lock has no balance
    public fun lock_permanent<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, ELockPermanentNotNormalEscrow);
        let v3 = *voting_escrow.locked.borrow(lock_id);
        assert!(!v3.is_permanent, ELockPermanentAlreadyPermanent);
        assert!(v3.end > distribution::common::current_timestamp(clock), ELockPermanentExpired);
        assert!(v3.amount > 0, ELockPermanentNoBalance);
        voting_escrow.lock_permanent_internal(lock, clock, ctx);
    }

    fun lock_permanent_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let mut current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance + current_locked_balance.amount;
        current_locked_balance.end = 0;
        current_locked_balance.is_permanent = true;
        let old_locked_balance = *voting_escrow.locked.borrow(lock_id);
        voting_escrow.checkpoint_internal(
            option::some<ID>(lock_id),
            old_locked_balance,
            current_locked_balance,
            clock,
            ctx
        );
        voting_escrow.locked.remove(lock_id);
        voting_escrow.locked.add(lock_id, current_locked_balance);
        let lock_permanent_event = EventLockPermanent {
            sender: tx_context::sender(ctx),
            lock_id,
            amount: current_locked_balance.amount,
        };
        sui::event::emit<EventLockPermanent>(lock_permanent_event);
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
        lock.end = 0;
        lock.permanent = true;
    }

    public fun locked<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): (LockedBalance, bool) {
        if (voting_escrow.locked.contains(lock_id)) {
            (*voting_escrow.locked.borrow(lock_id), true)
        } else {
            let lock_balance = LockedBalance {
                amount: 0,
                end: 0,
                is_permanent: false,
                is_perpetual: false,
            };
            (lock_balance, false)
        }
    }

    fun locked_balance(amount: u64, end_time: u64, is_permanent: bool, is_perpetual: bool): LockedBalance {
        LockedBalance {
            amount,
            end: end_time,
            is_permanent,
            is_perpetual,
        }
    }

    public fun managed_to_free<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): ID {
        object::id<distribution::free_managed_reward::FreeManagedReward>(
            voting_escrow.managed_to_free.borrow(lock_id)
        )
    }

    /// Merges two locks into one, combining their balances.
    /// This is useful for consolidating multiple positions.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_a` - The first lock to merge (will be consumed)
    /// * `lock_b` - The second lock to merge (will be updated)
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If lock_a has been used for voting
    /// * If either lock is not of type NORMAL
    /// * If both locks are the same
    /// * If lock_a is permanent
    /// * If lock_b has expired and is not permanent
    public fun merge<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_a: Lock,
        lock_b: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id_a = object::id<Lock>(&lock_a);
        let lock_id_b = object::id<Lock>(lock_b);
        let lock_a_voted = voting_escrow.lock_has_voted(lock_id_a);
        assert!(!lock_a_voted, EMergePositionVoted);
        assert!(voting_escrow.escrow_type(lock_id_a) == EscrowType::NORMAL, EMergeSourceNotNormalEscrow);
        assert!(voting_escrow.escrow_type(lock_id_b) == EscrowType::NORMAL, EMergeTargetNotNormalEscrow);
        assert!(lock_id_a != lock_id_b, EMergeSamePosition);
        let lock_b_balance = *voting_escrow.locked.borrow(lock_id_b);
        assert!(
            lock_b_balance.end > distribution::common::current_timestamp(clock) || lock_b_balance.is_permanent == true,
            EMergeSourcePermanent
        );
        let lock_a_balance = *voting_escrow.locked.borrow(lock_id_a);
        assert!(lock_a_balance.is_permanent == false, EMergeSourcePermanent);
        assert!(lock_a_balance.is_perpetual == false, EMergeSourcePerpetual);
        let max_end_time = if (lock_a_balance.end >= lock_b_balance.end) {
            lock_a_balance.end
        } else {
            lock_b_balance.end
        };
        voting_escrow.burn_lock_internal(lock_a, lock_a_balance, clock, ctx);
        let result_lock_end_time = if (lock_b_balance.is_permanent) {
            0
        } else {
            max_end_time
        };
        let new_locked_balance = locked_balance(
            lock_a_balance.amount + lock_b_balance.amount,
            result_lock_end_time,
            lock_b_balance.is_permanent,
            lock_b_balance.is_perpetual
        );
        if (new_locked_balance.is_permanent) {
            voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance + lock_a_balance.amount;
        };
        let delegatee = voting_escrow.voting_dao.delegatee(lock_id_b);
        voting_escrow.voting_dao.checkpoint_delegatee(
            delegatee,
            lock_a_balance.amount,
            true,
            clock,
            ctx
        );
        voting_escrow.checkpoint_internal(
            option::some<ID>(lock_id_b),
            lock_b_balance,
            new_locked_balance,
            clock,
            ctx
        );
        voting_escrow.locked.remove(lock_id_b);
        voting_escrow.locked.add(
            lock_id_b,
            new_locked_balance
        );
        lock_b.amount = new_locked_balance.amount;
        let merge_lock_event = EventMerge {
            sender: tx_context::sender(ctx),
            from: lock_id_a,
            to: lock_id_b,
            from_amount: lock_a_balance.amount,
            to_amount: lock_b_balance.amount,
            new_amount: new_locked_balance.amount,
            new_end: new_locked_balance.end,
        };
        sui::event::emit<EventMerge>(merge_lock_event);
        let metadata_update_event = EventMetadataUpdate { lock_id: lock_id_b };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
    }

    public fun owner_of<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): address {
        *voting_escrow.owner_of.borrow(lock_id)
    }

    public fun owner_proof<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock: &Lock,
        ctx: &mut TxContext
    ): distribution::lock_owner::OwnerProof {
        voting_escrow.validate_lock(lock);
        let sender = tx_context::sender(ctx);
        assert!(
            voting_escrow.owner_of.borrow(object::id<Lock>(lock)) == &sender,
            EOwnerProofNotOwner
        );
        distribution::lock_owner::issue(
            object::id<VotingEscrow<SailCoinType>>(voting_escrow),
            object::id<Lock>(lock),
            tx_context::sender(ctx)
        )
    }

    public fun ownership_change_at<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): u64 {
        *voting_escrow.ownership_change_at.borrow(lock_id)
    }

    public fun permanent_lock_balance<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>): u64 {
        voting_escrow.permanent_lock_balance
    }

    public fun remove_allowed_manager<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        publisher: &sui::package::Publisher,
        who: address
    ) {
        assert!(publisher.from_module<VOTING_ESCROW>(), ERemoveAllowedManagerInvalidPublisher);
        voting_escrow.allowed_managers.remove(&who);
    }

    /// Sets up the display properties for Lock NFTs so they appear correctly in wallets and explorers.
    /// This function configures metadata like name, locked amount, unlock time, and other properties
    /// that will be shown when viewing Lock NFTs.
    ///
    /// # Arguments
    /// * `publisher` - The publisher of the module, used to verify display creation authority
    /// * `ctx` - The transaction context, used to create the display and transfer it
    ///
    /// # Effects
    /// Creates and initializes a Display object for Lock NFTs with Fullsail-specific branding
    /// and transfers it to the transaction sender
    public fun set_display(publisher: &sui::package::Publisher, ctx: &mut TxContext) {
        let mut fields = std::vector::empty<std::string::String>();
        fields.push_back(std::string::utf8(b"name"));
        fields.push_back(std::string::utf8(b"locked_amount"));
        fields.push_back(std::string::utf8(b"unlock_timestamp"));
        fields.push_back(std::string::utf8(b"permanent"));
        fields.push_back(std::string::utf8(b"url"));
        fields.push_back(std::string::utf8(b"website"));
        fields.push_back(std::string::utf8(b"creator"));
        let mut values = std::vector::empty<std::string::String>();
        values.push_back(std::string::utf8(b"Fullsail Lock"));
        values.push_back(std::string::utf8(b"{amount}"));
        values.push_back(std::string::utf8(b"{end}"));
        values.push_back(std::string::utf8(b"{permanent}"));
        values.push_back(std::string::utf8(b""));
        values.push_back(std::string::utf8(b"https://app.fullsail.finance"));
        values.push_back(std::string::utf8(b"FULLSAIL"));
        let mut display = sui::display::new_with_fields<Lock>(
            publisher,
            fields,
            values,
            ctx
        );
        display.update_version();
        transfer::public_transfer<sui::display::Display<Lock>>(display, tx_context::sender(ctx));
    }

    fun set_locked<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID,
        lock_balance: LockedBalance
    ) {
        if (voting_escrow.locked.contains(lock_id)) {
            voting_escrow.locked.remove(lock_id);
        };
        voting_escrow.locked.add(lock_id, lock_balance);
    }

    /// Activates or deactivates a managed lock, requiring the emergency council's authorization.
    /// When a managed lock is deactivated, it can no longer accept new deposits, which is useful
    /// as a safety mechanism during unexpected situations or protocol updates.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `_emergency_council_cap` - Capability proving emergency council authorization
    /// * `lock_id` - The ID of the managed lock to activate/deactivate
    /// * `deactivated` - Boolean flag: true to deactivate, false to activate
    ///
    /// # Aborts
    /// * If the lock is not of type MANAGED
    /// * If the lock is already in the requested activation state
    public fun set_managed_lock_deactivated<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        lock_id: ID,
        deactivated: bool
    ) {
        emergency_council_cap.validate_emergency_council_voting_escrow_id(object::id(voting_escrow));
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::MANAGED, ESetManagedLockNotManagedType);
        assert!(
            !voting_escrow.deactivated.contains(lock_id) || voting_escrow.deactivated.borrow(lock_id) != &deactivated,
            ESetManagedLockAlreadySet
        );
        if (voting_escrow.deactivated.contains(lock_id)) {
            voting_escrow.deactivated.remove(lock_id);
        };
        voting_escrow.deactivated.add(lock_id, deactivated);
    }

    /// Stores a global checkpoint in the point history at the specified epoch.
    /// Updates or creates a record of the global voting power state at a particular epoch,
    /// which is essential for calculating historical voting power distribution.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `epoch` - The epoch number to store the point at
    /// * `point` - The GlobalPoint data containing bias, slope, timestamp and permanent lock balance
    fun set_point_history<SailCoinType>(voting_escrow: &mut VotingEscrow<SailCoinType>, epoch: u64, point: GlobalPoint) {
        if (voting_escrow.point_history.contains(epoch)) {
            voting_escrow.point_history.remove(epoch);
        };
        voting_escrow.point_history.add(epoch, point);
    }

    /// Records slope changes scheduled for a future epoch time.
    /// These slope changes track when voting power will decrease in the future due to
    /// locks expiring, which is critical for accurate voting power calculation over time.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `epoch_time` - The timestamp of the epoch when the slope change will occur
    /// * `slope_to_add` - The slope value to add (or subtract if negative) at that epoch time
    fun set_slope_changes<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        epoch_time: u64,
        slope_to_add: integer_mate::i128::I128
    ) {
        if (voting_escrow.slope_changes.contains(epoch_time)) {
            voting_escrow.slope_changes.remove(epoch_time);
        };
        voting_escrow.slope_changes.add(epoch_time, slope_to_add);
    }

    /// Updates the latest user point epoch for a specific lock.
    /// Keeps track of the most recent epoch number where a lock's voting power was updated,
    /// which helps efficiently retrieve voting power history.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to update the epoch for
    /// * `epoch` - The new epoch number to set
    fun set_user_point_epoch<SailCoinType>(voting_escrow: &mut VotingEscrow<SailCoinType>, lock_id: ID, epoch: u64) {
        if (voting_escrow.user_point_epoch.contains(lock_id)) {
            voting_escrow.user_point_epoch.remove(lock_id);
        };
        voting_escrow.user_point_epoch.add(lock_id, epoch);
    }

    /// Records a user's voting power point in the historical record at a specific epoch.
    /// This function maintains the per-lock voting power history, allowing the system to
    /// determine what voting power a specific lock had at any past point in time.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to update the point history for
    /// * `epoch` - The epoch number to store the point at
    /// * `point` - The UserPoint data containing bias, slope, timestamp and permanent amount
    /// * `ctx` - The transaction context, used to create new tables if needed
    fun set_user_point_history<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID,
        epoch: u64,
        point: UserPoint,
        ctx: &mut TxContext
    ) {
        if (!voting_escrow.user_point_history.contains(lock_id)) {
            voting_escrow.user_point_history.add(lock_id, sui::table::new<u64, UserPoint>(ctx));
        };
        let point_history = voting_escrow.user_point_history.borrow_mut(lock_id);
        if (point_history.contains(epoch)) {
            point_history.remove(epoch);
        };
        point_history.add(epoch, point);
    }


    public fun create_team_cap<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, publisher: &sui::package::Publisher, ctx: &mut TxContext): distribution::team_cap::TeamCap {
        assert!(publisher.from_module<VOTING_ESCROW>(), EGrantTeamCapInvalidPublisher);
        let team_cap = distribution::team_cap::create(object::id(voting_escrow), ctx);

        team_cap
    }


    /// Enables or disables the ability for an address to split locks.
    /// Split permission control is a governance feature that allows the team to regulate
    /// which addresses can split their locked positions, helping prevent potential market disruption
    /// or manipulation through excessive fragmentation of positions.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `team_cap` - The team capability used to authorize this privileged operation
    /// * `who` - The address to grant or revoke split permission for
    /// * `allowed` - Boolean flag: true to allow splitting, false to disallow
    ///
    /// # Events
    /// Emits an EventToggleSplit event with the address and new permission status
    public fun toggle_split<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        team_cap: &distribution::team_cap::TeamCap,
        who: address,
        allowed: bool
    ) {
        team_cap.validate(object::id<VotingEscrow<SailCoinType>>(voting_escrow));
        if (voting_escrow.can_split.contains(who)) {
            voting_escrow.can_split.remove(who);
        };
        voting_escrow.can_split.add(who, allowed);
        let toggle_split_event = EventToggleSplit {
            who,
            allowed,
        };
        sui::event::emit<EventToggleSplit>(toggle_split_event);
    }

    /// Returns the total amount of tokens locked in the voting escrow.
    /// This provides a view of the overall locked token supply, which is useful
    /// for protocol analytics and calculating the global participation rate.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    ///
    /// # Returns
    /// The total amount of tokens currently locked across all locks
    public fun total_locked<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>): u64 {
        voting_escrow.total_locked
    }

    /// Returns the total voting power supply at a specific timestamp.
    /// This is crucial for governance mechanics that need to know the
    /// total voting power at a particular point in time, such as calculating
    /// quorum or determining the weight of each vote relative to the whole.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `time` - The timestamp at which to calculate the total voting power
    ///
    /// # Returns
    /// The total voting power supply at the specified time
    public fun total_supply_at<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, time: u64): u64 {
        voting_escrow.total_supply_at_internal(voting_escrow.epoch, time)
    }

    /// Internal implementation to calculate the total voting power at a specific timestamp.
    /// This complex function implements the core voting power decay algorithm of the ve(3,3) model.
    /// It works by:
    /// 1. Finding the closest historical checkpoint before the requested time
    /// 2. Applying all scheduled slope changes between that checkpoint and the requested time
    /// 3. Calculating how much voting power has decayed due to the passage of time
    /// 4. Adding permanent lock balances that don't decay
    ///
    /// The function handles the linear decay of voting power for time-locked positions while
    /// accounting for scheduled changes in the decay rate (slopes) when locks expire.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `epoch` - The current epoch to start searching from
    /// * `time` - The timestamp at which to calculate the total voting power
    ///
    /// # Returns
    /// The total voting power at the specified timestamp, including both decaying and permanent locks
    ///
    /// # Algorithm
    /// Uses a bounded loop (max 255 iterations) to step through epochs, applying slope
    /// changes and calculating time-based decay until reaching the target timestamp
    fun total_supply_at_internal<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, epoch: u64, time: u64): u64 {
        let latest_point_index = voting_escrow.get_past_global_point_index(epoch, time);
        if (latest_point_index == 0) {
            return 0
        };
        let point = voting_escrow.point_history.borrow(latest_point_index);
        let mut bias = point.bias;
        let mut slope = point.slope;
        let point_time = point.ts;
        let mut point_epoch_time = distribution::common::to_period(point_time);
        let mut i = 0;
        while (i < 255) {
            let next_epoch_time = point_epoch_time + distribution::common::epoch();
            point_epoch_time = next_epoch_time;
            let mut slope_changes = integer_mate::i128::from(0);
            if (next_epoch_time > time) {
                point_epoch_time = time;
            } else {
                let next_epoch_slope_changes = if (voting_escrow.slope_changes.contains(next_epoch_time)) {
                    *voting_escrow.slope_changes.borrow(next_epoch_time)
                } else {
                    integer_mate::i128::from(0)
                };
                slope_changes = next_epoch_slope_changes;
            };
            bias = bias.sub(
                slope
                    .mul(integer_mate::i128::from(((point_epoch_time - point_time) as u128)))
                    .div(integer_mate::i128::from(1 << 64)));
            if (point_epoch_time == time) {
                break
            };
            slope = slope.add(slope_changes);
            i = i + 1;
        };
        if (bias.is_neg()) {
            bias = integer_mate::i128::from(0);
        };
        (bias.as_u128() as u64) + point.permanent_lock_balance
    }

    /// Converts a permanent lock back to a time-based lock with the maximum duration.
    /// This allows users to eventually withdraw tokens that were previously locked permanently.
    /// The converted lock will have a duration equal to the maximum lock time (typically 4 years),
    /// starting from the current time.
    ///
    /// When a permanent lock is converted:
    /// 1. The lock's voting power changes from constant to time-decaying
    /// 2. Any delegations are removed (delegation is only for permanent locks)
    /// 3. The global permanent lock balance is decreased
    /// 4. The system is checkpointed to record this change in voting power dynamics
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock` - The lock to convert from permanent to time-based
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the lock is not of type NORMAL
    /// * If the lock is currently used for voting
    /// * If the lock is not permanent
    ///
    /// # Events
    /// Emits EventUnlockPermanent and EventMetadataUpdate events
    public fun unlock_permanent<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let lock_id = object::id<Lock>(lock);
        let is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, EUnlockPermanentNotNormalEscrow);
        let has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!has_voted, EUnlockPermanentPositionVoted);
        let mut old_locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(old_locked_balance.is_permanent, EUnlockPermanentNotPermanent);
        assert!(!old_locked_balance.is_perpetual, EUnlockPermanentIsPerpetual);
        let current_time = distribution::common::current_timestamp(clock);
        voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance - old_locked_balance.amount;
        old_locked_balance.end = distribution::common::to_period(current_time + distribution::common::max_lock_time());
        old_locked_balance.is_permanent = false;
        voting_escrow.delegate_internal(lock, object::id_from_address(@0x0), clock, ctx);
        let current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        voting_escrow.checkpoint_internal(
            option::some<ID>(lock_id),
            current_locked_balance,
            old_locked_balance,
            clock,
            ctx
        );
        voting_escrow.locked.remove(lock_id);
        voting_escrow.locked.add(lock_id, old_locked_balance);
        lock.permanent = false;
        lock.end = old_locked_balance.end;
        lock.start = current_time;
        let permanent_unlock_event = EventUnlockPermanent {
            sender,
            lock_id,
            amount: old_locked_balance.amount,
        };
        sui::event::emit<EventUnlockPermanent>(permanent_unlock_event);
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
    }

    public fun user_point_epoch<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): u64 {
        *voting_escrow.user_point_epoch.borrow(lock_id)
    }

    public fun user_point_history<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID, epoch: u64): UserPoint {
        *voting_escrow.user_point_history.borrow(lock_id).borrow(epoch)
    }

    public fun user_point_ts(voting_escrow: &UserPoint): u64 {
        voting_escrow.ts
    }

    fun validate_lock<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock: &Lock) {
        assert!(lock.escrow == object::id<VotingEscrow<SailCoinType>>(voting_escrow), EValidateLockInvalidEscrow);
    }

    fun validate_lock_duration<SailCoinType>(_voting_escrow: &VotingEscrow<SailCoinType>, duration_days: u64) {
        assert!(
            duration_days * distribution::common::day() >= distribution::common::min_lock_time() &&
                duration_days * distribution::common::day() <= distribution::common::max_lock_time(),
            EValidateLockDurationInvalid
        );
    }

    /// Marks a lock as currently being used for voting or not.
    /// This function is called by governance systems when a lock is used to vote on proposals,
    /// preventing actions that might disrupt active votes (like withdrawing, splitting, or transferring).
    /// The lock remains frozen for operations until voting is completed and this flag is cleared.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `voter_cap` - The voter capability to authorize this operation
    /// * `lock_id` - The ID of the lock being used for voting
    /// * `is_voting` - Boolean flag: true when the lock is actively voting, false when done
    ///
    /// # Aborts
    /// * If the voter capability doesn't match the voting escrow instance
    ///
    /// # Security
    /// This operation requires the voter capability to prevent unauthorized freezing of positions.
    /// Only the authorized voter system should be able to mark locks as voting.
    public fun voting<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock_id: ID,
        is_voting: bool
    ) {
        assert!(voting_escrow.voter == voter_cap.get_voter_id(), EVotingInvalidVoter);
        if (voting_escrow.voted.contains(lock_id)) {
            voting_escrow.voted.remove(lock_id);
        };
        voting_escrow.voted.add(lock_id, is_voting);
    }

    /// Returns voting power delta for a given amount as if it was deposited into the lock and amount that cannot be deposited.
    /// If lock has ended, adding new voting power makes no sense. So we can't deposit anything and return the amount 
    /// that cannot be deposited as second return value.
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `lock_id` - The ID of the lock to simulate the deposit for
    /// * `amount` - The amount of tokens to simulate the deposit for
    /// * `clock` - The system clock
    ///
    /// # Returns
    /// The voting power delta for the given amount and the amount that cannot be deposited.
    public fun simulate_depoist<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        amount: u64,
        clock: &sui::clock::Clock,
    ): (u64, u64) {
        let locked_balance = voting_escrow.locked.borrow(lock_id);
        if (locked_balance.is_permanent || locked_balance.is_perpetual) {
            return (amount, 0);
        };
        let current_time = distribution::common::current_timestamp(clock);
        if (locked_balance.end <= current_time) {
            return (0, amount);
        };
        let remaining_time = locked_balance.end - current_time;
        let voting_power_delta = integer_mate::full_math_u64::mul_div_floor(
            amount,
            remaining_time,
            distribution::common::max_lock_time()
        );
        (voting_power_delta, 0)
    }

    /// Withdraws tokens and rewards from a managed lock back to the original lock.
    /// This allows users to exit from managed positions and regain control of their tokens.
    ///
    /// # Arguments
    /// * `voting_escrow` - The voting escrow instance
    /// * `voter_cap` - The voter capability to authorize the operation
    /// * `lock` - The original lock to withdraw back to
    /// * `managed_lock` - The managed lock to withdraw from
    /// * `owner_proof` - Proof of ownership of the lock
    /// * `clock` - The system clock
    /// * `ctx` - The transaction context
    ///
    /// # Aborts
    /// * If the voter capability doesn't match the voting escrow
    /// * If the lock is not managed
    /// * If the lock is not of type LOCKED
    /// * If the managed lock ID doesn't match
    public fun withdraw_managed<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock: &mut Lock,
        managed_lock: &mut Lock,
        owner_proof: distribution::lock_owner::OwnerProof,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        assert!(voter_cap.get_voter_id() == voting_escrow.voter, EWithdrawManagedInvalidVoter);
        assert!(voting_escrow.id_to_managed.contains(lock_id), EWithdrawManagedNotManaged);
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::LOCKED, EWithdrawManagedNotLockedType);
        let managed_lock_id = *voting_escrow.id_to_managed.borrow(lock_id);
        assert!(managed_lock_id == object::id<Lock>(managed_lock), EWithdrawManagedInvalidManagedLock);
        let locked_managed_reward = voting_escrow.managed_to_locked.borrow_mut(managed_lock_id);
        let managed_weight = *voting_escrow.managed_weights.borrow(lock_id).borrow(managed_lock_id);
        let new_managed_weight = managed_weight + locked_managed_reward.earned<SailCoinType>(lock_id, clock);
        let lock_end_time = distribution::common::to_period(
            distribution::common::current_timestamp(clock) + distribution::common::max_lock_time()
        );
        voting_escrow.managed_to_free.borrow_mut(managed_lock_id).get_reward<SailCoinType>(owner_proof, clock, ctx);
        voting_escrow.balance.join<SailCoinType>(locked_managed_reward.get_reward<SailCoinType>(
            &voting_escrow.locked_managed_reward_authorized_cap,
            lock_id,
            clock,
            ctx
        ));
        lock.amount = new_managed_weight;
        lock.permanent = false;
        lock.end = lock_end_time;
        managed_lock.amount = managed_lock.amount - managed_weight;
        let lock_balance = voting_escrow.locked.remove(lock_id);
        // this function has already been written in a way that is never returns permanent locks.
        // This is the reason why we create permanent locked balance only if it is already perpetual.
        let is_new_lock_permanent = lock.perpetual;
        let new_lock_balance = locked_balance(new_managed_weight, lock_end_time, is_new_lock_permanent, lock.perpetual);
        voting_escrow.checkpoint_internal(option::some<ID>(lock_id), lock_balance, new_lock_balance, clock, ctx);
        voting_escrow.locked.add(lock_id, new_lock_balance);
        let mut managed_lock_balance = *voting_escrow.locked.borrow(managed_lock_id);
        let remaining_amount = if (new_managed_weight < managed_lock_balance.amount) {
            managed_lock_balance.amount - new_managed_weight
        } else {
            0
        };
        managed_lock_balance.amount = remaining_amount;
        let new_weight = if (new_managed_weight < voting_escrow.permanent_lock_balance) {
            new_managed_weight
        } else {
            voting_escrow.permanent_lock_balance
        };
        voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance - new_weight;
        let delegatee_id = voting_escrow.voting_dao.delegatee(managed_lock_id);
        voting_escrow.voting_dao.checkpoint_delegatee(delegatee_id, new_managed_weight, false, clock, ctx);
        let old_lock_balance = voting_escrow.locked.remove(managed_lock_id);
        voting_escrow.checkpoint_internal(
            option::some<ID>(managed_lock_id),
            old_lock_balance,
            managed_lock_balance,
            clock,
            ctx
        );
        voting_escrow.locked.add(managed_lock_id, managed_lock_balance);
        voting_escrow.managed_to_locked.borrow_mut(managed_lock_id).withdraw(
            &voting_escrow.locked_managed_reward_authorized_cap,
            managed_weight,
            lock_id,
            clock,
            ctx
        );
        voting_escrow.managed_to_free.borrow_mut(managed_lock_id).withdraw(
            &voting_escrow.free_managed_reward_authorized_cap,
            managed_weight,
            lock_id,
            clock,
            ctx
        );
        voting_escrow.id_to_managed.remove(lock_id);
        voting_escrow.managed_weights.borrow_mut(lock_id).remove(managed_lock_id);
        voting_escrow.escrow_type.remove(lock_id);
        let event = EventWithdrawManaged {
            owner: *voting_escrow.owner_of.borrow(lock_id),
            lock_id,
            managed_lock_id,
            amount: new_managed_weight,
            perpetual: lock.perpetual,
        };
        sui::event::emit<EventWithdrawManaged>(event);
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
    }

    // Returns the voter ID of the voting escrow.
    public fun get_voter_id<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>): ID {
        voting_escrow.voter
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext): sui::package::Publisher {
        let publisher = sui::package::claim<VOTING_ESCROW>(VOTING_ESCROW {}, ctx);
        set_display(&publisher, ctx);
        publisher
    }
    
    #[test_only]
    public fun get_amount(lock: &Lock): u64 {
        lock.amount
    }
}


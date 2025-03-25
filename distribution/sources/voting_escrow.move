module distribution::voting_escrow {
    public struct VOTING_ESCROW has drop {}

    public struct DistributorCap has store, key {
        id: UID,
        ve: ID,
    }

    public struct Lock has store, key {
        id: UID,
        escrow: ID,
        amount: u64,
        start: u64,
        end: u64,
        permanent: bool,
    }

    public struct CreateLockReceipt {
        amount: u64,
    }

    public struct LockedBalance has copy, drop, store {
        amount: u64,
        end: u64,
        is_permanent: bool,
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
        min_lock_time: u64,
        max_lock_time: u64,
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

    public fun split<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: Lock,
        amount: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (ID, ID) {
        voting_escrow.validate_lock(&lock);
        let lock_id = object::id<Lock>(&lock);
        assert!(voting_escrow.owner_of.contains(lock_id), 9223375992521621535);
        let owner_of_lock = *voting_escrow.owner_of.borrow(lock_id);
        assert!(
            voting_escrow.is_split_allowed(owner_of_lock) || voting_escrow.is_split_allowed(tx_context::sender(ctx)),
            9223376001110900757
        );
        let mut is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, 9223376005406130201);
        let lock_has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!lock_has_voted, 9223376009701228571);
        let locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(
            locked_balance.end > distribution::common::current_timestamp(clock) || locked_balance.is_permanent,
            9223376026879787015
        );
        assert!(amount > 0, 9223376031174623237);
        assert!(locked_balance.amount > amount, 9223376035471163421);
        let lock_escrow_id = lock.escrow;
        let lock_start = lock.start;
        let lock_end = lock.end;
        voting_escrow.burn_lock_internal(lock, locked_balance, clock, ctx);
        let split_lock_a = voting_escrow.create_split_internal(
            owner_of_lock,
            lock_escrow_id,
            lock_start,
            lock_end,
            locked_balance(locked_balance.amount - amount, locked_balance.end, locked_balance.is_permanent),
            clock,
            ctx
        );
        let split_lock_b = voting_escrow.create_split_internal(
            owner_of_lock,
            lock_escrow_id,
            lock_start,
            lock_end,
            locked_balance(amount, locked_balance.end, locked_balance.is_permanent),
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

    public fun transfer<SailCoinType>(
        lock: Lock,
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        recipient: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(lock.escrow == object::id<VotingEscrow<SailCoinType>>(voting_escrow), 9223376864398016511);
        let lock_id = object::id<Lock>(&lock);
        if (recipient == voting_escrow.owner_of(lock_id) && recipient == tx_context::sender(ctx)) {
            transfer::transfer<Lock>(lock, recipient);
        } else {
            assert!(voting_escrow.escrow_type(lock_id) != EscrowType::LOCKED, 9223376885873770511);
            let owner_of_lock = voting_escrow.owner_of.remove(lock_id);
            assert!(owner_of_lock == tx_context::sender(ctx), 9223376898757754879);
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

    public fun create<SailCoinType>(
        _publisher: &sui::package::Publisher,
        voter_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): VotingEscrow<SailCoinType> {
        let uid = object::new(ctx);
        let inner_id = object::uid_to_inner(&uid);
        let mut voting_escrow = VotingEscrow<SailCoinType> {
            id: uid,
            voter: voter_id,
            balance: sui::balance::zero<SailCoinType>(),
            total_locked: 0,
            point_history: sui::table::new<u64, GlobalPoint>(ctx),
            epoch: 0,
            min_lock_time: distribution::common::min_lock_time(),
            max_lock_time: distribution::common::max_lock_time(),
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

    public fun withdraw<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let lock_id = object::id<Lock>(&lock);
        let lock_has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!lock_has_voted, 9223376404838219803);
        assert!(
            !voting_escrow.escrow_type.contains(lock_id) || *voting_escrow.escrow_type.borrow(
                lock_id
            ) == EscrowType::NORMAL,
            9223376409133056025
        );
        let locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(!locked_balance.is_permanent, 9223376422018613283);
        assert!(distribution::common::current_timestamp(clock) >= locked_balance.end, 9223376430606843913);
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

    public fun add_allowed_manager<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        _publisher: &sui::package::Publisher,
        who: address
    ) {
        voting_escrow.allowed_managers.insert(who);
    }

    public fun amount(locked_balance: &LockedBalance): u64 {
        locked_balance.amount
    }

    public fun balance_of_nft_at<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>,
        lock_id: ID,
        time: u64
    ): u64 {
        voting_escrow.balance_of_nft_at_internal(lock_id, time)
    }

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

    public fun borrow_allowed_managers<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>
    ): &sui::vec_set::VecSet<address> {
        &voting_escrow.allowed_managers
    }

    public fun borrow_managed_locks<SailCoinType>(
        voting_escrow: &VotingEscrow<SailCoinType>
    ): &sui::vec_set::VecSet<ID> {
        &voting_escrow.managed_locks
    }

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
            locked_balance(0, 0, false),
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
        } = lock;
        object::delete(id);
    }

    public fun checkpoint<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.checkpoint_internal(
            option::none<ID>(),
            locked_balance(0, 0, false),
            locked_balance(0, 0, false),
            clock,
            ctx
        );
    }

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
        let last_point_timestamp = current_point.ts;
        // TODO: it was useless code, find out why it was here
        // GlobalPoint {
        //     bias: current_point.bias,
        //     slope: current_point.slope,
        //     ts: current_point.ts,
        //     permanent_lock_balance: current_point.permanent_lock_balance
        // };
        let mut period_timestamp = distribution::common::to_period(last_point_timestamp);
        let mut i = 0;
        while (i < 255) {
            let next_week_timestamp = period_timestamp + distribution::common::week();
            period_timestamp = next_week_timestamp;
            let mut slope_change = integer_mate::i128::from(0);
            if (next_week_timestamp > current_timestamp) {
                period_timestamp = current_timestamp;
            } else {
                let existing_slope_change = if (voting_escrow.slope_changes.contains(next_week_timestamp)) {
                    *voting_escrow.slope_changes.borrow(next_week_timestamp)
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

    public fun create_lock<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        coin_to_lock: sui::coin::Coin<SailCoinType>,
        lock_duration_days: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.validate_lock_duration(lock_duration_days);
        let lock_amount = coin_to_lock.value();
        assert!(lock_amount > 0, 9223374381907181573);
        let current_time = distribution::common::current_timestamp(clock);
        let sender = tx_context::sender(ctx);
        let (lock_immut, create_lock_receipt) = voting_escrow.create_lock_internal(
            sender,
            lock_amount,
            current_time,
            distribution::common::to_period(current_time + lock_duration_days * distribution::common::day()),
            permanent,
            clock,
            ctx
        );
        let mut lock = lock_immut;
        let CreateLockReceipt { amount: amout } = create_lock_receipt;
        assert!(amout == lock_amount, 9223374416266657791);
        voting_escrow.balance.join(coin_to_lock.into_balance());
        if (permanent) {
            voting_escrow.lock_permanent_internal(&mut lock, clock, ctx);
        };
        transfer::transfer<Lock>(lock, sender);
    }

    public fun create_lock_for<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        owner: address,
        coin: sui::coin::Coin<T0>,
        arg3: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        voting_escrow.validate_lock_duration(arg3);
        let lock_amount = coin.value();
        assert!(lock_amount > 0, 9223374257353129989);
        let start_time = distribution::common::current_timestamp(clock);
        let (lock_immut, create_lock_receipt) = voting_escrow.create_lock_internal(
            owner,
            lock_amount,
            start_time,
            distribution::common::to_period(start_time + arg3 * distribution::common::day()),
            permanent,
            clock,
            ctx
        );
        let mut lock = lock_immut;
        let CreateLockReceipt { amount } = create_lock_receipt;
        assert!(amount == lock_amount, 9223374287417638911);
        voting_escrow.balance.join(coin.into_balance());
        if (permanent) {
            voting_escrow.lock_permanent_internal(&mut lock, clock, ctx);
        };
        transfer::transfer<Lock>(lock, owner);
    }

    fun create_lock_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        lock_amount: u64,
        start_time: u64,
        end_time: u64,
        permanent: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): (Lock, CreateLockReceipt) {
        let lock = Lock {
            id: object::new(ctx),
            escrow: object::id<VotingEscrow<SailCoinType>>(voting_escrow),
            amount: lock_amount,
            start: start_time,
            end: end_time,
            permanent,
        };
        let lock_id = object::id<Lock>(&lock);
        assert!(!voting_escrow.owner_of.contains(lock_id), 9223374171453521919);
        assert!(!voting_escrow.locked.contains(lock_id), 9223374175748489215);
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
            locked_balance(0, 0, permanent),
            DepositType::CREATE_LOCK_TYPE,
            clock,
            ctx
        );
        let create_lock_event = EventCreateLock {
            lock_id,
            owner,
        };
        sui::event::emit<EventCreateLock>(create_lock_event);
        let create_lock_receipt = CreateLockReceipt { amount: lock_amount };
        (lock, create_lock_receipt)
    }

    public fun create_managed_lock_for<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        owner: address,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): ID {
        let sender = tx_context::sender(ctx);
        assert!(voting_escrow.allowed_managers.contains(&sender), 9223377736277688341);
        let (lock, create_lock_receipt) = voting_escrow.create_lock_internal(
            owner,
            0,
            distribution::common::current_timestamp(clock),
            0,
            true,
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
        transfer::public_share_object<Lock>(lock);
        lock_id
    }

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
            locked_balance(0, 0, false),
            current_locked_balance,
            clock,
            ctx
        );
        lock
    }

    fun create_user_point(): UserPoint {
        UserPoint {
            bias: integer_mate::i128::from(0),
            slope: integer_mate::i128::from(0),
            ts: 0,
            permanent: 0,
        }
    }

    public fun deactivated<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, arg1: ID): bool {
        voting_escrow.deactivated.contains(arg1) && *voting_escrow.deactivated.borrow(arg1)
    }

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

    fun delegate_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &Lock,
        mut delegatee: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let (current_locked_balance, _) = voting_escrow.locked(lock_id);
        assert!(current_locked_balance.is_permanent, 9223375657513386003);
        assert!(
            delegatee == object::id_from_address(@0x0) || voting_escrow.owner_of.contains(delegatee),
            9223375661808615447
        );
        if (object::id<Lock>(lock) == delegatee) {
            delegatee = object::id_from_address(@0x0);
        };
        assert!(
            clock.timestamp_ms() - *voting_escrow.ownership_change_at.borrow(
                lock_id
            ) >= distribution::common::get_time_to_finality(),
            9223375683284107297
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

    public fun deposit_for<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        coin: sui::coin::Coin<SailCoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let deposit_amount = coin.value<SailCoinType>();
        voting_escrow.balance.join<SailCoinType>(coin.into_balance());
        voting_escrow.increase_amount_for_internal(
            object::id<Lock>(lock),
            deposit_amount,
            DepositType::DEPOSIT_FOR_TYPE,
            clock,
            ctx
        );
        lock.amount = lock.amount + deposit_amount;
    }

    fun deposit_for_internal<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
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
            current_locked_balance.is_permanent
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

    public fun deposit_managed<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock: &mut Lock,
        managed_lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(voter_cap.get_voter_id() == voting_escrow.voter, 9223377839355592703);
        let lock_id = object::id<Lock>(lock);
        let managed_lock_id = object::id<Lock>(managed_lock);
        assert!(voting_escrow.escrow_type(managed_lock_id) == EscrowType::MANAGED, 9223377847948279851);
        assert!(!voting_escrow.deactivated(managed_lock_id), 9223377852244295739);
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::NORMAL, 9223377856537034777);
        assert!(
            voting_escrow.balance_of_nft_at_internal(lock_id, distribution::common::current_timestamp(clock)) > 0,
            9223377865125658629
        );
        let current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        let current_locked_amount = current_locked_balance.amount;
        if (current_locked_balance.is_permanent) {
            voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance - current_locked_balance.amount;
            voting_escrow.delegate_internal(lock, object::id_from_address(@0x0), clock, ctx);
        };
        voting_escrow.checkpoint_internal(option::some<ID>(lock_id),
            current_locked_balance, locked_balance(0, 0, false), clock, ctx);
        voting_escrow.locked.remove(lock_id);
        voting_escrow.locked.add(lock_id, locked_balance(0, 0, false));
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

    public fun end(current_locked_balance: &LockedBalance): u64 {
        current_locked_balance.end
    }

    public fun escrow_type<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): EscrowType {
        if (voting_escrow.escrow_type.contains(lock_id)) {
            *voting_escrow.escrow_type.borrow(lock_id)
        } else {
            EscrowType::NORMAL
        }
    }

    public fun free_managed_reward_earned<SailCoinType, RewardCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): u64 {
        let lock_id = object::id<Lock>(lock);
        voting_escrow.managed_to_free.borrow(*voting_escrow.id_to_managed.borrow(lock_id)).earned<RewardCoinType>(
            lock_id,
            clock
        )
    }

    public fun free_managed_reward_get_reward<SailCoinType, RewardCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let v0 = voting_escrow.owner_proof(lock, ctx);
        voting_escrow.managed_to_free.borrow_mut(
            *voting_escrow.id_to_managed.borrow(object::id<Lock>(lock))
        ).get_reward<RewardCoinType>(
            v0,
            clock,
            ctx
        );
    }

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

    public fun free_managed_reward_token_list<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID
    ): vector<std::type_name::TypeName> {
        voting_escrow
            .managed_to_free
            .borrow(*voting_escrow.id_to_managed.borrow(lock_id))
            .rewards_list()
    }

    fun get_past_global_point_index<T0>(voting_escrow: &VotingEscrow<T0>, mut epoch: u64, point_time: u64): u64 {
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
            assert!(voting_escrow.point_history.contains(middle_epoch), 999);
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
                9223377117801086975
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
        lock: &Lock,
        clock: &sui::clock::Clock
    ): u64 {
        let lock_id = object::id<Lock>(lock);
        assert!(
            clock.timestamp_ms() - *voting_escrow.ownership_change_at.borrow(
                lock_id
            ) >= distribution::common::get_time_to_finality(),
            9223376997544099873
        );
        voting_escrow.balance_of_nft_at_internal(lock_id, distribution::common::current_timestamp(clock))
    }

    public fun id_to_managed<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, lock_id: ID): ID {
        *voting_escrow.id_to_managed.borrow(lock_id)
    }

    public fun increase_amount<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        lock: &mut Lock,
        coin: sui::coin::Coin<T0>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin.value();
        voting_escrow.balance.join(coin.into_balance());
        voting_escrow.increase_amount_for_internal(
            object::id<Lock>(lock),
            amount,
            DepositType::INCREASE_LOCK_AMOUNT,
            clock,
            ctx
        );
        lock.amount = lock.amount + amount;
    }

    fun increase_amount_for_internal<SailCoinType>(
        voting_escrow: &mut VotingEscrow<SailCoinType>,
        lock_id: ID,
        amount_to_add: u64,
        deposit_type: DepositType,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        assert!(amount_to_add > 0, 9223374463511560197);
        let escrow_type = voting_escrow.escrow_type(lock_id);
        assert!(escrow_type != EscrowType::LOCKED, 9223374472102150159);
        let (current_locked_balance, exists) = voting_escrow.locked(lock_id);
        assert!(exists, 9223374484986134527);
        assert!(current_locked_balance.amount > 0, 9223374484987183121);
        assert!(
            current_locked_balance.end > distribution::common::current_timestamp(
                clock
            ) || current_locked_balance.is_permanent,
            9223374493576462343
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
        days_to_add: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        let is_normal_escrow = if (!voting_escrow.escrow_type.contains(lock_id)) {
            true
        } else {
            *voting_escrow.escrow_type.borrow(lock_id) == EscrowType::NORMAL
        };
        assert!(is_normal_escrow, 9223376301758873625);
        let current_locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(!current_locked_balance.is_permanent, 9223376314644430883);
        let current_time = distribution::common::current_timestamp(clock);
        let lock_end_epoch_time = distribution::common::to_period(
            current_time + days_to_add * distribution::common::day()
        );
        assert!(current_locked_balance.end > current_time, 9223376331822465031);
        assert!(current_locked_balance.amount > 0, 9223376336118087697);
        assert!(lock_end_epoch_time > current_locked_balance.end, 9223376340414365733);
        assert!(
            lock_end_epoch_time < current_time + (distribution::common::max_lock_time() as u64),
            9223376344709464103
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

    public fun is_locked(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::LOCKED
    }

    public fun is_managed(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::MANAGED
    }

    public fun is_normal(escrow_type: EscrowType): bool {
        escrow_type == EscrowType::NORMAL
    }

    public fun is_permanent(is_permanent: &LockedBalance): bool {
        is_permanent.is_permanent
    }

    public fun is_split_allowed<SailCoinType>(voting_escrow: &VotingEscrow<SailCoinType>, who: address): bool {
        let can_user_split = if (voting_escrow.can_split.contains(who)) {
            let v1 = true;
            voting_escrow.can_split.borrow(who) == &v1
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
        assert!(is_normal_escrow, 9223376525097173017);
        let v3 = *voting_escrow.locked.borrow(lock_id);
        assert!(!v3.is_permanent, 9223376537982730275);
        assert!(v3.end > distribution::common::current_timestamp(clock), 9223376542275862535);
        assert!(v3.amount > 0, 9223376546571485201);
        voting_escrow.lock_permanent_internal(lock, clock, ctx);
    }

    fun lock_permanent_internal<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
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

    public fun locked<T0>(voting_escrow: &VotingEscrow<T0>, lock_id: ID): (LockedBalance, bool) {
        if (voting_escrow.locked.contains(lock_id)) {
            (*voting_escrow.locked.borrow(lock_id), true)
        } else {
            let lock_balance = LockedBalance {
                amount: 0,
                end: 0,
                is_permanent: false,
            };
            (lock_balance, false)
        }
    }

    fun locked_balance(amount: u64, end_time: u64, is_permanent: bool): LockedBalance {
        LockedBalance {
            amount,
            end: end_time,
            is_permanent,
        }
    }

    public fun managed_to_free<T0>(voting_escrow: &VotingEscrow<T0>, lock_id: ID): ID {
        object::id<distribution::free_managed_reward::FreeManagedReward>(
            voting_escrow.managed_to_free.borrow(lock_id)
        )
    }

    public fun merge<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        lock_a: Lock,
        lock_b: &mut Lock,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id_a = object::id<Lock>(&lock_a);
        let lock_id_b = object::id<Lock>(lock_b);
        let lock_a_voted = voting_escrow.lock_has_voted(lock_id_a);
        assert!(!lock_a_voted, 9223376074125738011);
        assert!(voting_escrow.escrow_type(lock_id_a) == EscrowType::NORMAL, 9223376078420574233);
        assert!(voting_escrow.escrow_type(lock_id_b) == EscrowType::NORMAL, 9223376082715541529);
        assert!(lock_id_a != lock_id_b, 9223376087012474935);
        let lock_b_balance = *voting_escrow.locked.borrow(lock_id_b);
        assert!(
            lock_b_balance.end > distribution::common::current_timestamp(clock) || lock_b_balance.is_permanent == true,
            9223376108484165639
        );
        let lock_a_balance = *voting_escrow.locked.borrow(lock_id_a);
        assert!(lock_a_balance.is_permanent == false, 9223376117075935267);
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
            lock_b_balance.is_permanent
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

    public fun owner_of<T0>(voting_escrow: &VotingEscrow<T0>, lock_id: ID): address {
        *voting_escrow.owner_of.borrow(lock_id)
    }

    public fun owner_proof<T0>(
        voting_escrow: &VotingEscrow<T0>,
        lock: &Lock,
        ctx: &mut TxContext
    ): distribution::lock_owner::OwnerProof {
        voting_escrow.validate_lock(lock);
        let sender = tx_context::sender(ctx);
        assert!(
            voting_escrow.owner_of.borrow(object::id<Lock>(lock)) == &sender,
            9223373209380847615
        );
        distribution::lock_owner::issue(
            object::id<VotingEscrow<T0>>(voting_escrow),
            object::id<Lock>(lock),
            tx_context::sender(ctx)
        )
    }

    public fun ownership_change_at<T0>(voting_escrow: &VotingEscrow<T0>, arg1: ID): u64 {
        *voting_escrow.ownership_change_at.borrow(arg1)
    }

    public fun permanent_lock_balance<T0>(voting_escrow: &VotingEscrow<T0>): u64 {
        voting_escrow.permanent_lock_balance
    }

    public fun remove_allowed_manager<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        _publisher: &sui::package::Publisher,
        who: address
    ) {
        voting_escrow.allowed_managers.remove(&who);
    }

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
        values.push_back(std::string::utf8(b"Magma Lock"));
        values.push_back(std::string::utf8(b"{amount}"));
        values.push_back(std::string::utf8(b"{end}"));
        values.push_back(std::string::utf8(b"{permanent}"));
        values.push_back(std::string::utf8(b""));
        values.push_back(std::string::utf8(b"https://magmafinance.io"));
        values.push_back(std::string::utf8(b"MAGMA"));
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

    public fun set_managed_lock_deactivated<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        _emergency_council_cap: &distribution::emergency_council::EmergencyCouncilCap,
        lock_id: ID,
        deactivated: bool
    ) {
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::MANAGED, 9223378500783308843);
        assert!(
            !voting_escrow.deactivated.contains(lock_id) || voting_escrow.deactivated.borrow(lock_id) != &deactivated,
            9223378505078931509
        );
        if (voting_escrow.deactivated.contains(lock_id)) {
            voting_escrow.deactivated.remove(lock_id);
        };
        voting_escrow.deactivated.add(lock_id, deactivated);
    }

    fun set_point_history<T0>(voting_escrow: &mut VotingEscrow<T0>, epoch: u64, point: GlobalPoint) {
        if (voting_escrow.point_history.contains(epoch)) {
            voting_escrow.point_history.remove(epoch);
        };
        voting_escrow.point_history.add(epoch, point);
    }

    fun set_slope_changes<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        epoch_time: u64,
        slope_to_add: integer_mate::i128::I128
    ) {
        if (voting_escrow.slope_changes.contains(epoch_time)) {
            voting_escrow.slope_changes.remove(epoch_time);
        };
        voting_escrow.slope_changes.add(epoch_time, slope_to_add);
    }

    fun set_user_point_epoch<T0>(voting_escrow: &mut VotingEscrow<T0>, lock_id: ID, epoch: u64) {
        if (voting_escrow.user_point_epoch.contains(lock_id)) {
            voting_escrow.user_point_epoch.remove(lock_id);
        };
        voting_escrow.user_point_epoch.add(lock_id, epoch);
    }

    fun set_user_point_history<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
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

    public fun toggle_split<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        team_cap: &distribution::team_cap::TeamCap,
        who: address,
        allowed: bool
    ) {
        team_cap.validate(object::id<VotingEscrow<T0>>(voting_escrow));
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

    public fun total_locked<T0>(voting_escrow: &VotingEscrow<T0>): u64 {
        voting_escrow.total_locked
    }

    public fun total_supply_at<T0>(voting_escrow: &VotingEscrow<T0>, time: u64): u64 {
        voting_escrow.total_supply_at_internal(voting_escrow.epoch, time)
    }

    fun total_supply_at_internal<T0>(voting_escrow: &VotingEscrow<T0>, epoch: u64, time: u64): u64 {
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
            let next_epoch_time = point_epoch_time + distribution::common::week();
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

    public fun unlock_permanent<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
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
        assert!(is_normal_escrow, 9223376666831093785);
        let has_voted = voting_escrow.lock_has_voted(lock_id);
        assert!(!has_voted, 9223376671126192155);
        let mut old_locked_balance = *voting_escrow.locked.borrow(lock_id);
        assert!(old_locked_balance.is_permanent, 9223376679715602451);
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

    public fun user_point_history<T0>(voting_escrow: &VotingEscrow<T0>, lock_id: ID, epoch: u64): UserPoint {
        *voting_escrow.user_point_history.borrow(lock_id).borrow(epoch)
    }

    public fun user_point_ts(voting_escrow: &UserPoint): u64 {
        voting_escrow.ts
    }

    fun validate_lock<T0>(voting_escrow: &VotingEscrow<T0>, lock: &Lock) {
        assert!(lock.escrow == object::id<VotingEscrow<T0>>(voting_escrow), 9223376052649197567);
    }

    fun validate_lock_duration<T0>(voting_escrow: &VotingEscrow<T0>, duration_days: u64) {
        assert!(
            duration_days * distribution::common::day() >= voting_escrow.min_lock_time &&
                duration_days * distribution::common::day() <= voting_escrow.max_lock_time,
            9223374111324635147
        );
    }

    public fun voting<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock_id: ID,
        is_voting: bool
    ) {
        assert!(voting_escrow.voter == voter_cap.get_voter_id(), 9223374076964241407);
        if (voting_escrow.voted.contains(lock_id)) {
            voting_escrow.voted.remove(lock_id);
        };
        voting_escrow.voted.add(lock_id, is_voting);
    }

    public fun withdraw_managed<T0>(
        voting_escrow: &mut VotingEscrow<T0>,
        voter_cap: &distribution::voter_cap::VoterCap,
        lock: &mut Lock,
        managed_lock: &mut Lock,
        owner_proof: distribution::lock_owner::OwnerProof,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let lock_id = object::id<Lock>(lock);
        assert!(voter_cap.get_voter_id() == voting_escrow.voter, 9223378084171612205);
        assert!(voting_escrow.id_to_managed.contains(lock_id), 9223378088466710575);
        assert!(voting_escrow.escrow_type(lock_id) == EscrowType::LOCKED, 9223378092761808945);
        let managed_lock_id = *voting_escrow.id_to_managed.borrow(lock_id);
        assert!(managed_lock_id == object::id<Lock>(managed_lock), 9223378105646579759);
        let locked_managed_reward = voting_escrow.managed_to_locked.borrow_mut(managed_lock_id);
        let managed_weight = *voting_escrow.managed_weights.borrow(lock_id).borrow(managed_lock_id);
        let new_managed_weight = managed_weight + locked_managed_reward.earned<T0>(lock_id, clock);
        let lock_end_time = distribution::common::to_period(
            distribution::common::current_timestamp(clock) + distribution::common::max_lock_time()
        );
        voting_escrow.managed_to_free.borrow_mut(managed_lock_id).get_reward<T0>(owner_proof, clock, ctx);
        voting_escrow.balance.join<T0>(locked_managed_reward.get_reward<T0>(
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
        let new_lock_balance = locked_balance(new_managed_weight, lock_end_time, false);
        voting_escrow.checkpoint_internal(option::some<ID>(lock_id), lock_balance, new_lock_balance, clock, ctx);
        voting_escrow.locked.add(lock_id, new_lock_balance);
        let mut managed_lock_balance = *voting_escrow.locked.borrow(managed_lock_id);
        let mut v9 = if (new_managed_weight < managed_lock_balance.amount) {
            managed_lock_balance.amount - new_managed_weight
        } else {
            0
        };
        managed_lock_balance.amount = v9;
        let mut v10 = if (new_managed_weight < voting_escrow.permanent_lock_balance) {
            new_managed_weight
        } else {
            voting_escrow.permanent_lock_balance
        };
        voting_escrow.permanent_lock_balance = voting_escrow.permanent_lock_balance - v10;
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
        let v12 = EventWithdrawManaged {
            owner: *voting_escrow.owner_of.borrow(lock_id),
            lock_id,
            managed_lock_id,
            amount: new_managed_weight,
        };
        sui::event::emit<EventWithdrawManaged>(v12);
        let metadata_update_event = EventMetadataUpdate { lock_id };
        sui::event::emit<EventMetadataUpdate>(metadata_update_event);
    }
}


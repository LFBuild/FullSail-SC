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

    public struct VotingEscrow<phantom T0> has store, key {
        id: UID,
        voter: ID,
        balance: sui::balance::Balance<T0>,
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

    public fun split<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Lock,
        arg2: u64,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ): (ID, ID) {
        arg0.validate_lock(&arg1);
        let v0 = object::id<Lock>(&arg1);
        assert!(arg0.owner_of.contains(v0), 9223375992521621535);
        let v1 = *arg0.owner_of.borrow(v0);
        assert!(
            arg0.is_split_allowed(v1) || arg0.is_split_allowed(tx_context::sender(arg4)),
            9223376001110900757
        );
        let mut v2 = if (!arg0.escrow_type.contains(v0)) {
            true
        } else {
            let v3 = EscrowType::NORMAL;
            arg0.escrow_type.borrow(v0) == &v3
        };
        assert!(v2, 9223376005406130201);
        let v4 = arg0.lock_has_voted(v0);
        assert!(!v4, 9223376009701228571);
        let v5 = *arg0.locked.borrow(v0);
        assert!(v5.end > distribution::common::current_timestamp(arg3) || v5.is_permanent, 9223376026879787015);
        assert!(arg2 > 0, 9223376031174623237);
        assert!(v5.amount > arg2, 9223376035471163421);
        let v6 = arg1.escrow;
        let v7 = arg1.start;
        let v8 = arg1.end;
        arg0.burn_lock_internal(arg1, v5, arg3, arg4);
        let v9 = arg0.create_split_internal(
            v1,
            v6,
            v7,
            v8,
            locked_balance(v5.amount - arg2, v5.end, v5.is_permanent),
            arg3,
            arg4
        );
        let v10 = arg0.create_split_internal(v1, v6, v7, v8, locked_balance(arg2, v5.end, v5.is_permanent), arg3, arg4);
        let v11 = object::id<Lock>(&v9);
        let v12 = object::id<Lock>(&v10);
        let v13 = EventSplit {
            original_id: v0,
            new_id1: v11,
            new_id2: v12,
            amount1: v9.amount,
            amount2: v10.amount,
        };
        sui::event::emit<EventSplit>(v13);
        v9.transfer(arg0, v1, arg3, arg4);
        v10.transfer(arg0, v1, arg3, arg4);
        (v11, v12)
    }

    public fun transfer<T0>(
        arg0: Lock,
        arg1: &mut VotingEscrow<T0>,
        arg2: address,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        assert!(arg0.escrow == object::id<VotingEscrow<T0>>(arg1), 9223376864398016511);
        let v0 = object::id<Lock>(&arg0);
        if (arg2 == arg1.owner_of(v0) && arg2 == tx_context::sender(arg4)) {
            transfer::transfer<Lock>(arg0, arg2);
        } else {
            assert!(arg1.escrow_type(v0) != EscrowType::LOCKED, 9223376885873770511);
            let v1 = arg1.owner_of.remove(v0);
            assert!(v1 == tx_context::sender(arg4), 9223376898757754879);
            arg1.voting_dao.checkpoint_delegator(v0, 0, object::id_from_address(@0x0), arg2, arg3, arg4);
            arg1.owner_of.add(v0, arg2);
            if (arg1.ownership_change_at.contains(v0)) {
                arg1.ownership_change_at.remove(v0);
            };
            arg1.ownership_change_at.add(v0, arg3.timestamp_ms());
            transfer::transfer<Lock>(arg0, arg2);
            let v2 = EventTransfer {
                from: v1,
                to: arg2,
                lock: v0,
            };
            sui::event::emit<EventTransfer>(v2);
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

    public fun withdraw<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ) {
        let v0 = tx_context::sender(arg3);
        let v1 = object::id<Lock>(&arg1);
        let v2 = arg0.lock_has_voted(v1);
        assert!(!v2, 9223376404838219803);
        assert!(
            !arg0.escrow_type.contains(v1) || *arg0.escrow_type.borrow(v1) == EscrowType::NORMAL,
            9223376409133056025
        );
        let v3 = *arg0.locked.borrow(v1);
        assert!(!v3.is_permanent, 9223376422018613283);
        assert!(distribution::common::current_timestamp(arg2) >= v3.end, 9223376430606843913);
        let v4 = arg0.total_locked;
        arg0.total_locked = arg0.total_locked - v3.amount;
        arg0.burn_lock_internal(arg1, v3, arg2, arg3);
        transfer::public_transfer<sui::coin::Coin<T0>>(
            sui::coin::from_balance<T0>(arg0.balance.split(v3.amount), arg3),
            v0
        );
        let v5 = EventWithdraw {
            sender: v0,
            lock_id: v1,
            amount: v3.amount,
        };
        sui::event::emit<EventWithdraw>(v5);
        let v6 = EventSupply {
            before: v4,
            after: v4 - v3.amount,
        };
        sui::event::emit<EventSupply>(v6);
    }

    public fun add_allowed_manager<T0>(arg0: &mut VotingEscrow<T0>, _arg1: &sui::package::Publisher, arg2: address) {
        arg0.allowed_managers.insert(arg2);
    }

    public fun amount(arg0: &LockedBalance): u64 {
        arg0.amount
    }

    public fun balance_of_nft_at<T0>(arg0: &VotingEscrow<T0>, arg1: ID, arg2: u64): u64 {
        arg0.balance_of_nft_at_internal(arg1, arg2)
    }

    fun balance_of_nft_at_internal<T0>(arg0: &VotingEscrow<T0>, arg1: ID, arg2: u64): u64 {
        let v0 = arg0.get_past_power_point_index(arg1, arg2);
        if (v0 == 0) {
            return 0
        };
        let mut v1 = *arg0.user_point_history.borrow(arg1).borrow(v0);
        if (v1.permanent > 0) {
            v1.permanent
        } else {
            v1.bias = v1.bias.sub(
                v1.slope.mul(
                    integer_mate::i128::from((arg2 as u128)).sub(integer_mate::i128::from((v1.ts as u128)))
                ).div(integer_mate::i128::from(1 << 64))
            );
            if (v1.bias.is_neg()) {
                v1.bias = integer_mate::i128::from(0);
            };
            (v1.bias.as_u128() as u64)
        }
    }

    public fun borrow_allowed_managers<T0>(arg0: &VotingEscrow<T0>): &sui::vec_set::VecSet<address> {
        &arg0.allowed_managers
    }

    public fun borrow_managed_locks<T0>(arg0: &VotingEscrow<T0>): &sui::vec_set::VecSet<ID> {
        &arg0.managed_locks
    }

    fun burn_lock_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Lock,
        arg2: LockedBalance,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = object::id<Lock>(&arg1);
        arg0.voting_dao.checkpoint_delegator(v0, arg2.amount, object::id_from_address(@0x0), @0x0, arg3, arg4);
        arg0.owner_of.remove(v0);
        arg0.locked.remove(v0);
        arg0.checkpoint_internal(option::some<ID>(v0), arg2, locked_balance(0, 0, false), arg3, arg4);
        let Lock {
            id: v1,
            escrow: _,
            amount: _,
            start: _,
            end: _,
            permanent: _,
        } = arg1;
        object::delete(v1);
    }

    public fun checkpoint<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &sui::clock::Clock,
        arg2: &mut TxContext
    ) {
        arg0.checkpoint_internal(
            option::none<ID>(),
            locked_balance(0, 0, false),
            locked_balance(0, 0, false),
            arg1,
            arg2
        );
    }

    fun checkpoint_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Option<ID>,
        arg2: LockedBalance,
        arg3: LockedBalance,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        let mut v0 = create_user_point();
        let mut v1 = create_user_point();
        let mut v2 = integer_mate::i128::from(0);
        let mut v3 = integer_mate::i128::from(0);
        let v4 = arg0.epoch;
        let mut v5 = v4;
        let v6 = distribution::common::current_timestamp(arg4);
        if (arg1.is_some()) {
            let v7 = if (arg3.is_permanent) {
                arg3.amount
            } else {
                0
            };
            v1.permanent = v7;
            if (arg2.end > v6 && arg2.amount > 0) {
                v0.slope = integer_mate::i128::from(
                    integer_mate::full_math_u128::mul_div_floor(
                        (arg2.amount as u128),
                        1 << 64,
                        (distribution::common::max_lock_time() as u128)
                    )
                );
                v0.bias = v0.slope.mul(integer_mate::i128::from(((arg2.end - v6) as u128))).div(
                    integer_mate::i128::from(1 << 64)
                );
            };
            if (arg3.end > v6 && arg3.amount > 0) {
                v1.slope = integer_mate::i128::from(
                    integer_mate::full_math_u128::mul_div_floor(
                        (arg3.amount as u128),
                        1 << 64,
                        (distribution::common::max_lock_time() as u128)
                    )
                );
                v1.bias = v1.slope.mul(integer_mate::i128::from(((arg3.end - v6) as u128))).div(
                    integer_mate::i128::from(1 << 64)
                );
            };
            let v8 = if (arg0.slope_changes.contains(arg2.end)) {
                *arg0.slope_changes.borrow(arg2.end)
            } else {
                integer_mate::i128::from(0)
            };
            v2 = v8;
            if (arg3.end != 0) {
                if (arg3.end == arg2.end) {
                    v3 = v8;
                } else {
                    let v9 = if (arg0.slope_changes.contains(arg3.end)) {
                        *arg0.slope_changes.borrow(arg3.end)
                    } else {
                        integer_mate::i128::from(0)
                    };
                    v3 = v9;
                };
            };
        };
        let v10 = if (v4 > 0) {
            *arg0.point_history.borrow(v4)
        } else {
            GlobalPoint {
                bias: integer_mate::i128::from(0), slope: integer_mate::i128::from(
                    0
                ), ts: v6, permanent_lock_balance: 0
            }
        };
        let mut v11 = v10;
        let v12 = v11.ts;
        GlobalPoint { bias: v11.bias, slope: v11.slope, ts: v11.ts, permanent_lock_balance: v11.permanent_lock_balance };
        let mut v13 = distribution::common::to_period(v12);
        let mut v14 = 0;
        while (v14 < 255) {
            let v15 = v13 + distribution::common::week();
            v13 = v15;
            let mut v16 = integer_mate::i128::from(0);
            if (v15 > v6) {
                v13 = v6;
            } else {
                let v17 = if (arg0.slope_changes.contains(v15)) {
                    *arg0.slope_changes.borrow(v15)
                } else {
                    integer_mate::i128::from(0)
                };
                v16 = v17;
            };
            v11.bias = v11.bias.sub(
                v11.slope.mul(integer_mate::i128::from(((v13 - v12) as u128))).div(integer_mate::i128::from(1 << 64))
            );
            v11.slope = v11.slope.add(v16);
            if (v11.bias.is_neg()) {
                v11.bias = integer_mate::i128::from(0);
            };
            if (v11.slope.is_neg()) {
                v11.slope = integer_mate::i128::from(0);
            };
            v11.ts = v13;
            let v18 = v5 + 1;
            v5 = v18;
            if (v13 == v6) {
                break
            };
            arg0.set_point_history(v18, v11);
            v14 = v14 + 1;
        };
        if (arg1.is_some()) {
            v11.slope = v11.slope.add(v1.slope.sub(v0.slope));
            v11.bias = v11.bias.add(v1.bias.sub(v0.bias));
            if (v11.slope.is_neg()) {
                v11.slope = integer_mate::i128::from(0);
            };
            if (v11.bias.is_neg()) {
                v11.bias = integer_mate::i128::from(0);
            };
            v11.permanent_lock_balance = arg0.permanent_lock_balance;
        };
        let v19 = if (v5 != 1) {
            if (arg0.point_history.contains(v5 - 1)) {
                arg0.point_history.borrow(v5 - 1).ts == v6
            } else {
                false
            }
        } else {
            false
        };
        if (v19) {
            arg0.set_point_history(v5 - 1, v11);
        } else {
            arg0.epoch = v5;
            arg0.set_point_history(v5, v11);
        };
        if (arg1.is_some()) {
            if (arg2.end > v6) {
                let v20 = v2.add(v0.slope);
                v2 = v20;
                if (arg3.end == arg2.end) {
                    v2 = v20.sub(v1.slope);
                };
                arg0.set_slope_changes(arg2.end, v2);
            };
            if (arg3.end > v6) {
                if (arg3.end > arg2.end) {
                    arg0.set_slope_changes(arg3.end, v3.sub(v1.slope));
                };
            };
            let v21 = *arg1.borrow();
            v1.ts = v6;
            let v22 = if (arg0.user_point_epoch.contains(v21)) {
                *arg0.user_point_epoch.borrow(v21)
            } else {
                0
            };
            let v23 = if (v22 != 0) {
                if (arg0.user_point_history.borrow(v21).contains(v22)) {
                    arg0.user_point_history.borrow(v21).borrow(v22).ts == v6
                } else {
                    false
                }
            } else {
                false
            };
            if (v23) {
                arg0.set_user_point_history(v21, v22, v1, arg5);
            } else {
                arg0.set_user_point_epoch(v21, v22 + 1);
                arg0.set_user_point_history(v21, v22 + 1, v1, arg5);
            };
        };
    }

    public fun create_lock<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: sui::coin::Coin<T0>,
        arg2: u64,
        arg3: bool,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        arg0.validate_lock_duration(arg2);
        let v0 = arg1.value();
        assert!(v0 > 0, 9223374381907181573);
        let v1 = distribution::common::current_timestamp(arg4);
        let v2 = tx_context::sender(arg5);
        let (v3, v4) = arg0.create_lock_internal(
            v2,
            v0,
            v1,
            distribution::common::to_period(v1 + arg2 * distribution::common::day()),
            arg3,
            arg4,
            arg5
        );
        let mut v5 = v3;
        let CreateLockReceipt { amount: v6 } = v4;
        assert!(v6 == v0, 9223374416266657791);
        arg0.balance.join(arg1.into_balance());
        if (arg3) {
            let v7 = &mut v5;
            arg0.lock_permanent_internal(v7, arg4, arg5);
        };
        transfer::transfer<Lock>(v5, v2);
    }

    public fun create_lock_for<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: address,
        arg2: sui::coin::Coin<T0>,
        arg3: u64,
        arg4: bool,
        arg5: &sui::clock::Clock,
        arg6: &mut TxContext
    ) {
        arg0.validate_lock_duration(arg3);
        let v0 = arg2.value();
        assert!(v0 > 0, 9223374257353129989);
        let v1 = distribution::common::current_timestamp(arg5);
        let (v2, v3) = arg0.create_lock_internal(
            arg1,
            v0,
            v1,
            distribution::common::to_period(v1 + arg3 * distribution::common::day()),
            arg4,
            arg5,
            arg6
        );
        let mut v4 = v2;
        let CreateLockReceipt { amount: v5 } = v3;
        assert!(v5 == v0, 9223374287417638911);
        arg0.balance.join(arg2.into_balance());
        if (arg4) {
            let v6 = &mut v4;
            arg0.lock_permanent_internal(v6, arg5, arg6);
        };
        transfer::transfer<Lock>(v4, arg1);
    }

    fun create_lock_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: address,
        arg2: u64,
        arg3: u64,
        arg4: u64,
        arg5: bool,
        arg6: &sui::clock::Clock,
        arg7: &mut TxContext
    ): (Lock, CreateLockReceipt) {
        let v0 = Lock {
            id: object::new(arg7),
            escrow: object::id<VotingEscrow<T0>>(arg0),
            amount: arg2,
            start: arg3,
            end: arg4,
            permanent: arg5,
        };
        let v1 = object::id<Lock>(&v0);
        assert!(!arg0.owner_of.contains(v1), 9223374171453521919);
        assert!(!arg0.locked.contains(v1), 9223374175748489215);
        arg0.owner_of.add(v1, arg1);
        arg0.ownership_change_at.add(v1, arg6.timestamp_ms());
        arg0.voting_dao.checkpoint_delegator(v1, arg2, object::id_from_address(@0x0), arg1, arg6, arg7);
        arg0.deposit_for_internal(
            v1,
            arg2,
            arg4,
            locked_balance(0, 0, arg5),
            DepositType::CREATE_LOCK_TYPE,
            arg6,
            arg7
        );
        let v2 = EventCreateLock {
            lock_id: v1,
            owner: arg1,
        };
        sui::event::emit<EventCreateLock>(v2);
        let v3 = CreateLockReceipt { amount: arg2 };
        (v0, v3)
    }

    public fun create_managed_lock_for<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: address,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ): ID {
        let v0 = tx_context::sender(arg3);
        assert!(arg0.allowed_managers.contains(&v0), 9223377736277688341);
        let (v1, v2) = arg0.create_lock_internal(
            arg1,
            0,
            distribution::common::current_timestamp(arg2),
            0,
            true,
            arg2,
            arg3
        );
        let v3 = v1;
        let CreateLockReceipt { amount: _ } = v2;
        let v4 = object::id<Lock>(&v3);
        arg0.managed_locks.insert(v4);
        arg0.escrow_type.add(v4, EscrowType::MANAGED);
        let v5 = std::type_name::get<T0>();
        let v6 = distribution::locked_managed_reward::create(
            arg0.voter,
            object::id<VotingEscrow<T0>>(arg0),
            v5,
            arg3
        );
        let v7 = distribution::free_managed_reward::create(
            arg0.voter,
            object::id<VotingEscrow<T0>>(arg0),
            v5,
            arg3
        );
        let v8 = EventCreateManaged {
            owner: arg1,
            lock_id: v4,
            sender: v0,
            locked_managed_reward: object::id<distribution::locked_managed_reward::LockedManagedReward>(&v6),
            free_managed_reward: object::id<distribution::free_managed_reward::FreeManagedReward>(&v7),
        };
        sui::event::emit<EventCreateManaged>(v8);
        arg0.managed_to_locked.add(v4, v6);
        arg0.managed_to_free.add(v4, v7);
        transfer::public_share_object<Lock>(v3);
        v4
    }

    fun create_split_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: address,
        arg2: ID,
        arg3: u64,
        arg4: u64,
        arg5: LockedBalance,
        arg6: &sui::clock::Clock,
        arg7: &mut TxContext
    ): Lock {
        let v0 = Lock {
            id: object::new(arg7),
            escrow: arg2,
            amount: arg5.amount,
            start: arg3,
            end: arg4,
            permanent: arg5.is_permanent,
        };
        let v1 = object::id<Lock>(&v0);
        arg0.locked.add(v1, arg5);
        arg0.owner_of.add(v1, arg1);
        arg0.ownership_change_at.add(v1, arg6.timestamp_ms());
        arg0.voting_dao.checkpoint_delegator(v1, arg5.amount, object::id_from_address(@0x0), arg1, arg6, arg7);
        arg0.checkpoint_internal(
            option::some<ID>(object::id<Lock>(&v0)),
            locked_balance(0, 0, false),
            arg5,
            arg6,
            arg7
        );
        v0
    }

    fun create_user_point(): UserPoint {
        UserPoint {
            bias: integer_mate::i128::from(0),
            slope: integer_mate::i128::from(0),
            ts: 0,
            permanent: 0,
        }
    }

    public fun deactivated<T0>(arg0: &VotingEscrow<T0>, arg1: ID): bool {
        arg0.deactivated.contains(arg1) && *arg0.deactivated.borrow(arg1)
    }

    public fun delegate<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &Lock,
        arg2: ID,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        arg0.validate_lock(arg1);
        arg0.delegate_internal(arg1, arg2, arg3, arg4);
    }

    fun delegate_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &Lock,
        mut arg2: ID,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = object::id<Lock>(arg1);
        let (v1, _) = arg0.locked(v0);
        let v3 = v1;
        assert!(v3.is_permanent, 9223375657513386003);
        assert!(
            arg2 == object::id_from_address(@0x0) || arg0.owner_of.contains(arg2),
            9223375661808615447
        );
        if (object::id<Lock>(arg1) == arg2) {
            arg2 = object::id_from_address(@0x0);
        };
        assert!(
            arg3.timestamp_ms() - *arg0.ownership_change_at.borrow(v0) >= distribution::common::get_time_to_finality(),
            9223375683284107297
        );
        let v4 = arg0.voting_dao.delegatee(v0);
        if (v4 == arg2) {
            return
        };
        arg0.voting_dao.checkpoint_delegator(v0, v3.amount, arg2, *arg0.owner_of.borrow(v0), arg3, arg4);
        arg0.voting_dao.checkpoint_delegatee(arg2, v3.amount, true, arg3, arg4);
        let v5 = EventDelegateChanged {
            old: v4,
            new: arg2,
        };
        sui::event::emit<EventDelegateChanged>(v5);
    }

    public fun deposit_for<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: sui::coin::Coin<T0>,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = arg2.value<T0>();
        arg0.balance.join<T0>(arg2.into_balance());
        arg0.increase_amount_for_internal(object::id<Lock>(arg1), v0, DepositType::DEPOSIT_FOR_TYPE, arg3, arg4);
        arg1.amount = arg1.amount + v0;
    }

    fun deposit_for_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: ID,
        arg2: u64,
        arg3: u64,
        arg4: LockedBalance,
        arg5: DepositType,
        arg6: &sui::clock::Clock,
        arg7: &mut TxContext
    ) {
        let v0 = arg0.total_locked;
        arg0.total_locked = arg0.total_locked + arg2;
        let mut v1 = locked_balance(arg4.amount, arg4.end, arg4.is_permanent);
        v1.amount = v1.amount + arg2;
        if (arg3 != 0) {
            v1.end = arg3;
        };
        arg0.set_locked(arg1, v1);
        arg0.checkpoint_internal(option::some<ID>(arg1), arg4, v1, arg6, arg7);
        let v2 = EventDeposit {
            lock_id: arg1,
            deposit_type: arg5,
            amount: arg2,
            unlock_time: v1.end,
        };
        sui::event::emit<EventDeposit>(v2);
        let v3 = EventSupply {
            before: v0,
            after: arg0.total_locked,
        };
        sui::event::emit<EventSupply>(v3);
    }

    public fun deposit_managed<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &distribution::voter_cap::VoterCap,
        arg2: &mut Lock,
        arg3: &mut Lock,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        assert!(arg1.get_voter_id() == arg0.voter, 9223377839355592703);
        let v0 = object::id<Lock>(arg2);
        let v1 = object::id<Lock>(arg3);
        assert!(arg0.escrow_type(v1) == EscrowType::MANAGED, 9223377847948279851);
        assert!(!arg0.deactivated(v1), 9223377852244295739);
        assert!(arg0.escrow_type(v0) == EscrowType::NORMAL, 9223377856537034777);
        assert!(
            arg0.balance_of_nft_at_internal(v0, distribution::common::current_timestamp(arg4)) > 0,
            9223377865125658629
        );
        let v2 = *arg0.locked.borrow(v0);
        let v3 = v2.amount;
        if (v2.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance - v2.amount;
            arg0.delegate_internal(arg2, object::id_from_address(@0x0), arg4, arg5);
        };
        arg0.checkpoint_internal(option::some<ID>(v0), v2, locked_balance(0, 0, false), arg4, arg5);
        arg0.locked.remove(v0);
        arg0.locked.add(v0, locked_balance(0, 0, false));
        arg0.permanent_lock_balance = arg0.permanent_lock_balance + v3;
        let mut v4 = *arg0.locked.borrow(v1);
        v4.amount = v4.amount + v3;
        let delegatee_id = arg0.voting_dao.delegatee(v1);
        arg0.voting_dao.checkpoint_delegatee(delegatee_id, v3, true, arg4, arg5);
        let v5 = arg0.locked.remove(v1);
        arg0.checkpoint_internal(option::some<ID>(v1), v5, v4, arg4, arg5);
        arg0.locked.add(v1, v4);
        if (!arg0.managed_weights.contains(v0)) {
            arg0.managed_weights.add(v0, sui::table::new<ID, u64>(arg5));
        };
        arg0.managed_weights.borrow_mut(v0).add(v1, v3);
        arg0.id_to_managed.add(v0, v1);
        arg0.escrow_type.add(v0, EscrowType::LOCKED);
        arg0.managed_to_locked.borrow_mut(v1).deposit(&arg0.locked_managed_reward_authorized_cap, v3, v0, arg4, arg5);
        arg0.managed_to_free.borrow_mut(v1).deposit(&arg0.free_managed_reward_authorized_cap, v3, v0, arg4, arg5);
        let v6 = EventDepositManaged {
            owner: *arg0.owner_of.borrow(v0),
            lock_id: v0,
            managed_lock_id: v1,
            amount: v3,
        };
        sui::event::emit<EventDepositManaged>(v6);
        let v7 = EventMetadataUpdate { lock_id: v0 };
        sui::event::emit<EventMetadataUpdate>(v7);
        arg3.amount = arg3.amount + v3;
    }

    public fun end(arg0: &LockedBalance): u64 {
        arg0.end
    }

    public fun escrow_type<T0>(arg0: &VotingEscrow<T0>, arg1: ID): EscrowType {
        if (arg0.escrow_type.contains(arg1)) {
            *arg0.escrow_type.borrow(arg1)
        } else {
            EscrowType::NORMAL
        }
    }

    public fun free_managed_reward_earned<T0, T1>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ): u64 {
        let v0 = object::id<Lock>(arg1);
        arg0.managed_to_free.borrow(*arg0.id_to_managed.borrow(v0)).earned<T1>(v0, arg2)
    }

    public fun free_managed_reward_get_reward<T0, T1>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ) {
        let v0 = arg0.owner_proof(arg1, arg3);
        arg0.managed_to_free.borrow_mut(*arg0.id_to_managed.borrow(object::id<Lock>(arg1))).get_reward<T1>(
            v0,
            arg2,
            arg3
        );
    }

    public fun free_managed_reward_notify_reward<T0, T1>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Option<distribution::whitelisted_tokens::WhitelistedToken>,
        arg2: sui::coin::Coin<T1>,
        arg3: ID,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        arg0.managed_to_free.borrow_mut(arg3).notify_reward_amount(arg1, arg2, arg4, arg5);
    }

    public fun free_managed_reward_token_list<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: ID
    ): vector<std::type_name::TypeName> {
        arg0.managed_to_free.borrow(*arg0.id_to_managed.borrow(arg1)).rewards_list()
    }

    fun get_past_global_point_index<T0>(arg0: &VotingEscrow<T0>, mut arg1: u64, arg2: u64): u64 {
        if (arg1 == 0) {
            return 0
        };
        if (!arg0.point_history.contains(arg1) || arg0.point_history.borrow(arg1).ts <= arg2) {
            return arg1
        };
        if (arg0.point_history.contains(1) && arg0.point_history.borrow(1).ts > arg2) {
            return 0
        };
        let mut v0 = 0;
        while (arg1 > v0) {
            let v1 = arg1 - (arg1 - v0) / 2;
            assert!(arg0.point_history.contains(v1), 999);
            let v2 = arg0.point_history.borrow(v1);
            if (v2.ts == arg2) {
                return v1
            };
            if (v2.ts < arg2) {
                v0 = v1;
                continue
            };
            arg1 = v1 - 1;
        };
        v0
    }

    fun get_past_power_point_index<T0>(arg0: &VotingEscrow<T0>, arg1: ID, arg2: u64): u64 {
        if (!arg0.user_point_epoch.contains(arg1)) {
            return 0
        };
        let mut v0 = *arg0.user_point_epoch.borrow(arg1);
        if (v0 == 0) {
            return 0
        };
        if (arg0.user_point_history.borrow(arg1).borrow(v0).ts <= arg2) {
            return v0
        };
        if (arg0.user_point_history.borrow(arg1).contains(1) && arg0.user_point_history.borrow(arg1).borrow(
            1
        ).ts > arg2) {
            return 0
        };
        let mut v1 = 0;
        while (v0 > v1) {
            let v2 = v0 - (v0 - v1) / 2;
            assert!(
                arg0.user_point_history.borrow(arg1).contains(v2),
                9223377117801086975
            );
            let v3 = arg0.user_point_history.borrow(arg1).borrow(v2);
            if (v3.ts == arg2) {
                return v2
            };
            if (v3.ts < arg2) {
                v1 = v2;
                continue
            };
            v0 = v2 - 1;
        };
        v1
    }

    public fun get_voting_power<T0>(arg0: &VotingEscrow<T0>, arg1: &Lock, arg2: &sui::clock::Clock): u64 {
        let v0 = object::id<Lock>(arg1);
        assert!(
            arg2.timestamp_ms() - *arg0.ownership_change_at.borrow(v0) >= distribution::common::get_time_to_finality(),
            9223376997544099873
        );
        arg0.balance_of_nft_at_internal(v0, distribution::common::current_timestamp(arg2))
    }

    public fun id_to_managed<T0>(arg0: &VotingEscrow<T0>, arg1: ID): ID {
        *arg0.id_to_managed.borrow(arg1)
    }

    public fun increase_amount<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: sui::coin::Coin<T0>,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = arg2.value();
        arg0.balance.join(arg2.into_balance());
        arg0.increase_amount_for_internal(
            object::id<Lock>(arg1),
            v0,
            DepositType::INCREASE_LOCK_AMOUNT,
            arg3,
            arg4
        );
        arg1.amount = arg1.amount + v0;
    }

    fun increase_amount_for_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: ID,
        arg2: u64,
        arg3: DepositType,
        arg4: &sui::clock::Clock,
        arg5: &mut TxContext
    ) {
        assert!(arg2 > 0, 9223374463511560197);
        let v0 = arg0.escrow_type(arg1);
        assert!(v0 != EscrowType::LOCKED, 9223374472102150159);
        let (v1, v2) = arg0.locked(arg1);
        let v3 = v1;
        assert!(v2, 9223374484986134527);
        assert!(v3.amount > 0, 9223374484987183121);
        assert!(v3.end > distribution::common::current_timestamp(arg4) || v3.is_permanent, 9223374493576462343);
        if (v3.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance + arg2;
        };
        let delegatee = arg0.voting_dao.delegatee(arg1);
        arg0.voting_dao.checkpoint_delegatee(delegatee, arg2, true, arg4, arg5);
        arg0.deposit_for_internal(arg1, arg2, 0, v3, arg3, arg4, arg5);
        if (v0 == EscrowType::MANAGED) {
            arg0.managed_to_locked.borrow_mut(arg1).notify_reward_amount(
                &arg0.locked_managed_reward_authorized_cap,
                sui::coin::from_balance<T0>(arg0.balance.split(arg2), arg5),
                arg4,
                arg5
            );
        };
        let v4 = EventMetadataUpdate { lock_id: arg1 };
        sui::event::emit<EventMetadataUpdate>(v4);
    }

    public fun increase_unlock_time<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: u64,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = object::id<Lock>(arg1);
        let v1 = if (!arg0.escrow_type.contains(v0)) {
            true
        } else {
            let v2 = EscrowType::NORMAL;
            arg0.escrow_type.borrow(v0) == &v2
        };
        assert!(v1, 9223376301758873625);
        let v3 = *arg0.locked.borrow(v0);
        assert!(!v3.is_permanent, 9223376314644430883);
        let v4 = distribution::common::current_timestamp(arg3);
        let v5 = distribution::common::to_period(v4 + arg2 * distribution::common::day());
        assert!(v3.end > v4, 9223376331822465031);
        assert!(v3.amount > 0, 9223376336118087697);
        assert!(v5 > v3.end, 9223376340414365733);
        assert!(v5 < v4 + (distribution::common::max_lock_time() as u64), 9223376344709464103);
        arg0.deposit_for_internal(v0, 0, v5, v3, DepositType::INCREASE_UNLOCK_TIME, arg3, arg4);
        let v6 = EventMetadataUpdate { lock_id: v0 };
        sui::event::emit<EventMetadataUpdate>(v6);
        arg1.start = v4;
        arg1.end = v5;
    }

    fun init(arg0: VOTING_ESCROW, arg1: &mut TxContext) {
        let v0 = sui::package::claim<VOTING_ESCROW>(arg0, arg1);
        set_display(&v0, arg1);
        transfer::public_transfer<sui::package::Publisher>(v0, tx_context::sender(arg1));
    }

    public fun is_locked(arg0: EscrowType): bool {
        arg0 == EscrowType::LOCKED
    }

    public fun is_managed(arg0: EscrowType): bool {
        arg0 == EscrowType::MANAGED
    }

    public fun is_normal(arg0: EscrowType): bool {
        arg0 == EscrowType::NORMAL
    }

    public fun is_permanent(arg0: &LockedBalance): bool {
        arg0.is_permanent
    }

    public fun is_split_allowed<T0>(arg0: &VotingEscrow<T0>, arg1: address): bool {
        let v0 = if (arg0.can_split.contains(arg1)) {
            let v1 = true;
            arg0.can_split.borrow(arg1) == &v1
        } else {
            false
        };
        if (v0) {
            true
        } else if (arg0.can_split.contains(@0x0)) {
            let v3 = true;
            arg0.can_split.borrow(@0x0) == &v3
        } else {
            false
        }
    }

    public fun lock_has_voted<T0>(arg0: &mut VotingEscrow<T0>, arg1: ID): bool {
        if (arg0.voted.contains(arg1)) {
            let v1 = true;
            arg0.voted.borrow(arg1) == &v1
        } else {
            false
        }
    }

    public fun lock_permanent<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ) {
        let v0 = object::id<Lock>(arg1);
        let v1 = if (!arg0.escrow_type.contains(v0)) {
            true
        } else {
            let v2 = EscrowType::NORMAL;
            arg0.escrow_type.borrow(v0) == &v2
        };
        assert!(v1, 9223376525097173017);
        let v3 = *arg0.locked.borrow(v0);
        assert!(!v3.is_permanent, 9223376537982730275);
        assert!(v3.end > distribution::common::current_timestamp(arg2), 9223376542275862535);
        assert!(v3.amount > 0, 9223376546571485201);
        arg0.lock_permanent_internal(arg1, arg2, arg3);
    }

    fun lock_permanent_internal<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ) {
        let v0 = object::id<Lock>(arg1);
        let mut v1 = *arg0.locked.borrow(v0);
        arg0.permanent_lock_balance = arg0.permanent_lock_balance + v1.amount;
        v1.end = 0;
        v1.is_permanent = true;
        let v2 = *arg0.locked.borrow(v0);
        arg0.checkpoint_internal(option::some<ID>(v0), v2, v1, arg2, arg3);
        arg0.locked.remove(v0);
        arg0.locked.add(v0, v1);
        let v3 = EventLockPermanent {
            sender: tx_context::sender(arg3),
            lock_id: v0,
            amount: v1.amount,
        };
        sui::event::emit<EventLockPermanent>(v3);
        let v4 = EventMetadataUpdate { lock_id: v0 };
        sui::event::emit<EventMetadataUpdate>(v4);
        arg1.end = 0;
        arg1.permanent = true;
    }

    public fun locked<T0>(arg0: &VotingEscrow<T0>, arg1: ID): (LockedBalance, bool) {
        if (arg0.locked.contains(arg1)) {
            (*arg0.locked.borrow(arg1), true)
        } else {
            let v2 = LockedBalance {
                amount: 0,
                end: 0,
                is_permanent: false,
            };
            (v2, false)
        }
    }

    fun locked_balance(arg0: u64, arg1: u64, arg2: bool): LockedBalance {
        LockedBalance {
            amount: arg0,
            end: arg1,
            is_permanent: arg2,
        }
    }

    public fun managed_to_free<T0>(arg0: &VotingEscrow<T0>, arg1: ID): ID {
        object::id<distribution::free_managed_reward::FreeManagedReward>(
            arg0.managed_to_free.borrow(arg1)
        )
    }

    public fun merge<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: Lock,
        arg2: &mut Lock,
        arg3: &sui::clock::Clock,
        arg4: &mut TxContext
    ) {
        let v0 = object::id<Lock>(&arg1);
        let v1 = object::id<Lock>(arg2);
        let v2 = arg0.lock_has_voted(v0);
        assert!(!v2, 9223376074125738011);
        assert!(arg0.escrow_type(v0) == EscrowType::NORMAL, 9223376078420574233);
        assert!(arg0.escrow_type(v1) == EscrowType::NORMAL, 9223376082715541529);
        assert!(v0 != v1, 9223376087012474935);
        let v3 = *arg0.locked.borrow(v1);
        assert!(v3.end > distribution::common::current_timestamp(arg3) || v3.is_permanent == true, 9223376108484165639);
        let v4 = *arg0.locked.borrow(v0);
        assert!(v4.is_permanent == false, 9223376117075935267);
        let v5 = if (v4.end >= v3.end) {
            v4.end
        } else {
            v3.end
        };
        arg0.burn_lock_internal(arg1, v4, arg3, arg4);
        let v6 = if (v3.is_permanent) {
            0
        } else {
            v5
        };
        let v7 = locked_balance(v4.amount + v3.amount, v6, v3.is_permanent);
        if (v7.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance + v4.amount;
        };
        let delegatee = arg0.voting_dao.delegatee(v1);
        arg0.voting_dao.checkpoint_delegatee(delegatee, v4.amount, true, arg3, arg4);
        arg0.checkpoint_internal(option::some<ID>(v1), v3, v7, arg3, arg4);
        arg0.locked.remove(v1);
        arg0.locked.add(v1, v7);
        arg2.amount = v7.amount;
        let v8 = EventMerge {
            sender: tx_context::sender(arg4),
            from: v0,
            to: v1,
            from_amount: v4.amount,
            to_amount: v3.amount,
            new_amount: v7.amount,
            new_end: v7.end,
        };
        sui::event::emit<EventMerge>(v8);
        let v9 = EventMetadataUpdate { lock_id: v1 };
        sui::event::emit<EventMetadataUpdate>(v9);
    }

    public fun owner_of<T0>(arg0: &VotingEscrow<T0>, arg1: ID): address {
        *arg0.owner_of.borrow(arg1)
    }

    public fun owner_proof<T0>(
        arg0: &VotingEscrow<T0>,
        arg1: &Lock,
        arg2: &mut TxContext
    ): distribution::lock_owner::OwnerProof {
        arg0.validate_lock(arg1);
        let v0 = tx_context::sender(arg2);
        assert!(
            arg0.owner_of.borrow(object::id<Lock>(arg1)) == &v0,
            9223373209380847615
        );
        distribution::lock_owner::issue(
            object::id<VotingEscrow<T0>>(arg0),
            object::id<Lock>(arg1),
            tx_context::sender(arg2)
        )
    }

    public fun ownership_change_at<T0>(arg0: &VotingEscrow<T0>, arg1: ID): u64 {
        *arg0.ownership_change_at.borrow(arg1)
    }

    public fun permanent_lock_balance<T0>(arg0: &VotingEscrow<T0>): u64 {
        arg0.permanent_lock_balance
    }

    public fun remove_allowed_manager<T0>(arg0: &mut VotingEscrow<T0>, _arg1: &sui::package::Publisher, arg2: address) {
        arg0.allowed_managers.remove(&arg2);
    }

    public fun set_display(arg0: &sui::package::Publisher, arg1: &mut TxContext) {
        let mut v0 = std::vector::empty<std::string::String>();
        v0.push_back(std::string::utf8(b"name"));
        v0.push_back(std::string::utf8(b"locked_amount"));
        v0.push_back(std::string::utf8(b"unlock_timestamp"));
        v0.push_back(std::string::utf8(b"permanent"));
        v0.push_back(std::string::utf8(b"url"));
        v0.push_back(std::string::utf8(b"website"));
        v0.push_back(std::string::utf8(b"creator"));
        let mut v1 = std::vector::empty<std::string::String>();
        v1.push_back(std::string::utf8(b"Magma Lock"));
        v1.push_back(std::string::utf8(b"{amount}"));
        v1.push_back(std::string::utf8(b"{end}"));
        v1.push_back(std::string::utf8(b"{permanent}"));
        v1.push_back(std::string::utf8(b""));
        v1.push_back(std::string::utf8(b"https://magmafinance.io"));
        v1.push_back(std::string::utf8(b"MAGMA"));
        let mut v2 = sui::display::new_with_fields<Lock>(arg0, v0, v1, arg1);
        v2.update_version();
        transfer::public_transfer<sui::display::Display<Lock>>(v2, tx_context::sender(arg1));
    }

    fun set_locked<T0>(arg0: &mut VotingEscrow<T0>, arg1: ID, arg2: LockedBalance) {
        if (arg0.locked.contains(arg1)) {
            arg0.locked.remove(arg1);
        };
        arg0.locked.add(arg1, arg2);
    }

    public fun set_managed_lock_deactivated<T0>(
        arg0: &mut VotingEscrow<T0>,
        _arg1: &distribution::emergency_council::EmergencyCouncilCap,
        arg2: ID,
        arg3: bool
    ) {
        assert!(arg0.escrow_type(arg2) == EscrowType::MANAGED, 9223378500783308843);
        assert!(
            !arg0.deactivated.contains(arg2) || arg0.deactivated.borrow(arg2) != &arg3,
            9223378505078931509
        );
        if (arg0.deactivated.contains(arg2)) {
            arg0.deactivated.remove(arg2);
        };
        arg0.deactivated.add(arg2, arg3);
    }

    fun set_point_history<T0>(arg0: &mut VotingEscrow<T0>, arg1: u64, arg2: GlobalPoint) {
        if (arg0.point_history.contains(arg1)) {
            arg0.point_history.remove(arg1);
        };
        arg0.point_history.add(arg1, arg2);
    }

    fun set_slope_changes<T0>(arg0: &mut VotingEscrow<T0>, arg1: u64, arg2: integer_mate::i128::I128) {
        if (arg0.slope_changes.contains(arg1)) {
            arg0.slope_changes.remove(arg1);
        };
        arg0.slope_changes.add(arg1, arg2);
    }

    fun set_user_point_epoch<T0>(arg0: &mut VotingEscrow<T0>, arg1: ID, arg2: u64) {
        if (arg0.user_point_epoch.contains(arg1)) {
            arg0.user_point_epoch.remove(arg1);
        };
        arg0.user_point_epoch.add(arg1, arg2);
    }

    fun set_user_point_history<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: ID,
        arg2: u64,
        arg3: UserPoint,
        arg4: &mut TxContext
    ) {
        if (!arg0.user_point_history.contains(arg1)) {
            arg0.user_point_history.add(arg1, sui::table::new<u64, UserPoint>(arg4));
        };
        let v0 = arg0.user_point_history.borrow_mut(arg1);
        if (v0.contains(arg2)) {
            v0.remove(arg2);
        };
        v0.add(arg2, arg3);
    }

    public fun toggle_split<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &distribution::team_cap::TeamCap,
        arg2: address,
        arg3: bool
    ) {
        arg1.validate(object::id<VotingEscrow<T0>>(arg0));
        if (arg0.can_split.contains(arg2)) {
            arg0.can_split.remove(arg2);
        };
        arg0.can_split.add(arg2, arg3);
        let v0 = EventToggleSplit {
            who: arg2,
            allowed: arg3,
        };
        sui::event::emit<EventToggleSplit>(v0);
    }

    public fun total_locked<T0>(arg0: &VotingEscrow<T0>): u64 {
        arg0.total_locked
    }

    public fun total_supply_at<T0>(arg0: &VotingEscrow<T0>, arg1: u64): u64 {
        arg0.total_supply_at_internal(arg0.epoch, arg1)
    }

    fun total_supply_at_internal<T0>(arg0: &VotingEscrow<T0>, arg1: u64, arg2: u64): u64 {
        let v0 = arg0.get_past_global_point_index(arg1, arg2);
        if (v0 == 0) {
            return 0
        };
        let v1 = arg0.point_history.borrow(v0);
        let mut v2 = v1.bias;
        let mut v3 = v1.slope;
        let v4 = v1.ts;
        let mut v5 = distribution::common::to_period(v4);
        let mut v6 = 0;
        while (v6 < 255) {
            let v7 = v5 + distribution::common::week();
            v5 = v7;
            let mut v8 = integer_mate::i128::from(0);
            if (v7 > arg2) {
                v5 = arg2;
            } else {
                let v9 = if (arg0.slope_changes.contains(v7)) {
                    *arg0.slope_changes.borrow(v7)
                } else {
                    integer_mate::i128::from(0)
                };
                v8 = v9;
            };
            v2 = v2.sub(v3.mul(integer_mate::i128::from(((v5 - v4) as u128))).div(integer_mate::i128::from(1 << 64)));
            if (v5 == arg2) {
                break
            };
            v3 = v3.add(v8);
            v6 = v6 + 1;
        };
        if (v2.is_neg()) {
            v2 = integer_mate::i128::from(0);
        };
        (v2.as_u128() as u64) + v1.permanent_lock_balance
    }

    public fun unlock_permanent<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &mut Lock,
        arg2: &sui::clock::Clock,
        arg3: &mut TxContext
    ) {
        let v0 = tx_context::sender(arg3);
        let v1 = object::id<Lock>(arg1);
        let v2 = if (!arg0.escrow_type.contains(v1)) {
            true
        } else {
            let v3 = EscrowType::NORMAL;
            arg0.escrow_type.borrow(v1) == &v3
        };
        assert!(v2, 9223376666831093785);
        let v4 = arg0.lock_has_voted(v1);
        assert!(!v4, 9223376671126192155);
        let mut v5 = *arg0.locked.borrow(v1);
        assert!(v5.is_permanent, 9223376679715602451);
        let v6 = distribution::common::current_timestamp(arg2);
        arg0.permanent_lock_balance = arg0.permanent_lock_balance - v5.amount;
        v5.end = distribution::common::to_period(v6 + distribution::common::max_lock_time());
        v5.is_permanent = false;
        arg0.delegate_internal(arg1, object::id_from_address(@0x0), arg2, arg3);
        let v7 = *arg0.locked.borrow(v1);
        arg0.checkpoint_internal(option::some<ID>(v1), v7, v5, arg2, arg3);
        arg0.locked.remove(v1);
        arg0.locked.add(v1, v5);
        arg1.permanent = false;
        arg1.end = v5.end;
        arg1.start = v6;
        let v8 = EventUnlockPermanent {
            sender: v0,
            lock_id: v1,
            amount: v5.amount,
        };
        sui::event::emit<EventUnlockPermanent>(v8);
        let v9 = EventMetadataUpdate { lock_id: v1 };
        sui::event::emit<EventMetadataUpdate>(v9);
    }

    public fun user_point_epoch<T0>(arg0: &VotingEscrow<T0>, arg1: ID): u64 {
        *arg0.user_point_epoch.borrow(arg1)
    }

    public fun user_point_history<T0>(arg0: &VotingEscrow<T0>, arg1: ID, arg2: u64): UserPoint {
        *arg0.user_point_history.borrow(arg1).borrow(arg2)
    }

    public fun user_point_ts(arg0: &UserPoint): u64 {
        arg0.ts
    }

    fun validate_lock<T0>(arg0: &VotingEscrow<T0>, arg1: &Lock) {
        assert!(arg1.escrow == object::id<VotingEscrow<T0>>(arg0), 9223376052649197567);
    }

    fun validate_lock_duration<T0>(arg0: &VotingEscrow<T0>, arg1: u64) {
        assert!(
            arg1 * distribution::common::day() >= arg0.min_lock_time && arg1 * distribution::common::day(
            ) <= arg0.max_lock_time,
            9223374111324635147
        );
    }

    public fun voting<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &distribution::voter_cap::VoterCap,
        arg2: ID,
        arg3: bool
    ) {
        assert!(arg0.voter == arg1.get_voter_id(), 9223374076964241407);
        if (arg0.voted.contains(arg2)) {
            arg0.voted.remove(arg2);
        };
        arg0.voted.add(arg2, arg3);
    }

    public fun withdraw_managed<T0>(
        arg0: &mut VotingEscrow<T0>,
        arg1: &distribution::voter_cap::VoterCap,
        arg2: &mut Lock,
        arg3: &mut Lock,
        arg4: distribution::lock_owner::OwnerProof,
        arg5: &sui::clock::Clock,
        arg6: &mut TxContext
    ) {
        let v0 = object::id<Lock>(arg2);
        assert!(arg1.get_voter_id() == arg0.voter, 9223378084171612205);
        assert!(arg0.id_to_managed.contains(v0), 9223378088466710575);
        assert!(arg0.escrow_type(v0) == EscrowType::LOCKED, 9223378092761808945);
        let v1 = *arg0.id_to_managed.borrow(v0);
        assert!(v1 == object::id<Lock>(arg3), 9223378105646579759);
        let v2 = arg0.managed_to_locked.borrow_mut(v1);
        let v3 = *arg0.managed_weights.borrow(v0).borrow(v1);
        let v4 = v3 + v2.earned<T0>(v0, arg5);
        let v5 = distribution::common::to_period(
            distribution::common::current_timestamp(arg5) + distribution::common::max_lock_time()
        );
        arg0.managed_to_free.borrow_mut(v1).get_reward<T0>(arg4, arg5, arg6);
        arg0.balance.join<T0>(v2.get_reward<T0>(&arg0.locked_managed_reward_authorized_cap, v0, arg5, arg6));
        arg2.amount = v4;
        arg2.permanent = false;
        arg2.end = v5;
        arg3.amount = arg3.amount - v3;
        let v6 = arg0.locked.remove(v0);
        let v7 = locked_balance(v4, v5, false);
        arg0.checkpoint_internal(option::some<ID>(v0), v6, v7, arg5, arg6);
        arg0.locked.add(v0, v7);
        let mut v8 = *arg0.locked.borrow(v1);
        let mut v9 = if (v4 < v8.amount) {
            v8.amount - v4
        } else {
            0
        };
        v8.amount = v9;
        let mut v10 = if (v4 < arg0.permanent_lock_balance) {
            v4
        } else {
            arg0.permanent_lock_balance
        };
        arg0.permanent_lock_balance = arg0.permanent_lock_balance - v10;
        let delegatee_id = arg0.voting_dao.delegatee(v1);
        arg0.voting_dao.checkpoint_delegatee(delegatee_id, v4, false, arg5, arg6);
        let v11 = arg0.locked.remove(v1);
        arg0.checkpoint_internal(option::some<ID>(v1), v11, v8, arg5, arg6);
        arg0.locked.add(v1, v8);
        arg0.managed_to_locked.borrow_mut(v1).withdraw(&arg0.locked_managed_reward_authorized_cap, v3, v0, arg5, arg6);
        arg0.managed_to_free.borrow_mut(v1).withdraw(&arg0.free_managed_reward_authorized_cap, v3, v0, arg5, arg6);
        arg0.id_to_managed.remove(v0);
        arg0.managed_weights.borrow_mut(v0).remove(v1);
        arg0.escrow_type.remove(v0);
        let v12 = EventWithdrawManaged {
            owner: *arg0.owner_of.borrow(v0),
            lock_id: v0,
            managed_lock_id: v1,
            amount: v4,
        };
        sui::event::emit<EventWithdrawManaged>(v12);
        let v13 = EventMetadataUpdate { lock_id: v0 };
        sui::event::emit<EventMetadataUpdate>(v13);
    }

    // decompiled from Move bytecode v7
}


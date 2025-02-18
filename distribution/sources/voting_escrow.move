module distribution::voting_escrow {
    public struct VOTING_ESCROW has drop {
        dummy_field: bool,
    }

    public struct DistributorCap has store, key {
        id: 0x2::object::UID,
        ve: 0x2::object::ID,
    }

    public struct Lock has key {
        id: 0x2::object::UID,
        escrow: 0x2::object::ID,
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
        lock_id: 0x2::object::ID,
        owner: address,
    }

    public struct EventDeposit has copy, drop, store {
        lock_id: 0x2::object::ID,
        deposit_type: DepositType,
        amount: u64,
        unlock_time: u64,
    }

    public struct EventSupply has copy, drop, store {
        before: u64,
        after: u64,
    }

    public struct EventDelegateChanged has copy, drop, store {
        old: 0x2::object::ID,
        new: 0x2::object::ID,
    }

    public struct EventMetadataUpdate has copy, drop, store {
        lock_id: 0x2::object::ID,
    }

    public struct EventToggleSplit has copy, drop, store {
        who: address,
        allowed: bool,
    }

    public struct EventSplit has copy, drop, store {
        original_id: 0x2::object::ID,
        new_id1: 0x2::object::ID,
        new_id2: 0x2::object::ID,
        amount1: u64,
        amount2: u64,
    }

    public struct EventWithdraw has copy, drop, store {
        sender: address,
        lock_id: 0x2::object::ID,
        amount: u64,
    }

    public struct EventLockPermanent has copy, drop, store {
        sender: address,
        lock_id: 0x2::object::ID,
        amount: u64,
    }

    public struct EventUnlockPermanent has copy, drop, store {
        sender: address,
        lock_id: 0x2::object::ID,
        amount: u64,
    }

    public struct EventCreateManaged has copy, drop, store {
        owner: address,
        lock_id: 0x2::object::ID,
        sender: address,
        locked_managed_reward: 0x2::object::ID,
        free_managed_reward: 0x2::object::ID,
    }

    public struct EventDepositManaged has copy, drop, store {
        owner: address,
        lock_id: 0x2::object::ID,
        managed_lock_id: 0x2::object::ID,
        amount: u64,
    }

    public struct EventWithdrawManaged has copy, drop, store {
        owner: address,
        lock_id: 0x2::object::ID,
        managed_lock_id: 0x2::object::ID,
        amount: u64,
    }

    public struct EventMerge has copy, drop, store {
        sender: address,
        from: 0x2::object::ID,
        to: 0x2::object::ID,
        from_amount: u64,
        to_amount: u64,
        new_amount: u64,
        new_end: u64,
    }

    public struct EventTransfer has copy, drop, store {
        from: address,
        to: address,
        lock: 0x2::object::ID,
    }

    public struct VotingEscrow<phantom T0> has store, key {
        id: 0x2::object::UID,
        voter: 0x2::object::ID,
        balance: 0x2::balance::Balance<T0>,
        total_locked: u64,
        point_history: 0x2::table::Table<u64, GlobalPoint>,
        epoch: u64,
        min_lock_time: u64,
        max_lock_time: u64,
        lock_durations: 0x2::vec_set::VecSet<u64>,
        deactivated: 0x2::table::Table<0x2::object::ID, bool>,
        ownership_change_at: 0x2::table::Table<0x2::object::ID, u64>,
        user_point_epoch: 0x2::table::Table<0x2::object::ID, u64>,
        user_point_history: 0x2::table::Table<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>,
        voted: 0x2::table::Table<0x2::object::ID, bool>,
        locked: 0x2::table::Table<0x2::object::ID, LockedBalance>,
        owner_of: 0x2::table::Table<0x2::object::ID, address>,
        slope_changes: 0x2::table::Table<u64, integer_mate::i128::I128>,
        permanent_lock_balance: u64,
        escrow_type: 0x2::table::Table<0x2::object::ID, EscrowType>,
        voting_dao: distribution::voting_dao::VotingDAO,
        can_split: 0x2::table::Table<address, bool>,
        allowed_managers: 0x2::vec_set::VecSet<address>,
        managed_weights: 0x2::table::Table<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>,
        managed_to_locked: 0x2::table::Table<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>,
        managed_to_free: 0x2::table::Table<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>,
        id_to_managed: 0x2::table::Table<0x2::object::ID, 0x2::object::ID>,
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

    public fun split<T0>(arg0: &mut VotingEscrow<T0>, arg1: Lock, arg2: u64, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        validate_lock<T0>(arg0, &arg1);
        let v0 = 0x2::object::id<Lock>(&arg1);
        assert!(0x2::table::contains<0x2::object::ID, address>(&arg0.owner_of, v0), 9223375893737373727);
        let v1 = *0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, v0);
        assert!(is_split_allowed<T0>(arg0, v1) || is_split_allowed<T0>(arg0, 0x2::tx_context::sender(arg4)), 9223375902326652949);
        let mut v2 = if (!0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0)) {
            true
        } else {
            let v3 = EscrowType::NORMAL{};
            0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0) == &v3
        };
        assert!(v2, 9223375906621882393);
        let v4 = lock_has_voted<T0>(arg0, v0);
        assert!(!v4, 9223375910916980763);
        let v5 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        assert!(v5.end > distribution::common::current_timestamp(arg3) || v5.is_permanent, 9223375928095539207);
        assert!(arg2 > 0, 9223375932390375429);
        assert!(v5.amount > arg2, 9223375936686915613);
        let v6 = arg1.escrow;
        let v7 = arg1.start;
        let v8 = arg1.end;
        burn_lock_internal<T0>(arg0, arg1, v5, arg3, arg4);
        let v9 = create_split_internal<T0>(arg0, v1, v6, v7, v8, locked_balance(v5.amount - arg2, v5.end, v5.is_permanent), arg3, arg4);
        let v10 = create_split_internal<T0>(arg0, v1, v6, v7, v8, locked_balance(arg2, v5.end, v5.is_permanent), arg3, arg4);
        let v11 = EventSplit{
            original_id : v0,
            new_id1     : 0x2::object::id<Lock>(&v9),
            new_id2     : 0x2::object::id<Lock>(&v10),
            amount1     : v9.amount,
            amount2     : v10.amount,
        };
        0x2::event::emit<EventSplit>(v11);
        transfer<T0>(v9, arg0, v1, arg3, arg4);
        transfer<T0>(v10, arg0, v1, arg3, arg4);
    }

    public fun transfer<T0>(arg0: Lock, arg1: &mut VotingEscrow<T0>, arg2: address, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        assert!(arg0.escrow == 0x2::object::id<VotingEscrow<T0>>(arg1), 9223376864398016511);
        let v0 = 0x2::object::id<Lock>(&arg0);
        if (arg2 == owner_of<T0>(arg1, v0) && arg2 == 0x2::tx_context::sender(arg4)) {
            0x2::transfer::transfer<Lock>(arg0, arg2);
        } else {
            assert!(escrow_type<T0>(arg1, v0) != EscrowType::LOCKED{}, 9223376885873770511);
            let v1 = 0x2::table::remove<0x2::object::ID, address>(&mut arg1.owner_of, v0);
            assert!(v1 == 0x2::tx_context::sender(arg4), 9223376898757754879);
            distribution::voting_dao::checkpoint_delegator(&mut arg1.voting_dao, v0, 0, 0x2::object::id_from_address(@0x0), arg2, arg3, arg4);
            0x2::table::add<0x2::object::ID, address>(&mut arg1.owner_of, v0, arg2);
            if (0x2::table::contains<0x2::object::ID, u64>(&arg1.ownership_change_at, v0)) {
                0x2::table::remove<0x2::object::ID, u64>(&mut arg1.ownership_change_at, v0);
            };
            0x2::table::add<0x2::object::ID, u64>(&mut arg1.ownership_change_at, v0, 0x2::clock::timestamp_ms(arg3));
            0x2::transfer::transfer<Lock>(arg0, arg2);
            let v2 = EventTransfer{
                from : v1,
                to   : arg2,
                lock : v0,
            };
            0x2::event::emit<EventTransfer>(v2);
        };
    }

    public fun create<T0>(arg0: &0x2::package::Publisher, arg1: 0x2::object::ID, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) : VotingEscrow<T0> {
        let v0 = 0x2::object::new(arg3);
        let v1 = 0x2::object::uid_to_inner(&v0);
        let mut v2 = VotingEscrow<T0>{
            id                                   : v0,
            voter                                : arg1,
            balance                              : 0x2::balance::zero<T0>(),
            total_locked                         : 0,
            point_history                        : 0x2::table::new<u64, GlobalPoint>(arg3),
            epoch                                : 0,
            min_lock_time                        : distribution::common::min_lock_time(),
            max_lock_time                        : distribution::common::max_lock_time(),
            lock_durations                       : 0x2::vec_set::empty<u64>(),
            deactivated                          : 0x2::table::new<0x2::object::ID, bool>(arg3),
            ownership_change_at                  : 0x2::table::new<0x2::object::ID, u64>(arg3),
            user_point_epoch                     : 0x2::table::new<0x2::object::ID, u64>(arg3),
            user_point_history                   : 0x2::table::new<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(arg3),
            voted                                : 0x2::table::new<0x2::object::ID, bool>(arg3),
            locked                               : 0x2::table::new<0x2::object::ID, LockedBalance>(arg3),
            owner_of                             : 0x2::table::new<0x2::object::ID, address>(arg3),
            slope_changes                        : 0x2::table::new<u64, integer_mate::i128::I128>(arg3),
            permanent_lock_balance               : 0,
            escrow_type                          : 0x2::table::new<0x2::object::ID, EscrowType>(arg3),
            voting_dao                           : distribution::voting_dao::create(arg3),
            can_split                            : 0x2::table::new<address, bool>(arg3),
            allowed_managers                     : 0x2::vec_set::empty<address>(),
            managed_weights                      : 0x2::table::new<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(arg3),
            managed_to_locked                    : 0x2::table::new<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(arg3),
            managed_to_free                      : 0x2::table::new<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(arg3),
            id_to_managed                        : 0x2::table::new<0x2::object::ID, 0x2::object::ID>(arg3),
            locked_managed_reward_authorized_cap : distribution::reward_authorized_cap::create(v1, arg3),
            free_managed_reward_authorized_cap   : distribution::reward_authorized_cap::create(v1, arg3),
        };
        let v3 = GlobalPoint{
            bias                   : integer_mate::i128::from(0),
            slope                  : integer_mate::i128::from(0),
            ts                     : distribution::common::current_timestamp(arg2),
            permanent_lock_balance : 0,
        };
        0x2::table::add<u64, GlobalPoint>(&mut v2.point_history, 0, v3);
        v2
    }

    public fun withdraw<T0>(arg0: &mut VotingEscrow<T0>, arg1: Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::tx_context::sender(arg3);
        let v1 = 0x2::object::id<Lock>(&arg1);
        let v2 = lock_has_voted<T0>(arg0, v1);
        assert!(!v2, 9223376404838219803);
        assert!(!0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, v1) || *0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, v1) == EscrowType::NORMAL{}, 9223376409133056025);
        let v3 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v1);
        assert!(!v3.is_permanent, 9223376422018613283);
        assert!(distribution::common::current_timestamp(arg2) >= v3.end, 9223376430606843913);
        let v4 = arg0.total_locked;
        arg0.total_locked = arg0.total_locked - v3.amount;
        burn_lock_internal<T0>(arg0, arg1, v3, arg2, arg3);
        0x2::transfer::public_transfer<0x2::coin::Coin<T0>>(0x2::coin::from_balance<T0>(0x2::balance::split<T0>(&mut arg0.balance, v3.amount), arg3), v0);
        let v5 = EventWithdraw{
            sender  : v0,
            lock_id : v1,
            amount  : v3.amount,
        };
        0x2::event::emit<EventWithdraw>(v5);
        let v6 = EventSupply{
            before : v4,
            after  : v4 - v3.amount,
        };
        0x2::event::emit<EventSupply>(v6);
    }

    public fun add_allowed_manager<T0>(arg0: &mut VotingEscrow<T0>, arg1: &0x2::package::Publisher, arg2: address) {
        0x2::vec_set::insert<address>(&mut arg0.allowed_managers, arg2);
    }

    public fun amount(arg0: &LockedBalance) : u64 {
        arg0.amount
    }

    public fun balance_of_nft_at<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64) : u64 {
        balance_of_nft_at_internal<T0>(arg0, arg1, arg2)
    }

    fun balance_of_nft_at_internal<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64) : u64 {
        let v0 = get_past_power_point_index<T0>(arg0, arg1, arg2);
        if (v0 == 0) {
            return 0
        };
        let mut v1 = *0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), v0);
        if (v1.permanent > 0) {
            v1.permanent
        } else {
            v1.bias = integer_mate::i128::sub(v1.bias, integer_mate::i128::div(integer_mate::i128::mul(v1.slope, integer_mate::i128::sub(integer_mate::i128::from((arg2 as u128)), integer_mate::i128::from((v1.ts as u128)))), integer_mate::i128::from(18446744073709551616)));
            if (integer_mate::i128::is_neg(v1.bias)) {
                v1.bias = integer_mate::i128::from(0);
            };
            (integer_mate::i128::as_u128(v1.bias) as u64)
        }
    }

    fun burn_lock_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: Lock, arg2: LockedBalance, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(&arg1);
        distribution::voting_dao::checkpoint_delegator(&mut arg0.voting_dao, v0, arg2.amount, 0x2::object::id_from_address(@0x0), @0x0, arg3, arg4);
        0x2::table::remove<0x2::object::ID, address>(&mut arg0.owner_of, v0);
        0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v0), arg2, locked_balance(0, 0, false), arg3, arg4);
        let Lock {
            id        : v1,
            escrow    : _,
            amount    : _,
            start     : _,
            end       : _,
            permanent : _,
        } = arg1;
        0x2::object::delete(v1);
    }

    public fun checkpoint<T0>(arg0: &mut VotingEscrow<T0>, arg1: &0x2::clock::Clock, arg2: &mut 0x2::tx_context::TxContext) {
        checkpoint_internal<T0>(arg0, std::option::none<0x2::object::ID>(), locked_balance(0, 0, false), locked_balance(0, 0, false), arg1, arg2);
    }

    fun checkpoint_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: std::option::Option<0x2::object::ID>, arg2: LockedBalance, arg3: LockedBalance, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        let mut v0 = create_user_point();
        let mut v1 = create_user_point();
        let mut v2 = integer_mate::i128::from(0);
        let mut v3 = integer_mate::i128::from(0);
        let v4 = arg0.epoch;
        let mut v5 = v4;
        let v6 = distribution::common::current_timestamp(arg4);
        if (std::option::is_some<0x2::object::ID>(&arg1)) {
            let mut v7 = if (arg3.is_permanent) {
                arg3.amount
            } else {
                0
            };
            v1.permanent = v7;
            if (arg2.end > v6 && arg2.amount > 0) {
                v0.slope = integer_mate::i128::from(integer_mate::full_math_u128::mul_div_floor((arg2.amount as u128), 18446744073709551616, (distribution::common::max_lock_time() as u128)));
                v0.bias = integer_mate::i128::div(integer_mate::i128::mul(v0.slope, integer_mate::i128::from(((arg2.end - v6) as u128))), integer_mate::i128::from(18446744073709551616));
            };
            if (arg3.end > v6 && arg3.amount > 0) {
                v1.slope = integer_mate::i128::from(integer_mate::full_math_u128::mul_div_floor((arg3.amount as u128), 18446744073709551616, (distribution::common::max_lock_time() as u128)));
                v1.bias = integer_mate::i128::div(integer_mate::i128::mul(v1.slope, integer_mate::i128::from(((arg3.end - v6) as u128))), integer_mate::i128::from(18446744073709551616));
            };
            let mut v8 = if (0x2::table::contains<u64, integer_mate::i128::I128>(&arg0.slope_changes, arg2.end)) {
                *0x2::table::borrow<u64, integer_mate::i128::I128>(&arg0.slope_changes, arg2.end)
            } else {
                integer_mate::i128::from(0)
            };
            v2 = v8;
            if (arg3.end != 0) {
                if (arg3.end == arg2.end) {
                    v3 = v8;
                } else {
                    let mut v9 = if (0x2::table::contains<u64, integer_mate::i128::I128>(&arg0.slope_changes, arg3.end)) {
                        *0x2::table::borrow<u64, integer_mate::i128::I128>(&arg0.slope_changes, arg3.end)
                    } else {
                        integer_mate::i128::from(0)
                    };
                    v3 = v9;
                };
            };
        };
        let mut v10 = if (v4 > 0) {
            *0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, v4)
        } else {
            GlobalPoint{bias: integer_mate::i128::from(0), slope: integer_mate::i128::from(0), ts: v6, permanent_lock_balance: 0}
        };
        let mut v11 = v10;
        let v12 = v11.ts;
        GlobalPoint{bias: v11.bias, slope: v11.slope, ts: v11.ts, permanent_lock_balance: v11.permanent_lock_balance};
        let mut v13 = distribution::common::to_period(v12);
        let mut v14 = 0;
        while (v14 < 255) {
            let v15 = v13 + distribution::common::week();
            v13 = v15;
            let mut v16 = integer_mate::i128::from(0);
            if (v15 > v6) {
                v13 = v6;
            } else {
                let mut v17 = if (0x2::table::contains<u64, integer_mate::i128::I128>(&arg0.slope_changes, v15)) {
                    *0x2::table::borrow<u64, integer_mate::i128::I128>(&arg0.slope_changes, v15)
                } else {
                    integer_mate::i128::from(0)
                };
                v16 = v17;
            };
            v11.bias = integer_mate::i128::sub(v11.bias, integer_mate::i128::div(integer_mate::i128::mul(v11.slope, integer_mate::i128::from(((v13 - v12) as u128))), integer_mate::i128::from(18446744073709551616)));
            v11.slope = integer_mate::i128::add(v11.slope, v16);
            if (integer_mate::i128::is_neg(v11.bias)) {
                v11.bias = integer_mate::i128::from(0);
            };
            if (integer_mate::i128::is_neg(v11.slope)) {
                v11.slope = integer_mate::i128::from(0);
            };
            v11.ts = v13;
            let v18 = v5 + 1;
            v5 = v18;
            if (v13 == v6) {
                break
            };
            set_point_history<T0>(arg0, v18, v11);
            v14 = v14 + 1;
        };
        if (std::option::is_some<0x2::object::ID>(&arg1)) {
            v11.slope = integer_mate::i128::add(v11.slope, integer_mate::i128::sub(v1.slope, v0.slope));
            v11.bias = integer_mate::i128::add(v11.bias, integer_mate::i128::sub(v1.bias, v0.bias));
            if (integer_mate::i128::is_neg(v11.slope)) {
                v11.slope = integer_mate::i128::from(0);
            };
            if (integer_mate::i128::is_neg(v11.bias)) {
                v11.bias = integer_mate::i128::from(0);
            };
            v11.permanent_lock_balance = arg0.permanent_lock_balance;
        };
        let mut v19 = if (v5 != 1) {
            if (0x2::table::contains<u64, GlobalPoint>(&arg0.point_history, v5 - 1)) {
                0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, v5 - 1).ts == v6
            } else {
                false
            }
        } else {
            false
        };
        if (v19) {
            set_point_history<T0>(arg0, v5 - 1, v11);
        } else {
            arg0.epoch = v5;
            set_point_history<T0>(arg0, v5, v11);
        };
        if (std::option::is_some<0x2::object::ID>(&arg1)) {
            if (arg2.end > v6) {
                let v20 = integer_mate::i128::add(v2, v0.slope);
                v2 = v20;
                if (arg3.end == arg2.end) {
                    v2 = integer_mate::i128::sub(v20, v1.slope);
                };
                set_slope_changes<T0>(arg0, arg2.end, v2);
            };
            if (arg3.end > v6) {
                if (arg3.end > arg2.end) {
                    set_slope_changes<T0>(arg0, arg3.end, integer_mate::i128::sub(v3, v1.slope));
                };
            };
            let v21 = *std::option::borrow<0x2::object::ID>(&arg1);
            v1.ts = v6;
            let mut v22 = if (0x2::table::contains<0x2::object::ID, u64>(&arg0.user_point_epoch, v21)) {
                *0x2::table::borrow<0x2::object::ID, u64>(&arg0.user_point_epoch, v21)
            } else {
                0
            };
            let mut v23 = if (v22 != 0) {
                if (0x2::table::contains<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, v21), v22)) {
                    0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, v21), v22).ts == v6
                } else {
                    false
                }
            } else {
                false
            };
            if (v23) {
                set_user_point_history<T0>(arg0, v21, v22, v1, arg5);
            } else {
                set_user_point_epoch<T0>(arg0, v21, v22 + 1);
                set_user_point_history<T0>(arg0, v21, v22 + 1, v1, arg5);
            };
        };
    }

    public fun create_lock<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::coin::Coin<T0>, arg2: u64, arg3: bool, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        validate_lock_duration<T0>(arg0, arg2);
        let v0 = 0x2::coin::value<T0>(&arg1);
        assert!(v0 > 0, 9223374381907181573);
        let v1 = distribution::common::current_timestamp(arg4);
        let v2 = 0x2::tx_context::sender(arg5);
        let (v3, v4) = create_lock_internal<T0>(arg0, v2, v0, v1, distribution::common::to_period(v1 + arg2 * distribution::common::day()), arg3, arg4, arg5);
        let mut v5 = v3;
        let CreateLockReceipt { amount: v6 } = v4;
        assert!(v6 == v0, 9223374416266657791);
        0x2::balance::join<T0>(&mut arg0.balance, 0x2::coin::into_balance<T0>(arg1));
        if (arg3) {
            let v7 = &mut v5;
            lock_permanent_internal<T0>(arg0, v7, arg4, arg5);
        };
        0x2::transfer::transfer<Lock>(v5, v2);
    }

    public fun create_lock_for<T0>(arg0: &mut VotingEscrow<T0>, arg1: address, arg2: 0x2::coin::Coin<T0>, arg3: u64, arg4: bool, arg5: &0x2::clock::Clock, arg6: &mut 0x2::tx_context::TxContext) {
        validate_lock_duration<T0>(arg0, arg3);
        let v0 = 0x2::coin::value<T0>(&arg2);
        assert!(v0 > 0, 9223374257353129989);
        let v1 = distribution::common::current_timestamp(arg5);
        let (v2, v3) = create_lock_internal<T0>(arg0, arg1, v0, v1, distribution::common::to_period(v1 + arg3 * distribution::common::day()), arg4, arg5, arg6);
        let mut v4 = v2;
        let CreateLockReceipt { amount: v5 } = v3;
        assert!(v5 == v0, 9223374287417638911);
        0x2::balance::join<T0>(&mut arg0.balance, 0x2::coin::into_balance<T0>(arg2));
        if (arg4) {
            let v6 = &mut v4;
            lock_permanent_internal<T0>(arg0, v6, arg5, arg6);
        };
        0x2::transfer::transfer<Lock>(v4, arg1);
    }

    fun create_lock_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: address, arg2: u64, arg3: u64, arg4: u64, arg5: bool, arg6: &0x2::clock::Clock, arg7: &mut 0x2::tx_context::TxContext) : (Lock, CreateLockReceipt) {
        let v0 = Lock{
            id        : 0x2::object::new(arg7),
            escrow    : 0x2::object::id<VotingEscrow<T0>>(arg0),
            amount    : arg2,
            start     : arg3,
            end       : arg4,
            permanent : arg5,
        };
        let v1 = 0x2::object::id<Lock>(&v0);
        assert!(!0x2::table::contains<0x2::object::ID, address>(&arg0.owner_of, v1), 9223374171453521919);
        assert!(!0x2::table::contains<0x2::object::ID, LockedBalance>(&arg0.locked, v1), 9223374175748489215);
        0x2::table::add<0x2::object::ID, address>(&mut arg0.owner_of, v1, arg1);
        0x2::table::add<0x2::object::ID, u64>(&mut arg0.ownership_change_at, v1, 0x2::clock::timestamp_ms(arg6));
        distribution::voting_dao::checkpoint_delegator(&mut arg0.voting_dao, v1, arg2, 0x2::object::id_from_address(@0x0), arg1, arg6, arg7);
        deposit_for_internal<T0>(arg0, v1, arg2, arg4, locked_balance(0, 0, arg5), DepositType::CREATE_LOCK_TYPE{}, arg6, arg7);
        let v2 = EventCreateLock{
            lock_id : v1,
            owner   : arg1,
        };
        0x2::event::emit<EventCreateLock>(v2);
        let v3 = CreateLockReceipt{amount: arg2};
        (v0, v3)
    }

    public fun create_managed_lock_for<T0>(arg0: &mut VotingEscrow<T0>, arg1: address, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) : 0x2::object::ID {
        let v0 = 0x2::tx_context::sender(arg3);
        assert!(0x2::vec_set::contains<address>(&arg0.allowed_managers, &v0), 9223377598838734869);
        let (v1, v2) = create_lock_internal<T0>(arg0, arg1, 0, distribution::common::current_timestamp(arg2), 0, true, arg2, arg3);
        let v3 = v1;
        let CreateLockReceipt {  } = v2;
        let v4 = 0x2::object::id<Lock>(&v3);
        0x2::transfer::transfer<Lock>(v3, arg1);
        0x2::table::add<0x2::object::ID, EscrowType>(&mut arg0.escrow_type, v4, EscrowType::MANAGED{});
        let v5 = std::type_name::get<T0>();
        let v6 = distribution::locked_managed_reward::create(arg0.voter, 0x2::object::id<VotingEscrow<T0>>(arg0), v5, arg3);
        let v7 = distribution::free_managed_reward::create(arg0.voter, 0x2::object::id<VotingEscrow<T0>>(arg0), v5, arg3);
        let v8 = EventCreateManaged{
            owner                 : arg1,
            lock_id               : v4,
            sender                : v0,
            locked_managed_reward : 0x2::object::id<distribution::locked_managed_reward::LockedManagedReward>(&v6),
            free_managed_reward   : 0x2::object::id<distribution::free_managed_reward::FreeManagedReward>(&v7),
        };
        0x2::event::emit<EventCreateManaged>(v8);
        0x2::table::add<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(&mut arg0.managed_to_locked, v4, v6);
        0x2::table::add<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, v4, v7);
        v4
    }

    fun create_split_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: address, arg2: 0x2::object::ID, arg3: u64, arg4: u64, arg5: LockedBalance, arg6: &0x2::clock::Clock, arg7: &mut 0x2::tx_context::TxContext) : Lock {
        let v0 = Lock{
            id        : 0x2::object::new(arg7),
            escrow    : arg2,
            amount    : arg5.amount,
            start     : arg3,
            end       : arg4,
            permanent : arg5.is_permanent,
        };
        let v1 = 0x2::object::id<Lock>(&v0);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v1, arg5);
        0x2::table::add<0x2::object::ID, address>(&mut arg0.owner_of, v1, arg1);
        0x2::table::add<0x2::object::ID, u64>(&mut arg0.ownership_change_at, v1, 0x2::clock::timestamp_ms(arg6));
        distribution::voting_dao::checkpoint_delegator(&mut arg0.voting_dao, v1, arg5.amount, 0x2::object::id_from_address(@0x0), arg1, arg6, arg7);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(0x2::object::id<Lock>(&v0)), locked_balance(0, 0, false), arg5, arg6, arg7);
        v0
    }

    fun create_user_point() : UserPoint {
        UserPoint{
            bias      : integer_mate::i128::from(0),
            slope     : integer_mate::i128::from(0),
            ts        : 0,
            permanent : 0,
        }
    }

    public fun deactivated<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : bool {
        0x2::table::contains<0x2::object::ID, bool>(&arg0.deactivated, arg1) && *0x2::table::borrow<0x2::object::ID, bool>(&arg0.deactivated, arg1)
    }

    public fun delegate<T0>(arg0: &mut VotingEscrow<T0>, arg1: &Lock, arg2: 0x2::object::ID, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        validate_lock<T0>(arg0, arg1);
        delegate_internal<T0>(arg0, arg1, arg2, arg3, arg4);
    }

    fun delegate_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: &Lock, mut arg2: 0x2::object::ID, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(arg1);
        let (v1, _) = locked<T0>(arg0, v0);
        let v3 = v1;
        assert!(v3.is_permanent, 9223375657513386003);
        assert!(arg2 == 0x2::object::id_from_address(@0x0) || 0x2::table::contains<0x2::object::ID, address>(&arg0.owner_of, arg2), 9223375661808615447);
        if (0x2::object::id<Lock>(arg1) == arg2) {
            arg2 = 0x2::object::id_from_address(@0x0);
        };
        assert!(0x2::clock::timestamp_ms(arg3) - *0x2::table::borrow<0x2::object::ID, u64>(&arg0.ownership_change_at, v0) >= distribution::common::get_time_to_finality(), 9223375683284107297);
        let v4 = distribution::voting_dao::delegatee(&arg0.voting_dao, v0);
        if (v4 == arg2) {
            return
        };
        distribution::voting_dao::checkpoint_delegator(&mut arg0.voting_dao, v0, v3.amount, arg2, *0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, v0), arg3, arg4);
        distribution::voting_dao::checkpoint_delegatee(&mut arg0.voting_dao, arg2, v3.amount, true, arg3, arg4);
        let v5 = EventDelegateChanged{
            old : v4,
            new : arg2,
        };
        0x2::event::emit<EventDelegateChanged>(v5);
    }

    public fun deposit_for<T0>(arg0: &mut VotingEscrow<T0>, mut arg1: std::option::Option<DistributorCap>, arg2: &mut Lock, arg3: 0x2::coin::Coin<T0>, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(arg2);
        if (escrow_type<T0>(arg0, v0) == EscrowType::MANAGED{}) {
            if (std::option::is_none<DistributorCap>(&arg1)) {
                abort 9223374605247840297
            };
            let v1 = std::option::extract<DistributorCap>(&mut arg1);
            if (v1.ve != 0x2::object::id<VotingEscrow<T0>>(arg0)) {
                0x2::transfer::transfer<DistributorCap>(v1, 0x2::tx_context::sender(arg5));
                abort 9223374626722676777
            };
            0x2::transfer::transfer<DistributorCap>(v1, 0x2::tx_context::sender(arg5));
        };
        let v2 = 0x2::coin::value<T0>(&arg3);
        0x2::balance::join<T0>(&mut arg0.balance, 0x2::coin::into_balance<T0>(arg3));
        increase_amount_for_internal<T0>(arg0, v0, v2, DepositType::DEPOSIT_FOR_TYPE{}, arg4, arg5);
        std::option::destroy_none<DistributorCap>(arg1);
        arg2.amount = arg2.amount + v2;
    }

    fun deposit_for_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64, arg3: u64, arg4: LockedBalance, arg5: DepositType, arg6: &0x2::clock::Clock, arg7: &mut 0x2::tx_context::TxContext) {
        let v0 = arg0.total_locked;
        arg0.total_locked = arg0.total_locked + arg2;
        let mut v1 = locked_balance(arg4.amount, arg4.end, arg4.is_permanent);
        v1.amount = v1.amount + arg2;
        if (arg3 != 0) {
            v1.end = arg3;
        };
        set_locked<T0>(arg0, arg1, v1);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(arg1), arg4, v1, arg6, arg7);
        let v2 = EventDeposit{
            lock_id      : arg1,
            deposit_type : arg5,
            amount       : arg2,
            unlock_time  : v1.end,
        };
        0x2::event::emit<EventDeposit>(v2);
        let v3 = EventSupply{
            before : v0,
            after  : arg0.total_locked,
        };
        0x2::event::emit<EventSupply>(v3);
    }

    public fun deposit_managed<T0>(arg0: &mut VotingEscrow<T0>, arg1: &distribution::voter_cap::VoterCap, arg2: &mut Lock, arg3: 0x2::object::ID, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        assert!(distribution::voter_cap::get_voter_id(arg1) == arg0.voter, 9223377701916639231);
        let v0 = 0x2::object::id<Lock>(arg2);
        assert!(escrow_type<T0>(arg0, arg3) == EscrowType::MANAGED{}, 9223377706214359083);
        assert!(escrow_type<T0>(arg0, v0) == EscrowType::NORMAL{}, 9223377710508146713);
        assert!(balance_of_nft_at_internal<T0>(arg0, v0, distribution::common::current_timestamp(arg4)) > 0, 9223377719096770565);
        let v1 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        let v2 = v1.amount;
        if (v1.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance - v1.amount;
            delegate_internal<T0>(arg0, arg2, 0x2::object::id_from_address(@0x0), arg4, arg5);
        };
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v0), v1, locked_balance(0, 0, false), arg4, arg5);
        0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0, locked_balance(0, 0, false));
        arg0.permanent_lock_balance = arg0.permanent_lock_balance + v2;
        let mut v3 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, arg3);
        v3.amount = v3.amount + v2;
        distribution::voting_dao::checkpoint_delegatee(&mut arg0.voting_dao, distribution::voting_dao::delegatee(&arg0.voting_dao, arg3), v2, true, arg4, arg5);
        let v4 = 0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg3);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(arg3), v4, v3, arg4, arg5);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg3, v3);
        if (!0x2::table::contains<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(&arg0.managed_weights, v0)) {
            0x2::table::add<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(&mut arg0.managed_weights, v0, 0x2::table::new<0x2::object::ID, u64>(arg5));
        };
        0x2::table::add<0x2::object::ID, u64>(0x2::table::borrow_mut<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(&mut arg0.managed_weights, v0), arg3, v2);
        0x2::table::add<0x2::object::ID, 0x2::object::ID>(&mut arg0.id_to_managed, v0, arg3);
        0x2::table::add<0x2::object::ID, EscrowType>(&mut arg0.escrow_type, v0, EscrowType::LOCKED{});
        distribution::locked_managed_reward::deposit(0x2::table::borrow_mut<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(&mut arg0.managed_to_locked, arg3), &arg0.locked_managed_reward_authorized_cap, v2, v0, arg4, arg5);
        distribution::free_managed_reward::deposit(0x2::table::borrow_mut<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, arg3), &arg0.free_managed_reward_authorized_cap, v2, v0, arg4, arg5);
        let v5 = EventDepositManaged{
            owner           : *0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, v0),
            lock_id         : v0,
            managed_lock_id : arg3,
            amount          : v2,
        };
        0x2::event::emit<EventDepositManaged>(v5);
        let v6 = EventMetadataUpdate{lock_id: v0};
        0x2::event::emit<EventMetadataUpdate>(v6);
    }

    public fun end(arg0: &LockedBalance) : u64 {
        arg0.end
    }

    public fun escrow_type<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : EscrowType {
        if (0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, arg1)) {
            *0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, arg1)
        } else {
            EscrowType::NORMAL{}
        }
    }

    public fun free_managed_reward_earned<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) : u64 {
        let v0 = 0x2::object::id<Lock>(arg1);
        distribution::free_managed_reward::earned<T0>(0x2::table::borrow<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&arg0.managed_to_free, *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, v0)), v0, arg2)
    }

    public fun free_managed_reward_get_reward<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = owner_proof<T0>(arg0, arg1, arg3);
        distribution::free_managed_reward::get_reward<T0>(0x2::table::borrow_mut<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, 0x2::object::id<Lock>(arg1))), v0, arg2, arg3);
    }

    public fun free_managed_reward_notify_reward<T0>(arg0: &mut VotingEscrow<T0>, arg1: std::option::Option<distribution::whitelisted_tokens::WhitelistedToken>, arg2: 0x2::coin::Coin<T0>, arg3: 0x2::object::ID, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        distribution::free_managed_reward::notify_reward_amount<T0>(0x2::table::borrow_mut<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, arg3)), arg1, arg2, arg4, arg5);
    }

    public fun free_managed_reward_token_list<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID) : vector<std::type_name::TypeName> {
        distribution::free_managed_reward::rewards_list(0x2::table::borrow<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&arg0.managed_to_free, *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, arg1)))
    }

    fun get_past_global_point_index<T0>(arg0: &VotingEscrow<T0>, arg1: u64, arg2: u64) : u64 {
        if (arg1 == 0) {
            return 0
        };
        if (!0x2::table::contains<u64, GlobalPoint>(&arg0.point_history, arg1) || 0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, arg1).ts <= arg2) {
            return arg1
        };
        if (0x2::table::contains<u64, GlobalPoint>(&arg0.point_history, 1) && 0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, 1).ts > arg2) {
            return 0
        };
        let mut v0 = 0;
        while (arg1 > v0) {
            let v1 = arg1 - (arg1 - v0) / 2;
            assert!(0x2::table::contains<u64, GlobalPoint>(&arg0.point_history, v1), 999);
            let v2 = 0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, v1);
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

    fun get_past_power_point_index<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64) : u64 {
        if (!0x2::table::contains<0x2::object::ID, u64>(&arg0.user_point_epoch, arg1)) {
            return 0
        };
        let mut v0 = *0x2::table::borrow<0x2::object::ID, u64>(&arg0.user_point_epoch, arg1);
        if (v0 == 0) {
            return 0
        };
        if (0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), v0).ts <= arg2) {
            return v0
        };
        if (0x2::table::contains<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), 1) && 0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), 1).ts > arg2) {
            return 0
        };
        let mut v1 = 0;
        while (v0 > v1) {
            let v2 = v0 - (v0 - v1) / 2;
            assert!(0x2::table::contains<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), v2), 9223377117801086975);
            let v3 = 0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), v2);
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

    public fun get_voting_power<T0>(arg0: &VotingEscrow<T0>, arg1: &Lock, arg2: &0x2::clock::Clock) : u64 {
        let v0 = 0x2::object::id<Lock>(arg1);
        assert!(0x2::clock::timestamp_ms(arg2) - *0x2::table::borrow<0x2::object::ID, u64>(&arg0.ownership_change_at, v0) >= distribution::common::get_time_to_finality(), 9223376997544099873);
        balance_of_nft_at_internal<T0>(arg0, v0, distribution::common::current_timestamp(arg2))
    }

    public fun id_to_managed<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : 0x2::object::ID {
        *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, arg1)
    }

    public fun increase_amount<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: 0x2::coin::Coin<T0>, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::coin::value<T0>(&arg2);
        0x2::balance::join<T0>(&mut arg0.balance, 0x2::coin::into_balance<T0>(arg2));
        increase_amount_for_internal<T0>(arg0, 0x2::object::id<Lock>(arg1), v0, DepositType::INCREASE_LOCK_AMOUNT{}, arg3, arg4);
        arg1.amount = arg1.amount + v0;
    }

    fun increase_amount_for_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64, arg3: DepositType, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) {
        assert!(arg2 > 0, 9223374463511560197);
        let v0 = escrow_type<T0>(arg0, arg1);
        assert!(v0 != EscrowType::LOCKED{}, 9223374472102150159);
        let (v1, v2) = locked<T0>(arg0, arg1);
        let v3 = v1;
        assert!(v2, 9223374484986134527);
        assert!(v3.amount > 0, 9223374484987183121);
        assert!(v3.end > distribution::common::current_timestamp(arg4) || v3.is_permanent, 9223374493576462343);
        if (v3.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance + arg2;
        };
        distribution::voting_dao::checkpoint_delegatee(&mut arg0.voting_dao, distribution::voting_dao::delegatee(&arg0.voting_dao, arg1), arg2, true, arg4, arg5);
        deposit_for_internal<T0>(arg0, arg1, arg2, 0, v3, arg3, arg4, arg5);
        if (v0 == EscrowType::MANAGED{}) {
            distribution::locked_managed_reward::notify_reward_amount<T0>(0x2::table::borrow_mut<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(&mut arg0.managed_to_locked, arg1), &arg0.locked_managed_reward_authorized_cap, 0x2::coin::from_balance<T0>(0x2::balance::split<T0>(&mut arg0.balance, arg2), arg5), arg4, arg5);
        };
        let v4 = EventMetadataUpdate{lock_id: arg1};
        0x2::event::emit<EventMetadataUpdate>(v4);
    }

    public fun increase_unlock_time<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: u64, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(arg1);
        let mut v1 = if (!0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0)) {
            true
        } else {
            let v2 = EscrowType::NORMAL{};
            0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0) == &v2
        };
        assert!(v1, 9223376301758873625);
        let v3 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        assert!(!v3.is_permanent, 9223376314644430883);
        let v4 = distribution::common::current_timestamp(arg3);
        let v5 = distribution::common::to_period(v4 + arg2 * distribution::common::day());
        assert!(v3.end > v4, 9223376331822465031);
        assert!(v3.amount > 0, 9223376336118087697);
        assert!(v5 > v3.end, 9223376340414365733);
        assert!(v5 < v4 + (distribution::common::max_lock_time() as u64), 9223376344709464103);
        deposit_for_internal<T0>(arg0, v0, 0, v5, v3, DepositType::INCREASE_UNLOCK_TIME{}, arg3, arg4);
        let v6 = EventMetadataUpdate{lock_id: v0};
        0x2::event::emit<EventMetadataUpdate>(v6);
        arg1.start = v4;
        arg1.end = v5;
    }

    fun init(arg0: VOTING_ESCROW, arg1: &mut 0x2::tx_context::TxContext) {
        0x2::package::claim_and_keep<VOTING_ESCROW>(arg0, arg1);
    }

    public fun is_locked(arg0: EscrowType) : bool {
        arg0 == EscrowType::LOCKED{}
    }

    public fun is_managed(arg0: EscrowType) : bool {
        arg0 == EscrowType::MANAGED{}
    }

    public fun is_normal(arg0: EscrowType) : bool {
        arg0 == EscrowType::NORMAL{}
    }

    public fun is_permanent(arg0: &LockedBalance) : bool {
        arg0.is_permanent
    }

    public fun is_split_allowed<T0>(arg0: &VotingEscrow<T0>, arg1: address) : bool {
        let mut v0 = if (0x2::table::contains<address, bool>(&arg0.can_split, arg1)) {
            let v1 = true;
            0x2::table::borrow<address, bool>(&arg0.can_split, arg1) == &v1
        } else {
            false
        };
        if (v0) {
            true
        } else if (0x2::table::contains<address, bool>(&arg0.can_split, @0x0)) {
            let v3 = true;
            0x2::table::borrow<address, bool>(&arg0.can_split, @0x0) == &v3
        } else {
            false
        }
    }

    public fun lock_has_voted<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID) : bool {
        if (0x2::table::contains<0x2::object::ID, bool>(&arg0.voted, arg1)) {
            let v1 = true;
            0x2::table::borrow<0x2::object::ID, bool>(&arg0.voted, arg1) == &v1
        } else {
            false
        }
    }

    public fun lock_permanent<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(arg1);
        let mut v1 = if (!0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0)) {
            true
        } else {
            let v2 = EscrowType::NORMAL{};
            0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, v0) == &v2
        };
        assert!(v1, 9223376525097173017);
        let v3 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        assert!(!v3.is_permanent, 9223376537982730275);
        assert!(v3.end > distribution::common::current_timestamp(arg2), 9223376542275862535);
        assert!(v3.amount > 0, 9223376546571485201);
        lock_permanent_internal<T0>(arg0, arg1, arg2, arg3);
    }

    fun lock_permanent_internal<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(arg1);
        let mut v1 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        arg0.permanent_lock_balance = arg0.permanent_lock_balance + v1.amount;
        v1.end = 0;
        v1.is_permanent = true;
        let v2 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v0), v2, v1, arg2, arg3);
        0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0, v1);
        let v3 = EventLockPermanent{
            sender  : 0x2::tx_context::sender(arg3),
            lock_id : v0,
            amount  : v1.amount,
        };
        0x2::event::emit<EventLockPermanent>(v3);
        let v4 = EventMetadataUpdate{lock_id: v0};
        0x2::event::emit<EventMetadataUpdate>(v4);
        arg1.end = 0;
        arg1.permanent = true;
    }

    public fun locked<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : (LockedBalance, bool) {
        if (0x2::table::contains<0x2::object::ID, LockedBalance>(&arg0.locked, arg1)) {
            (*0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, arg1), true)
        } else {
            let v2 = LockedBalance{
                amount       : 0,
                end          : 0,
                is_permanent : false,
            };
            (v2, false)
        }
    }

    fun locked_balance(arg0: u64, arg1: u64, arg2: bool) : LockedBalance {
        LockedBalance{
            amount       : arg0,
            end          : arg1,
            is_permanent : arg2,
        }
    }

    public fun managed_to_free<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : 0x2::object::ID {
        0x2::object::id<distribution::free_managed_reward::FreeManagedReward>(0x2::table::borrow<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&arg0.managed_to_free, arg1))
    }

    public fun merge<T0>(arg0: &mut VotingEscrow<T0>, arg1: Lock, arg2: &mut Lock, arg3: &0x2::clock::Clock, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::object::id<Lock>(&arg1);
        let v1 = 0x2::object::id<Lock>(arg2);
        let v2 = lock_has_voted<T0>(arg0, v0);
        assert!(!v2, 9223376074125738011);
        assert!(escrow_type<T0>(arg0, v0) == EscrowType::NORMAL{}, 9223376078420574233);
        assert!(escrow_type<T0>(arg0, v1) == EscrowType::NORMAL{}, 9223376082715541529);
        assert!(v0 != v1, 9223376087012474935);
        let v3 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v1);
        assert!(v3.end > distribution::common::current_timestamp(arg3) || v3.is_permanent == true, 9223376108484165639);
        let v4 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        assert!(v4.is_permanent == false, 9223376117075935267);
        let mut v5 = if (v4.end >= v3.end) {
            v4.end
        } else {
            v3.end
        };
        burn_lock_internal<T0>(arg0, arg1, v4, arg3, arg4);
        let mut v6 = if (v3.is_permanent) {
            0
        } else {
            v5
        };
        let v7 = locked_balance(v4.amount + v3.amount, v6, v3.is_permanent);
        if (v7.is_permanent) {
            arg0.permanent_lock_balance = arg0.permanent_lock_balance + v4.amount;
        };
        distribution::voting_dao::checkpoint_delegatee(&mut arg0.voting_dao, distribution::voting_dao::delegatee(&arg0.voting_dao, v1), v4.amount, true, arg3, arg4);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v1), v3, v7, arg3, arg4);
        0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v1);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v1, v7);
        arg2.amount = v7.amount;
        let v8 = EventMerge{
            sender      : 0x2::tx_context::sender(arg4),
            from        : v0,
            to          : v1,
            from_amount : v4.amount,
            to_amount   : v3.amount,
            new_amount  : v7.amount,
            new_end     : v7.end,
        };
        0x2::event::emit<EventMerge>(v8);
        let v9 = EventMetadataUpdate{lock_id: v1};
        0x2::event::emit<EventMetadataUpdate>(v9);
    }

    public fun owner_of<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : address {
        *0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, arg1)
    }

    public fun owner_proof<T0>(arg0: &VotingEscrow<T0>, arg1: &Lock, arg2: &mut 0x2::tx_context::TxContext) : distribution::lock_owner::OwnerProof {
        validate_lock<T0>(arg0, arg1);
        let v0 = 0x2::tx_context::sender(arg2);
        assert!(0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, 0x2::object::id<Lock>(arg1)) == &v0, 9223373209380847615);
        distribution::lock_owner::issue(0x2::object::id<VotingEscrow<T0>>(arg0), 0x2::object::id<Lock>(arg1), 0x2::tx_context::sender(arg2))
    }

    public fun ownership_change_at<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : u64 {
        *0x2::table::borrow<0x2::object::ID, u64>(&arg0.ownership_change_at, arg1)
    }

    public fun remove_allowed_manager<T0>(arg0: &mut VotingEscrow<T0>, arg1: &0x2::package::Publisher, arg2: address) {
        0x2::vec_set::remove<address>(&mut arg0.allowed_managers, &arg2);
    }

    fun set_locked<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: LockedBalance) {
        if (0x2::table::contains<0x2::object::ID, LockedBalance>(&arg0.locked, arg1)) {
            0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg1);
        };
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg1, arg2);
    }

    public fun set_managed_state<T0>(arg0: &mut VotingEscrow<T0>, arg1: &distribution::emergency_council::EmergencyCouncilCap, arg2: 0x2::object::ID, arg3: bool, arg4: &mut 0x2::tx_context::TxContext) {
        assert!(escrow_type<T0>(arg0, arg2) == EscrowType::MANAGED{}, 9223378410588995627);
        assert!(0x2::table::borrow<0x2::object::ID, bool>(&arg0.deactivated, arg2) != &arg3, 9223378414884618293);
        0x2::table::remove<0x2::object::ID, bool>(&mut arg0.deactivated, arg2);
        0x2::table::add<0x2::object::ID, bool>(&mut arg0.deactivated, arg2, arg3);
    }

    fun set_point_history<T0>(arg0: &mut VotingEscrow<T0>, arg1: u64, arg2: GlobalPoint) {
        if (0x2::table::contains<u64, GlobalPoint>(&arg0.point_history, arg1)) {
            0x2::table::remove<u64, GlobalPoint>(&mut arg0.point_history, arg1);
        };
        0x2::table::add<u64, GlobalPoint>(&mut arg0.point_history, arg1, arg2);
    }

    fun set_slope_changes<T0>(arg0: &mut VotingEscrow<T0>, arg1: u64, arg2: integer_mate::i128::I128) {
        if (0x2::table::contains<u64, integer_mate::i128::I128>(&arg0.slope_changes, arg1)) {
            0x2::table::remove<u64, integer_mate::i128::I128>(&mut arg0.slope_changes, arg1);
        };
        0x2::table::add<u64, integer_mate::i128::I128>(&mut arg0.slope_changes, arg1, arg2);
    }

    fun set_user_point_epoch<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64) {
        if (0x2::table::contains<0x2::object::ID, u64>(&arg0.user_point_epoch, arg1)) {
            0x2::table::remove<0x2::object::ID, u64>(&mut arg0.user_point_epoch, arg1);
        };
        0x2::table::add<0x2::object::ID, u64>(&mut arg0.user_point_epoch, arg1, arg2);
    }

    fun set_user_point_history<T0>(arg0: &mut VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64, arg3: UserPoint, arg4: &mut 0x2::tx_context::TxContext) {
        if (!0x2::table::contains<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1)) {
            0x2::table::add<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&mut arg0.user_point_history, arg1, 0x2::table::new<u64, UserPoint>(arg4));
        };
        let v0 = 0x2::table::borrow_mut<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&mut arg0.user_point_history, arg1);
        if (0x2::table::contains<u64, UserPoint>(v0, arg2)) {
            0x2::table::remove<u64, UserPoint>(v0, arg2);
        };
        0x2::table::add<u64, UserPoint>(v0, arg2, arg3);
    }

    public fun toggle_split<T0>(arg0: &mut VotingEscrow<T0>, arg1: &distribution::team_cap::TeamCap, arg2: address, arg3: bool) {
        distribution::team_cap::validate(arg1, 0x2::object::id<VotingEscrow<T0>>(arg0));
        if (0x2::table::contains<address, bool>(&arg0.can_split, arg2)) {
            0x2::table::remove<address, bool>(&mut arg0.can_split, arg2);
        };
        0x2::table::add<address, bool>(&mut arg0.can_split, arg2, arg3);
        let v0 = EventToggleSplit{
            who     : arg2,
            allowed : arg3,
        };
        0x2::event::emit<EventToggleSplit>(v0);
    }

    public fun total_locked<T0>(arg0: &VotingEscrow<T0>) : u64 {
        arg0.total_locked
    }

    public fun total_supply_at<T0>(arg0: &VotingEscrow<T0>, arg1: u64) : u64 {
        total_supply_at_internal<T0>(arg0, arg0.epoch, arg1)
    }

    fun total_supply_at_internal<T0>(arg0: &VotingEscrow<T0>, arg1: u64, arg2: u64) : u64 {
        let v0 = get_past_global_point_index<T0>(arg0, arg1, arg2);
        if (v0 == 0) {
            return 0
        };
        let v1 = 0x2::table::borrow<u64, GlobalPoint>(&arg0.point_history, v0);
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
                let mut v9 = if (0x2::table::contains<u64, integer_mate::i128::I128>(&arg0.slope_changes, v7)) {
                    *0x2::table::borrow<u64, integer_mate::i128::I128>(&arg0.slope_changes, v7)
                } else {
                    integer_mate::i128::from(0)
                };
                v8 = v9;
            };
            v2 = integer_mate::i128::sub(v2, integer_mate::i128::div(integer_mate::i128::mul(v3, integer_mate::i128::from(((v5 - v4) as u128))), integer_mate::i128::from(18446744073709551616)));
            if (v5 == arg2) {
                break
            };
            v3 = integer_mate::i128::add(v3, v8);
            v6 = v6 + 1;
        };
        if (integer_mate::i128::is_neg(v2)) {
            v2 = integer_mate::i128::from(0);
        };
        (integer_mate::i128::as_u128(v2) as u64) + v1.permanent_lock_balance
    }

    public fun unlock_permanent<T0>(arg0: &mut VotingEscrow<T0>, arg1: &mut Lock, arg2: &0x2::clock::Clock, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::tx_context::sender(arg3);
        let v1 = 0x2::object::id<Lock>(arg1);
        let mut v2 = if (!0x2::table::contains<0x2::object::ID, EscrowType>(&arg0.escrow_type, v1)) {
            true
        } else {
            let v3 = EscrowType::NORMAL{};
            0x2::table::borrow<0x2::object::ID, EscrowType>(&arg0.escrow_type, v1) == &v3
        };
        assert!(v2, 9223376666831093785);
        let v4 = lock_has_voted<T0>(arg0, v1);
        assert!(!v4, 9223376671126192155);
        let mut v5 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v1);
        assert!(v5.is_permanent, 9223376679715602451);
        let v6 = distribution::common::current_timestamp(arg2);
        arg0.permanent_lock_balance = arg0.permanent_lock_balance - v5.amount;
        v5.end = distribution::common::to_period(v6 + distribution::common::max_lock_time());
        v5.is_permanent = false;
        delegate_internal<T0>(arg0, arg1, 0x2::object::id_from_address(@0x0), arg2, arg3);
        let v7 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v1);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v1), v7, v5, arg2, arg3);
        0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v1);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v1, v5);
        arg1.permanent = false;
        arg1.end = v5.end;
        arg1.start = v6;
        let v8 = EventUnlockPermanent{
            sender  : v0,
            lock_id : v1,
            amount  : v5.amount,
        };
        0x2::event::emit<EventUnlockPermanent>(v8);
        let v9 = EventMetadataUpdate{lock_id: v1};
        0x2::event::emit<EventMetadataUpdate>(v9);
    }

    public fun user_point_epoch<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID) : u64 {
        *0x2::table::borrow<0x2::object::ID, u64>(&arg0.user_point_epoch, arg1)
    }

    public fun user_point_history<T0>(arg0: &VotingEscrow<T0>, arg1: 0x2::object::ID, arg2: u64) : UserPoint {
        *0x2::table::borrow<u64, UserPoint>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<u64, UserPoint>>(&arg0.user_point_history, arg1), arg2)
    }

    public fun user_point_ts(arg0: &UserPoint) : u64 {
        arg0.ts
    }

    fun validate_lock<T0>(arg0: &VotingEscrow<T0>, arg1: &Lock) {
        assert!(arg1.escrow == 0x2::object::id<VotingEscrow<T0>>(arg0), 9223376052649197567);
    }

    fun validate_lock_duration<T0>(arg0: &VotingEscrow<T0>, arg1: u64) {
        assert!(arg1 * distribution::common::day() >= arg0.min_lock_time && arg1 * distribution::common::day() <= arg0.max_lock_time, 9223374111324635147);
    }

    public fun voting<T0>(arg0: &mut VotingEscrow<T0>, arg1: &distribution::voter_cap::VoterCap, arg2: 0x2::object::ID, arg3: bool) {
        assert!(arg0.voter == distribution::voter_cap::get_voter_id(arg1), 9223374076964241407);
        if (0x2::table::contains<0x2::object::ID, bool>(&arg0.voted, arg2)) {
            0x2::table::remove<0x2::object::ID, bool>(&mut arg0.voted, arg2);
        };
        0x2::table::add<0x2::object::ID, bool>(&mut arg0.voted, arg2, arg3);
    }

    public fun withdraw_managed<T0>(arg0: &mut VotingEscrow<T0>, arg1: &distribution::voter_cap::VoterCap, arg2: 0x2::object::ID, arg3: distribution::lock_owner::OwnerProof, arg4: &0x2::clock::Clock, arg5: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        assert!(distribution::voter_cap::get_voter_id(arg1) == arg0.voter, 9223377925257822253);
        assert!(0x2::table::contains<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, arg2), 9223377929552920623);
        assert!(escrow_type<T0>(arg0, arg2) == EscrowType::LOCKED{}, 9223377933848018993);
        let v0 = *0x2::table::borrow<0x2::object::ID, 0x2::object::ID>(&arg0.id_to_managed, arg2);
        let v1 = 0x2::table::borrow_mut<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(&mut arg0.managed_to_locked, v0);
        let v2 = *0x2::table::borrow<0x2::object::ID, u64>(0x2::table::borrow<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(&arg0.managed_weights, arg2), v0);
        let v3 = v2 + distribution::locked_managed_reward::earned<T0>(v1, arg2, arg4);
        let v4 = distribution::locked_managed_reward::get_reward<T0>(v1, &arg0.locked_managed_reward_authorized_cap, arg2, arg4, arg5);
        distribution::free_managed_reward::get_reward<T0>(0x2::table::borrow_mut<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, v0), arg3, arg4, arg5);
        let v5 = 0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg2);
        let v6 = locked_balance(v3, distribution::common::to_period(distribution::common::current_timestamp(arg4) + distribution::common::max_lock_time()), false);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(arg2), v5, v6, arg4, arg5);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, arg2, v6);
        let mut v7 = *0x2::table::borrow<0x2::object::ID, LockedBalance>(&arg0.locked, v0);
        let mut v8 = if (v3 < v7.amount) {
            v7.amount - v3
        } else {
            0
        };
        v7.amount = v8;
        let mut v9 = if (v3 < arg0.permanent_lock_balance) {
            v3
        } else {
            arg0.permanent_lock_balance
        };
        arg0.permanent_lock_balance = arg0.permanent_lock_balance - v9;
        distribution::voting_dao::checkpoint_delegatee(&mut arg0.voting_dao, distribution::voting_dao::delegatee(&arg0.voting_dao, v0), v3, false, arg4, arg5);
        let v10 = 0x2::table::remove<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0);
        checkpoint_internal<T0>(arg0, std::option::some<0x2::object::ID>(v0), v10, v7, arg4, arg5);
        0x2::table::add<0x2::object::ID, LockedBalance>(&mut arg0.locked, v0, v7);
        distribution::locked_managed_reward::withdraw(0x2::table::borrow_mut<0x2::object::ID, distribution::locked_managed_reward::LockedManagedReward>(&mut arg0.managed_to_locked, v0), &arg0.locked_managed_reward_authorized_cap, v2, arg2, arg4, arg5);
        distribution::free_managed_reward::withdraw(0x2::table::borrow_mut<0x2::object::ID, distribution::free_managed_reward::FreeManagedReward>(&mut arg0.managed_to_free, v0), &arg0.free_managed_reward_authorized_cap, v2, arg2, arg4, arg5);
        0x2::table::remove<0x2::object::ID, 0x2::object::ID>(&mut arg0.id_to_managed, arg2);
        0x2::table::remove<0x2::object::ID, u64>(0x2::table::borrow_mut<0x2::object::ID, 0x2::table::Table<0x2::object::ID, u64>>(&mut arg0.managed_weights, arg2), v0);
        0x2::table::remove<0x2::object::ID, EscrowType>(&mut arg0.escrow_type, arg2);
        let v11 = EventWithdrawManaged{
            owner           : *0x2::table::borrow<0x2::object::ID, address>(&arg0.owner_of, arg2),
            lock_id         : arg2,
            managed_lock_id : v0,
            amount          : v3,
        };
        0x2::event::emit<EventWithdrawManaged>(v11);
        let v12 = EventMetadataUpdate{lock_id: arg2};
        0x2::event::emit<EventMetadataUpdate>(v12);
        v4
    }

    // decompiled from Move bytecode v7
}


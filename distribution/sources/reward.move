module distribution::reward {
    public struct EventDeposit has copy, drop, store {
        sender: address,
        lock_id: sui::object::ID,
        amount: u64,
    }

    public struct EventWithdraw has copy, drop, store {
        sender: address,
        lock_id: sui::object::ID,
        amount: u64,
    }

    public struct EventClaimRewards has copy, drop, store {
        recipient: address,
        token_name: std::type_name::TypeName,
        reward_amount: u64,
    }

    public struct EventNotifyReward has copy, drop, store {
        sender: address,
        token_name: std::type_name::TypeName,
        epoch_start: u64,
        amount: u64,
    }

    public struct Checkpoint has drop, store {
        timestamp: u64,
        balance_of: u64,
    }

    public struct SupplyCheckpoint has drop, store {
        timestamp: u64,
        supply: u64,
    }

    public struct Reward has store, key {
        id: sui::object::UID,
        voter: sui::object::ID,
        ve: sui::object::ID,
        authorized: sui::object::ID,
        total_supply: u64,
        balance_of: sui::table::Table<sui::object::ID, u64>,
        token_rewards_per_epoch: sui::table::Table<std::type_name::TypeName, sui::table::Table<u64, u64>>,
        last_earn: sui::table::Table<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>,
        rewards: sui::vec_set::VecSet<std::type_name::TypeName>,
        checkpoints: sui::table::Table<sui::object::ID, sui::table::Table<u64, Checkpoint>>,
        num_checkpoints: sui::table::Table<sui::object::ID, u64>,
        supply_checkpoints: sui::table::Table<u64, SupplyCheckpoint>,
        supply_num_checkpoints: u64,
        balances: sui::bag::Bag,
    }

    public fun balance<T0>(arg0: &Reward): u64 {
        sui::balance::value<T0>(
            sui::bag::borrow<std::type_name::TypeName, sui::balance::Balance<T0>>(
                &arg0.balances,
                std::type_name::get<T0>()
            )
        )
    }

    public(package) fun add_reward_token(arg0: &mut Reward, arg1: std::type_name::TypeName) {
        sui::vec_set::insert<std::type_name::TypeName>(&mut arg0.rewards, arg1);
    }

    public fun authorized(arg0: &Reward): sui::object::ID {
        arg0.authorized
    }

    public(package) fun create(
        arg0: sui::object::ID,
        arg1: sui::object::ID,
        arg2: sui::object::ID,
        arg3: vector<std::type_name::TypeName>,
        arg4: &mut sui::tx_context::TxContext
    ): Reward {
        let mut v0 = Reward {
            id: sui::object::new(arg4),
            voter: arg0,
            ve: arg1,
            authorized: arg2,
            total_supply: 0,
            balance_of: sui::table::new<sui::object::ID, u64>(arg4),
            token_rewards_per_epoch: sui::table::new<std::type_name::TypeName, sui::table::Table<u64, u64>>(arg4),
            last_earn: sui::table::new<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(arg4),
            rewards: sui::vec_set::empty<std::type_name::TypeName>(),
            checkpoints: sui::table::new<sui::object::ID, sui::table::Table<u64, Checkpoint>>(arg4),
            num_checkpoints: sui::table::new<sui::object::ID, u64>(arg4),
            supply_checkpoints: sui::table::new<u64, SupplyCheckpoint>(arg4),
            supply_num_checkpoints: 0,
            balances: sui::bag::new(arg4),
        };
        let mut v1 = 0;
        while (v1 < std::vector::length<std::type_name::TypeName>(&arg3)) {
            sui::vec_set::insert<std::type_name::TypeName>(
                &mut v0.rewards,
                *std::vector::borrow<std::type_name::TypeName>(&arg3, v1)
            );
            v1 = v1 + 1;
        };
        v0
    }

    public(package) fun deposit(
        arg0: &mut Reward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: u64,
        arg3: sui::object::ID,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(arg1, arg0.authorized);
        arg0.total_supply = arg0.total_supply + arg2;
        let v0 = if (sui::table::contains<sui::object::ID, u64>(&arg0.balance_of, arg3)) {
            sui::table::remove<sui::object::ID, u64>(&mut arg0.balance_of, arg3)
        } else {
            0
        };
        let v1 = v0 + arg2;
        sui::table::add<sui::object::ID, u64>(&mut arg0.balance_of, arg3, v1);
        let v2 = distribution::common::current_timestamp(arg4);
        write_checkpoint_internal(arg0, arg3, v1, v2, arg5);
        write_supply_checkpoint_internal(arg0, v2);
        let v3 = EventDeposit {
            sender: sui::tx_context::sender(arg5),
            lock_id: arg3,
            amount: arg2,
        };
        sui::event::emit<EventDeposit>(v3);
    }

    public(package) fun earned<T0>(arg0: &Reward, arg1: sui::object::ID, arg2: &sui::clock::Clock): u64 {
        let v0 = if (!sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
            true
        } else {
            let v1 = 0;
            sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1) == &v1
        };
        if (v0) {
            return 0
        };
        let v2 = std::type_name::get<T0>();
        let mut v3 = 0;
        let v4 = if (sui::table::contains<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &arg0.last_earn,
            v2
        ) && sui::table::contains<sui::object::ID, u64>(
            sui::table::borrow<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(&arg0.last_earn, v2),
            arg1
        )) {
            distribution::common::epoch_start(
                *sui::table::borrow<sui::object::ID, u64>(
                    sui::table::borrow<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
                        &arg0.last_earn,
                        v2
                    ),
                    arg1
                )
            )
        } else {
            0
        };
        let v5 = sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
            get_prior_balance_index(arg0, arg1, v4)
        );
        let v6 = if (v4 >= distribution::common::epoch_start(v5.timestamp)) {
            v4
        } else {
            distribution::common::epoch_start(v5.timestamp)
        };
        let mut v7 = v6;
        let v8 = (distribution::common::epoch_start(distribution::common::current_timestamp(arg2)) - v6) / 604800;
        if (v8 > 0) {
            let mut v9 = 0;
            while (v9 < v8) {
                let v10 = sui::table::borrow<u64, Checkpoint>(
                    sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
                    get_prior_balance_index(arg0, arg1, v7 + 604800 - 1)
                );
                let v11 = get_prior_supply_index(arg0, v7 + 604800 - 1);
                let v12 = if (!sui::table::contains<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v11)) {
                    1
                } else {
                    let v13 = sui::table::borrow<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v11).supply;
                    let mut v14 = v13;
                    if (v13 == 0) {
                        v14 = 1;
                    };
                    v14
                };
                if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                    &arg0.token_rewards_per_epoch,
                    v2
                )) {
                    break
                };
                let v15 = sui::table::borrow<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                    &arg0.token_rewards_per_epoch,
                    v2
                );
                let v16 = if (sui::table::contains<u64, u64>(v15, v7)) {
                    let v17 = sui::table::borrow<u64, u64>(v15, v7);
                    *v17
                } else {
                    0
                };
                v3 = v3 + v10.balance_of * v16 / v12;
                v7 = v7 + 604800;
                v9 = v9 + 1;
            };
        };
        v3
    }

    public fun get_prior_balance_index(arg0: &Reward, arg1: sui::object::ID, arg2: u64): u64 {
        let v0 = *sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1);
        if (v0 == 0) {
            return 0
        };
        if (sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
            v0 - 1
        ).timestamp <= arg2) {
            return v0 - 1
        };
        if (sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
            0
        ).timestamp > arg2) {
            return 0
        };
        let mut v1 = 0;
        let mut v2 = v0 - 1;
        while (v2 > v1) {
            let v3 = v2 - (v2 - v1) / 2;
            let v4 = sui::table::borrow<u64, Checkpoint>(
                sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
                v3
            );
            if (v4.timestamp == arg2) {
                return v3
            };
            if (v4.timestamp < arg2) {
                v1 = v3;
                continue
            };
            v2 = v3 - 1;
        };
        v1
    }

    public fun get_prior_supply_index(arg0: &Reward, arg1: u64): u64 {
        let v0 = arg0.supply_num_checkpoints;
        if (v0 == 0) {
            return 0
        };
        if (sui::table::borrow<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v0 - 1).timestamp <= arg1) {
            return v0 - 1
        };
        if (sui::table::borrow<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, 0).timestamp > arg1) {
            return 0
        };
        let mut v1 = 0;
        let mut v2 = v0 - 1;
        while (v2 > v1) {
            let v3 = v2 - (v2 - v1) / 2;
            let v4 = sui::table::borrow<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v3);
            if (v4.timestamp == arg1) {
                return v3
            };
            if (v4.timestamp < arg1) {
                v1 = v3;
                continue
            };
            v2 = v3 - 1;
        };
        v1
    }

    public(package) fun get_reward_internal<T0>(
        arg0: &mut Reward,
        arg1: address,
        arg2: sui::object::ID,
        arg3: &sui::clock::Clock,
        arg4: &mut sui::tx_context::TxContext
    ): std::option::Option<sui::balance::Balance<T0>> {
        let v0 = earned<T0>(arg0, arg2, arg3);
        let v1 = std::type_name::get<T0>();
        if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &arg0.last_earn,
            v1
        )) {
            sui::table::add<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
                &mut arg0.last_earn,
                v1,
                sui::table::new<sui::object::ID, u64>(arg4)
            );
        };
        let v2 = sui::table::borrow_mut<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &mut arg0.last_earn,
            v1
        );
        if (sui::table::contains<sui::object::ID, u64>(v2, arg2)) {
            sui::table::remove<sui::object::ID, u64>(v2, arg2);
        };
        sui::table::add<sui::object::ID, u64>(v2, arg2, distribution::common::current_timestamp(arg3));
        let v3 = EventClaimRewards {
            recipient: arg1,
            token_name: v1,
            reward_amount: v0,
        };
        sui::event::emit<EventClaimRewards>(v3);
        if (v0 > 0) {
            return std::option::some<sui::balance::Balance<T0>>(
                sui::balance::split<T0>(
                    sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v1),
                    v0
                )
            )
        };
        std::option::none<sui::balance::Balance<T0>>()
    }

    public(package) fun notify_reward_amount_internal<T0>(
        arg0: &mut Reward,
        arg1: sui::balance::Balance<T0>,
        arg2: &sui::clock::Clock,
        arg3: &mut sui::tx_context::TxContext
    ) {
        let v0 = sui::balance::value<T0>(&arg1);
        let v1 = std::type_name::get<T0>();
        let v2 = distribution::common::epoch_start(distribution::common::current_timestamp(arg2));
        if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<u64, u64>>(
            &arg0.token_rewards_per_epoch,
            v1
        )) {
            sui::table::add<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                &mut arg0.token_rewards_per_epoch,
                v1,
                sui::table::new<u64, u64>(arg3)
            );
        };
        let v3 = sui::table::borrow_mut<std::type_name::TypeName, sui::table::Table<u64, u64>>(
            &mut arg0.token_rewards_per_epoch,
            v1
        );
        let v4 = if (sui::table::contains<u64, u64>(v3, v2)) {
            sui::table::remove<u64, u64>(v3, v2)
        } else {
            0
        };
        sui::table::add<u64, u64>(v3, v2, v4 + v0);
        if (!sui::bag::contains<std::type_name::TypeName>(&arg0.balances, v1)) {
            sui::bag::add<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v1, arg1);
        } else {
            sui::balance::join<T0>(
                sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v1),
                arg1
            );
        };
        let v5 = EventNotifyReward {
            sender: sui::tx_context::sender(arg3),
            token_name: v1,
            epoch_start: v2,
            amount: v0,
        };
        sui::event::emit<EventNotifyReward>(v5);
    }

    public fun rewards_contains(arg0: &Reward, arg1: std::type_name::TypeName): bool {
        sui::vec_set::contains<std::type_name::TypeName>(&arg0.rewards, &arg1)
    }

    public fun rewards_list(arg0: &Reward): vector<std::type_name::TypeName> {
        sui::vec_set::into_keys<std::type_name::TypeName>(arg0.rewards)
    }

    public(package) fun rewards_list_length(arg0: &Reward): u64 {
        sui::vec_set::size<std::type_name::TypeName>(&arg0.rewards)
    }

    public fun ve(arg0: &Reward): sui::object::ID {
        arg0.ve
    }

    public fun voter(arg0: &Reward): sui::object::ID {
        arg0.voter
    }

    public(package) fun withdraw(
        arg0: &mut Reward,
        arg1: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        arg2: u64,
        arg3: sui::object::ID,
        arg4: &sui::clock::Clock,
        arg5: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(arg1, arg0.authorized);
        arg0.total_supply = arg0.total_supply - arg2;
        let v0 = sui::table::remove<sui::object::ID, u64>(&mut arg0.balance_of, arg3);
        sui::table::add<sui::object::ID, u64>(&mut arg0.balance_of, arg3, v0 - arg2);
        let v1 = distribution::common::current_timestamp(arg4);
        write_checkpoint_internal(arg0, arg3, v0 - arg2, v1, arg5);
        write_supply_checkpoint_internal(arg0, v1);
        let v2 = EventWithdraw {
            sender: sui::tx_context::sender(arg5),
            lock_id: arg3,
            amount: arg2,
        };
        sui::event::emit<EventWithdraw>(v2);
    }

    fun write_checkpoint_internal(
        arg0: &mut Reward,
        arg1: sui::object::ID,
        arg2: u64,
        arg3: u64,
        arg4: &mut sui::tx_context::TxContext
    ) {
        let v0 = if (sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
            *sui::table::borrow<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)
        } else {
            0
        };
        if (v0 > 0 && distribution::common::epoch_start(
            sui::table::borrow<u64, Checkpoint>(
                sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1),
                v0 - 1
            ).timestamp
        ) == distribution::common::epoch_start(arg3)) {
            let v1 = sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                &mut arg0.checkpoints,
                arg1
            );
            if (sui::table::contains<u64, Checkpoint>(v1, v0 - 1)) {
                sui::table::remove<u64, Checkpoint>(v1, v0 - 1);
            };
            let v2 = Checkpoint {
                timestamp: arg3,
                balance_of: arg2,
            };
            sui::table::add<u64, Checkpoint>(v1, v0 - 1, v2);
        } else {
            if (!sui::table::contains<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&arg0.checkpoints, arg1)) {
                sui::table::add<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                    &mut arg0.checkpoints,
                    arg1,
                    sui::table::new<u64, Checkpoint>(arg4)
                );
            };
            let v3 = sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                &mut arg0.checkpoints,
                arg1
            );
            if (sui::table::contains<u64, Checkpoint>(v3, v0)) {
                sui::table::remove<u64, Checkpoint>(v3, v0);
            };
            let v4 = Checkpoint {
                timestamp: arg3,
                balance_of: arg2,
            };
            sui::table::add<u64, Checkpoint>(v3, v0, v4);
            if (sui::table::contains<sui::object::ID, u64>(&arg0.num_checkpoints, arg1)) {
                sui::table::remove<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1);
            };
            sui::table::add<sui::object::ID, u64>(&mut arg0.num_checkpoints, arg1, v0 + 1);
        };
    }

    fun write_supply_checkpoint_internal(arg0: &mut Reward, arg1: u64) {
        let v0 = arg0.supply_num_checkpoints;
        if (v0 > 0 && distribution::common::epoch_start(
            sui::table::borrow<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v0 - 1).timestamp
        ) == distribution::common::epoch_start(arg1)) {
            if (sui::table::contains<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v0 - 1)) {
                sui::table::remove<u64, SupplyCheckpoint>(&mut arg0.supply_checkpoints, v0 - 1);
            };
            let v1 = SupplyCheckpoint {
                timestamp: arg1,
                supply: arg0.total_supply,
            };
            sui::table::add<u64, SupplyCheckpoint>(&mut arg0.supply_checkpoints, v0 - 1, v1);
        } else {
            if (sui::table::contains<u64, SupplyCheckpoint>(&arg0.supply_checkpoints, v0)) {
                sui::table::remove<u64, SupplyCheckpoint>(&mut arg0.supply_checkpoints, v0);
            };
            let v2 = SupplyCheckpoint {
                timestamp: arg1,
                supply: arg0.total_supply,
            };
            sui::table::add<u64, SupplyCheckpoint>(&mut arg0.supply_checkpoints, v0, v2);
            arg0.supply_num_checkpoints = v0 + 1;
        };
    }

    // decompiled from Move bytecode v6
}


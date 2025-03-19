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

    public fun balance<CoinType>(reward: &Reward): u64 {
        sui::bag::borrow<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
            &reward.balances,
            std::type_name::get<CoinType>()
        ).value<CoinType>()
    }

    public(package) fun add_reward_token(reward: &mut Reward, coinTypeName: std::type_name::TypeName) {
        reward.rewards.insert<std::type_name::TypeName>(coinTypeName);
    }

    public fun authorized(reward: &Reward): sui::object::ID {
        reward.authorized
    }

    public(package) fun create(
        voter: sui::object::ID,
        ve: sui::object::ID,
        authorized: sui::object::ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut sui::tx_context::TxContext
    ): Reward {
        let mut reward = Reward {
            id: sui::object::new(ctx),
            voter,
            ve,
            authorized,
            total_supply: 0,
            balance_of: sui::table::new<sui::object::ID, u64>(ctx),
            token_rewards_per_epoch: sui::table::new<std::type_name::TypeName, sui::table::Table<u64, u64>>(ctx),
            last_earn: sui::table::new<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(ctx),
            rewards: sui::vec_set::empty<std::type_name::TypeName>(),
            checkpoints: sui::table::new<sui::object::ID, sui::table::Table<u64, Checkpoint>>(ctx),
            num_checkpoints: sui::table::new<sui::object::ID, u64>(ctx),
            supply_checkpoints: sui::table::new<u64, SupplyCheckpoint>(ctx),
            supply_num_checkpoints: 0,
            balances: sui::bag::new(ctx),
        };
        let mut i = 0;
        while (i < std::vector::length<std::type_name::TypeName>(&reward_coin_types)) {
            reward.rewards.insert<std::type_name::TypeName>(
                *std::vector::borrow<std::type_name::TypeName>(&reward_coin_types, i)
            );
            i = i + 1;
        };
        reward
    }

    public(package) fun deposit(
        reward: &mut Reward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(reward_authorized_cap, reward.authorized);
        reward.total_supply = reward.total_supply + amount;
        let lock_balance = if (sui::table::contains<sui::object::ID, u64>(&reward.balance_of, lock_id)) {
            sui::table::remove<sui::object::ID, u64>(&mut reward.balance_of, lock_id)
        } else {
            0
        };
        let updated_lock_votes_balance = lock_balance + amount;
        sui::table::add<sui::object::ID, u64>(&mut reward.balance_of, lock_id, updated_lock_votes_balance);
        let current_time = distribution::common::current_timestamp(clock);
        write_checkpoint_internal(reward, lock_id, updated_lock_votes_balance, current_time, ctx);
        write_supply_checkpoint_internal(reward, current_time);
        let deposit_event = EventDeposit {
            sender: sui::tx_context::sender(ctx),
            lock_id,
            amount,
        };
        sui::event::emit<EventDeposit>(deposit_event);
    }

    public(package) fun earned<CoinType>(reward: &Reward, lock_id: sui::object::ID, clock: &sui::clock::Clock): u64 {
        let zero_checkpoints = if (!sui::table::contains<sui::object::ID, u64>(&reward.num_checkpoints, lock_id)) {
            true
        } else {
            let v1 = 0;
            sui::table::borrow<sui::object::ID, u64>(&reward.num_checkpoints, lock_id) == &v1
        };
        if (zero_checkpoints) {
            return 0
        };
        let coin_type_name = std::type_name::get<CoinType>();
        let mut earned_amount = 0;
        let last_earn_epoch_time = if (sui::table::contains<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &reward.last_earn,
            coin_type_name
        ) && sui::table::contains<sui::object::ID, u64>(
            sui::table::borrow<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
                &reward.last_earn,
                coin_type_name
            ),
            lock_id
        )) {
            distribution::common::epoch_start(
                *sui::table::borrow<sui::object::ID, u64>(
                    sui::table::borrow<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
                        &reward.last_earn,
                        coin_type_name
                    ),
                    lock_id
                )
            )
        } else {
            0
        };
        let prior_checkpoint = sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&reward.checkpoints, lock_id),
            get_prior_balance_index(reward, lock_id, last_earn_epoch_time)
        );
        let latest_epoch_time = if (last_earn_epoch_time >= distribution::common::epoch_start(prior_checkpoint.timestamp)) {
            last_earn_epoch_time
        } else {
            distribution::common::epoch_start(prior_checkpoint.timestamp)
        };
        let mut next_epoch_time = latest_epoch_time;
        let epochs_until_now = (distribution::common::epoch_start(distribution::common::current_timestamp(clock)) - latest_epoch_time) / 604800;
        if (epochs_until_now > 0) {
            let mut i = 0;
            while (i < epochs_until_now) {
                let next_checkpoint = sui::table::borrow<u64, Checkpoint>(
                    sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                        &reward.checkpoints,
                        lock_id
                    ),
                    get_prior_balance_index(reward, lock_id, next_epoch_time + 604800 - 1)
                );
                let supply_index = get_prior_supply_index(reward, next_epoch_time + 604800 - 1);
                let supply = if (!sui::table::contains<u64, SupplyCheckpoint>(
                    &reward.supply_checkpoints,
                    supply_index
                )) {
                    1
                } else {
                    let checkpoint_supply = sui::table::borrow<u64, SupplyCheckpoint>(&reward.supply_checkpoints, supply_index).supply;
                    let mut checkpoint_supply_mut = checkpoint_supply;
                    if (checkpoint_supply == 0) {
                        checkpoint_supply_mut = 1;
                    };
                    checkpoint_supply_mut
                };
                if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                    &reward.token_rewards_per_epoch,
                    coin_type_name
                )) {
                    break
                };
                let rewards_per_epoch = sui::table::borrow<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                    &reward.token_rewards_per_epoch,
                    coin_type_name
                );
                let reward_in_epoch = if (sui::table::contains<u64, u64>(rewards_per_epoch, next_epoch_time)) {
                    let v17 = sui::table::borrow<u64, u64>(rewards_per_epoch, next_epoch_time);
                    *v17
                } else {
                    0
                };
                earned_amount = earned_amount + next_checkpoint.balance_of * reward_in_epoch / supply;
                next_epoch_time = next_epoch_time + 604800;
                i = i + 1;
            };
        };
        earned_amount
    }

    /**
    * Returns the index of the latest checkpoint that has timestamp lower or equal to the specified time.
    */
    public fun get_prior_balance_index(reward: &Reward, lock_id: sui::object::ID, time: u64): u64 {
        let num_checkpoints = *sui::table::borrow<sui::object::ID, u64>(&reward.num_checkpoints, lock_id);
        if (num_checkpoints == 0) {
            return 0
        };
        if (sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&reward.checkpoints, lock_id),
            num_checkpoints - 1
        ).timestamp <= time) {
            return num_checkpoints - 1
        };
        if (sui::table::borrow<u64, Checkpoint>(
            sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&reward.checkpoints, lock_id),
            0
        ).timestamp > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = sui::table::borrow<u64, Checkpoint>(
                sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(&reward.checkpoints, lock_id),
                middle
            );
            if (middle_checkpoint.timestamp == time) {
                return middle
            };
            if (middle_checkpoint.timestamp < time) {
                lower_bound = middle;
                continue
            };
            upper_bound = middle - 1;
        };
        lower_bound
    }

    /**
    * Returns the index of the latest supply checkpoint that has timestamp lower or equal to the specified time.
    */
    public fun get_prior_supply_index(reward: &Reward, time: u64): u64 {
        let num_checkpoints = reward.supply_num_checkpoints;
        if (num_checkpoints == 0) {
            return 0
        };
        if (sui::table::borrow<u64, SupplyCheckpoint>(&reward.supply_checkpoints, num_checkpoints - 1).timestamp <= time) {
            return num_checkpoints - 1
        };
        if (sui::table::borrow<u64, SupplyCheckpoint>(&reward.supply_checkpoints, 0).timestamp > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = sui::table::borrow<u64, SupplyCheckpoint>(&reward.supply_checkpoints, middle);
            if (middle_checkpoint.timestamp == time) {
                return middle
            };
            if (middle_checkpoint.timestamp < time) {
                lower_bound = middle;
                continue
            };
            upper_bound = middle - 1;
        };
        lower_bound
    }

    public(package) fun get_reward_internal<CoinType>(
        reward: &mut Reward,
        recipient: address,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ): std::option::Option<sui::balance::Balance<CoinType>> {
        let reward_amount = earned<CoinType>(reward, lock_id, clock);
        let coin_type_name = std::type_name::get<CoinType>();
        if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &reward.last_earn,
            coin_type_name
        )) {
            sui::table::add<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
                &mut reward.last_earn,
                coin_type_name,
                sui::table::new<sui::object::ID, u64>(ctx)
            );
        };
        let last_earned_times = sui::table::borrow_mut<std::type_name::TypeName, sui::table::Table<sui::object::ID, u64>>(
            &mut reward.last_earn,
            coin_type_name
        );
        if (sui::table::contains<sui::object::ID, u64>(last_earned_times, lock_id)) {
            sui::table::remove<sui::object::ID, u64>(last_earned_times, lock_id);
        };
        sui::table::add<sui::object::ID, u64>(
            last_earned_times,
            lock_id,
            distribution::common::current_timestamp(clock)
        );
        let claim_rewards_event = EventClaimRewards {
            recipient,
            token_name: coin_type_name,
            reward_amount,
        };
        sui::event::emit<EventClaimRewards>(claim_rewards_event);
        if (reward_amount > 0) {
            return std::option::some<sui::balance::Balance<CoinType>>(
                sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
                    &mut reward.balances,
                    coin_type_name
                ).split<CoinType>(reward_amount)
            )
        };
        std::option::none<sui::balance::Balance<CoinType>>()
    }

    public(package) fun notify_reward_amount_internal<CoinType>(
        reward: &mut Reward,
        balance: sui::balance::Balance<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let reward_amount = balance.value<CoinType>();
        let reward_type_name = std::type_name::get<CoinType>();
        let epoch_start = distribution::common::epoch_start(distribution::common::current_timestamp(clock));
        if (!sui::table::contains<std::type_name::TypeName, sui::table::Table<u64, u64>>(
            &reward.token_rewards_per_epoch,
            reward_type_name
        )) {
            sui::table::add<std::type_name::TypeName, sui::table::Table<u64, u64>>(
                &mut reward.token_rewards_per_epoch,
                reward_type_name,
                sui::table::new<u64, u64>(ctx)
            );
        };
        let rewards_per_epoch = sui::table::borrow_mut<std::type_name::TypeName, sui::table::Table<u64, u64>>(
            &mut reward.token_rewards_per_epoch,
            reward_type_name
        );
        let rewards_in_current_epoch = if (sui::table::contains<u64, u64>(rewards_per_epoch, epoch_start)) {
            sui::table::remove<u64, u64>(rewards_per_epoch, epoch_start)
        } else {
            0
        };
        sui::table::add<u64, u64>(rewards_per_epoch, epoch_start, rewards_in_current_epoch + reward_amount);
        if (!sui::bag::contains<std::type_name::TypeName>(&reward.balances, reward_type_name)) {
            sui::bag::add<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
                &mut reward.balances,
                reward_type_name,
                balance
            );
        } else {
            sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<CoinType>>(&mut reward.balances,
                reward_type_name
            ).join<CoinType>(balance);
        };
        let notify_reward_event = EventNotifyReward {
            sender: sui::tx_context::sender(ctx),
            token_name: reward_type_name,
            epoch_start,
            amount: reward_amount,
        };
        sui::event::emit<EventNotifyReward>(notify_reward_event);
    }

    public fun rewards_contains(reward: &Reward, arg1: std::type_name::TypeName): bool {
        reward.rewards.contains<std::type_name::TypeName>(&arg1)
    }

    public fun rewards_list(reward: &Reward): vector<std::type_name::TypeName> {
        reward.rewards.into_keys<std::type_name::TypeName>()
    }

    public(package) fun rewards_list_length(arg0: &Reward): u64 {
        arg0.rewards.size<std::type_name::TypeName>()
    }

    public fun ve(reward: &Reward): sui::object::ID {
        reward.ve
    }

    public fun voter(reward: &Reward): sui::object::ID {
        reward.voter
    }

    public(package) fun withdraw(
        reward: &mut Reward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: sui::object::ID,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        distribution::reward_authorized_cap::validate(reward_authorized_cap, reward.authorized);
        reward.total_supply = reward.total_supply - amount;
        let lock_balance = sui::table::remove<sui::object::ID, u64>(&mut reward.balance_of, lock_id);
        sui::table::add<sui::object::ID, u64>(&mut reward.balance_of, lock_id, lock_balance - amount);
        let current_time = distribution::common::current_timestamp(clock);
        write_checkpoint_internal(reward, lock_id, lock_balance - amount, current_time, ctx);
        write_supply_checkpoint_internal(reward, current_time);
        let v2 = EventWithdraw {
            sender: sui::tx_context::sender(ctx),
            lock_id,
            amount,
        };
        sui::event::emit<EventWithdraw>(v2);
    }

    fun write_checkpoint_internal(
        reward: &mut Reward,
        lock_id: sui::object::ID,
        balance: u64,
        time: u64,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let num_of_checkpoints = if (sui::table::contains<sui::object::ID, u64>(
            &reward.num_checkpoints,
            lock_id
        )) {
            *sui::table::borrow<sui::object::ID, u64>(&reward.num_checkpoints, lock_id)
        } else {
            0
        };
        // latest checkpoint timestam is equal to current epoch start
        if (num_of_checkpoints > 0 && distribution::common::epoch_start(
            sui::table::borrow<u64, Checkpoint>(
                sui::table::borrow<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                    &reward.checkpoints,
                    lock_id
                ),
                num_of_checkpoints - 1
            ).timestamp
        ) == distribution::common::epoch_start(time)) {
            let checkpoint = sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                &mut reward.checkpoints,
                lock_id
            );
            if (sui::table::contains<u64, Checkpoint>(checkpoint, num_of_checkpoints - 1)) {
                sui::table::remove<u64, Checkpoint>(checkpoint, num_of_checkpoints - 1);
            };
            let updated_checkpoint = Checkpoint {
                timestamp: time,
                balance_of: balance,
            };
            sui::table::add<u64, Checkpoint>(checkpoint, num_of_checkpoints - 1, updated_checkpoint);
        } else {
            if (!sui::table::contains<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                &reward.checkpoints,
                lock_id
            )) {
                sui::table::add<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                    &mut reward.checkpoints,
                    lock_id,
                    sui::table::new<u64, Checkpoint>(ctx)
                );
            };
            let lock_checkpoints = sui::table::borrow_mut<sui::object::ID, sui::table::Table<u64, Checkpoint>>(
                &mut reward.checkpoints,
                lock_id
            );
            if (sui::table::contains<u64, Checkpoint>(lock_checkpoints, num_of_checkpoints)) {
                sui::table::remove<u64, Checkpoint>(lock_checkpoints, num_of_checkpoints);
            };
            let updated_checkpoint = Checkpoint {
                timestamp: time,
                balance_of: balance,
            };
            sui::table::add<u64, Checkpoint>(lock_checkpoints, num_of_checkpoints, updated_checkpoint);
            if (sui::table::contains<sui::object::ID, u64>(&reward.num_checkpoints, lock_id)) {
                sui::table::remove<sui::object::ID, u64>(&mut reward.num_checkpoints, lock_id);
            };
            sui::table::add<sui::object::ID, u64>(&mut reward.num_checkpoints, lock_id, num_of_checkpoints + 1);
        };
    }

    fun write_supply_checkpoint_internal(reward: &mut Reward, current_time: u64) {
        let num_of_checkpoints = reward.supply_num_checkpoints;
        // latest checkpoint timestam is equal to current epoch start
        if (num_of_checkpoints > 0 && distribution::common::epoch_start(
            sui::table::borrow<u64, SupplyCheckpoint>(
                &reward.supply_checkpoints,
                num_of_checkpoints - 1
            ).timestamp
        ) == distribution::common::epoch_start(current_time)) {
            if (sui::table::contains<u64, SupplyCheckpoint>(&reward.supply_checkpoints, num_of_checkpoints - 1)) {
                sui::table::remove<u64, SupplyCheckpoint>(&mut reward.supply_checkpoints, num_of_checkpoints - 1);
            };
            let updated_checkpoint = SupplyCheckpoint {
                timestamp: current_time,
                supply: reward.total_supply,
            };
            sui::table::add<u64, SupplyCheckpoint>(
                &mut reward.supply_checkpoints,
                num_of_checkpoints - 1,
                updated_checkpoint
            );
        } else {
            if (sui::table::contains<u64, SupplyCheckpoint>(&reward.supply_checkpoints, num_of_checkpoints)) {
                sui::table::remove<u64, SupplyCheckpoint>(&mut reward.supply_checkpoints, num_of_checkpoints);
            };
            let updated_checkpoint = SupplyCheckpoint {
                timestamp: current_time,
                supply: reward.total_supply,
            };
            sui::table::add<u64, SupplyCheckpoint>(
                &mut reward.supply_checkpoints,
                num_of_checkpoints,
                updated_checkpoint
            );
            reward.supply_num_checkpoints = num_of_checkpoints + 1;
        };
    }
}


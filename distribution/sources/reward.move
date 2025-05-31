module distribution::reward {
    public struct EventDeposit has copy, drop, store {
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventWithdraw has copy, drop, store {
        sender: address,
        lock_id: ID,
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
        id: UID,
        voter: ID,
        ve: Option<ID>,
        authorized: ID,
        token_rewards_per_epoch: sui::table::Table<std::type_name::TypeName, sui::table::Table<u64, u64>>,
        last_earn: sui::table::Table<std::type_name::TypeName, sui::table::Table<ID, u64>>,
        rewards: sui::vec_set::VecSet<std::type_name::TypeName>,
        checkpoints: sui::table::Table<ID, sui::table::Table<u64, Checkpoint>>,
        num_checkpoints: sui::table::Table<ID, u64>,
        supply_checkpoints: sui::table::Table<u64, SupplyCheckpoint>,
        supply_num_checkpoints: u64,
        balances: sui::bag::Bag,
    }

    /// Returns the balance of a specific coin type in the reward contract.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// The amount of coins held by the reward contract
    public fun balance<CoinType>(reward: &Reward): u64 {
        reward.balances.borrow<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
            std::type_name::get<CoinType>()
        ).value<CoinType>()
    }

    /// Adds a new reward token type to the contract.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to be modified
    /// * `coinTypeName` - The type name of the coin to add as reward
    public(package) fun add_reward_token(reward: &mut Reward, coinTypeName: std::type_name::TypeName) {
        reward.rewards.insert<std::type_name::TypeName>(coinTypeName);
    }

    /// Returns the ID of the authorized entity for this reward contract.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// The ID of the authorized entity
    public fun authorized(reward: &Reward): ID {
        reward.authorized
    }

    /// Returns the balance of a specific lock in the reward system.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `lock_id` - The ID of the lock to check
    /// * `clock` - Clock object for timestamp to get the current balance
    ///
    /// # Returns
    /// The amount of tokens locked for the specified lock_id at the current time.
    public fun balance_of(reward: &Reward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        let current_time = distribution::common::current_timestamp(clock);

        reward.balance_of_at(lock_id, current_time)
    }

    /// Returns the balance of a specific lock in the reward system at a specific timestamp.
    /// Balance is stable inside epoch.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `lock_id` - The ID of the lock to check
    /// * `timestamp` - The timestamp to get the balance at
    /// 
    public fun balance_of_at(reward: &Reward, lock_id: ID, timestamp: u64): u64 {
        let num_checkpoints = if (reward.num_checkpoints.contains(lock_id)) {
            *reward.num_checkpoints.borrow(lock_id)
        } else {
            0
        };
        if (num_checkpoints == 0) {
            return 0
        };
        let prior_idx = reward.get_prior_balance_index(lock_id, timestamp);
        let lock_checkpoints = reward.checkpoints.borrow(lock_id);

        // If prior_idx is 0 and the checkpoint at 0 is for a time after current_time,
        // it means there are no checkpoints at or before current_time, so balance is 0.
        let first_checkpoint = lock_checkpoints.borrow(0);
        if (prior_idx == 0 && first_checkpoint.timestamp > timestamp) {
            return 0
        };

        // Otherwise, the checkpoint at prior_idx is the relevant one.
        lock_checkpoints.borrow(prior_idx).balance_of
    }

    /// Creates a new Reward object.
    /// 
    /// # Arguments
    /// * `voter` - The ID of the voter module
    /// * `ve` - The ID of the voting escrow module
    /// * `authorized` - The ID for authorization
    /// * `reward_coin_types` - A vector of coin types that can be used as rewards
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// A new Reward object with initialized data structures
    public(package) fun create(
        voter: ID,
        ve: Option<ID>,
        authorized: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        ctx: &mut TxContext
    ): Reward {
        let mut reward = Reward {
            id: object::new(ctx),
            voter,
            ve,
            authorized,
            token_rewards_per_epoch: sui::table::new<std::type_name::TypeName, sui::table::Table<u64, u64>>(ctx),
            last_earn: sui::table::new<std::type_name::TypeName, sui::table::Table<ID, u64>>(ctx),
            rewards: sui::vec_set::empty<std::type_name::TypeName>(),
            checkpoints: sui::table::new<ID, sui::table::Table<u64, Checkpoint>>(ctx),
            num_checkpoints: sui::table::new<ID, u64>(ctx),
            supply_checkpoints: sui::table::new<u64, SupplyCheckpoint>(ctx),
            supply_num_checkpoints: 0,
            balances: sui::bag::new(ctx),
        };
        let mut i = 0;
        while (i < reward_coin_types.length()) {
            reward.rewards.insert<std::type_name::TypeName>(
                *reward_coin_types.borrow(i)
            );
            i = i + 1;
        };
        reward
    }

    /// Increases the balance of a specific lock in the current epoch.
    /// Updates checkpoints and supply data, then emits a deposit event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to deposit into
    /// * `reward_authorized_cap` - Capability object for authorization
    /// * `amount` - The amount of tokens to deposit
    /// * `lock_id` - The ID of the lock to deposit for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public(package) fun deposit(
        reward: &mut Reward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.authorized);
        let current_time = distribution::common::current_timestamp(clock);

        // Update total supply
        let current_total_supply = reward.total_supply_at(current_time);
        let new_total_supply = current_total_supply + amount;

        // Update lock balance
        let lock_balance = reward.balance_of(lock_id, clock); // Use the updated balance_of
        let updated_lock_balance = lock_balance + amount;

        reward.write_checkpoint_internal(lock_id, updated_lock_balance, current_time, ctx);

        // reward.write_supply_checkpoint_internal will update reward.supply_num_checkpoints if needed
        reward.write_supply_checkpoint_internal(current_time, new_total_supply);

        let deposit_event = EventDeposit {
            sender: tx_context::sender(ctx),
            lock_id,
            amount,
        };
        sui::event::emit<EventDeposit>(deposit_event);
    }

    /// Function that can rebalance balances of multiple locks at once. Used in cases when 
    /// weights are calculated on the backend and then applied to the reward contract.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to update
    /// * `reward_authorized_cap` - Capability object for authorization
    /// * `balances` - Vector of balances to update
    /// * `lock_ids` - Vector of lock IDs to update
    /// * `for_timestamp` - The timestamp to update the balances at
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public(package) fun update_balances(
        reward: &mut Reward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        balances: vector<u64>,
        lock_ids: vector<ID>,
        for_timestamp: u64,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.authorized);
        let mut i = 0;
        let mut total_supply = reward.total_supply_at(for_timestamp);
        while (i < balances.length()) {
            let lock_id = lock_ids[i];
            let balance = balances[i];
            let old_balance = reward.balance_of_at(lock_id, for_timestamp);
            // change total supply by balance delta. Should never overflow cos old balance is always included in total supply
            total_supply = total_supply + balance - old_balance;

            reward.write_checkpoint_internal(lock_id, balance, for_timestamp, ctx);
            i = i + 1;
        };

        reward.write_supply_checkpoint_internal(for_timestamp, total_supply);
    }

    /// Calculates how much reward a lock has earned for a specific coin type.
    /// This complex function calculates earnings across epochs based on checkpoints and supply ratios.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `lock_id` - The ID of the lock to check earnings for
    /// * `clock` - Clock object for timestamp
    /// 
    /// # Returns
    /// The amount of coins earned as rewards
    public(package) fun earned<CoinType>(reward: &Reward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        let zero_checkpoints = if (!reward.num_checkpoints.contains(lock_id)) {
            true
        } else {
            let v1 = 0;
            reward.num_checkpoints.borrow(lock_id) == &v1
        };
        if (zero_checkpoints) {
            return 0
        };
        let coin_type_name = std::type_name::get<CoinType>();
        let mut earned_amount = 0;
        let last_earn_epoch_time = if (reward.last_earn.contains(coin_type_name) && reward.last_earn.borrow(
            coin_type_name
        ).contains(lock_id)) {
            distribution::common::epoch_start(
                *reward.last_earn.borrow(coin_type_name).borrow(lock_id)
            )
        } else {
            0
        };
        let prior_checkpoint = reward.checkpoints.borrow(lock_id).borrow(
            reward.get_prior_balance_index(lock_id, last_earn_epoch_time)
        );
        let latest_epoch_time = if (last_earn_epoch_time >= distribution::common::epoch_start(
            prior_checkpoint.timestamp
        )) {
            last_earn_epoch_time
        } else {
            distribution::common::epoch_start(prior_checkpoint.timestamp)
        };
        let mut next_epoch_time = latest_epoch_time;
        let epochs_until_now = (distribution::common::epoch_start(
            distribution::common::current_timestamp(clock)
        ) - latest_epoch_time) / distribution::common::week();
        if (epochs_until_now > 0) {
            let mut i = 0;
            while (i < epochs_until_now) {
                let next_checkpoint = reward.checkpoints.borrow(lock_id).borrow(
                    reward.get_prior_balance_index(lock_id, next_epoch_time + distribution::common::week() - 1)
                );
                let supply_index = reward.get_prior_supply_index(next_epoch_time + distribution::common::week() - 1);
                let supply = if (!reward.supply_checkpoints.contains(supply_index)) {
                    1
                } else {
                    let checkpoint_supply = reward.supply_checkpoints.borrow(supply_index).supply;
                    let mut checkpoint_supply_mut = checkpoint_supply;
                    if (checkpoint_supply == 0) {
                        checkpoint_supply_mut = 1;
                    };
                    checkpoint_supply_mut
                };
                if (!reward.token_rewards_per_epoch.contains(coin_type_name)) {
                    break
                };
                let rewards_per_epoch = reward.token_rewards_per_epoch.borrow(coin_type_name);
                let reward_in_epoch = if (rewards_per_epoch.contains(next_epoch_time)) {
                    *rewards_per_epoch.borrow(next_epoch_time)
                } else {
                    0
                };
                earned_amount = earned_amount + integer_mate::full_math_u64::mul_div_floor(
                    next_checkpoint.balance_of,
                    reward_in_epoch,
                    supply
                );
                next_epoch_time = next_epoch_time + distribution::common::week();
                i = i + 1;
            };
        };
        earned_amount
    }

    /// Returns the index of the latest checkpoint that has timestamp lower or equal to the specified time.
    /// Uses binary search to efficiently find the appropriate checkpoint.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `lock_id` - The ID of the lock to check checkpoints for
    /// * `time` - The timestamp to find the prior checkpoint for
    /// 
    /// # Returns
    /// The index of the checkpoint
    public fun get_prior_balance_index(reward: &Reward, lock_id: ID, time: u64): u64 {
        let num_checkpoints = if (reward.num_checkpoints.contains(lock_id)) {
            *reward.num_checkpoints.borrow(lock_id)
        } else {
            0
        };
        if (num_checkpoints == 0) {
            return 0
        };
        if (reward.checkpoints.borrow(lock_id).borrow(num_checkpoints - 1).timestamp <= time) {
            return num_checkpoints - 1
        };
        if (reward.checkpoints.borrow(lock_id).borrow(0).timestamp > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = reward.checkpoints.borrow(lock_id).borrow(middle);
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

    /// Returns the index of the latest supply checkpoint that has timestamp lower or equal to the specified time.
    /// Uses binary search to efficiently find the appropriate supply checkpoint.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `time` - The timestamp to find the prior checkpoint for
    /// 
    /// # Returns
    /// The index of the supply checkpoint
    public fun get_prior_supply_index(reward: &Reward, time: u64): u64 {
        let num_checkpoints = reward.supply_num_checkpoints;
        if (num_checkpoints == 0) {
            return 0
        };
        if (reward.supply_checkpoints.borrow(num_checkpoints - 1).timestamp <= time) {
            return num_checkpoints - 1
        };
        if (reward.supply_checkpoints.borrow(0).timestamp > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = reward.supply_checkpoints.borrow(middle);
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

    /// Claims earned rewards for a specific lock and coin type.
    /// Updates the last earn timestamp for the lock and emits a claim event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `recipient` - The address that will receive the rewards
    /// * `lock_id` - The ID of the lock to claim rewards for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// An optional balance of the claimed rewards, None if no rewards to claim
    public(package) fun get_reward_internal<CoinType>(
        reward: &mut Reward,
        recipient: address,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): Option<sui::balance::Balance<CoinType>> {
        let reward_amount = reward.earned<CoinType>(lock_id, clock);
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.last_earn.contains(coin_type_name)) {
            reward.last_earn.add(coin_type_name, sui::table::new<ID, u64>(ctx));
        };
        let last_earned_times = reward.last_earn.borrow_mut(coin_type_name);
        if (last_earned_times.contains(lock_id)) {
            last_earned_times.remove(lock_id);
        };
        last_earned_times.add(lock_id, distribution::common::current_timestamp(clock));
        let claim_rewards_event = EventClaimRewards {
            recipient,
            token_name: coin_type_name,
            reward_amount,
        };
        sui::event::emit<EventClaimRewards>(claim_rewards_event);
        if (reward_amount > 0) {
            return option::some<sui::balance::Balance<CoinType>>(
                reward.balances.borrow_mut<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
                    coin_type_name
                ).split<CoinType>(reward_amount)
            )
        };
        option::none<sui::balance::Balance<CoinType>>()
    }

    /// Adds reward tokens for distribution in the current epoch.
    /// Tracks rewards per epoch and emits a notification event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to add tokens to
    /// * `balance` - The balance of tokens to add as rewards
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    public(package) fun notify_reward_amount_internal<CoinType>(
        reward: &mut Reward,
        balance: sui::balance::Balance<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let reward_amount = balance.value<CoinType>();
        let reward_type_name = std::type_name::get<CoinType>();
        let epoch_start = distribution::common::epoch_start(distribution::common::current_timestamp(clock));
        if (!reward.token_rewards_per_epoch.contains(reward_type_name)) {
            reward.token_rewards_per_epoch.add(reward_type_name, sui::table::new<u64, u64>(ctx));
        };
        let rewards_per_epoch = reward.token_rewards_per_epoch.borrow_mut(reward_type_name);
        let rewards_in_current_epoch = if (rewards_per_epoch.contains(epoch_start)) {
            rewards_per_epoch.remove(epoch_start)
        } else {
            0
        };
        rewards_per_epoch.add(epoch_start, rewards_in_current_epoch + reward_amount);
        if (!reward.balances.contains(reward_type_name)) {
            reward.balances.add(reward_type_name, balance);
        } else {
            reward.balances.borrow_mut<std::type_name::TypeName, sui::balance::Balance<CoinType>>(
                reward_type_name
            ).join<CoinType>(balance);
        };
        let notify_reward_event = EventNotifyReward {
            sender: tx_context::sender(ctx),
            token_name: reward_type_name,
            epoch_start,
            amount: reward_amount,
        };
        sui::event::emit<EventNotifyReward>(notify_reward_event);
    }

    /// Checks if a specific coin type is supported as a reward.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `arg1` - The type name to check
    /// 
    /// # Returns
    /// Boolean indicating if the type is supported as a reward
    public fun rewards_contains(reward: &Reward, arg1: std::type_name::TypeName): bool {
        reward.rewards.contains<std::type_name::TypeName>(&arg1)
    }

    /// Returns a vector of all supported reward token types.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// Vector of type names representing all supported rewards
    public fun rewards_list(reward: &Reward): vector<std::type_name::TypeName> {
        reward.rewards.into_keys<std::type_name::TypeName>()
    }

    /// Returns the number of supported reward token types.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// The count of supported reward token types
    public(package) fun rewards_list_length(reward: &Reward): u64 {
        reward.rewards.size<std::type_name::TypeName>()
    }

    /// Gets the rewards per epoch table for a specific coin type.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// Reference to the table mapping epochs to reward amounts
    /// 
    /// # Aborts
    /// * If the coin type is not supported as a reward
    public fun rewards_per_epoch<CoinType>(reward: &Reward): &sui::table::Table<u64, u64> {
        let coin_type_name = std::type_name::get<CoinType>();
        assert!(
            reward.token_rewards_per_epoch.contains(coin_type_name),
            9223372492121309183
        );
        reward.token_rewards_per_epoch.borrow(coin_type_name)
    }

    /// Gets the total rewards available for the current epoch for a specific coin type.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `clock` - Clock object for timestamp
    /// 
    /// # Returns
    /// The amount of rewards for the current epoch
    public fun rewards_this_epoch<CoinType>(reward: &Reward, clock: &sui::clock::Clock): u64 {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.token_rewards_per_epoch.contains(coin_type_name)) {
            return 0
        };
        let epoch_start_time = distribution::common::epoch_start(distribution::common::current_timestamp(clock));
        let rewards_per_epoch = reward.token_rewards_per_epoch.borrow(coin_type_name);
        if (!rewards_per_epoch.contains(epoch_start_time)) {
            return 0
        };
        *rewards_per_epoch.borrow(epoch_start_time)
    }

    /// Returns the total supply of tokens in the reward system based on the latest checkpoint relative to the clock.
    ///
    /// # Arguments
    /// * `reward` - The reward object
    /// * `clock` - Clock object for timestamp
    ///
    /// # Returns
    /// The total supply value from the relevant checkpoint, or 0 if no history.
    public fun total_supply(reward: &Reward, clock: &sui::clock::Clock): u64 {
        let current_time = distribution::common::current_timestamp(clock);
        reward.total_supply_at(current_time)
    }

    /// Returns the total supply recorded at or before a specific timestamp.
    /// It refers to the supply checkpoints to find the appropriate historical value.
    ///
    /// # Arguments
    /// * `reward` - The reward object.
    /// * `time` - The timestamp for which to find the supply.
    ///
    /// # Returns
    /// The supply value from the relevant checkpoint, or 0 if no applicable history.
    public fun total_supply_at(reward: &Reward, time: u64): u64 {
        let num_checkpoints = reward.supply_num_checkpoints;
        if (num_checkpoints == 0) {
            return 0
        };
        let supply_idx = reward.get_prior_supply_index(time);
        // It's assumed get_prior_supply_index returns a valid index if num_checkpoints > 0.
        // The checkpoint at supply_idx is the one whose timestamp is <= time,
        // or it's index 0 if time is before the first checkpoint.
        let checkpoint = reward.supply_checkpoints.borrow(supply_idx);

        // If get_prior_supply_index returned 0 because time is before the very first checkpoint's timestamp,
        // the effective supply before that first recorded history point is 0.
        if (supply_idx == 0 && checkpoint.timestamp > time) {
            return 0
        };
        // Otherwise, the checkpoint at supply_idx is the correct one to use.
        checkpoint.supply
    }

    /// Returns the ID of the voting escrow module for this reward.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// The ID of the ve (voting escrow) module
    public fun ve(reward: &Reward): ID {
        *reward.ve.borrow()
    }

    /// Returns the ID of the voter module for this reward.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// 
    /// # Returns
    /// The ID of the voter module
    public fun voter(reward: &Reward): ID {
        reward.voter
    }

    /// Decreases the balance of a specific lock in the current epoch.
    /// Updates checkpoints and supply data, then emits a withdraw event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to withdraw from
    /// * `reward_authorized_cap` - Capability object for authorization
    /// * `amount` - The amount of tokens to withdraw
    /// * `lock_id` - The ID of the lock to withdraw from
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public(package) fun withdraw(
        reward: &mut Reward,
        reward_authorized_cap: &distribution::reward_authorized_cap::RewardAuthorizedCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_authorized_cap.validate(reward.authorized);
        let current_time = distribution::common::current_timestamp(clock);

        // Update total supply
        let current_total_supply = reward.total_supply_at(current_time);
        
        let new_total_supply = current_total_supply - amount;

        // Update lock balance
        let lock_balance = reward.balance_of(lock_id, clock);
        let updated_lock_balance = lock_balance - amount;

        reward.write_checkpoint_internal(lock_id, updated_lock_balance, current_time, ctx);
        reward.write_supply_checkpoint_internal(current_time, new_total_supply);

        let withdraw_event = EventWithdraw {
            sender: tx_context::sender(ctx),
            lock_id,
            amount,
        };
        sui::event::emit<EventWithdraw>(withdraw_event);
    }

    /// Updates or creates a checkpoint for a lock's balance.
    /// If a checkpoint already exists for the same epoch, it updates it; otherwise creates a new one.
    /// Checkpoints are always written with time equal to epoch start.
    /// Thats because balance changes during epoch doesn't matter.
    /// And this way it is easier to update balances in update_balances.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `lock_id` - The ID of the lock to checkpoint
    /// * `balance` - The current balance to record
    /// * `time` - The timestamp for the checkpoint
    /// * `ctx` - Transaction context
    fun write_checkpoint_internal(
        reward: &mut Reward,
        lock_id: ID,
        balance: u64,
        time: u64,
        ctx: &mut TxContext
    ) {
        let num_of_checkpoints = if (reward.num_checkpoints.contains(lock_id)) {
            *reward.num_checkpoints.borrow(lock_id)
        } else {
            0
        };
        let epoch_start = distribution::common::epoch_start(time);
        // latest checkpoint timestam is equal to current epoch start
        if (
            num_of_checkpoints > 0 && 
            reward.checkpoints.borrow(lock_id).borrow(num_of_checkpoints - 1).timestamp == epoch_start 
        ) {
            let checkpoint = reward.checkpoints.borrow_mut(lock_id);
            if (checkpoint.contains(num_of_checkpoints - 1)) {
                checkpoint.remove(num_of_checkpoints - 1);
            };
            let updated_checkpoint = Checkpoint {
                timestamp: epoch_start,
                balance_of: balance,
            };
            checkpoint.add(num_of_checkpoints - 1, updated_checkpoint);
        } else {
            if (!reward.checkpoints.contains(lock_id)) {
                reward.checkpoints.add(lock_id, sui::table::new<u64, Checkpoint>(ctx));
            };
            let prior_idx = reward.get_prior_balance_index(lock_id, epoch_start);
            let lock_checkpoints = reward.checkpoints.borrow_mut(lock_id);
            if (lock_checkpoints.contains(prior_idx) && lock_checkpoints.borrow(prior_idx).timestamp == epoch_start) {
                lock_checkpoints.remove(prior_idx);
                let updated_checkpoint = Checkpoint {
                    timestamp: epoch_start,
                    balance_of: balance,
                };
                lock_checkpoints.add(prior_idx, updated_checkpoint);
            } else {
                let new_checkpoint = Checkpoint {
                    timestamp: epoch_start,
                    balance_of: balance,
                };
                if (num_of_checkpoints == 0) {
                    lock_checkpoints.add(num_of_checkpoints, new_checkpoint);
                } else {
                    let mut idx_to_move = prior_idx + 1;
                    while (idx_to_move < num_of_checkpoints) {
                        let checkpoint = lock_checkpoints.remove(idx_to_move);
                        lock_checkpoints.add(idx_to_move + 1, checkpoint);
                        idx_to_move = idx_to_move + 1;
                    };
                    lock_checkpoints.add(prior_idx + 1, new_checkpoint);
                };
                if (reward.num_checkpoints.contains(lock_id)) {
                    reward.num_checkpoints.remove(lock_id);
                };
                reward.num_checkpoints.add(lock_id, num_of_checkpoints + 1);
            };
        };
    }

    /// Updates or creates a checkpoint for the total supply.
    /// If a checkpoint already exists for the same epoch, it updates it; otherwise creates a new one.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `current_time` - The timestamp for the checkpoint
    fun write_supply_checkpoint_internal(reward: &mut Reward, time: u64, total_supply: u64) {
        let num_of_checkpoints = reward.supply_num_checkpoints;
        let epoch_start = distribution::common::epoch_start(time);
        // latest checkpoint timestam is equal to current epoch start
        if (
            num_of_checkpoints > 0 
            && reward.supply_checkpoints.borrow(num_of_checkpoints - 1).timestamp == epoch_start
        ) {
            if (reward.supply_checkpoints.contains(num_of_checkpoints - 1)) {
                reward.supply_checkpoints.remove(num_of_checkpoints - 1);
            };
            let updated_checkpoint = SupplyCheckpoint {
                timestamp: epoch_start,
                supply: total_supply,
            };
            reward.supply_checkpoints.add(num_of_checkpoints - 1, updated_checkpoint);
        } else {
            if (reward.supply_checkpoints.contains(num_of_checkpoints)) {
                reward.supply_checkpoints.remove(num_of_checkpoints);
            };
            let prior_idx = reward.get_prior_supply_index(epoch_start);
            if (reward.supply_checkpoints.contains(prior_idx) && reward.supply_checkpoints.borrow(prior_idx).timestamp == epoch_start) {
                reward.supply_checkpoints.remove(prior_idx);
                let updated_checkpoint = SupplyCheckpoint {
                    timestamp: epoch_start,
                    supply: total_supply,
                };
                reward.supply_checkpoints.add(prior_idx, updated_checkpoint);
            } else {
                let new_checkpoint = SupplyCheckpoint {
                    timestamp: epoch_start,
                    supply: total_supply,
                };
                if (num_of_checkpoints == 0) {
                    reward.supply_checkpoints.add(num_of_checkpoints, new_checkpoint);
                } else {
                    let mut idx_to_move = prior_idx + 1;
                    while (idx_to_move < num_of_checkpoints) {
                        let checkpoint = reward.supply_checkpoints.remove(idx_to_move);
                        reward.supply_checkpoints.add(idx_to_move + 1, checkpoint);
                        idx_to_move = idx_to_move + 1;
                    };
                    reward.supply_checkpoints.add(prior_idx + 1, new_checkpoint);
                };
                reward.supply_num_checkpoints = num_of_checkpoints + 1;
            }
        };
    }

    #[test_only]
    public fun total_length(reward: &Reward): u64 {
        reward.token_rewards_per_epoch.length() +
        reward.rewards.size() +
        reward.last_earn.length() +
        reward.checkpoints.length() +
        reward.num_checkpoints.length() +
        reward.supply_checkpoints.length() +
        reward.supply_num_checkpoints +
        reward.balances.length()
    }
}


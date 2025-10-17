/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
module voting_escrow::reward {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const EUpdateBalancesDisabled: u64 = 931921756019291001;
    const EUpdateBalancesEpochStartInvalid: u64 = 97211664930268266;
    const EUpdateBalancesInvalidLocksLength: u64 = 951147350837936100;
    const EUpdateBalancesAlreadyFinal: u64 = 931921756019291000;
    const EUpdateBalancesOnlyFinishedEpochAllowed: u64 = 987934305039328400;

    const EUpdateSupplyStartInvalid: u64 = 705782693965862900;
    const EUpdateSupplyAlreadyFinal: u64 = 904903521124960500;
    const EUpdateSupplyOnlyFinishedEpochAllowed: u64 = 313936473495920450;

    const EResetFinalNotFinal: u64 = 86720681210724470;
    const EResetFinalUpdateDisabled: u64 = 87295163281596280;
    const EResetFinalEpochStartInvalid: u64 = 57465357444921274;

    const ERewardPerEpochInvalidToken: u64 = 9223372492121309183;


    public struct EventDeposit has copy, drop, store {
        wrapper_reward_id: ID,
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventWithdraw has copy, drop, store {
        wrapper_reward_id: ID,
        sender: address,
        lock_id: ID,
        amount: u64,
    }

    public struct EventClaimRewards has copy, drop, store {
        wrapper_reward_id: ID,
        recipient: address,
        token_name: std::type_name::TypeName,
        reward_amount: u64,
        lock_id: ID,
    }

    public struct EventNotifyReward has copy, drop, store {
        wrapper_reward_id: ID,
        sender: address,
        token_name: std::type_name::TypeName,
        epoch_start: u64,
        amount: u64,
    }


    public struct EventEpochFinalized has copy, drop, store {
        // FeeVotingReward, or FreeManagedReward id. Supposed to be used to track for which exactly reward this event is.
        wrapper_reward_id: ID,
        // Reward id. Usually this reward is unaccessible cos it is wrapped in other object.
        internal_reward_id: ID,
        epoch_start: u64,
    }

    public struct EventUpdateSupply has copy, drop, store {
        wrapper_reward_id: ID,
        internal_reward_id: ID,
        epoch_start: u64,
        total_supply: u64,
    }

    public struct EventEpochResetFinal has copy, drop, store {
        // FeeVotingReward, or FreeManagedReward id. Supposed to be used to track for which exactly reward this event is.
        wrapper_reward_id: ID,
        // Reward id. Usually this reward is unaccessible cos it is wrapped in other object.
        internal_reward_id: ID,
        epoch_start: u64,
    }

    public struct EventUpdateBalances has copy, drop, store {
        // FeeVotingReward, or FreeManagedReward id. Supposed to be used to track for which exactly reward this event is.
        wrapper_reward_id: ID,
        // Reward id. Usually this reward is unaccessible cos it is wrapped in other object.
        internal_reward_id: ID,
        epoch_start: u64,
        balances: vector<u64>,
        lock_ids: vector<ID>,
    }

    public struct Checkpoint has drop, store {
        epoch_start: u64,
        balance_of: u64,
    }

    public struct SupplyCheckpoint has drop, store {
        epoch_start: u64,
        supply: u64,
    }

    public struct Reward has store, key {
        id: UID,
        // FeeVotingReward or FreeManagedReward id
        wrapper_reward_id: ID,
        token_rewards_per_epoch: sui::table::Table<std::type_name::TypeName, sui::table::Table<u64, u64>>,
        last_earn: sui::table::Table<std::type_name::TypeName, sui::table::Table<ID, u64>>,
        rewards: sui::vec_set::VecSet<std::type_name::TypeName>,
        checkpoints: sui::table::Table<ID, sui::table::Table<u64, Checkpoint>>,
        num_checkpoints: sui::table::Table<ID, u64>,
        supply_checkpoints: sui::table::Table<u64, SupplyCheckpoint>,
        supply_num_checkpoints: u64,
        balances: sui::bag::Bag,
        /// if true then users need to wait until balance update for epoch is done to claim rewards.
        balance_update_enabled: bool,
        /// true if balance update for epoch is done.
        epoch_updates_finalized: sui::table::Table<u64, bool>,
        // bag to be preapred for future updates
        bag: sui::bag::Bag,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
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
    /// * `reward_cap` - Capability object for authorization
    /// * `coinTypeName` - The type name of the coin to add as reward
    public fun add_reward_token(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        coinTypeName: std::type_name::TypeName
    ) {
        reward_cap.validate(object::id(reward));
        reward.rewards.insert<std::type_name::TypeName>(coinTypeName);
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
        let current_time = voting_escrow::common::current_timestamp(clock);

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
        if (prior_idx == 0 && first_checkpoint.epoch_start > timestamp) {
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
    /// * `reward_coin_types` - A vector of coin types that can be used as rewards
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// A new Reward object with initialized data structures
    public fun create(
        wrapper_reward_id: ID,
        reward_coin_types: vector<std::type_name::TypeName>,
        balance_update_enabled: bool,
        ctx: &mut TxContext
    ): (Reward, voting_escrow::reward_cap::RewardCap) {
        let id = object::new(ctx);
        let id_inner = id.uid_to_inner();
        let mut reward = Reward {
            id,
            wrapper_reward_id,
            token_rewards_per_epoch: sui::table::new<std::type_name::TypeName, sui::table::Table<u64, u64>>(ctx),
            last_earn: sui::table::new<std::type_name::TypeName, sui::table::Table<ID, u64>>(ctx),
            rewards: sui::vec_set::empty<std::type_name::TypeName>(),
            checkpoints: sui::table::new<ID, sui::table::Table<u64, Checkpoint>>(ctx),
            num_checkpoints: sui::table::new<ID, u64>(ctx),
            supply_checkpoints: sui::table::new<u64, SupplyCheckpoint>(ctx),
            supply_num_checkpoints: 0,
            balances: sui::bag::new(ctx),
            balance_update_enabled,
            epoch_updates_finalized: sui::table::new<u64, bool>(ctx),
            // bag to be preapred for future updates
            bag: sui::bag::new(ctx),
        };
        let mut i = 0;
        while (i < reward_coin_types.length()) {
            reward.rewards.insert<std::type_name::TypeName>(
                *reward_coin_types.borrow(i)
            );
            i = i + 1;
        };
        let reward_cap = voting_escrow::reward_cap::create(id_inner, ctx);
        (reward, reward_cap)
    }

    /// Increases the balance of a specific lock in the current epoch.
    /// Updates checkpoints and supply data, then emits a deposit event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to deposit into
    /// * `reward_cap` - Capability object for authorization
    /// * `amount` - The amount of tokens to deposit
    /// * `lock_id` - The ID of the lock to deposit for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public fun deposit(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        let current_time = voting_escrow::common::current_timestamp(clock);

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
            wrapper_reward_id: reward.wrapper_reward_id,
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
    /// * `reward_cap` - Capability object for authorization
    /// * `balances` - Vector of balances to update
    /// * `lock_ids` - Vector of lock IDs to update
    /// * `for_epoch_start` - The epoch start to update the balances at. Balances are invariant inside epoch.
    /// * `final` - true if thats the last update for the epoch
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    /// * If the lock was not deposited in the epoch start
    /// * If the epoch start is not a multiple of the epoch
    /// * If the epoch is already finalized
    public fun update_balances(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        balances: vector<u64>,
        lock_ids: vector<ID>,
        for_epoch_start: u64,
        final: bool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        assert!(reward.balance_update_enabled, EUpdateBalancesDisabled);
        assert!(for_epoch_start % voting_escrow::common::epoch() == 0, EUpdateBalancesEpochStartInvalid);
        assert!(lock_ids.length() == balances.length(), EUpdateBalancesInvalidLocksLength);
        assert!(
            !reward.epoch_updates_finalized.contains(for_epoch_start) || 
            !(*reward.epoch_updates_finalized.borrow(for_epoch_start)), 
            EUpdateBalancesAlreadyFinal
        );
        let current_time = voting_escrow::common::current_timestamp(clock);
        let current_epoch_start = voting_escrow::common::epoch_start(current_time);
        // balance update is only allowed for finished epochs
        assert!(for_epoch_start < current_epoch_start, EUpdateBalancesOnlyFinishedEpochAllowed);

        // If we are updating past lock checkpoints, we need to update supply for the next epochs.
        // But only if supply checkpoint for the next epoch exists
        // and there is no next lock checkpoints before or at next supply checkpoint 

        // the list, containing current supply checkpoint (even if there is no current checkpoint)
        // and supply chekcpoints after the current one.
        let mut supply_list = vector::empty<SupplyCheckpoint>();

        // first of all we retrieve current checkpoint and add it to the list
        let supply_num_checkpoints = reward.supply_num_checkpoints;
        if (supply_num_checkpoints == 0) {
            // no checkpoints at all, we create a new one
            supply_list.push_back(SupplyCheckpoint {
                epoch_start: for_epoch_start,
                supply: 0,
            });
        } else {
            // there are checkpoints, so we find the last checkpoint before the current epoch or at the current epoch
            let supply_idx = reward.get_prior_supply_index(for_epoch_start);
            let supply_checkpoint = reward.supply_checkpoints.borrow(supply_idx);
            let mut next_supply_idx;
            if (supply_idx == 0 && supply_checkpoint.epoch_start > for_epoch_start) {
                supply_list.push_back(SupplyCheckpoint {
                    epoch_start: for_epoch_start,
                    supply: 0,
                });
                next_supply_idx = supply_idx;
            } else {
                supply_list.push_back(SupplyCheckpoint {
                    epoch_start: for_epoch_start,
                    supply: supply_checkpoint.supply,
                });
                next_supply_idx = supply_idx + 1;
            };

            while (next_supply_idx < supply_num_checkpoints) {
                let next_supply_checkpoint = reward.supply_checkpoints.borrow(next_supply_idx);
                supply_list.push_back(SupplyCheckpoint {
                    epoch_start: next_supply_checkpoint.epoch_start,
                    supply: next_supply_checkpoint.supply,
                });
                next_supply_idx = next_supply_idx + 1;
            }
        };
        let mut i = 0;
        while (i < balances.length()) {
            let lock_id = lock_ids[i];
            let balance = balances[i];
            let mut old_balance: u64;
            // zero means that there are no next checkpoints
            let mut next_lock_checkpoint_time: u64 = 0;
            let num_checkpoints = if (reward.num_checkpoints.contains(lock_id)) {
                *reward.num_checkpoints.borrow(lock_id)
            } else {
                0
            };
            if (num_checkpoints == 0) {
                old_balance = 0;
                // no next lock checkpoints
            } else {
                let prior_idx = reward.get_prior_balance_index(lock_id, for_epoch_start);
                let lock_checkpoints = reward.checkpoints.borrow(lock_id);

                // If prior_idx is 0 and the checkpoint at 0 is for a time after current_time,
                // it means there are no checkpoints at or before current_time, so balance is 0.
                let first_checkpoint = lock_checkpoints.borrow(0);
                if (prior_idx == 0 && first_checkpoint.epoch_start > for_epoch_start) {
                    old_balance = 0;
                    next_lock_checkpoint_time = first_checkpoint.epoch_start;
                } else {
                    // Otherwise, the checkpoint at prior_idx is the relevant one.
                    let prior_checkpoint = lock_checkpoints.borrow(prior_idx);
                    old_balance = prior_checkpoint.balance_of;
                    if (prior_idx < num_checkpoints - 1) {
                        // if there is a next checkpoint, we save it
                        next_lock_checkpoint_time = lock_checkpoints.borrow(prior_idx + 1).epoch_start;
                    }
                }
            };
            let mut j = 0;
            while (j < supply_list.length()) {
                let supply_checkpoint_j = supply_list.borrow_mut(j);
                if (next_lock_checkpoint_time != 0 && supply_checkpoint_j.epoch_start >= next_lock_checkpoint_time) {
                    break
                };
                // change total supply by balance delta. Should never overflow cos old balance is always included in total supply
                supply_checkpoint_j.supply = supply_checkpoint_j.supply + balance - old_balance;
                j = j + 1;
            };

            reward.write_checkpoint_internal(lock_id, balance, for_epoch_start, ctx);
            i = i + 1;
        };

        i = 0;
        while (i < supply_list.length()) {
            reward.write_supply_checkpoint_internal(supply_list[i].epoch_start, supply_list[i].supply);
            i = i + 1;
        };
        let internal_reward_id = object::id(reward);
        let event = EventUpdateBalances {
            wrapper_reward_id: reward.wrapper_reward_id,
            internal_reward_id,
            epoch_start: for_epoch_start,
            balances,
            lock_ids,
        };
        sui::event::emit<EventUpdateBalances>(event);
        if (final) {
            reward.epoch_updates_finalized.add(for_epoch_start, true);
            let event = EventEpochFinalized {
                wrapper_reward_id: reward.wrapper_reward_id,
                internal_reward_id,
                epoch_start: for_epoch_start,
            };
            sui::event::emit<EventEpochFinalized>(event);
        };
    }

    /// Updates the total supply for the epoch.
    /// It is important for total supply to be sum of the weights of the locks 
    /// previously pushed by update_balances method
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `reward_cap` - Capability object for authorization
    /// * `for_epoch_start` - The epoch start to update the total supply at
    /// * `total_supply` - The total supply for the epoch
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    public fun update_supply(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        for_epoch_start: u64,
        total_supply: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        assert!(reward.balance_update_enabled, EUpdateBalancesDisabled);
        assert!(for_epoch_start % voting_escrow::common::epoch() == 0, EUpdateSupplyStartInvalid);
        assert!(
            !reward.epoch_updates_finalized.contains(for_epoch_start) || 
            !(*reward.epoch_updates_finalized.borrow(for_epoch_start)), 
            EUpdateSupplyAlreadyFinal
        );
        let current_time = voting_escrow::common::current_timestamp(clock);
        let current_epoch_start = voting_escrow::common::epoch_start(current_time);
        // balance update is only allowed for finished epochs
        assert!(for_epoch_start < current_epoch_start, EUpdateSupplyOnlyFinishedEpochAllowed);

        reward.write_supply_checkpoint_internal(for_epoch_start, total_supply);
        
        let internal_reward_id = object::id(reward);
        let event = EventUpdateSupply {
            wrapper_reward_id: reward.wrapper_reward_id,
            internal_reward_id,
            epoch_start: for_epoch_start,
            total_supply,
        };
        sui::event::emit<EventUpdateSupply>(event);
    }

    /// Resets the final status of an epoch. Supposed to be used when we need to recover the state after problematic balance update.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to reset the final status for
    /// * `reward_cap` - Capability object for authorization
    /// * `for_epoch_start` - The epoch start to reset the final status for
    /// * `ctx` - Transaction context
    public fun reset_final(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        for_epoch_start: u64,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        assert!(for_epoch_start % voting_escrow::common::epoch() == 0, EResetFinalEpochStartInvalid);
        assert!(reward.epoch_updates_finalized.contains(for_epoch_start), EResetFinalNotFinal);
        assert!(reward.balance_update_enabled, EResetFinalUpdateDisabled);

        reward.epoch_updates_finalized.remove(for_epoch_start);

        let event = EventEpochResetFinal {
            wrapper_reward_id: reward.wrapper_reward_id,
            internal_reward_id: object::id(reward),
            epoch_start: for_epoch_start,
        };
        sui::event::emit<EventEpochResetFinal>(event);
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
    /// The amount of coins earned as rewards, first epoch that has not been earned yet.
    fun earned_internal<CoinType>(reward: &Reward, lock_id: ID, clock: &sui::clock::Clock, ignore_epoch_final: bool): (u64, u64) {
        let zero_checkpoints = if (!reward.num_checkpoints.contains(lock_id)) {
            true
        } else {
            *reward.num_checkpoints.borrow(lock_id) == 0
        };
        if (zero_checkpoints) {
            return (0, 0)
        };
        let coin_type_name = std::type_name::get<CoinType>();
        let mut earned_amount = 0;
        let last_earn_epoch_time = if (reward.last_earn.contains(coin_type_name) && reward.last_earn.borrow(
            coin_type_name
        ).contains(lock_id)) {
            voting_escrow::common::epoch_start(
                *reward.last_earn.borrow(coin_type_name).borrow(lock_id)
            )
        } else {
            0
        };
        let prior_checkpoint = reward.checkpoints.borrow(lock_id).borrow(
            reward.get_prior_balance_index(lock_id, last_earn_epoch_time)
        );
        let latest_epoch_time = if (last_earn_epoch_time >= prior_checkpoint.epoch_start) {
            last_earn_epoch_time
        } else {
            prior_checkpoint.epoch_start
        };
        let mut next_epoch_time = latest_epoch_time;
        let epochs_until_now = (voting_escrow::common::epoch_start(
            voting_escrow::common::current_timestamp(clock)
        ) - latest_epoch_time) / voting_escrow::common::epoch();
        if (epochs_until_now > 0) {
            let mut i = 0;
            // limit the number of iterations to prevent denial of service.
            // sui move test --gas-limit 50000000 (i.e. 0.05 SUI) successfully runs this
            // claim function even with 1000 epochs (i.e 1000 iterations).
            // So 100 iterations seems to be a safe limit.
            let max_num_iterations = 100;
            while (i < epochs_until_now && i < max_num_iterations) {
                // stop when we encounter epoch that is not final and reward is configured to wait for balance update.
                if (
                    reward.balance_update_enabled && !ignore_epoch_final && (
                        !reward.epoch_updates_finalized.contains(next_epoch_time) || 
                        !(*reward.epoch_updates_finalized.borrow(next_epoch_time))
                    )
                ) {
                    break
                };
                let next_checkpoint = reward.checkpoints.borrow(lock_id).borrow(
                    reward.get_prior_balance_index(lock_id, next_epoch_time + voting_escrow::common::epoch() - 1)
                );
                let supply_index = reward.get_prior_supply_index(next_epoch_time + voting_escrow::common::epoch() - 1);
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
                next_epoch_time = next_epoch_time + voting_escrow::common::epoch();
                i = i + 1;
            };
        };
        (earned_amount, next_epoch_time)
    }

    public fun earned<CoinType>(reward: &Reward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        let (earned_amount, _) = reward.earned_internal<CoinType>(lock_id, clock, false);

        earned_amount
    }

    public fun earned_ignore_epoch_final<CoinType>(reward: &Reward, lock_id: ID, clock: &sui::clock::Clock): u64 {
        let (earned_amount, _) = reward.earned_internal<CoinType>(lock_id, clock, true);

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
        if (reward.checkpoints.borrow(lock_id).borrow(num_checkpoints - 1).epoch_start <= time) {
            return num_checkpoints - 1
        };
        if (reward.checkpoints.borrow(lock_id).borrow(0).epoch_start > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = reward.checkpoints.borrow(lock_id).borrow(middle);
            if (middle_checkpoint.epoch_start == time) {
                return middle
            };
            if (middle_checkpoint.epoch_start < time) {
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
        if (reward.supply_checkpoints.borrow(num_checkpoints - 1).epoch_start <= time) {
            return num_checkpoints - 1
        };
        if (reward.supply_checkpoints.borrow(0).epoch_start > time) {
            return 0
        };
        let mut lower_bound = 0;
        let mut upper_bound = num_checkpoints - 1;
        while (upper_bound > lower_bound) {
            let middle = upper_bound - (upper_bound - lower_bound) / 2;
            let middle_checkpoint = reward.supply_checkpoints.borrow(middle);
            if (middle_checkpoint.epoch_start == time) {
                return middle
            };
            if (middle_checkpoint.epoch_start < time) {
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
    /// * `reward_cap` - Capability object for authorization
    /// * `recipient` - The address that will receive the rewards
    /// * `lock_id` - The ID of the lock to claim rewards for
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// An optional balance of the claimed rewards, None if no rewards to claim
    public fun get_reward_internal<CoinType>(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        recipient: address,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ): Option<sui::balance::Balance<CoinType>> {
        reward_cap.validate(object::id(reward));
        let (reward_amount, first_non_earned_epoch) = reward.earned_internal<CoinType>(lock_id, clock, false);
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.last_earn.contains(coin_type_name)) {
            reward.last_earn.add(coin_type_name, sui::table::new<ID, u64>(ctx));
        };
        let last_earned_times = reward.last_earn.borrow_mut(coin_type_name);
        if (last_earned_times.contains(lock_id)) {
            last_earned_times.remove(lock_id);
        };
        last_earned_times.add(lock_id, first_non_earned_epoch);
        let claim_rewards_event = EventClaimRewards {
            wrapper_reward_id: reward.wrapper_reward_id,
            recipient,
            token_name: coin_type_name,
            reward_amount,
            lock_id,
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
    /// * `reward_cap` - Capability object for authorization
    /// * `balance` - The balance of tokens to add as rewards
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    public fun notify_reward_amount_internal<CoinType>(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        balance: sui::balance::Balance<CoinType>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        let reward_amount = balance.value<CoinType>();
        let reward_type_name = std::type_name::get<CoinType>();
        let epoch_start = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(clock));
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
            wrapper_reward_id: reward.wrapper_reward_id,
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
    public fun rewards_list_length(reward: &Reward): u64 {
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
            ERewardPerEpochInvalidToken,
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
        let epoch_start_time = voting_escrow::common::epoch_start(voting_escrow::common::current_timestamp(clock));
        reward.rewards_at_epoch<CoinType>(epoch_start_time)
    }

    /// Returns the total rewards available for a specific epoch for a specific coin type.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `epoch_start` - The start time of the epoch
    /// 
    /// # Returns
    /// The amount of rewards for the specified epoch
    public fun rewards_at_epoch<CoinType>(reward: &Reward, epoch_start: u64): u64 {
        let coin_type_name = std::type_name::get<CoinType>();
        if (!reward.token_rewards_per_epoch.contains(coin_type_name)) {
            return 0
        };
        let rewards_per_epoch = reward.token_rewards_per_epoch.borrow(coin_type_name);
        if (!rewards_per_epoch.contains(epoch_start)) {
            return 0
        };
        *rewards_per_epoch.borrow(epoch_start)
    }

    /// Returns true if the epoch is finalized.
    /// 
    /// # Arguments
    /// * `reward` - The reward object
    /// * `epoch_start` - The start time of the epoch
    public fun is_epoch_final(reward: &Reward, epoch_start: u64): bool {
        reward.epoch_updates_finalized.contains(epoch_start) && *reward.epoch_updates_finalized.borrow(epoch_start)
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
        let current_time = voting_escrow::common::current_timestamp(clock);
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
        if (supply_idx == 0 && checkpoint.epoch_start > time) {
            return 0
        };
        // Otherwise, the checkpoint at supply_idx is the correct one to use.
        checkpoint.supply
    }

    /// Decreases the balance of a specific lock in the current epoch.
    /// Updates checkpoints and supply data, then emits a withdraw event.
    /// 
    /// # Arguments
    /// * `reward` - The reward object to withdraw from
    /// * `reward_cap` - Capability object for authorization
    /// * `amount` - The amount of tokens to withdraw
    /// * `lock_id` - The ID of the lock to withdraw from
    /// * `clock` - Clock object for timestamp
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If the authorization is invalid
    public fun withdraw(
        reward: &mut Reward,
        reward_cap: &voting_escrow::reward_cap::RewardCap,
        amount: u64,
        lock_id: ID,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        reward_cap.validate(object::id(reward));
        let current_time = voting_escrow::common::current_timestamp(clock);

        // Update total supply
        let current_total_supply = reward.total_supply_at(current_time);
        
        let new_total_supply = current_total_supply - amount;

        // Update lock balance
        let lock_balance = reward.balance_of(lock_id, clock);
        let updated_lock_balance = lock_balance - amount;

        reward.write_checkpoint_internal(lock_id, updated_lock_balance, current_time, ctx);
        reward.write_supply_checkpoint_internal(current_time, new_total_supply);

        let withdraw_event = EventWithdraw {
            wrapper_reward_id: reward.wrapper_reward_id,
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
        let epoch_start = voting_escrow::common::epoch_start(time);
        // latest checkpoint timestam is equal to current epoch start
        if (
            num_of_checkpoints > 0 &&
            reward.checkpoints.contains(lock_id) &&
            reward.checkpoints.borrow(lock_id).contains(num_of_checkpoints - 1) &&
            reward.checkpoints.borrow(lock_id).borrow(num_of_checkpoints - 1).epoch_start == epoch_start 
        ) {
            let checkpoint = reward.checkpoints.borrow_mut(lock_id);
            if (checkpoint.contains(num_of_checkpoints - 1)) {
                checkpoint.remove(num_of_checkpoints - 1);
            };
            let updated_checkpoint = Checkpoint {
                epoch_start,
                balance_of: balance,
            };
            checkpoint.add(num_of_checkpoints - 1, updated_checkpoint);
        } else {
            if (!reward.checkpoints.contains(lock_id)) {
                reward.checkpoints.add(lock_id, sui::table::new<u64, Checkpoint>(ctx));
            };
            let prior_idx = reward.get_prior_balance_index(lock_id, epoch_start);
            let lock_checkpoints = reward.checkpoints.borrow_mut(lock_id);
            if (lock_checkpoints.contains(prior_idx) && lock_checkpoints.borrow(prior_idx).epoch_start == epoch_start) {
                lock_checkpoints.remove(prior_idx);
                let updated_checkpoint = Checkpoint {
                    epoch_start,
                    balance_of: balance,
                };
                lock_checkpoints.add(prior_idx, updated_checkpoint);
            } else {
                let new_checkpoint = Checkpoint {
                    epoch_start,
                    balance_of: balance,
                };
                if (num_of_checkpoints == 0) {
                    lock_checkpoints.add(num_of_checkpoints, new_checkpoint);
                } else {
                    let idx_to_free = if (lock_checkpoints.contains(prior_idx) && lock_checkpoints.borrow(prior_idx).epoch_start < epoch_start) {
                        prior_idx + 1 
                    } else {
                        prior_idx
                    };
                    let mut idx_to_move = num_of_checkpoints - 1;
                    while (idx_to_move >= idx_to_free) {
                        let checkpoint = lock_checkpoints.remove(idx_to_move);
                        lock_checkpoints.add(idx_to_move + 1, checkpoint);
                        if (idx_to_move == 0) {
                            break
                        };
                        idx_to_move = idx_to_move - 1;
                    };
                    lock_checkpoints.add(idx_to_free, new_checkpoint);
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
    /// * `time` - The timestamp for the checkpoint
    /// * `total_supply` - The total supply to record
    fun write_supply_checkpoint_internal(reward: &mut Reward, time: u64, total_supply: u64) {
        let num_of_checkpoints = reward.supply_num_checkpoints;
        let epoch_start = voting_escrow::common::epoch_start(time);
        // latest checkpoint timestam is equal to current epoch start
        if (
            num_of_checkpoints > 0 &&
            reward.supply_checkpoints.contains(num_of_checkpoints - 1) &&
            reward.supply_checkpoints.borrow(num_of_checkpoints - 1).epoch_start == epoch_start
        ) {
            reward.supply_checkpoints.remove(num_of_checkpoints - 1);
            
            let updated_checkpoint = SupplyCheckpoint {
                epoch_start,
                supply: total_supply,
            };
            reward.supply_checkpoints.add(num_of_checkpoints - 1, updated_checkpoint);
        } else {
            if (reward.supply_checkpoints.contains(num_of_checkpoints)) {
                reward.supply_checkpoints.remove(num_of_checkpoints);
            };
            let prior_idx = reward.get_prior_supply_index(epoch_start);
            if (reward.supply_checkpoints.contains(prior_idx) && reward.supply_checkpoints.borrow(prior_idx).epoch_start == epoch_start) {
                reward.supply_checkpoints.remove(prior_idx);
                let updated_checkpoint = SupplyCheckpoint {
                    epoch_start,
                    supply: total_supply,
                };
                reward.supply_checkpoints.add(prior_idx, updated_checkpoint);
            } else {
                let new_checkpoint = SupplyCheckpoint {
                    epoch_start,
                    supply: total_supply,
                };
                if (num_of_checkpoints == 0) {
                    reward.supply_checkpoints.add(num_of_checkpoints, new_checkpoint);
                } else {
                    let idx_to_free = if (
                        reward.supply_checkpoints.contains(prior_idx) && 
                        reward.supply_checkpoints.borrow(prior_idx).epoch_start < epoch_start
                    ) {
                        prior_idx + 1 
                    } else {
                        prior_idx
                    };
                    let mut idx_to_move = num_of_checkpoints -1;
                    while (idx_to_move >= idx_to_free) {
                        let checkpoint = reward.supply_checkpoints.remove(idx_to_move);
                        reward.supply_checkpoints.add(idx_to_move + 1, checkpoint);
                        if (idx_to_move == 0) {
                            break
                        };
                        idx_to_move = idx_to_move - 1;
                    };
                    reward.supply_checkpoints.add(idx_to_free, new_checkpoint);
                };
                reward.supply_num_checkpoints = num_of_checkpoints + 1;
            }
        };
    }

    public fun wrapper_reward_id(reward: &Reward): ID {
        reward.wrapper_reward_id
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


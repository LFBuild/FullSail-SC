module vault::reward_manager {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    use std::type_name::{TypeName, with_defining_ids};

    const SECONDS_PER_DAY: u64 = 86400;

    /// Manager for reward distribution in the pool.
    /// Contains information about all rewarders, points, and timing.
    /// 
    /// # Fields
    /// * `balances` - Bag containing reward token balances
    /// * `available_balance` - Table tracking available reward balances in Q64 format, used to monitor and control reward distribution
    /// * `emissions_per_second` - Table tracking emission rate per second for each reward token, Q64.64
    /// * `growth_global` - Table tracking growth global for each reward token, Q64.64
    /// * `last_update_growth_time` - Timestamp of last update for growth global in seconds
    public struct RewarderManager has store {
        types: vector<std::type_name::TypeName>,
        balances: sui::bag::Bag,
        available_balance: sui::table::Table<std::type_name::TypeName, u128>,
        emissions_per_second: sui::table::Table<std::type_name::TypeName, u128>,
        growth_global: sui::table::Table<std::type_name::TypeName, u128>,
        last_update_growth_time: u64,
    }

    /// Event emitted when the rewarder is initialized.
    /// 
    /// # Fields
    /// * `global_vault_id` - ID of the initialized global vault
    public struct RewarderInitEvent has copy, drop {
        global_vault_id: sui::object::ID,
    }

    /// Event emitted when rewards are deposited.
    /// 
    /// # Fields
    /// * `reward_type` - Type of the deposited reward
    /// * `deposit_amount` - Amount of rewards deposited
    /// * `after_amount` - Total amount after deposit
    public struct DepositEvent has copy, drop, store {
        reward_type: std::type_name::TypeName,
        deposit_amount: u64,
        after_amount: u64,
    }

    /// Event emitted during emergency withdrawal of rewards.
    /// 
    /// # Fields
    /// * `reward_type` - Type of the withdrawn reward
    /// * `withdraw_amount` - Amount of rewards withdrawn
    /// * `after_amount` - Total amount after withdrawal
    /// * `available_balance` - Available balance for the reward token (Q64.64)
    public struct EmergentWithdrawEvent has copy, drop, store {
        reward_type: std::type_name::TypeName,
        withdraw_amount: u64,
        after_amount: u64,
        available_balance: u128,
    }

    /// Event emitted when a reward balance is depleted.
    /// 
    /// # Fields
    /// * `reward_type` - Type of the reward
    /// * `emission_rate` - Rate of reward emission
    public struct RewardBalanceDepletedEvent has copy, drop, store {
        reward_type: std::type_name::TypeName,
        emission_rate: u128,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }

    /// Initializes the rewarder module and creates the global vault.
    /// 
    /// # Arguments
    /// * `ctx` - Mutable reference to the transaction context
    fun init(ctx: &mut sui::tx_context::TxContext) {
        // let vault = RewarderGlobalVault {
        //     id: sui::object::new(ctx),
        //     balances: sui::bag::new(ctx),
        //     available_balance: sui::table::new(ctx),
        // };
        // let global_vault_id = sui::object::id<RewarderGlobalVault>(&vault);
        // sui::transfer::share_object<RewarderGlobalVault>(vault);
        // let event = RewarderInitEvent { global_vault_id };
        // sui::event::emit<RewarderInitEvent>(event);
    }

    /// Creates a new RewarderManager instance with default values.
    /// Initializes all fields to their zero values.
    /// 
    /// # Returns
    /// A new RewarderManager instance with:
    /// * Empty balances bag
    /// * Empty available balance table
    /// * Empty emissions per second table
    /// * Empty growth global table
    /// * Empty last update growth time ms table
    public(package) fun new(ctx: &mut sui::tx_context::TxContext): RewarderManager {
        RewarderManager {
            types: vector::empty(),
            balances: sui::bag::new(ctx),
            available_balance: sui::table::new(ctx),
            emissions_per_second: sui::table::new(ctx),
            growth_global: sui::table::new(ctx),
            last_update_growth_time: 0,
        }
    }

    /// Deposits reward tokens into the rewarder manager.
    /// 
    /// # Arguments
    /// * `global_config` - Reference to the global configuration
    /// * `rewarder_manager` - Mutable reference to the rewarder manager
    /// * `balance` - Balance of reward tokens to deposit
    /// 
    /// # Returns
    /// The total amount after deposit
    public fun deposit_reward<RewardCoinType>(
        rewarder_manager: &mut RewarderManager,
        balance: sui::balance::Balance<RewardCoinType>
    ): u64 {
        let reward_type = with_defining_ids<RewardCoinType>();
        if (!rewarder_manager.types.contains(&reward_type)) {

            rewarder_manager.types.push_back(reward_type);

            rewarder_manager.balances.add(
                reward_type,
                sui::balance::zero<RewardCoinType>()
            );
            rewarder_manager.emissions_per_second.add(
                reward_type,
                0
            );
            rewarder_manager.growth_global.add(
                reward_type,
                0
            );
        };
        let deposit_amount = balance.value();
        if (!rewarder_manager.available_balance.contains(reward_type)) {
            rewarder_manager.available_balance.add(reward_type, (deposit_amount as u128)<<64);
        } else {
            let available_balance = rewarder_manager.available_balance.remove(reward_type);
            let (new_available_balance, overflow) = integer_mate::math_u128::overflowing_add(available_balance, (deposit_amount as u128)<<64);
            if (overflow) {
                abort  vault::error::available_balance_overflow()
            };
            rewarder_manager.available_balance.add(reward_type, new_available_balance);
        };
        let after_amount = sui::balance::join<RewardCoinType>(
            rewarder_manager.balances.borrow_mut(reward_type),
            balance
        );
        let event = DepositEvent {
            reward_type: reward_type,
            deposit_amount: deposit_amount,
            after_amount: after_amount,
        };
        sui::event::emit<DepositEvent>(event);

        after_amount
    }

    /// Settles reward calculations based on time elapsed and liquidity.
    /// 
    /// # Arguments
    /// * `manager` - Mutable reference to the rewarder manager
    /// * `liquidity` - Current liquidity value
    /// * `current_time` - Current timestamp in seconds
    /// 
    /// # Abort Conditions
    public(package) fun settle(
        rewarder_manager: &mut RewarderManager, 
        total_volume: u64,
        current_time: u64
    ) {
        let last_time = rewarder_manager.last_update_growth_time;
        assert!(last_time <= current_time, vault::error::invalid_time());

        rewarder_manager.last_update_growth_time = current_time;
        if (total_volume == 0 || last_time == current_time) {
            return
        };
        let time_delta = current_time - last_time;
        let mut index = 0;
        while (index < rewarder_manager.types.length()) {
            let reward_type = *rewarder_manager.types.borrow(index);
            if (
                !rewarder_manager.available_balance.contains(reward_type) ||
                !rewarder_manager.emissions_per_second.contains(reward_type) ||
                *rewarder_manager.emissions_per_second.borrow(reward_type) == 0
            ) {
                index = index + 1;
                continue
            };
            let emissions_per_second = *rewarder_manager.emissions_per_second.borrow(reward_type);

            let mut add_growth_global = integer_mate::full_math_u128::mul_div_floor(
                (time_delta as u128),
                integer_mate::full_math_u128::mul_div_floor(
                    emissions_per_second,
                    1,
                    (total_volume as u128)
                ),
                1
            );
            let available_balance = rewarder_manager.available_balance.remove(reward_type);
            if (available_balance <= add_growth_global * (total_volume as u128)) {
                rewarder_manager.emissions_per_second.remove(reward_type);
                rewarder_manager.emissions_per_second.add(reward_type, 0);
                
                add_growth_global = integer_mate::full_math_u128::mul_div_floor(
                    available_balance,
                    1,
                    (total_volume as u128)
                );
                rewarder_manager.available_balance.add(reward_type, 0);

                let event = RewardBalanceDepletedEvent {
                    reward_type: reward_type,
                    emission_rate: 0,
                };
                sui::event::emit<RewardBalanceDepletedEvent>(event);
            } else {
                rewarder_manager.available_balance.add(reward_type, available_balance - (add_growth_global * (total_volume as u128)));
            };

            let growth_global = rewarder_manager.growth_global.remove(reward_type);
            rewarder_manager.growth_global.add(reward_type, growth_global + add_growth_global);
            
            index = index + 1;
        };
    }

    /// Updates the emission rate for a specific reward token.
    /// 
    /// # Arguments
    /// * `rewarder_vault` - Reference to the rewarder global vault
    /// * `rewarder_manager` - Mutable reference to the rewarder manager
    /// * `liquidity` - Current liquidity value
    /// * `emission_rate` - New emission rate Q64.64
    /// * `current_time` - Current timestamp in seconds
    /// 
    /// # Abort Conditions
    public(package) fun update_emission<RewardCoinType>(
        rewarder_manager: &mut RewarderManager,
        total_volume: u64,
        new_emission_rate: u128,
        current_time: u64
    ) {
        let reward_type = with_defining_ids<RewardCoinType>();
        assert!(rewarder_manager.types.contains(&reward_type), vault::error::incentive_reward_not_found());

        settle(rewarder_manager, total_volume, current_time);
        if (new_emission_rate > 0) {
            assert!(
                rewarder_manager.available_balance.contains(reward_type) &&
                *rewarder_manager.available_balance.borrow(reward_type)
                >= 
                integer_mate::full_math_u128::mul_shr(
                    (SECONDS_PER_DAY as u128)<<64, 
                    new_emission_rate, 
                    64
                ), 
                vault::error::insufficient_incentive_balance()
            );
        };

        rewarder_manager.emissions_per_second.remove(reward_type);
        rewarder_manager.emissions_per_second.add(reward_type, new_emission_rate);
    }

    /// Withdraws reward tokens from the vault.
    /// 
    /// # Arguments
    /// * `rewarder_vault` - Mutable reference to the rewarder global vault
    /// * `amount` - Amount of tokens to withdraw
    /// 
    /// # Returns
    /// Balance of withdrawn reward tokens
    public(package) fun withdraw_reward<RewardCoinType>(
        rewarder_manager: &mut RewarderManager,
        amount: u64
    ): sui::balance::Balance<RewardCoinType> {
        sui::balance::split<RewardCoinType>(
            rewarder_manager.balances.borrow_mut(with_defining_ids<RewardCoinType>()),
            amount
        )
    }

    /// Performs an emergency withdrawal of reward tokens.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Mutable reference to the rewarder manager
    /// * `withdraw_amount` - Amount of tokens to withdraw
    /// * `total_volume` - Current total volume
    /// * `current_time` - Current timestamp in seconds
    /// 
    /// # Returns
    /// Balance of withdrawn reward tokens
    public fun emergent_withdraw<RewardCoinType>(
        rewarder_manager: &mut RewarderManager,
        withdraw_amount: u64,
        total_volume: u64,
        current_time: u64
    ): sui::balance::Balance<RewardCoinType> {

        let reward_type = with_defining_ids<RewardCoinType>();
        settle(rewarder_manager, total_volume, current_time);
        assert!(((withdraw_amount as u128)<<64) <= *rewarder_manager.available_balance.borrow(reward_type), vault::error::incorrect_withdraw_amount());

        let available_balance = rewarder_manager.available_balance.remove(reward_type);
        rewarder_manager.available_balance.add(reward_type, available_balance - ((withdraw_amount as u128)<<64));

        let event = EmergentWithdrawEvent {
            reward_type: with_defining_ids<RewardCoinType>(),
            withdraw_amount: withdraw_amount,
            after_amount: balance_of<RewardCoinType>(rewarder_manager),
            available_balance: available_balance_of<RewardCoinType>(rewarder_manager),
        };
        sui::event::emit<EmergentWithdrawEvent>(event);
        withdraw_reward<RewardCoinType>(rewarder_manager, withdraw_amount)
    }

    /// Gets the balance of a specific reward token in the vault.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Reference to the rewarder manager
    /// 
    /// # Returns
    /// The balance of the specified reward token. Returns 0 if the token is not found.
    public fun balance_of<RewardCoinType>(rewarder_manager: &RewarderManager): u64 {
        let reward_type = with_defining_ids<RewardCoinType>();
        if (!rewarder_manager.balances.contains(reward_type)) {
            return 0
        };
        sui::balance::value<RewardCoinType>(
            rewarder_manager.balances.borrow(reward_type)
        )
    }

    /// Gets the available balance for a specific reward token.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Reference to the rewarder manager
    /// 
    /// # Returns
    /// The available balance for the specified reward token (Q64.64)
    public fun available_balance_of<RewardCoinType>(rewarder_manager: &RewarderManager): u128 {
        let reward_type = with_defining_ids<RewardCoinType>();
        if (!rewarder_manager.available_balance.contains(reward_type)) {
            return 0
        };
        *rewarder_manager.available_balance.borrow(reward_type)
    }

    /// Gets the emission rate for a rewarder.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Reference to the rewarder manager
    /// 
    /// # Returns
    /// The emission rate per second
    public fun emissions_per_second<RewardCoinType>(rewarder_manager: &RewarderManager): u128 {
        if (!rewarder_manager.emissions_per_second.contains(with_defining_ids<RewardCoinType>())) {
            return 0
        };
        *rewarder_manager.emissions_per_second.borrow(with_defining_ids<RewardCoinType>())
    }

    /// Gets the global growth for a rewarder.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Reference to the rewarder manager
    /// 
    /// # Returns
    /// The global growth value
    public fun growth_global<RewardCoinType>(rewarder_manager: &RewarderManager): u128 {
        if (!rewarder_manager.growth_global.contains(with_defining_ids<RewardCoinType>())) {
            return 0
        };
        *rewarder_manager.growth_global.borrow(with_defining_ids<RewardCoinType>())
    }

    /// Gets the last update time from the manager.
    /// 
    /// # Arguments
    /// * `rewarder_manager` - Reference to the rewarder manager
    /// 
    /// # Returns
    /// The timestamp of the last update in seconds
    public fun last_update_growth_time(rewarder_manager: &RewarderManager): u64 {
        rewarder_manager.last_update_growth_time
    }

    public fun get_rewards_info(rewarder_manager: &RewarderManager): (vector<std::type_name::TypeName>, vector<u128>, vector<u128>) {
        let types =rewarder_manager.types;
        let mut emissions_per_second = vector::empty<u128>();
        let mut growth_global = vector::empty<u128>();
        let mut i = 0;
        while (i < rewarder_manager.types.length()) {
            let reward_type = *rewarder_manager.types.borrow(i);
            emissions_per_second.push_back(*rewarder_manager.emissions_per_second.borrow(reward_type));
            growth_global.push_back(*rewarder_manager.growth_global.borrow(reward_type));

            i = i + 1;
        };
        (types, emissions_per_second, growth_global)
    }

    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        init(ctx);
    }

    #[test]
    fun test_init_fun() {
        let admin = @0x123;
        let mut scenario = sui::test_scenario::begin(admin);
        {
            init(scenario.ctx());
        };

        // scenario.next_tx(admin);
        // {
        //     let vault = scenario.take_shared<RewarderManager>();
        //     assert!(sui::bag::is_empty(&rewarder_manager.balances), EMaxRewardersExceeded);
        //     sui::test_scenario::return_shared(rewarder_manager);
        // };
        scenario.end();
    }
}

module clmm_pool::rewarder {
    public struct RewarderManager has store {
        rewarders: vector<Rewarder>,
        points_released: u128,
        points_growth_global: u128,
        last_updated_time: u64,
    }

    public struct Rewarder has copy, drop, store {
        reward_coin: std::type_name::TypeName,
        emissions_per_second: u128,
        growth_global: u128,
    }

    public struct RewarderGlobalVault has store, key {
        id: sui::object::UID,
        balances: sui::bag::Bag,
    }

    public struct RewarderInitEvent has copy, drop {
        global_vault_id: sui::object::ID,
    }

    public struct DepositEvent has copy, drop, store {
        reward_type: std::type_name::TypeName,
        deposit_amount: u64,
        after_amount: u64,
    }

    public struct EmergentWithdrawEvent has copy, drop, store {
        reward_type: std::type_name::TypeName,
        withdraw_amount: u64,
        after_amount: u64,
    }

    public(package) fun new(): RewarderManager {
        RewarderManager {
            rewarders: std::vector::empty<Rewarder>(),
            points_released: 0,
            points_growth_global: 0,
            last_updated_time: 0,
        }
    }

    public(package) fun add_rewarder<RewardCoinType>(rewarder_manager: &mut RewarderManager) {
        let rewarder_idx = rewarder_index<RewardCoinType>(rewarder_manager);
        assert!(std::option::is_none<u64>(&rewarder_idx), 2);
        assert!(std::vector::length<Rewarder>(&rewarder_manager.rewarders) <= 2, 1);
        let new_rewarder = Rewarder {
            reward_coin: std::type_name::get<RewardCoinType>(),
            emissions_per_second: 0,
            growth_global: 0,
        };
        std::vector::push_back<Rewarder>(&mut rewarder_manager.rewarders, new_rewarder);
    }

    public fun balance_of<RewardCoinType>(vault: &RewarderGlobalVault): u64 {
        let reward_type = std::type_name::get<RewardCoinType>();
        if (!sui::bag::contains<std::type_name::TypeName>(&vault.balances, reward_type)) {
            return 0
        };
        sui::balance::value<RewardCoinType>(
            sui::bag::borrow<std::type_name::TypeName, sui::balance::Balance<RewardCoinType>>(&vault.balances, reward_type)
        )
    }

    public fun balances(vault: &RewarderGlobalVault): &sui::bag::Bag {
        &vault.balances
    }
    public(package) fun borrow_mut_rewarder<RewardCoinType>(manager: &mut RewarderManager): &mut Rewarder {
        let mut index = 0;
        while (index < std::vector::length<Rewarder>(&manager.rewarders)) {
            if (std::vector::borrow<Rewarder>(&manager.rewarders, index).reward_coin == std::type_name::get<RewardCoinType>()) {
                return std::vector::borrow_mut<Rewarder>(&mut manager.rewarders, index)
            };
            index = index + 1;
        };
        abort 5
    }

    public fun borrow_rewarder<RewardCoinType>(manager: &RewarderManager): &Rewarder {
        let mut index = 0;
        while (index < std::vector::length<Rewarder>(&manager.rewarders)) {
            if (std::vector::borrow<Rewarder>(&manager.rewarders, index).reward_coin == std::type_name::get<RewardCoinType>()) {
                return std::vector::borrow<Rewarder>(&manager.rewarders, index)
            };
            index = index + 1;
        };
        abort 5
    }

    public fun deposit_reward<RewardCoinType>(
        global_config: &clmm_pool::config::GlobalConfig,
        vault: &mut RewarderGlobalVault,
        balance: sui::balance::Balance<RewardCoinType>
    ): u64 {
        clmm_pool::config::checked_package_version(global_config);
        let reward_type = std::type_name::get<RewardCoinType>();
        if (!sui::bag::contains<std::type_name::TypeName>(&vault.balances, reward_type)) {
            sui::bag::add<std::type_name::TypeName, sui::balance::Balance<RewardCoinType>>(
                &mut vault.balances,
                reward_type,
                sui::balance::zero<RewardCoinType>()
            );
        };
        let deposit_amount = sui::balance::value<RewardCoinType>(&balance);
        let after_amount = sui::balance::join<RewardCoinType>(
            sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<RewardCoinType>>(&mut vault.balances, reward_type),
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

    public fun emergent_withdraw<RewardCoinType>(
        admin_cap: &clmm_pool::config::AdminCap,
        global_config: &clmm_pool::config::GlobalConfig,
        rewarder_vault: &mut RewarderGlobalVault,
        withdraw_amount: u64
    ): sui::balance::Balance<RewardCoinType> {
        clmm_pool::config::checked_package_version(global_config);
        let event = EmergentWithdrawEvent {
            reward_type: std::type_name::get<RewardCoinType>(),
            withdraw_amount: withdraw_amount,
            after_amount: balance_of<RewardCoinType>(rewarder_vault),
        };
        sui::event::emit<EmergentWithdrawEvent>(event);
        withdraw_reward<RewardCoinType>(rewarder_vault, withdraw_amount)
    }

    public fun emissions_per_second(rewarder: &Rewarder): u128 {
        rewarder.emissions_per_second
    }

    public fun growth_global(rewarder: &Rewarder): u128 {
        rewarder.growth_global
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let vault = RewarderGlobalVault {
            id: sui::object::new(ctx),
            balances: sui::bag::new(ctx),
        };
        let global_vault_id = sui::object::id<RewarderGlobalVault>(&vault);
        sui::transfer::share_object<RewarderGlobalVault>(vault);
        let event = RewarderInitEvent { global_vault_id };
        sui::event::emit<RewarderInitEvent>(event);
    }

    public fun last_update_time(manager: &RewarderManager): u64 {
        manager.last_updated_time
    }

    public fun points_growth_global(manager: &RewarderManager): u128 {
        manager.points_growth_global
    }

    public fun points_released(manager: &RewarderManager): u128 {
        manager.points_released
    }

    public fun reward_coin(rewarder: &Rewarder): std::type_name::TypeName {
        rewarder.reward_coin
    }

    public fun rewarder_index<RewardCoinType>(manager: &RewarderManager): std::option::Option<u64> {
        let mut index = 0;
        while (index < std::vector::length<Rewarder>(&manager.rewarders)) {
            if (std::vector::borrow<Rewarder>(&manager.rewarders, index).reward_coin == std::type_name::get<RewardCoinType>()) {
                return std::option::some<u64>(index)
            };
            index = index + 1;
        };
        std::option::none<u64>()
    }

    public fun rewarders(manager: &RewarderManager): vector<Rewarder> {
        manager.rewarders
    }

    public fun rewards_growth_global(manager: &RewarderManager): vector<u128> {
        let mut index = 0;
        let mut rewards = std::vector::empty<u128>();
        while (index < std::vector::length<Rewarder>(&manager.rewarders)) {
            std::vector::push_back<u128>(&mut rewards, std::vector::borrow<Rewarder>(&manager.rewarders, index).growth_global);
            index = index + 1;
        };
        rewards
    }

    public(package) fun settle(manager: &mut RewarderManager, liquidity: u128, current_time: u64) {
        let last_time = manager.last_updated_time;
        manager.last_updated_time = current_time;
        assert!(last_time <= current_time, 3);
        if (liquidity == 0 || last_time == current_time) {
            return
        };
        let time_delta = current_time - last_time;
        let mut index = 0;
        while (index < std::vector::length<Rewarder>(&manager.rewarders)) {
            std::vector::borrow_mut<Rewarder>(&mut manager.rewarders, index).growth_global = std::vector::borrow<Rewarder>(
                &manager.rewarders,
                index
            ).growth_global + integer_mate::full_math_u128::mul_div_floor(
                time_delta as u128,
                std::vector::borrow<Rewarder>(&manager.rewarders, index).emissions_per_second,
                liquidity
            );
            index = index + 1;
        };
        manager.points_released = manager.points_released + (time_delta as u128) * 18446744073709551616000000;
        manager.points_growth_global = manager.points_growth_global + integer_mate::full_math_u128::mul_div_floor(
            time_delta as u128,
            18446744073709551616000000,
            liquidity
        );
    }

    public(package) fun update_emission<RewardCoinType>(
        rewarder_vault: &RewarderGlobalVault,
        rewarder_manager: &mut RewarderManager,
        liquidity: u128,
        emission_rate: u128,
        current_time: u64
    ) {
        settle(rewarder_manager, liquidity, current_time);
        if (emission_rate > 0) {
            let reward_type = std::type_name::get<RewardCoinType>();
            assert!(sui::bag::contains<std::type_name::TypeName>(&rewarder_vault.balances, reward_type), 5);
            assert!(
                ((sui::balance::value<RewardCoinType>(
                    sui::bag::borrow<std::type_name::TypeName, sui::balance::Balance<RewardCoinType>>(&rewarder_vault.balances, reward_type)
                ) as u128) << 64) >= 86400 * emission_rate,
                4
            );
        };
        borrow_mut_rewarder<RewardCoinType>(rewarder_manager).emissions_per_second = emission_rate;
    }

    public(package) fun withdraw_reward<RewardCoinType>(
        rewarder_vault: &mut RewarderGlobalVault,
        amount: u64
    ): sui::balance::Balance<RewardCoinType> {
        sui::balance::split<RewardCoinType>(
            sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<RewardCoinType>>(
                &mut rewarder_vault.balances,
                std::type_name::get<RewardCoinType>()
            ),
            amount
        )
    }

    // decompiled from Move bytecode v6
}


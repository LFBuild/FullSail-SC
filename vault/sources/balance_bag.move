module vault::balance_bag {

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    public struct BalanceBag has store {
        balances: sui::vec_map::VecMap<std::type_name::TypeName, u64>,
        bag: sui::bag::Bag,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }
    
    public fun balances(balance_bag: &BalanceBag) : &sui::vec_map::VecMap<std::type_name::TypeName, u64> {
        &balance_bag.balances
    }
    
    public(package) fun join<CoinType>(balance_bag: &mut BalanceBag, balance: sui::balance::Balance<CoinType>) { 
        let type_name = std::type_name::with_defining_ids<CoinType>();
        if (balance_bag.balances.contains(&type_name)) {
            *sui::vec_map::get_mut<std::type_name::TypeName, u64>(
                &mut balance_bag.balances, 
                &type_name
            ) = vault::vault_utils::add_balance_to_bag<CoinType>(&mut balance_bag.bag, balance);
        } else {
            balance_bag.balances.insert(type_name, vault::vault_utils::add_balance_to_bag<CoinType>(&mut balance_bag.bag, balance));
        };
    }
    
    public(package) fun new_balance_bag(ctx: &mut sui::tx_context::TxContext) : BalanceBag { 
        BalanceBag{
            balances : sui::vec_map::empty<std::type_name::TypeName, u64>(), 
            bag      : sui::bag::new(ctx),
        }
    }
    
    public(package) fun split<CoinType>(balance_bag: &mut BalanceBag, amount: u64) : sui::balance::Balance<CoinType> {
        let (balance, new_balance) = vault::vault_utils::remove_balance_from_bag<CoinType>(&mut balance_bag.bag, amount, false);
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        if (balance_bag.balances.contains(&type_name)) {
            *sui::vec_map::get_mut<std::type_name::TypeName, u64>(&mut balance_bag.balances, &type_name) = new_balance;
        };
        balance
    }
    
    public fun value<CoinType>(balance_bag: &BalanceBag) : u64 {
        let type_name = std::type_name::with_defining_ids<CoinType>();
        if (sui::vec_map::contains<std::type_name::TypeName, u64>(&balance_bag.balances, &type_name)) {
            *sui::vec_map::get<std::type_name::TypeName, u64>(&balance_bag.balances, &type_name)
        } else {
            0
        }
    }
    
    public(package) fun withdraw_all<CoinType>(balance_bag: &mut BalanceBag) : sui::balance::Balance<CoinType> {
        let (balance, _) = vault::vault_utils::remove_balance_from_bag<CoinType>(&mut balance_bag.bag, 0, true);
        let type_name = std::type_name::with_defining_ids<CoinType>(); 
        if (sui::vec_map::contains<std::type_name::TypeName, u64>(&balance_bag.balances, &type_name)) {
            *sui::vec_map::get_mut<std::type_name::TypeName, u64>(&mut balance_bag.balances, &type_name) = 0;
        };
        balance
    }
}


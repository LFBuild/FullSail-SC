module vault::vault_utils {

    const MAX_U64: u128 = 0x10000000000000000;

    public fun add_balance_to_bag<CoinType>(bag: &mut sui::bag::Bag, balance: sui::balance::Balance<CoinType>) : u64 {
        let type_name_str = std::string::from_ascii(std::type_name::into_string(std::type_name::with_defining_ids<CoinType>()));
        if (sui::bag::contains<std::string::String>(bag, type_name_str)) {
            sui::balance::join<CoinType>(sui::bag::borrow_mut<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str), balance); 
        } else {
            sui::bag::add<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str, balance);
        };
        sui::balance::value<CoinType>(sui::bag::borrow<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str))
    }
    
    public fun price_to_sqrt_price(price: u64, price_multiplier_decimal: u8) : u128 {
        integer_mate::full_math_u128::mul_div_floor(std::u128::sqrt((price as u128) * std::u128::pow(10, 10)), MAX_U64, std::u128::pow(10, (10 + price_multiplier_decimal) / 2))
    }
    
    public fun remove_balance_from_bag<CoinType>(bag: &mut sui::bag::Bag, amount: u64, keep_balance: bool) : (sui::balance::Balance<CoinType>, u64) {
        let type_name_str = std::string::from_ascii(std::type_name::into_string(std::type_name::with_defining_ids<CoinType>())); 
        if (!sui::bag::contains<std::string::String>(bag, type_name_str)) {
            return (sui::balance::zero<CoinType>(), 0) 
        };
        let remaining_amount = if (keep_balance) {
            sui::balance::value<CoinType>(sui::bag::borrow<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str)) 
        } else {
            amount
        };
        (
            sui::balance::split<CoinType>(
                sui::bag::borrow_mut<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str), remaining_amount),
                sui::balance::value<CoinType>(sui::bag::borrow<std::string::String, sui::balance::Balance<CoinType>>(bag, type_name_str)
            )
        )
    }
    
    public fun send_coin<CoinType>(coin: sui::coin::Coin<CoinType>, recipient: address) {
        if (sui::coin::value<CoinType>(&coin) > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(coin, recipient); 
        } else {
            sui::coin::destroy_zero<CoinType>(coin);
        };
    }
    
    public fun sqrt_price_to_price(sqrt_price: u128, coin_decimals_1: u8, coin_decimals_2: u8, price_multiplier_decimal: u8) : u128 {
        let price = if (coin_decimals_1 > coin_decimals_2) {
            (
                (
                    std::u256::pow((sqrt_price as u256) * std::u256::pow(10, price_multiplier_decimal) / (MAX_U64 as u256), 2) 
                    / 
                    std::u256::pow(10, price_multiplier_decimal)
                ) as u128
            ) * std::u128::pow(10, coin_decimals_1 - coin_decimals_2)
        } else {
            (
                (
                    std::u256::pow((sqrt_price as u256) * std::u256::pow(10, price_multiplier_decimal) / (MAX_U64 as u256), 2) 
                    / 
                    std::u256::pow(10, price_multiplier_decimal)
                ) as u128
            ) / std::u128::pow(10, coin_decimals_2 - coin_decimals_1)
        };
        price
    }
    
    public fun uint64_max() : u128 {
        MAX_U64
    }
}


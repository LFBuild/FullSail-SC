module distribution::fullsail_token {
    public struct FULLSAIL_TOKEN has drop {
    }
    
    public struct MinterCap<phantom T0> has store, key {
        id: sui::object::UID,
        cap: sui::coin::TreasuryCap<T0>,
    }
    
    public fun burn<T0>(arg0: &mut MinterCap<T0>, arg1: sui::coin::Coin<T0>) {
        sui::coin::burn<T0>(&mut arg0.cap, arg1);
    }
    
    public fun mint<T0>(arg0: &mut MinterCap<T0>, arg1: u64, arg2: address, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        assert!(arg2 != @0x0, 0);
        sui::coin::mint<T0>(&mut arg0.cap, arg1, arg3)
    }
    
    public fun total_supply<T0>(arg0: &MinterCap<T0>) : u64 {
        sui::coin::total_supply<T0>(&arg0.cap)
    }
    
    fun init(arg0: FULLSAIL_TOKEN, arg1: &mut sui::tx_context::TxContext) {
        let (v0, v1) = sui::coin::create_currency<FULLSAIL_TOKEN>(arg0, 6, b"FSAIL", b"FullSail", b"FullSail Governance Token with ve(4,4) capabilities", std::option::none<sui::url::Url>(), arg1);
        let v2 = MinterCap<FULLSAIL_TOKEN>{
            id  : sui::object::new(arg1), 
            cap : v0,
        };
        sui::transfer::transfer<MinterCap<FULLSAIL_TOKEN>>(v2, sui::tx_context::sender(arg1));
        sui::transfer::public_transfer<sui::coin::CoinMetadata<FULLSAIL_TOKEN>>(v1, sui::tx_context::sender(arg1));
    }
    
    // decompiled from Move bytecode v6
}


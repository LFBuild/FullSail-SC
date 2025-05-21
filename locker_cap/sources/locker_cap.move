module locker_cap::locker_cap {
    
    const ENotOwner: u64 = 923752748582334234;
    
    public struct LOCKER_CAP has drop {}

    public struct CreateCap has store, key {
        id: sui::object::UID,
    }

    public struct LockerCap has store, key {
        id: sui::object::UID,
    }

    public fun create_locker_cap(
        _create_cap: &CreateCap,
        tx_context: &mut sui::tx_context::TxContext
    ): LockerCap {
        LockerCap {
            id: sui::object::new(tx_context),
        }
    }


    public fun grant_create_cap(publisher: &sui::package::Publisher, recipient: address, ctx: &mut sui::tx_context::TxContext) {
        assert!(publisher.from_module<CreateCap>(), ENotOwner);
        let new_cap = CreateCap { id: sui::object::new(ctx) };
        sui::transfer::public_transfer<CreateCap>(new_cap, recipient);
    }

    fun init(locker_cap_instance: LOCKER_CAP, ctx: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<LOCKER_CAP>(locker_cap_instance, ctx);
        let new_cap = CreateCap { id: sui::object::new(ctx) };
        sui::transfer::public_transfer<CreateCap>(new_cap, sui::tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_test(ctx: &mut sui::tx_context::TxContext) {
        let new_cap = CreateCap { id: sui::object::new(ctx) };
        sui::transfer::public_transfer<CreateCap>(new_cap, sui::tx_context::sender(ctx));
    }
}


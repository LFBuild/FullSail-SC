module full_sail::coin_wrapper {
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use std::ascii::String;
    use std::type_name;
    use sui::dynamic_object_field;

    // Error constants
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    public struct WrappedCoinType has drop {}

    public struct WrappedAssetData has store {
        metadata: CoinMetadata<WrappedCoinType>,
        treasury_cap: TreasuryCap<WrappedCoinType>,
        original_coin_type: String,
    }

    public struct WrapperStore has key {
        id: UID,
        coin_to_wrapper: Table<String, WrappedAssetData>,
        wrapper_to_coin: Table<ID, String>,
    }

    public struct WrapperStoreCap has key {
        id: UID
    }

    // init
    fun init(ctx: &mut TxContext) {
        let admin_cap = WrapperStoreCap {
            id: object::new(ctx)
        };

        let registry = WrapperStore {
            id: object::new(ctx),
            coin_to_wrapper: table::new(ctx),
            wrapper_to_coin: table::new(ctx)
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(registry);
    }

    public fun register_coin<CoinType>(
        _cap: &WrapperStoreCap,
        otw: WrappedCoinType,
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ) {
        // check if the coin is already registered
        let coin_type = type_name::get<CoinType>();
        let coin_type_name = coin_type.into_string();
        assert!(!table::contains(&store.coin_to_wrapper, coin_type_name), E_ALREADY_INITIALIZED);

        // create the new wrapped coin
        let (treasury_cap, metadata) = coin::create_currency<WrappedCoinType>(
            otw, 
            9, // decimals
            b"WRAPPED", // symbol
            b"Wrapped Coin", // name
            b"A wrapped version of the original coin", // description
            option::none(), // icon_url
            ctx
        );

        let metadata_id = object::id(&metadata);

        // create WrappedAssetData
        let wrapped_data = WrappedAssetData {
            metadata,
            treasury_cap,
            original_coin_type: coin_type_name
        };
        
        table::add(&mut store.coin_to_wrapper, coin_type_name, wrapped_data);
        table::add(&mut store.wrapper_to_coin, metadata_id, coin_type_name);
    }

    // wrap
    public fun wrap<CoinType>(
        store: &mut WrapperStore,
        coin_in: Coin<CoinType>,
        ctx: &mut TxContext
    ): Coin<WrappedCoinType> {
        let coin_type = type_name::get<CoinType>();
        let coin_type_name = coin_type.into_string();
        assert!(is_supported(store, &coin_type_name), E_NOT_INITIALIZED);

        let amount = coin::value(&coin_in);
        let wrapped_data = table::borrow_mut(&mut store.coin_to_wrapper, coin_type_name);

        // store original coin
        transfer::public_transfer(coin_in, object::uid_to_address(&store.id));

        // mint wrapped coin
        let wrapped_coin = coin::mint(&mut wrapped_data.treasury_cap, amount, ctx);

        wrapped_coin
    }

    // unwrap
    public fun unwrap<CoinType>(
        store: &mut WrapperStore,
        wrapped_coin: Coin<WrappedCoinType>,
    ): Coin<CoinType> {
        let coin_type = type_name::get<CoinType>();
        let coin_type_name = coin_type.into_string();
        assert!(is_supported(store, &coin_type_name), E_NOT_INITIALIZED);

        let wrapped_data = table::borrow_mut(&mut store.coin_to_wrapper, coin_type_name);

        // burn wrapped coin
        coin::burn(&mut wrapped_data.treasury_cap, wrapped_coin);

        let stored_coin = dynamic_object_field::remove<String, Coin<CoinType>>(
            &mut store.id, 
            coin_type_name
        );

        stored_coin
    }

    // --- public view functions ---
    public fun is_supported(store: &mut WrapperStore, coin_type: &String): bool {
        table::contains(&store.coin_to_wrapper, *coin_type)
    }

    public fun is_wrapper(store: &WrapperStore, metadata_id: ID): bool {
        table::contains(&store.wrapper_to_coin, metadata_id)
    }

    public fun get_coin_type(store: &WrapperStore, metadata_id: ID): String {
        *table::borrow(&store.wrapper_to_coin, metadata_id)
    }

    public fun get_wrapper<CoinType>(store: &WrapperStore): &WrappedAssetData {
        let coin_type_name = type_name::get<CoinType>().into_string();
        table::borrow(&store.coin_to_wrapper, coin_type_name)
    }
}
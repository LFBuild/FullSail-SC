module full_sail::coin_wrapper {
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::dynamic_object_field;
    //use sui::dynamic_field;
    use std::string;
    use std::ascii::String;
    use std::type_name;

    // --- errors ---
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    // --- structs ---
    public struct COIN_WRAPPER has drop {}

    /*public struct WrappedAssetData has store {
        metadata: CoinMetadata<COIN_WRAPPER>,
        treasury_cap: TreasuryCap<COIN_WRAPPER>,
        original_coin_type: String,
    }*/

    public struct WrappedAssetData<phantom T> has key, store {
        id: UID,
        metadata: CoinMetadata<T>,
        treasury_cap: TreasuryCap<T>,
        original_coin_type: String,
    }

    public struct WrapperStore has key {
        id: UID,
        coin_to_wrapper: Table<String, ID>,
        wrapper_to_coin: Table<ID, String>,
    }

    public struct WrapperStoreCap has key {
        id: UID
    }

    // init
    public(package) fun initialize(_otw: COIN_WRAPPER, ctx: &mut TxContext) {
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

    public fun register_coin<CoinType, WrapperType: drop>(
        _cap: &WrapperStoreCap,
        witness: WrapperType,
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ): &CoinMetadata<WrapperType> {
        let coin_type = type_name::get<CoinType>();
        let coin_type_name = coin_type.into_string();
        assert!(!table::contains(&store.coin_to_wrapper, coin_type_name), E_ALREADY_INITIALIZED);

        let (treasury_cap, metadata) = coin::create_currency<WrapperType>(
            witness,
            9,
            b"WRAPPED",
            b"Wrapped Coin",
            b"A wrapped version of the original coin",
            option::none(),
            ctx
        );

        let metadata_id = object::id(&metadata);
        
        // Store the metadata ID and mapping
        table::add(&mut store.coin_to_wrapper, coin_type_name, metadata_id);
        table::add(&mut store.wrapper_to_coin, metadata_id, coin_type_name);

        // Store the wrapped asset data as a dynamic field
        dynamic_object_field::add(&mut store.id, metadata_id, WrappedAssetData {
            id: object::new(ctx),
            metadata,
            treasury_cap,
            original_coin_type: coin_type_name
        });

        dynamic_object_field::borrow(&store.id, metadata_id)
    }

    // wrap
    public fun wrap<CoinType, WrapperType>(
        store: &mut WrapperStore,
        coin_in: Coin<CoinType>,
        ctx: &mut TxContext
    ): Coin<WrapperType> {
        let coin_type_name = type_name::get<CoinType>().into_string();
        assert!(table::contains(&store.coin_to_wrapper, coin_type_name), E_NOT_INITIALIZED);

        let metadata_id = *table::borrow(&store.coin_to_wrapper, coin_type_name);
        let wrapped_data: &mut WrappedAssetData<WrapperType> = dynamic_object_field::borrow_mut(&mut store.id, metadata_id);
        
        let amount = coin::value(&coin_in);
        // Store original coin
        dynamic_object_field::add(&mut store.id, coin_type_name, coin_in);
        
        coin::mint(&mut wrapped_data.treasury_cap, amount, ctx)
    }

    // unwrap
    public fun unwrap<WrapperType, CoinType>(
        store: &mut WrapperStore,
        wrapped_coin: Coin<WrapperType>,
    ): Coin<CoinType> {
        let coin_type_name = type_name::get<CoinType>().into_string();
        assert!(table::contains(&store.coin_to_wrapper, coin_type_name), E_NOT_INITIALIZED);

        let metadata_id = *table::borrow(&store.coin_to_wrapper, coin_type_name);
        let wrapped_data: &mut WrappedAssetData<WrapperType> = dynamic_object_field::borrow_mut(&mut store.id, metadata_id);
        
        coin::burn(&mut wrapped_data.treasury_cap, wrapped_coin);
        
        dynamic_object_field::remove(&mut store.id, coin_type_name)
    }

    public fun format_fungible_asset(id: ID): String {
        let bytes = object::id_to_bytes(&id);

        string::to_ascii(string::utf8(bytes))
    }

    public fun format_coin<T>(): String {
        type_name::get<T>().into_string()
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

    public fun get_wrapper<CoinType>(store: &WrapperStore): &CoinMetadata<CoinType> {
        let coin_type_name = type_name::get<CoinType>().into_string();
        assert!(table::contains(&store.coin_to_wrapper, coin_type_name), E_NOT_INITIALIZED);
        
        let metadata_id = *table::borrow(&store.coin_to_wrapper, coin_type_name);
        let wrapped_data: &WrappedAssetData<CoinType> = dynamic_object_field::borrow(&store.id, metadata_id);
        
        &wrapped_data.metadata
    }

    public fun get_original(store: &WrapperStore, metadata_id: ID) : String {
        if (is_wrapper(store, metadata_id)) {
            get_coin_type(store, metadata_id)
        } else {
            format_fungible_asset(metadata_id)
        }
    }

    // --- tests funcs ---
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        initialize(COIN_WRAPPER {}, ctx);
    }

    #[test_only]
    public fun register_coin_for_testing<CoinType, WrapperType: drop>(
        cap: &WrapperStoreCap,
        witness: WrapperType,
        store: &mut WrapperStore,
        ctx: &mut TxContext
    ):&CoinMetadata<WrapperType> {
        register_coin<CoinType, WrapperType>(cap, witness, store, ctx)
    }

    #[test_only]
    public(package) fun get_original_coin_type<T>(wcoin_type: &WrappedAssetData<T>): String {
        wcoin_type.original_coin_type
    }
    
    #[test_only]
    public fun get_wrapped_data<CoinType, WrapperType>(store: &WrapperStore): &WrappedAssetData<WrapperType> {
        let coin_type_name = type_name::get<CoinType>().into_string();
        let metadata_id = *table::borrow(&store.coin_to_wrapper, coin_type_name);
        dynamic_object_field::borrow(&store.id, metadata_id)
    }

    #[test_only]
    public fun create_witness(): COIN_WRAPPER {
        COIN_WRAPPER {}
    }
}
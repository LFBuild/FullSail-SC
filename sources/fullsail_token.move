module full_sail::fullsail_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    
    //friend fullsail::voting_escrow;
    //friend fullsail::minter;
    //friend fullsail::vote_manager;

    // --- structs ---
    // OTW
    public struct FULLSAIL_TOKEN has drop {}
    
    // token manager
    public struct FullSailManager has key {
        id: UID,
        cap: TreasuryCap<FULLSAIL_TOKEN>,
        minter: address
    }

    // init
    fun init(
        witness: FULLSAIL_TOKEN, 
        ctx: &mut TxContext
    ) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            18, // decimals
            b"SAIL", // symbol
            b"FullSail", // name
            b"Coin of FullSail Dex", // description
            option::none(), // icon url
            ctx
        );

        let manager = FullSailManager {
            id: object::new(ctx),
            cap: treasury_cap,
            minter: tx_context::sender(ctx)
        };

        transfer::share_object(manager);
        transfer::public_freeze_object(metadata);
    }

    // mint
    public(package) fun mint(
        authority: &mut TreasuryCap<FULLSAIL_TOKEN>, 
        amount: u64, 
        ctx: &mut TxContext
    ): Coin<FULLSAIL_TOKEN> {
        coin::mint(authority, amount, ctx)
    }

    // burn
    public(package) fun burn(
        authority: &mut TreasuryCap<FULLSAIL_TOKEN>, 
        coin: Coin<FULLSAIL_TOKEN>
    ): u64 {
        coin::burn(authority, coin)
    }

    // transfer
    public(package) fun transfer(
        coin: &mut Coin<FULLSAIL_TOKEN>, 
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin_to_send = coin::split(coin, amount, ctx);
        transfer::public_transfer(coin_to_send, recipient);
    }

    public(package) fun freeze_transfers(coin: Coin<FULLSAIL_TOKEN>) {
        transfer::public_freeze_object(coin);
    }

    // --- public view functions ---
    // balance
    public fun balance(coin: &Coin<FULLSAIL_TOKEN>): u64 {
        coin::value(coin)
    }

    public fun total_supply(manager: &FullSailManager): u64 {
        coin::total_supply(&manager.cap)
    }

    // --- tests funcs ---
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init( FULLSAIL_TOKEN{}, ctx);
    }

    public(package) fun cap(manager: &mut FullSailManager): &mut TreasuryCap<FULLSAIL_TOKEN> {
        &mut manager.cap
    }
}


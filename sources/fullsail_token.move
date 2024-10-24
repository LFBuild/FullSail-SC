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

        transfer::transfer(manager, tx_context::sender(ctx));
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

    // balance
    public fun balance(coin: &Coin<FULLSAIL_TOKEN>): u64 {
        coin::value(coin)
    }
}


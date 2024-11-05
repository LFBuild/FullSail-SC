module full_sail::minter {
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::clock::Clock;
    use sui::dynamic_object_field;
    use std::ascii::String;
    use std::type_name;

    use full_sail::fullsail_token::{Self, FULLSAIL_TOKEN, FullSailManager};
    use full_sail::epoch;

    // --- errors ---
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    // --- structs ---
    public struct MINTER has drop {}

    public struct MinterConfig has key {
        id: UID,
        team_account: address,
        pending_team_account: address,
        team_emission_rate_bps: u64,
        weekly_emission_amount: u64,
        last_emission_update_epoch: u64,
    }

    public struct AdminCap has key {
        id: UID
    }

    fun init(otw: MINTER, ctx: &mut TxContext) {
        let minter_config = MinterConfig{
            id                         : object::new(ctx),
            team_account               : @full_sail,
            pending_team_account       : @0x0,
            team_emission_rate_bps     : 30,
            weekly_emission_amount     : 150000000000000,
            last_emission_update_epoch : ctx.epoch(),
        };
        transfer::share_object(minter_config);

        let initial_mint_amount = fullsail_token::mint(
            AdminCap { id: object::new(ctx) }, 
            100000000000000000, 
            ctx
        );
        transfer::public_transfer(initial_mint_amount, @full_sail);
    }
}
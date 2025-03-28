module sail_token::o_sail_token;

use sui::{
    coin::{Self, TreasuryCap},
    token::{Self, TokenPolicy}
};

use sail_token::allow_list;

public struct O_SAIL_TOKEN has drop {

}

fun init(otw: O_SAIL_TOKEN, ctx: &mut TxContext) {
    let treasury_cap = create_currency(otw, ctx);

    let (mut policy, policy_cap) = token::new_policy<O_SAIL_TOKEN>(&treasury_cap, ctx);

    allow_list::init_rule<O_SAIL_TOKEN>(&policy_cap, &mut policy, ctx);

    transfer::public_transfer(policy_cap, ctx.sender());
    transfer::public_transfer(treasury_cap, ctx.sender());
    token::share_policy<O_SAIL_TOKEN>(policy);
}

fun create_currency(otw: O_SAIL_TOKEN, ctx: &mut TxContext): TreasuryCap<O_SAIL_TOKEN> {
    // TODO add link to logo
    let logoUrl = sui::url::new_unsafe_from_bytes(b"https://link.to.logo");
    let (trasury_cap, metadata) = coin::create_currency(
        otw,
        6,
        b"oSAIL",
        b"FullSail Option",
        b"Option token that can be executed in order to get SAIL with discount",
        option::some(logoUrl),
        ctx,
    );
    transfer::public_freeze_object(metadata);

    trasury_cap
}
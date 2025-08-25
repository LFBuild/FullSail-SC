#[test_only]
module airdrop::setup;

use sui::test_scenario::{Self as ts};
use sui::clock::{Self, Clock};
use ve::voting_escrow::{Self, VotingEscrow, Lock};
use sui::test_utils;

public struct SAIL has drop, store {}

public struct PRE_SAIL has drop, store {}

public fun setup<SailCoinType>(scenario: &mut ts::Scenario, sender: address): Clock {
    let clock = clock::create_for_testing(scenario.ctx());
    let voter_id = object::id_from_address(@0xABCD1337);

    scenario.next_tx(sender);
    {
        let ve_publisher = voting_escrow::test_init(scenario.ctx());
        let (ve, ve_cap) = voting_escrow::create<SailCoinType>(
            &ve_publisher,
            voter_id,
            &clock,
            scenario.ctx()
        );
        transfer::public_share_object(ve);
        transfer::public_transfer(ve_cap, sender);
        test_utils::destroy(ve_publisher);
    };

    clock
}
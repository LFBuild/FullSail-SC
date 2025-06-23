/// This module defines a Distribute capability
/// which grants the owner ability to call methods
/// that related to the flow of new tokens, i.e.
/// notify rewards methods, distribute gauges methods.
/// Is supposed to be owned by the minter.

module distribution::distribute_cap;
use sui::package;

const EValidateDistributeInvalidVoter: u64 = 421990001503268030;

public struct DISTRIBUTE_CAP has drop {}

public struct DistributeCap has store, key {
    id: UID,
    voter_id: ID,
    who: ID,
}

public fun create(
    _publisher: &package::Publisher,
    voter_id: ID,
    who: ID,
    ctx: &mut TxContext
): DistributeCap {
    DistributeCap {
        id: object::new(ctx),
        voter_id,
        who,
    }
}

public(package) fun create_internal(
    voter_id: ID,
    ctx: &mut TxContext
): DistributeCap {
    DistributeCap {
        id: object::new(ctx),
        voter_id,
        who: object::id_from_address(ctx.sender()),
    }
}

fun init(otw: DISTRIBUTE_CAP, ctx: &mut TxContext) {
    package::claim_and_keep<DISTRIBUTE_CAP>(otw, ctx);
}

#[test_only]
public fun test_create(
    voter_id: ID,
    who: ID,
    ctx: &mut TxContext
): DistributeCap {
    DistributeCap {
        id: object::new(ctx),
        voter_id,
        who,
    }
}

public fun validate_distribute_voter_id(distribute_cap: &DistributeCap, voter_id: ID) {
    assert!(distribute_cap.voter_id == voter_id, EValidateDistributeInvalidVoter);
}

public fun who(distribute_cap: &DistributeCap): ID {
    distribute_cap.who
}

public fun voter_id(distribute_cap: &DistributeCap): ID {
    distribute_cap.voter_id
}


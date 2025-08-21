/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module ve::voting_escrow_cap;

#[allow(unused_const)]
const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

const EVotingEscrowCapInvalid: u64 = 145221715012404670;

public struct VotingEscrowCap has store, key {
    id: UID,
    voting_escrow_id: ID,
}

    
public(package) fun create(voting_escrow_id: ID, ctx: &mut TxContext): VotingEscrowCap {
    VotingEscrowCap {
        id: object::new(ctx),
        voting_escrow_id,
    }
}

public fun validate(voting_escrow_cap: &VotingEscrowCap, voting_escrow_id: ID) {
    assert!(voting_escrow_cap.voting_escrow_id == voting_escrow_id, EVotingEscrowCapInvalid);
}


/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module governance::rebase_distributor_cap {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";

    const ERebaseDistributorInvalid: u64 = 641490194087433300;

    public struct RebaseDistributorCap has store, key {
        id: UID,
        rebase_distributor: ID,
    }

    public(package) fun create(rebase_distributor_id: ID, ctx: &mut TxContext): RebaseDistributorCap {
        RebaseDistributorCap {
            id: object::new(ctx),
            rebase_distributor: rebase_distributor_id,
        }
    }

    public fun validate(rebase_distributor_cap: &RebaseDistributorCap, rebase_distributor_id: ID) {
        assert!(rebase_distributor_cap.rebase_distributor == rebase_distributor_id, ERebaseDistributorInvalid);
    }
}


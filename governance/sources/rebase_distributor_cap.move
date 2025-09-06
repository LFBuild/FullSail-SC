/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.

module governance::rebase_distributor_cap {
    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const ERebaseDistributorInvalid: u64 = 641490194087433300;

    public struct RebaseDistributorCap has store, key {
        id: UID,
        rebase_distributor: ID,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
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


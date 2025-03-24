module distribution::lock_owner {
    public struct OwnerProof {
        prover: ID,
        lock: ID,
        owner: address,
    }

    public fun consume(owner_proof: OwnerProof): (ID, ID, address) {
        let OwnerProof {
            prover,
            lock,
            owner,
        } = owner_proof;
        (prover, lock, owner)
    }

    public(package) fun issue(prover: ID, lock: ID, owner: address): OwnerProof {
        OwnerProof {
            prover,
            lock,
            owner,
        }
    }
}


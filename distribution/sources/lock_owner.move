module distribution::lock_owner {
    public struct OwnerProof {
        prover: sui::object::ID,
        lock: sui::object::ID,
        owner: address,
    }

    public fun consume(owner_proof: OwnerProof): (sui::object::ID, sui::object::ID, address) {
        let OwnerProof {
            prover,
            lock,
            owner,
        } = owner_proof;
        (prover, lock, owner)
    }

    public(package) fun issue(prover: sui::object::ID, lock: sui::object::ID, owner: address): OwnerProof {
        OwnerProof {
            prover,
            lock,
            owner,
        }
    }
}


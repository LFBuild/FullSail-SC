module distribution::lock_owner {
    public struct OwnerProof {
        prover: sui::object::ID,
        lock: sui::object::ID,
        owner: address,
    }
    
    public fun consume(arg0: OwnerProof) : (sui::object::ID, sui::object::ID, address) {
        let OwnerProof {
            prover : v0,
            lock   : v1,
            owner  : v2,
        } = arg0;
        (v0, v1, v2)
    }
    
    public(package) fun issue(arg0: sui::object::ID, arg1: sui::object::ID, arg2: address) : OwnerProof {
        OwnerProof{
            prover : arg0, 
            lock   : arg1, 
            owner  : arg2,
        }
    }
    
    // decompiled from Move bytecode v6
}


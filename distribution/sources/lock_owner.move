module 0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1::lock_owner {
    struct OwnerProof {
        prover: 0x2::object::ID,
        lock: 0x2::object::ID,
        owner: address,
    }
    
    public fun consume(arg0: OwnerProof) : (0x2::object::ID, 0x2::object::ID, address) {
        let OwnerProof {
            prover : v0,
            lock   : v1,
            owner  : v2,
        } = arg0;
        (v0, v1, v2)
    }
    
    public(friend) fun issue(arg0: 0x2::object::ID, arg1: 0x2::object::ID, arg2: address) : OwnerProof {
        OwnerProof{
            prover : arg0, 
            lock   : arg1, 
            owner  : arg2,
        }
    }
    
    // decompiled from Move bytecode v6
}


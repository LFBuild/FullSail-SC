module vault::vault_acl {
    use sui::linked_table::{Self, LinkedTable};

    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const EInvalidRole: u64 = 939729457959745944;
    const EMemberNotFound: u64 = 943957943929212325;
    
    const U128_MAX: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    public struct ACL has store {
        permissions: LinkedTable<address, u128>,
    }
    
    public struct Member has copy, drop, store {
        address: address,
        permission: u128,
    }

    public fun notices(): (vector<u8>, vector<u8>) {
        (COPYRIGHT_NOTICE, PATENT_NOTICE)
    }
    
    public fun new(ctx: &mut sui::tx_context::TxContext) : ACL {
        ACL{permissions: linked_table::new(ctx)}
    }
    
    public fun add_role(acl: &mut ACL, member: address, role: u8) {
        assert!(role < 128, EInvalidRole);
        if (acl.permissions.contains(member)) {
            let permission = acl.permissions.borrow_mut(member);
            *permission = *permission | (1 << role);
        } else {
            acl.permissions.push_back(member, 1 << role);
        };
    }
    
    public fun get_members(acl: &ACL) : vector<Member> {
        let mut members = std::vector::empty<Member>(); 
        let mut head = acl.permissions.front();
        while (std::option::is_some<address>(head)) {
            let member_addr = *std::option::borrow<address>(head);
            let permission = acl.permissions.borrow(member_addr);
            let member = Member{
                address    : member_addr, 
                permission : *permission,
            };
            std::vector::push_back<Member>(&mut members, member);
            head = acl.permissions.next(member_addr);
        };
        members
    }
    
    public fun get_permission(acl: &ACL, member: address) : u128 {
        if (!acl.permissions.contains(member)) {
            0
        } else {
            *acl.permissions.borrow(member)
        }
    }
    
    public fun has_role(acl: &ACL, member: address, role: u8) : bool {
        assert!(role < 128, EInvalidRole);
        acl.permissions.contains(member) 
        && 
        (*acl.permissions.borrow(member) & (1 << role) > 0)
    }
    
    public fun remove_member(acl: &mut ACL, member: address) {
        assert!(acl.permissions.contains(member), EMemberNotFound);
        acl.permissions.remove(member); 
    }
    
    public fun remove_role(acl: &mut ACL, member: address, role: u8) {
        assert!(role < 128, EInvalidRole);
        assert!(acl.permissions.contains(member), EMemberNotFound);
        let permission = acl.permissions.borrow_mut(member);
        *permission = *permission & (U128_MAX - (1 << role));
    }
    
    public fun set_roles(acl: &mut ACL, member: address, roles: u128) {
        if (acl.permissions.contains(member)) {
            *acl.permissions.borrow_mut(member) = roles;
        } else {
            acl.permissions.push_back(member, roles);
        };
    }
}


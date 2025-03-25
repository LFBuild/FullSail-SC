module clmm_pool::acl {
    public struct ACL has store {
        permissions: move_stl::linked_table::LinkedTable<address, u128>,
    }

    public struct Member has copy, drop, store {
        address: address,
        permission: u128,
    }

    public fun new(ctx: &mut sui::tx_context::TxContext): ACL {
        ACL { permissions: move_stl::linked_table::new<address, u128>(ctx) }
    }

    public fun add_role(acl: &mut ACL, member_addr: address, role: u8) {
        assert!(role < 128, 1);
        if (move_stl::linked_table::contains<address, u128>(&acl.permissions, member_addr)) {
            let permission = move_stl::linked_table::borrow_mut<address, u128>(&mut acl.permissions, member_addr);
            *permission = *permission | 1 << role;
        } else {
            move_stl::linked_table::push_back<address, u128>(&mut acl.permissions, member_addr, 1 << role);
        };
    }

    public fun get_members(acl: &ACL): vector<Member> {
        let mut members = std::vector::empty<Member>();
        let mut current_addr = move_stl::linked_table::head<address, u128>(&acl.permissions);
        while (std::option::is_some<address>(&current_addr)) {
            let addr = *std::option::borrow<address>(&current_addr);
            let node = move_stl::linked_table::borrow_node<address, u128>(&acl.permissions, addr);
            let member = Member {
                address: addr,
                permission: *move_stl::linked_table::borrow_value<address, u128>(node),
            };
            std::vector::push_back<Member>(&mut members, member);
            current_addr = move_stl::linked_table::next<address, u128>(node);
        };
        members
    }

    public fun get_permission(acl: &ACL, member_addr: address): u128 {
        if (!move_stl::linked_table::contains<address, u128>(&acl.permissions, member_addr)) {
            0
        } else {
            *move_stl::linked_table::borrow<address, u128>(&acl.permissions, member_addr)
        }
    }
    
    public fun has_role(acl: &ACL, member_addr: address, role: u8): bool {
        assert!(role < 128, 1);
        move_stl::linked_table::contains<address, u128>(
            &acl.permissions,
            member_addr
        ) && *move_stl::linked_table::borrow<address, u128>(&acl.permissions, member_addr) & 1 << role > 0
    }

    public fun remove_member(acl: &mut ACL, member_addr: address) {
        if (move_stl::linked_table::contains<address, u128>(&acl.permissions, member_addr)) {
            move_stl::linked_table::remove<address, u128>(&mut acl.permissions, member_addr);
        };
    }

    public fun remove_role(acl: &mut ACL, member_addr: address, role: u8) {
        assert!(role < 128, 1);
        if (move_stl::linked_table::contains<address, u128>(&acl.permissions, member_addr)) {
            let permission = move_stl::linked_table::borrow_mut<address, u128>(&mut acl.permissions, member_addr);
            if (*permission & 1 << role > 0) {
                *permission = *permission - (1 << role);
            };
        };
    }

    public fun set_roles(acl: &mut ACL, member_addr: address, permission: u128) {
        if (move_stl::linked_table::contains<address, u128>(&acl.permissions, member_addr)) {
            *move_stl::linked_table::borrow_mut<address, u128>(&mut acl.permissions, member_addr) = permission;
        } else {
            move_stl::linked_table::push_back<address, u128>(&mut acl.permissions, member_addr, permission);
        };
    }

    // decompiled from Move bytecode v6
}


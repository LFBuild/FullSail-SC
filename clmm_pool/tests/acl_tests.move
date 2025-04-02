#[test_only]
module clmm_pool::acl_tests {
    use clmm_pool::acl::{Self, ACL, Member};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    #[test]
    fun test_acl_creation() {
        // let mut ctx = tx_context::dummy();
        // let mut acl = acl::new(&mut ctx);
        // assert!(std::vector::length(&acl::get_members(&acl)) == 0, 0);
        // transfer::share_object(acl);
    }

    // #[test]
    // fun test_add_and_check_role() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Добавляем роль 0 (Pool Manager)
    //     acl::add_role(&mut acl, member, 0);
    //     assert!(acl::has_role(&acl, member, 0), 1);
    //     assert!(!acl::has_role(&acl, member, 1), 2);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_remove_role() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Добавляем и затем удаляем роль
    //     acl::add_role(&mut acl, member, 0);
    //     assert!(acl::has_role(&acl, member, 0), 1);
    //     acl::remove_role(&mut acl, member, 0);
    //     assert!(!acl::has_role(&acl, member, 0), 2);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_multiple_roles() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Добавляем несколько ролей
    //     acl::add_role(&mut acl, member, 0);
    //     acl::add_role(&mut acl, member, 1);
    //     acl::add_role(&mut acl, member, 2);

    //     assert!(acl::has_role(&acl, member, 0), 1);
    //     assert!(acl::has_role(&acl, member, 1), 2);
    //     assert!(acl::has_role(&acl, member, 2), 3);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_remove_member() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Добавляем роли и удаляем члена
    //     acl::add_role(&mut acl, member, 0);
    //     acl::add_role(&mut acl, member, 1);
    //     assert!(acl::has_role(&acl, member, 0), 1);
    //     assert!(acl::has_role(&acl, member, 1), 2);

    //     acl::remove_member(&mut acl, member);
    //     assert!(!acl::has_role(&acl, member, 0), 3);
    //     assert!(!acl::has_role(&acl, member, 1), 4);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_set_roles() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Устанавливаем роли через битовую маску
    //     let permission = 1 << 0 | 1 << 1; // Роли 0 и 1
    //     acl::set_roles(&mut acl, member, permission);

    //     assert!(acl::has_role(&acl, member, 0), 1);
    //     assert!(acl::has_role(&acl, member, 1), 2);
    //     assert!(!acl::has_role(&acl, member, 2), 3);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_get_members() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member1 = @0x2;
    //     let member2 = @0x3;

    //     // Добавляем двух членов с разными ролями
    //     acl::add_role(&mut acl, member1, 0);
    //     acl::add_role(&mut acl, member2, 1);

    //     let members = acl::get_members(&acl);
    //     assert!(std::vector::length(&members) == 2, 1);

    //     // Проверяем права членов
    //     assert!(acl::get_permission(&acl, member1) == 1 << 0, 2);
    //     assert!(acl::get_permission(&acl, member2) == 1 << 1, 3);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // fun test_get_permission() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Проверяем получение прав для несуществующего члена
    //     assert!(acl::get_permission(&acl, member) == 0, 1);

    //     // Добавляем роли и проверяем права
    //     acl::add_role(&mut acl, member, 0);
    //     acl::add_role(&mut acl, member, 1);
    //     assert!(acl::get_permission(&acl, member) == (1 << 0 | 1 << 1), 2);
    //     transfer::share_object(acl);
    // }

    // #[test]
    // #[expected_failure(abort_code = 1)]
    // fun test_invalid_role() {
    //     let mut ctx = tx_context::dummy();
    //     let mut acl = acl::new(&mut ctx);
    //     let member = @0x2;

    //     // Пытаемся добавить невалидную роль (>= 128)
    //     acl::add_role(&mut acl, member, 128);
    //     transfer::share_object(acl);
    // }
}

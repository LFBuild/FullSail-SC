module distribution::exercise_o_sail;
use sail_token::o_coin;
use distribution::common;

/// This module is used to ensure access control in methods
/// that exercise oSAIL option. The responsibility of voting_escrow contract
/// is to determine if oSAIL is eligible to be exercised and discount percent.
/// Later the minter contract actually exercises oSAIL and burns it
/// given the permission from voting_escrow contract.

const EIssueProofDiscountTooLarge: u64 = 4700868122737303000;
const EIssueProofDiscountTooSmall: u64 = 1852565901933545000;

public struct ExerciseOSailProof {
    amount: u64,
    o_sail_id: ID,
    discount_percent: u64,
}

public fun consume(exercise_o_sail_proof: ExerciseOSailProof): (u64, ID, u64) {
    let ExerciseOSailProof {
        amount,
        o_sail_id,
        discount_percent,
    } = exercise_o_sail_proof;

    (amount, o_sail_id, discount_percent)
}

public(package) fun issue<SailCoinType>(
    o_sail: &o_coin::OCoin<SailCoinType>,
    discount_percent: u64
): ExerciseOSailProof {
    assert!(discount_percent <= common::max_o_sail_discount(), EIssueProofDiscountTooLarge);
    assert!(discount_percent >= common::min_o_sail_discount(), EIssueProofDiscountTooSmall);

    ExerciseOSailProof {
        amount: o_sail.value(),
        o_sail_id: sui::object::id(o_sail),
        discount_percent,
    }
}
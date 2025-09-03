/// © 2025 Metabyte Labs, Inc.  All Rights Reserved.
/// 
/// The emergency_council module provides a safety mechanism for the ve(3,3) DEX system.
/// In a ve(3,3) decentralized exchange, governance is primarily controlled by token holders
/// who lock their tokens to gain voting power. However, emergency situations may arise that 
/// require immediate action to protect the protocol and its users.
///
/// The Emergency Council serves several critical purposes:
/// 1. Security oversight - Authorized to take swift action in case of vulnerabilities or attacks
/// 2. Circuit breaker functionality - Can disable compromised or malfunctioning components (gauges)
/// 3. Risk management - Provides a layer of protection against governance attacks or exploits
/// 4. Emergency intervention - Ability to freeze problematic liquidity pools or voting mechanisms
///
/// Unlike regular governance which relies on proposal submission, voting periods, and execution delays,
/// the Emergency Council can act immediately when needed. This is crucial for maintaining system 
/// integrity in a DeFi environment where rapid response to threats is essential.
///
/// The council's powers are deliberately limited to specific safety-oriented functions like
/// killing/reviving gauges and deactivating managed locks, ensuring it cannot override normal
/// governance for routine protocol decisions.
module voting_escrow::emergency_council {
    use sui::package;

    #[allow(unused_const)]
    const COPYRIGHT_NOTICE: vector<u8> = b"© 2025 Metabyte Labs, Inc.  All Rights Reserved.";
    #[allow(unused_const)]
    const PATENT_NOTICE: vector<u8> = b"Patent pending - U.S. Patent Application No. 63/861,982";

    const EEmergencyCouncilDoesNotMatchVoter: u64 = 370065501622769400;
    const EEmergencyCouncilDoesNotMatchMinter: u64 = 715059658219014000;
    const EEmergencyCouncilDoesNotMatchVotingEscrow: u64 = 623276780904261200;
    const ECreateEmergencyCouncilCapInvalidPublisher: u64 = 652407077368530000;

    /// The Emergency Council Capability (EmergencyCouncilCap) is a privileged object that 
    /// grants special administrative powers to address emergency situations in the protocol.
    ///
    /// This capability enables its holder to:
    /// - Kill gauges (deactivate pools) in case of exploits or vulnerabilities
    /// - Revive previously killed gauges once issues are resolved
    /// - Deactivate managed locks if compromised or being misused
    /// - Execute other emergency safety measures when regular governance would be too slow
    ///
    /// The capability is tied to a specific voter ID to ensure authorized use only within
    /// the intended voter contract instance, preventing misuse across different parts of the system.
    public struct EmergencyCouncilCap has store, key {
        id: UID,
        voter: ID,
        minter: ID,
        voting_escrow: ID,
    }

    public struct EMERGENCY_COUNCIL has drop {}

    public fun validate_emergency_council_voter_id(emergency_council_cap: &EmergencyCouncilCap, voter_id: ID) {
        assert!(emergency_council_cap.voter == voter_id, EEmergencyCouncilDoesNotMatchVoter);
    }

    public fun validate_emergency_council_minter_id(emergency_council_cap: &EmergencyCouncilCap, minter_id: ID) {
        assert!(emergency_council_cap.minter == minter_id, EEmergencyCouncilDoesNotMatchMinter);
    }

    public fun validate_emergency_council_voting_escrow_id(emergency_council_cap: &EmergencyCouncilCap, voting_escrow_id: ID) {
        assert!(emergency_council_cap.voting_escrow == voting_escrow_id, EEmergencyCouncilDoesNotMatchVotingEscrow);
    }

    fun init(otw: EMERGENCY_COUNCIL, ctx: &mut TxContext) {
        package::claim_and_keep<EMERGENCY_COUNCIL>(otw, ctx);
    }

    public fun create_cap(
        publisher: &sui::package::Publisher,
        voter_id: ID,
        minter_id: ID,
        voting_escrow_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(publisher.from_module<EMERGENCY_COUNCIL>(), ECreateEmergencyCouncilCapInvalidPublisher);
        let emergency_council_cap = EmergencyCouncilCap {
            id: object::new(ctx),
            voter: voter_id,
            minter: minter_id,
            voting_escrow: voting_escrow_id,
        };
        
        transfer::public_transfer<EmergencyCouncilCap>(emergency_council_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun create_for_testing(
        voter_id: ID,
        minter_id: ID,
        voting_escrow_id: ID,
        ctx: &mut sui::tx_context::TxContext
    ): EmergencyCouncilCap {
        EmergencyCouncilCap {
            id: object::new(ctx),
            voter: voter_id,
            minter: minter_id,
            voting_escrow: voting_escrow_id,
        }
    }
}


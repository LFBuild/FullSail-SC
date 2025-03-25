module distribution::reward_authorized_cap {

    const ERewardAuthorizedCapInvalid: u64 = 9223372109869219839;

    public struct RewardAuthorizedCap has store, key {
        id: UID,
        authorized: ID,
    }

    public(package) fun create(authority_id: ID, ctx: &mut TxContext): RewardAuthorizedCap {
        RewardAuthorizedCap {
            id: object::new(ctx),
            authorized: authority_id,
        }
    }

    public fun validate(reward: &RewardAuthorizedCap, authority_id: ID) {
        assert!(reward.authorized == authority_id, ERewardAuthorizedCapInvalid);
    }
}


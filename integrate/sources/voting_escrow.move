module integrate::voting_escrow {
    public struct Summary has copy, drop, store {
        total_locked: u64,
        total_voting_power: u64,
        total_voted_power: u64,
        rebase_apr: u64,
        current_epoch_end: u64,
        current_epoch_vote_end: u64,
        team_emission_rate: u64,
    }
    
    public struct LockSummary has copy, drop, store {
        voting_power: u64,
        reward_distributor_claimable: u64,
        fee_incentive_total: u64,
    }
    
    public entry fun transfer<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: distribution::voting_escrow::Lock, arg2: address, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::transfer<T0>(arg1, arg0, arg2, arg3, arg4);
    }
    
    public fun max_bps() : u64 {
        100000000
    }
    
    public entry fun create<T0>(arg0: &sui::package::Publisher, arg1: sui::object::ID, arg2: &sui::clock::Clock, arg3: &mut sui::tx_context::TxContext) {
        sui::transfer::public_share_object<distribution::voting_escrow::VotingEscrow<T0>>(distribution::voting_escrow::create<T0>(arg0, arg1, arg2, arg3));
    }
    
    public entry fun create_lock<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: vector<sui::coin::Coin<T0>>, arg2: u64, arg3: bool, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::create_lock<T0>(arg0, integrate::utils::merge_coins<T0>(arg1, arg5), arg2, arg3, arg4, arg5);
    }
    
    public entry fun increase_amount<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: &mut distribution::voting_escrow::Lock, arg2: vector<sui::coin::Coin<T0>>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::increase_amount<T0>(arg0, arg1, integrate::utils::merge_coins<T0>(arg2, arg4), arg3, arg4);
    }
    
    public entry fun increase_unlock_time<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: &mut distribution::voting_escrow::Lock, arg2: u64, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::increase_unlock_time<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public entry fun lock_permanent<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: &mut distribution::voting_escrow::Lock, arg2: &sui::clock::Clock, arg3: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::lock_permanent<T0>(arg0, arg1, arg2, arg3);
    }
    
    public entry fun unlock_permanent<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: &mut distribution::voting_escrow::Lock, arg2: &sui::clock::Clock, arg3: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::unlock_permanent<T0>(arg0, arg1, arg2, arg3);
    }
    
    public entry fun create_lock_single_coin<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: sui::coin::Coin<T0>, arg2: u64, arg3: bool, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        let mut v0 = std::vector::empty<sui::coin::Coin<T0>>();
        std::vector::push_back<sui::coin::Coin<T0>>(&mut v0, arg1);
        create_lock<T0>(arg0, v0, arg2, arg3, arg4, arg5);
    }
    
    public entry fun increase_amount_single_coin<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: &mut distribution::voting_escrow::Lock, arg2: sui::coin::Coin<T0>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::increase_amount<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public entry fun lock_summary<T0>(arg0: &distribution::voter::Voter<T0>, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::reward_distributor::RewardDistributor<T0>, arg3: sui::object::ID, arg4: &sui::clock::Clock) {
        sui::event::emit<LockSummary>(lock_summary_internal<T0>(arg0, arg1, arg2, arg3, arg4));
    }
    
    fun lock_summary_internal<T0>(arg0: &distribution::voter::Voter<T0>, arg1: &distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::reward_distributor::RewardDistributor<T0>, arg3: sui::object::ID, arg4: &sui::clock::Clock) : LockSummary {
        let mut v0 = 0;
        let v1 = distribution::voter::voted_pools<T0>(arg0, arg3);
        let mut v2 = 0;
        while (v2 < std::vector::length<sui::object::ID>(&v1)) {
            let v3 = distribution::voter::pool_to_gauge<T0>(arg0, *std::vector::borrow<sui::object::ID>(&v1, v2));
            let v4 = v0 + distribution::fee_voting_reward::earned<T0>(distribution::voter::borrow_fee_voting_reward<T0>(arg0, v3), arg3, arg4);
            v0 = v4 + distribution::bribe_voting_reward::earned<T0>(distribution::voter::borrow_bribe_voting_reward<T0>(arg0, v3), arg3, arg4);
            v2 = v2 + 1;
        };
        LockSummary{
            voting_power                 : distribution::voting_escrow::balance_of_nft_at<T0>(arg1, arg3, sui::clock::timestamp_ms(arg4) / 1000), 
            reward_distributor_claimable : distribution::reward_distributor::claimable<T0>(arg2, arg1, arg3), 
            fee_incentive_total          : v0,
        }
    }
    
    public entry fun merge_locks<T0>(arg0: &mut distribution::voting_escrow::VotingEscrow<T0>, arg1: distribution::voting_escrow::Lock, arg2: &mut distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voting_escrow::merge<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public entry fun summary<T0>(arg0: &distribution::minter::Minter<T0>, arg1: &distribution::voter::Voter<T0>, arg2: &distribution::voting_escrow::VotingEscrow<T0>, arg3: &sui::clock::Clock) {
        let v0 = distribution::common::current_timestamp(arg3);
        let v1 = distribution::voting_escrow::total_locked<T0>(arg2);
        let v2 = distribution::minter::epoch_emissions<T0>(arg0);
        let v3 = distribution::minter::calculate_rebase_growth(v2, distribution::minter::total_supply<T0>(arg0), v1);
        let v4 = Summary{
            total_locked           : v1, 
            total_voting_power     : distribution::voting_escrow::total_supply_at<T0>(arg2, distribution::common::current_timestamp(arg3)), 
            total_voted_power      : distribution::voter::total_weight<T0>(arg1), 
            rebase_apr             : integer_mate::full_math_u64::mul_div_floor(v3, max_bps(), integer_mate::full_math_u64::mul_div_floor(v2 + v3, distribution::minter::max_bps(), distribution::minter::max_bps() - distribution::minter::team_emission_rate<T0>(arg0))), 
            current_epoch_end      : distribution::common::epoch_next(v0), 
            current_epoch_vote_end : distribution::common::epoch_vote_end(v0), 
            team_emission_rate     : distribution::minter::team_emission_rate<T0>(arg0),
        };
        sui::event::emit<Summary>(v4);
    }
    
    // decompiled from Move bytecode v6
}


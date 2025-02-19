module distribution::voter {
    public struct VOTER has drop {
    }
    
    public struct PoolID has copy, drop, store {
        id: sui::object::ID,
    }
    
    public struct LockID has copy, drop, store {
        id: sui::object::ID,
    }
    
    public struct GaugeID has copy, drop, store {
        id: sui::object::ID,
    }
    
    public struct GaugeRepresent has drop, store {
        gauger_id: sui::object::ID,
        pool_id: sui::object::ID,
        weight: u64,
        last_reward_time: u64,
    }
    
    public struct Voter<phantom T0> has store, key {
        id: sui::object::UID,
        flag_distribution: bool,
        governors: sui::vec_set::VecSet<sui::object::ID>,
        epoch_governors: sui::vec_set::VecSet<sui::object::ID>,
        emergency_council: sui::object::ID,
        is_alive: sui::table::Table<GaugeID, bool>,
        total_weight: u64,
        used_weights: sui::table::Table<LockID, u64>,
        pools: vector<PoolID>,
        pool_to_gauger: sui::table::Table<PoolID, GaugeID>,
        gauge_represents: sui::table::Table<GaugeID, GaugeRepresent>,
        votes: sui::table::Table<LockID, sui::table::Table<PoolID, u64>>,
        rewards: sui::table::Table<GaugeID, sui::balance::Balance<T0>>,
        weights: sui::table::Table<GaugeID, u64>,
        epoch: u64,
        voter_cap: distribution::voter_cap::VoterCap,
        balances: sui::bag::Bag,
        index: u128,
        supply_index: sui::table::Table<GaugeID, u128>,
        claimable: sui::table::Table<GaugeID, u64>,
        is_whitelisted_token: sui::table::Table<std::type_name::TypeName, bool>,
        is_whitelisted_nft: sui::table::Table<LockID, bool>,
        max_voting_num: u64,
        last_voted: sui::table::Table<LockID, u64>,
        pool_vote: sui::table::Table<LockID, vector<PoolID>>,
        gauge_to_fee_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        gauge_to_fee: sui::table::Table<GaugeID, distribution::fee_voting_reward::FeeVotingReward>,
        gauge_to_bribe_authorized_cap: distribution::reward_authorized_cap::RewardAuthorizedCap,
        gauge_to_bribe: sui::table::Table<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>,
    }
    
    public struct EventNotifyReward has copy, drop, store {
        notifier: sui::object::ID,
        token: std::type_name::TypeName,
        amount: u64,
    }
    
    public struct EventExtractClaimable has copy, drop, store {
        gauger: sui::object::ID,
        amount: u64,
    }
    
    public struct EventWhitelistToken has copy, drop, store {
        sender: address,
        token: std::type_name::TypeName,
        listed: bool,
    }
    
    public struct EventWhitelistNFT has copy, drop, store {
        sender: address,
        id: sui::object::ID,
        listed: bool,
    }
    
    public struct EventKillGauge has copy, drop, store {
        id: sui::object::ID,
    }
    
    public struct EventReviveGauge has copy, drop, store {
        id: sui::object::ID,
    }
    
    public struct EventVoted has copy, drop, store {
        sender: address,
        pool: sui::object::ID,
        lock: sui::object::ID,
        voting_weight: u64,
        pool_weight: u64,
    }
    
    public struct EventAbstained has copy, drop, store {
        sender: address,
        pool: sui::object::ID,
        lock: sui::object::ID,
        votes: u64,
        pool_weight: u64,
    }
    
    public struct EventAddGovernor has copy, drop, store {
        who: address,
    }
    
    public struct EventRemoveGovernor has copy, drop, store {
        who: address,
    }
    
    public struct EventAddEpochGovernor has copy, drop, store {
        who: address,
    }
    
    public struct EventRemoveEpochGovernor has copy, drop, store {
        who: address,
    }
    
    public fun create<T0>(_arg0: &sui::package::Publisher, arg1: vector<std::type_name::TypeName>, arg2: &mut sui::tx_context::TxContext) : (Voter<T0>, distribution::notify_reward_cap::NotifyRewardCap) {
        let v0 = sui::object::new(arg2);
        let v1 = *sui::object::uid_as_inner(&v0);
        let mut v2 = Voter<T0>{
            id                            : v0, 
            flag_distribution             : false, 
            governors                     : sui::vec_set::empty<sui::object::ID>(), 
            epoch_governors               : sui::vec_set::empty<sui::object::ID>(), 
            emergency_council             : sui::object::id_from_address(@0x0), 
            is_alive                      : sui::table::new<GaugeID, bool>(arg2), 
            total_weight                  : 0, 
            used_weights                  : sui::table::new<LockID, u64>(arg2), 
            pools                         : std::vector::empty<PoolID>(), 
            pool_to_gauger                : sui::table::new<PoolID, GaugeID>(arg2), 
            gauge_represents              : sui::table::new<GaugeID, GaugeRepresent>(arg2), 
            votes                         : sui::table::new<LockID, sui::table::Table<PoolID, u64>>(arg2), 
            rewards                       : sui::table::new<GaugeID, sui::balance::Balance<T0>>(arg2), 
            weights                       : sui::table::new<GaugeID, u64>(arg2), 
            epoch                         : 0, 
            voter_cap                     : distribution::voter_cap::create_voter_cap(v1, arg2), 
            balances                      : sui::bag::new(arg2), 
            index                         : 0, 
            supply_index                  : sui::table::new<GaugeID, u128>(arg2), 
            claimable                     : sui::table::new<GaugeID, u64>(arg2), 
            is_whitelisted_token          : sui::table::new<std::type_name::TypeName, bool>(arg2), 
            is_whitelisted_nft            : sui::table::new<LockID, bool>(arg2), 
            max_voting_num                : 10, 
            last_voted                    : sui::table::new<LockID, u64>(arg2), 
            pool_vote                     : sui::table::new<LockID, vector<PoolID>>(arg2), 
            gauge_to_fee_authorized_cap   : distribution::reward_authorized_cap::create(v1, arg2), 
            gauge_to_fee                  : sui::table::new<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(arg2), 
            gauge_to_bribe_authorized_cap : distribution::reward_authorized_cap::create(v1, arg2), 
            gauge_to_bribe                : sui::table::new<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(arg2),
        };
        let mut v3 = 0;
        while (v3 < std::vector::length<std::type_name::TypeName>(&arg1)) {
            whitelist_token_internal<T0>(&mut v2, *std::vector::borrow<std::type_name::TypeName>(&arg1, v3), true, sui::tx_context::sender(arg2));
            v3 = v3 + 1;
        };
        let voter_id = sui::object::id<Voter<T0>>(&v2);
        (v2, distribution::notify_reward_cap::create_internal(voter_id, arg2))
    }
    
    public fun deposit_managed<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &mut distribution::voting_escrow::Lock, arg3: &mut distribution::voting_escrow::Lock, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        assert_only_new_epoch<T0>(arg0, v0, arg4);
        assert!(distribution::voting_escrow::owner_of<T0>(arg1, v0.id) == sui::tx_context::sender(arg5), 9223375275260116991);
        assert!(!distribution::voting_escrow::deactivated<T0>(arg1, v0.id), 9223375275262279714);
        let v1 = distribution::voting_escrow::id_to_managed<T0>(arg1, v0.id);
        assert!(v1 == sui::object::id<distribution::voting_escrow::Lock>(arg3), 9223375292439986175);
        let v2 = distribution::common::current_timestamp(arg4);
        assert!(v2 <= distribution::common::epoch_vote_end(v2), 9223375301033263156);
        if (sui::table::contains<LockID, u64>(&arg0.last_voted, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.last_voted, v0);
        };
        sui::table::add<LockID, u64>(&mut arg0.last_voted, v0, v2);
        distribution::voting_escrow::deposit_managed<T0>(arg1, &arg0.voter_cap, arg2, v1, arg4, arg5);
        let balance = distribution::voting_escrow::balance_of_nft_at<T0>(arg1, v0.id, v2);
        poke_internal<T0>(arg0, arg1, arg3, balance, arg4, arg5);
    }
    
    public fun withdraw_managed<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &mut distribution::voting_escrow::Lock, arg3: &mut distribution::voting_escrow::Lock, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        assert_only_new_epoch<T0>(arg0, v0, arg4);
        let v1 = distribution::voting_escrow::id_to_managed<T0>(arg1, v0.id);
        assert!(v1 == sui::object::id<distribution::voting_escrow::Lock>(arg3), 9223375378339332095);
        let v2 = distribution::voting_escrow::balance_of_nft_at<T0>(arg1, v1, distribution::common::current_timestamp(arg4));
        if (v2 == 0) {
            reset_internal<T0>(arg0, arg1, arg3, arg4, arg5);
            if (sui::table::contains<LockID, u64>(&arg0.last_voted, into_lock_id(v1))) {
                sui::table::remove<LockID, u64>(&mut arg0.last_voted, into_lock_id(v1));
            };
        } else {
            poke_internal<T0>(arg0, arg1, arg3, v2, arg4, arg5);
        };
        let proof = distribution::voting_escrow::owner_proof<T0>(arg1, arg2, arg5);
        let balance = distribution::voting_escrow::withdraw_managed<T0>(arg1, &arg0.voter_cap, v0.id, proof, arg4, arg5);
        sui::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::from_balance<T0>(balance, arg5), sui::tx_context::sender(arg5));
    }
    
    public fun add_epoch_governor<T0>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: address, arg3: &mut sui::tx_context::TxContext) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        sui::transfer::public_transfer<distribution::voter_cap::EpochGovernorCap>(distribution::voter_cap::create_epoch_governor_cap(sui::object::id<Voter<T0>>(arg0), arg3), arg2);
        let v0 = EventAddEpochGovernor{who: arg2};
        sui::event::emit<EventAddEpochGovernor>(v0);
    }
    
    public fun add_governor<T0>(arg0: &mut Voter<T0>, _arg1: &sui::package::Publisher, arg2: address, arg3: &mut sui::tx_context::TxContext) {
        sui::transfer::public_transfer<distribution::voter_cap::GovernorCap>(distribution::voter_cap::create_governor_cap(sui::object::id<Voter<T0>>(arg0), arg2, arg3), arg2);
        sui::vec_set::insert<sui::object::ID>(&mut arg0.governors, sui::object::id_from_address(arg2));
        let v0 = EventAddGovernor{who: arg2};
        sui::event::emit<EventAddGovernor>(v0);
    }
    
    fun assert_only_new_epoch<T0>(arg0: &Voter<T0>, arg1: LockID, arg2: &sui::clock::Clock) {
        let v0 = distribution::common::current_timestamp(arg2);
        assert!(!sui::table::contains<LockID, u64>(&arg0.last_voted, arg1) || distribution::common::epoch_start(v0) > *sui::table::borrow<LockID, u64>(&arg0.last_voted, arg1), 9223373329641701404);
        assert!(v0 > distribution::common::epoch_vote_start(v0), 9223373333936799774);
    }
    
    public fun borrow_bribe_voting_reward<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : &distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&arg0.gauge_to_bribe, into_gauge_id(arg1))
    }
    
    public fun borrow_bribe_voting_reward_mut<T0>(arg0: &mut Voter<T0>, arg1: sui::object::ID) : &mut distribution::bribe_voting_reward::BribeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&mut arg0.gauge_to_bribe, into_gauge_id(arg1))
    }
    
    public fun borrow_fee_voting_reward<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : &distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&arg0.gauge_to_fee, into_gauge_id(arg1))
    }
    
    public fun borrow_fee_voting_reward_mut<T0>(arg0: &mut Voter<T0>, arg1: sui::object::ID) : &mut distribution::fee_voting_reward::FeeVotingReward {
        sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, into_gauge_id(arg1))
    }
    
    public fun borrow_voter_cap<T0>(arg0: &Voter<T0>, arg1: &distribution::notify_reward_cap::NotifyRewardCap) : &distribution::voter_cap::VoterCap {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        &arg0.voter_cap
    }
    
    fun check_vote<T0>(arg0: &Voter<T0>, arg1: &vector<sui::object::ID>, arg2: &vector<u64>) {
        let v0 = std::vector::length<sui::object::ID>(arg1);
        assert!(v0 == std::vector::length<u64>(arg2), 9223374162864308236);
        assert!(v0 <= arg0.max_voting_num, 9223374167160586272);
        let mut v1 = 0;
        while (v1 < v0) {
            assert!(sui::table::contains<PoolID, GaugeID>(&arg0.pool_to_gauger, into_pool_id(*std::vector::borrow<sui::object::ID>(arg1, v1))), 9223374184339275790);
            assert!(*std::vector::borrow<u64>(arg2, v1) <= 10000, 9223374188634374160);
            v1 = v1 + 1;
        };
    }
    
    public fun claim_voting_bribe<T0, T1>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2)));
        let mut v1 = 0;
        while (v1 < std::vector::length<PoolID>(v0)) {
            distribution::bribe_voting_reward::get_reward<T0, T1>(sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&mut arg0.gauge_to_bribe, *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, *std::vector::borrow<PoolID>(v0, v1))), arg1, arg2, arg3, arg4);
            v1 = v1 + 1;
        };
    }
    
    public fun claim_voting_fee_reward<T0, T1>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2)));
        let mut v1 = 0;
        while (v1 < std::vector::length<PoolID>(v0)) {
            distribution::fee_voting_reward::get_reward<T0, T1>(sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, *std::vector::borrow<PoolID>(v0, v1))), arg1, arg2, arg3, arg4);
            v1 = v1 + 1;
        };
    }
    
    public fun claimable<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : u64 {
        let v0 = into_gauge_id(arg1);
        if (sui::table::contains<GaugeID, u64>(&arg0.claimable, v0)) {
            *sui::table::borrow<GaugeID, u64>(&arg0.claimable, v0)
        } else {
            0
        }
    }
    
    public fun create_gauge<T0, T1, T2>(arg0: &mut Voter<T2>, arg1: &gauge_cap::gauge_cap::CreateCap, arg2: &distribution::voter_cap::GovernorCap, arg3: &distribution::voting_escrow::VotingEscrow<T2>, arg4: &mut clmm_pool::pool::Pool<T0, T1>, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) : distribution::gauge::Gauge<T0, T1, T2> {
        distribution::voter_cap::validate_governor_voter_id(arg2, sui::object::id<Voter<T2>>(arg0));
        assert!(is_governor<T2>(arg0, distribution::voter_cap::who(arg2)), 9223373604519346200);
        let mut v0 = return_new_gauge<T0, T1, T2>(arg1, arg4, arg6);
        let mut v1 = std::vector::empty<std::type_name::TypeName>();
        std::vector::push_back<std::type_name::TypeName>(&mut v1, std::type_name::get<T0>());
        std::vector::push_back<std::type_name::TypeName>(&mut v1, std::type_name::get<T1>());
        let v2 = sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(&v0);
        let v3 = sui::object::id<Voter<T2>>(arg0);
        let v4 = sui::object::id<distribution::voting_escrow::VotingEscrow<T2>>(arg3);
        sui::table::add<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, into_gauge_id(v2), distribution::fee_voting_reward::create(v3, v4, v2, v1, arg6));
        std::vector::push_back<std::type_name::TypeName>(&mut v1, std::type_name::get<T2>());
        sui::table::add<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&mut arg0.gauge_to_bribe, into_gauge_id(v2), distribution::bribe_voting_reward::create(v3, v4, v2, v1, arg6));
        receive_gauger<T0, T1, T2>(arg0, arg2, &mut v0, arg5, arg6);
        v0
    }
    
    public fun distribute_gauge<T0, T1, T2>(arg0: &mut Voter<T2>, arg1: &mut distribution::gauge::Gauge<T0, T1, T2>, arg2: &mut clmm_pool::pool::Pool<T0, T1>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) : u64 {
        let v0 = into_gauge_id(sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg1));
        let v1 = sui::table::borrow<GaugeID, GaugeRepresent>(&arg0.gauge_represents, v0);
        assert!(v1.pool_id == sui::object::id<clmm_pool::pool::Pool<T0, T1>>(arg2) && v1.gauger_id == v0.id, 9223375983929720831);
        let v2 = extract_claimable_for<T2>(arg0, v0.id);
        let balance = sui::balance::value<T2>(&v2);
        let (v3, v4) = distribution::gauge::notify_reward<T0, T1, T2>(arg1, &arg0.voter_cap, arg2, v2, arg3, arg4);
        let v5 = sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, v0);
        distribution::fee_voting_reward::notify_reward_amount<T0>(v5, &arg0.gauge_to_fee_authorized_cap, sui::coin::from_balance<T0>(v3, arg4), arg3, arg4);
        distribution::fee_voting_reward::notify_reward_amount<T1>(v5, &arg0.gauge_to_fee_authorized_cap, sui::coin::from_balance<T1>(v4, arg4), arg3, arg4);
        balance
    }
    
    fun extract_claimable_for<T0>(arg0: &mut Voter<T0>, arg1: sui::object::ID) : sui::balance::Balance<T0> {
        let v0 = into_gauge_id(arg1);
        update_for_internal<T0>(arg0, v0);
        let v1 = *sui::table::borrow<GaugeID, u64>(&arg0.claimable, v0);
        assert!(v1 > 604800, 9223375923800178687);
        sui::table::remove<GaugeID, u64>(&mut arg0.claimable, v0);
        sui::table::add<GaugeID, u64>(&mut arg0.claimable, v0, 0);
        let v2 = EventExtractClaimable{
            gauger : v0.id, 
            amount : v1,
        };
        sui::event::emit<EventExtractClaimable>(v2);
        sui::balance::split<T0>(sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, std::type_name::get<T0>()), v1)
    }
    
    public fun fee_voting_reward_balance<T0, T1>(arg0: &Voter<T0>, arg1: sui::object::ID) : u64 {
        distribution::fee_voting_reward::balance<T1>(sui::table::borrow<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&arg0.gauge_to_fee, into_gauge_id(arg1)))
    }
    
    public fun get_gauge_weight<T0>(arg0: &Voter<T0>, arg1: GaugeID) : u64 {
        *sui::table::borrow<GaugeID, u64>(&arg0.weights, arg1)
    }
    
    public fun get_pool_weight<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : u64 {
        get_gauge_weight<T0>(arg0, *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, into_pool_id(arg1)))
    }
    
    public fun get_total_weight<T0>(arg0: &Voter<T0>) : u64 {
        arg0.total_weight
    }
    
    public fun get_votes<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : &sui::table::Table<PoolID, u64> {
        let v0 = into_lock_id(arg1);
        assert!(sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), 9223375618857500671);
        sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0)
    }
    
    fun init(arg0: VOTER, arg1: &mut sui::tx_context::TxContext) {
        sui::package::claim_and_keep<VOTER>(arg0, arg1);
    }
    
    public(package) fun into_gauge_id(arg0: sui::object::ID) : GaugeID {
        GaugeID{id: arg0}
    }
    
    public(package) fun into_lock_id(arg0: sui::object::ID) : LockID {
        LockID{id: arg0}
    }
    
    public(package) fun into_pool_id(arg0: sui::object::ID) : PoolID {
        PoolID{id: arg0}
    }
    
    fun is_gauge_alive<T0>(arg0: &Voter<T0>, arg1: GaugeID) : bool {
        sui::table::contains<GaugeID, bool>(&arg0.is_alive, arg1) && *sui::table::borrow<GaugeID, bool>(&arg0.is_alive, arg1) == true
    }
    
    public fun is_governor<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : bool {
        sui::vec_set::contains<sui::object::ID>(&arg0.governors, &arg1)
    }
    
    public fun is_whitelisted_token<T0, T1>(arg0: &Voter<T0>) : bool {
        let v0 = std::type_name::get<T1>();
        if (sui::table::contains<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, v0)) {
            let v2 = true;
            &v2 == sui::table::borrow<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, v0)
        } else {
            false
        }
    }
    
    public fun kill_gauger<T0>(arg0: &mut Voter<T0>, arg1: &distribution::emergency_council::EmergencyCouncilCap, arg2: sui::object::ID, _arg3: &sui::clock::Clock) : sui::balance::Balance<T0> {
        distribution::emergency_council::validate_emergency_council_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = into_gauge_id(arg2);
        assert!(sui::table::contains<GaugeID, bool>(&arg0.is_alive, v0), 9223374012540190728);
        let v1 = true;
        assert!(sui::table::borrow<GaugeID, bool>(&arg0.is_alive, v0) == &v1, 9223374016835944468);
        update_for_internal<T0>(arg0, v0);
        let v2 = sui::table::remove<GaugeID, u64>(&mut arg0.claimable, v0);
        let mut v3 = sui::balance::zero<T0>();
        if (v2 > 0) {
            sui::balance::join<T0>(&mut v3, sui::balance::split<T0>(sui::bag::borrow_mut<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, std::type_name::get<T0>()), v2));
        };
        sui::table::remove<GaugeID, bool>(&mut arg0.is_alive, v0);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, false);
        let v4 = EventKillGauge{id: v0.id};
        sui::event::emit<EventKillGauge>(v4);
        v3
    }
    
    public fun notify_rewards<T0>(arg0: &mut Voter<T0>, arg1: &distribution::notify_reward_cap::NotifyRewardCap, arg2: sui::coin::Coin<T0>) {
        distribution::notify_reward_cap::validate_notify_reward_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = sui::coin::into_balance<T0>(arg2);
        let v1 = sui::balance::value<T0>(&v0);
        let v2 = std::type_name::get<T0>();
        let v3 = if (sui::bag::contains<std::type_name::TypeName>(&arg0.balances, v2)) {
            sui::bag::remove<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v2)
        } else {
            sui::balance::zero<T0>()
        };
        let mut v4 = v3;
        sui::balance::join<T0>(&mut v4, v0);
        sui::bag::add<std::type_name::TypeName, sui::balance::Balance<T0>>(&mut arg0.balances, v2, v4);
        let v5 = if (arg0.total_weight == 0) {
            1
        } else {
            arg0.total_weight
        };
        let v6 = integer_mate::full_math_u128::mul_div_floor(v1 as u128, 18446744073709551616, v5 as u128);
        if (v6 > 0) {
            arg0.index = arg0.index + v6;
        };
        let v7 = EventNotifyReward{
            notifier : distribution::notify_reward_cap::who(arg1), 
            token    : v2, 
            amount   : v1,
        };
        sui::event::emit<EventNotifyReward>(v7);
    }
    
    public fun poke<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = distribution::common::current_timestamp(arg3);
        assert!(v0 > distribution::common::epoch_vote_start(v0), 9223374433448427550);
        let voting_power = distribution::voting_escrow::get_voting_power<T0>(arg1, arg2, arg3);
        poke_internal<T0>(arg0, arg1, arg2, voting_power, arg3, arg4);
    }
    
    fun poke_internal<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: u64, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        let v1 = if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
            std::vector::length<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0))
        } else {
            0
        };
        if (v1 > 0) {
            let mut v2 = std::vector::empty<u64>();
            let mut v3 = 0;
            let v4 = sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0);
            let mut v5 = std::vector::empty<sui::object::ID>();
            assert!(sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), 9223374510758756396);
            while (v3 < v1) {
                std::vector::push_back<sui::object::ID>(&mut v5, std::vector::borrow<PoolID>(v4, v3).id);
                let v6 = sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0);
                assert!(sui::table::contains<PoolID, u64>(v6, *std::vector::borrow<PoolID>(v4, v3)), 9223374527938625580);
                std::vector::push_back<u64>(&mut v2, *sui::table::borrow<PoolID, u64>(v6, *std::vector::borrow<PoolID>(v4, v3)));
                v3 = v3 + 1;
            };
            vote_internal<T0>(arg0, arg1, arg2, arg3, v5, v2, arg4, arg5);
        };
    }
    
    public fun pool_to_gauge<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : sui::object::ID {
        sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, into_pool_id(arg1)).id
    }
    
    public fun prove_pair_whitelisted<T0, T1, T2>(arg0: &Voter<T0>) : distribution::whitelisted_tokens::WhitelistedTokenPair {
        assert!(is_whitelisted_token<T0, T1>(arg0), 9223373870805811199);
        assert!(is_whitelisted_token<T0, T2>(arg0), 9223373875100778495);
        distribution::whitelisted_tokens::create_pair<T1, T2>(sui::object::id<Voter<T0>>(arg0))
    }
    
    public fun prove_token_whitelisted<T0, T1>(arg0: &Voter<T0>) : distribution::whitelisted_tokens::WhitelistedToken {
        assert!(is_whitelisted_token<T0, T1>(arg0), 9223373853625942015);
        distribution::whitelisted_tokens::create<T1>(sui::object::id<Voter<T0>>(arg0))
    }
    
    public fun receive_gauger<T0, T1, T2>(arg0: &mut Voter<T2>, arg1: &distribution::voter_cap::GovernorCap, arg2: &mut distribution::gauge::Gauge<T0, T1, T2>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T2>>(arg0));
        let v0 = into_gauge_id(sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg2));
        let v1 = into_pool_id(distribution::gauge::pool_id<T0, T1, T2>(arg2));
        assert!(!sui::table::contains<GaugeID, GaugeRepresent>(&arg0.gauge_represents, v0), 9223373720482283526);
        assert!(!sui::table::contains<PoolID, GaugeID>(&arg0.pool_to_gauger, v1), 9223373724779872302);
        let v2 = GaugeRepresent{
            gauger_id        : sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(arg2), 
            pool_id          : distribution::gauge::pool_id<T0, T1, T2>(arg2), 
            weight           : 0, 
            last_reward_time : sui::clock::timestamp_ms(arg3),
        };
        sui::table::add<GaugeID, GaugeRepresent>(&mut arg0.gauge_represents, v0, v2);
        sui::table::add<GaugeID, sui::balance::Balance<T2>>(&mut arg0.rewards, v0, sui::balance::zero<T2>());
        sui::table::add<GaugeID, u64>(&mut arg0.weights, v0, 0);
        std::vector::push_back<PoolID>(&mut arg0.pools, v1);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, true);
        sui::table::add<PoolID, GaugeID>(&mut arg0.pool_to_gauger, v1, v0);
        distribution::gauge::set_voter<T0, T1, T2>(arg2, sui::object::id<Voter<T2>>(arg0));
        whitelist_token<T2, T0>(arg0, arg1, true, arg4);
        whitelist_token<T2, T1>(arg0, arg1, true, arg4);
        if (!is_whitelisted_token<T2, T2>(arg0)) {
            whitelist_token<T2, T2>(arg0, arg1, true, arg4);
        };
    }
    
    public fun remove_epoch_governor<T0>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: address) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = sui::object::id_from_address(arg2);
        sui::vec_set::remove<sui::object::ID>(&mut arg0.epoch_governors, &v0);
        let v1 = EventRemoveEpochGovernor{who: arg2};
        sui::event::emit<EventRemoveEpochGovernor>(v1);
    }
    
    public fun remove_governor<T0>(arg0: &mut Voter<T0>, _arg1: &sui::package::Publisher, arg2: address) {
        let v0 = sui::object::id_from_address(arg2);
        sui::vec_set::remove<sui::object::ID>(&mut arg0.governors, &v0);
        let v1 = EventRemoveGovernor{who: arg2};
        sui::event::emit<EventRemoveGovernor>(v1);
    }
    
    public fun reset<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        assert_only_new_epoch<T0>(arg0, into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2)), arg3);
        reset_internal<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    fun reset_internal<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        let v1 = if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
            std::vector::length<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0))
        } else {
            0
        };
        let mut v2 = 0;
        let mut v3 = 0;
        while (v3 < v1) {
            let v4 = *std::vector::borrow<PoolID>(sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v0), v3);
            let v5 = *sui::table::borrow<PoolID, u64>(sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), v4);
            let v6 = *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, v4);
            if (v5 != 0) {
                update_for_internal<T0>(arg0, v6);
                let weight = sui::table::remove<GaugeID, u64>(&mut arg0.weights, v6) - v5;
                sui::table::add<GaugeID, u64>(&mut arg0.weights, v6, weight);
                sui::table::remove<PoolID, u64>(sui::table::borrow_mut<LockID, sui::table::Table<PoolID, u64>>(&mut arg0.votes, v0), v4);
                distribution::fee_voting_reward::withdraw(sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, v6), &arg0.gauge_to_fee_authorized_cap, v5, v0.id, arg3, arg4);
                distribution::bribe_voting_reward::withdraw(sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&mut arg0.gauge_to_bribe, v6), &arg0.gauge_to_bribe_authorized_cap, v5, v0.id, arg3, arg4);
                v2 = v2 + v5;
                let v7 = EventAbstained{
                    sender      : sui::tx_context::sender(arg4), 
                    pool        : v4.id, 
                    lock        : v0.id, 
                    votes       : v5, 
                    pool_weight : *sui::table::borrow<GaugeID, u64>(&arg0.weights, v6),
                };
                sui::event::emit<EventAbstained>(v7);
            };
            v3 = v3 + 1;
        };
        distribution::voting_escrow::voting<T0>(arg1, &arg0.voter_cap, v0.id, false);
        arg0.total_weight = arg0.total_weight - v2;
        if (sui::table::contains<LockID, u64>(&arg0.used_weights, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.used_weights, v0);
        };
        if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
            sui::table::remove<LockID, vector<PoolID>>(&mut arg0.pool_vote, v0);
        };
    }
    
    public(package) fun return_new_gauge<T0, T1, T2>(arg0: &gauge_cap::gauge_cap::CreateCap, arg1: &mut clmm_pool::pool::Pool<T0, T1>, arg2: &mut sui::tx_context::TxContext) : distribution::gauge::Gauge<T0, T1, T2> {
        let v0 = sui::object::id<clmm_pool::pool::Pool<T0, T1>>(arg1);
        let mut v1 = distribution::gauge::create<T0, T1, T2>(v0, arg2);
        let v2 = gauge_cap::gauge_cap::create_gauge_cap(arg0, v0, sui::object::id<distribution::gauge::Gauge<T0, T1, T2>>(&v1), arg2);
        clmm_pool::pool::init_magma_distribution_gauge<T0, T1>(arg1, &v2);
        distribution::gauge::receive_gauge_cap<T0, T1, T2>(&mut v1, v2);
        v1
    }
    
    public fun revive_gauger<T0>(arg0: &mut Voter<T0>, arg1: &distribution::emergency_council::EmergencyCouncilCap, arg2: sui::object::ID) {
        distribution::emergency_council::validate_emergency_council_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        let v0 = into_gauge_id(arg2);
        assert!(sui::table::contains<GaugeID, bool>(&arg0.is_alive, v0), 9223374115619405832);
        let v1 = false;
        assert!(sui::table::borrow<GaugeID, bool>(&arg0.is_alive, v0) == &v1, 9223374124208881663);
        sui::table::remove<GaugeID, bool>(&mut arg0.is_alive, v0);
        sui::table::add<GaugeID, bool>(&mut arg0.is_alive, v0, true);
        let v2 = EventReviveGauge{id: v0.id};
        sui::event::emit<EventReviveGauge>(v2);
    }
    
    public fun set_max_voting_num<T0>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: u64) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373183612551192);
        assert!(arg2 >= 10, 9223373187907649562);
        assert!(arg2 != arg0.max_voting_num, 9223373196495945727);
        arg0.max_voting_num = arg2;
    }
    
    public fun total_weight<T0>(arg0: &Voter<T0>) : u64 {
        arg0.total_weight
    }
    
    public fun update_for<T0>(arg0: &mut Voter<T0>, arg1: sui::object::ID) {
        update_for_internal<T0>(arg0, into_gauge_id(arg1));
    }
    
    fun update_for_internal<T0>(arg0: &mut Voter<T0>, arg1: GaugeID) {
        let v0 = if (sui::table::contains<GaugeID, u64>(&arg0.weights, arg1)) {
            *sui::table::borrow<GaugeID, u64>(&arg0.weights, arg1)
        } else {
            0
        };
        if (v0 > 0) {
            let v1 = if (sui::table::contains<GaugeID, u128>(&arg0.supply_index, arg1)) {
                sui::table::remove<GaugeID, u128>(&mut arg0.supply_index, arg1)
            } else {
                0
            };
            let v2 = arg0.index;
            sui::table::add<GaugeID, u128>(&mut arg0.supply_index, arg1, v2);
            let v3 = v2 - v1;
            if (v3 > 0) {
                let v4 = if (sui::table::contains<GaugeID, bool>(&arg0.is_alive, arg1)) {
                    let v5 = true;
                    sui::table::borrow<GaugeID, bool>(&arg0.is_alive, arg1) == &v5
                } else {
                    false
                };
                assert!(v4, 9223375717644828720);
                let v6 = if (sui::table::contains<GaugeID, u64>(&arg0.claimable, arg1)) {
                    sui::table::remove<GaugeID, u64>(&mut arg0.claimable, arg1)
                } else {
                    0
                };
                sui::table::add<GaugeID, u64>(&mut arg0.claimable, arg1, v6 + (integer_mate::full_math_u128::mul_div_floor(v0 as u128, v3, 18446744073709551616) as u64));
            };
        } else {
            if (sui::table::contains<GaugeID, u128>(&arg0.supply_index, arg1)) {
                sui::table::remove<GaugeID, u128>(&mut arg0.supply_index, arg1);
            };
            sui::table::add<GaugeID, u128>(&mut arg0.supply_index, arg1, arg0.index);
        };
        // TODO: looks like this function was disabled, check why
        // return
        // abort 9223375717644828720
    }
    
    public fun update_for_many<T0>(arg0: &mut Voter<T0>, arg1: vector<sui::object::ID>) {
        let mut v0 = 0;
        while (v0 < std::vector::length<sui::object::ID>(&arg1)) {
            update_for_internal<T0>(arg0, into_gauge_id(*std::vector::borrow<sui::object::ID>(&arg1, v0)));
            v0 = v0 + 1;
        };
    }
    
    public fun update_for_range<T0>(arg0: &mut Voter<T0>, arg1: u64, arg2: u64) {
        let mut v0 = 0;
        while (arg1 + v0 < arg2) {
            let pool_id = *std::vector::borrow<PoolID>(&arg0.pools, arg1 + v0);
            let gauge_id = *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, pool_id);
            update_for_internal<T0>(arg0, gauge_id);
            v0 = v0 + 1;
        };
    }
    
    public fun used_weights<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : u64 {
        *sui::table::borrow<LockID, u64>(&arg0.used_weights, into_lock_id(arg1))
    }
    
    public fun vote<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: vector<sui::object::ID>, arg4: vector<u64>, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        assert_only_new_epoch<T0>(arg0, v0, arg5);
        check_vote<T0>(arg0, &arg3, &arg4);
        assert!(!arg0.flag_distribution, 9223374626723266610);
        assert!(!distribution::voting_escrow::deactivated<T0>(arg1, v0.id), 9223374631017185314);
        let v1 = distribution::common::current_timestamp(arg5);
        let v2 = if (v1 > distribution::common::epoch_vote_end(v1)) {
            let v3 = !sui::table::contains<LockID, bool>(&arg0.is_whitelisted_nft, v0) || *sui::table::borrow<LockID, bool>(&arg0.is_whitelisted_nft, v0) == false;
            v3
        } else {
            false
        };
        if (v2) {
            abort 9223374648197185572
        };
        if (sui::table::contains<LockID, u64>(&arg0.last_voted, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.last_voted, v0);
        };
        sui::table::add<LockID, u64>(&mut arg0.last_voted, v0, v1);
        let v4 = distribution::voting_escrow::get_voting_power<T0>(arg1, arg2, arg5);
        assert!(v4 > 0, 9223374686852022310);
        vote_internal<T0>(arg0, arg1, arg2, v4, arg3, arg4, arg5, arg6);
    }
    
    fun vote_internal<T0>(arg0: &mut Voter<T0>, arg1: &mut distribution::voting_escrow::VotingEscrow<T0>, arg2: &distribution::voting_escrow::Lock, arg3: u64, arg4: vector<sui::object::ID>, arg5: vector<u64>, arg6: &sui::clock::Clock, arg7: &mut sui::tx_context::TxContext) {
        let v0 = into_lock_id(sui::object::id<distribution::voting_escrow::Lock>(arg2));
        reset_internal<T0>(arg0, arg1, arg2, arg6, arg7);
        let mut v1 = 0;
        let mut v2 = 0;
        let mut v3 = 0;
        let mut v4 = 0;
        let v5 = std::vector::length<sui::object::ID>(&arg4);
        while (v4 < v5) {
            let v6 = std::vector::borrow<u64>(&arg5, v4);
            v1 = v1 + *v6;
            v4 = v4 + 1;
        };
        v4 = 0;
        while (v4 < v5) {
            let v7 = into_pool_id(*std::vector::borrow<sui::object::ID>(&arg4, v4));
            assert!(sui::table::contains<PoolID, GaugeID>(&arg0.pool_to_gauger, v7), 9223374798519205896);
            let v8 = *sui::table::borrow<PoolID, GaugeID>(&arg0.pool_to_gauger, v7);
            assert!(is_gauge_alive<T0>(arg0, v8), 9223374807109926932);
            let v9 = integer_mate::full_math_u64::mul_div_floor(*std::vector::borrow<u64>(&arg5, v4), arg3, v1);
            let v10 = if (sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0)) {
                if (sui::table::contains<PoolID, u64>(sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), v7)) {
                    let v11 = 0;
                    sui::table::borrow<PoolID, u64>(sui::table::borrow<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0), v7) != &v11
                } else {
                    false
                }
            } else {
                false
            };
            if (v10) {
                abort 9223374832881041448
            };
            assert!(v9 > 0, 9223374841471107114);
            update_for_internal<T0>(arg0, v8);
            if (!sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v0)) {
                sui::table::add<LockID, vector<PoolID>>(&mut arg0.pool_vote, v0, std::vector::empty<PoolID>());
            };
            std::vector::push_back<PoolID>(sui::table::borrow_mut<LockID, vector<PoolID>>(&mut arg0.pool_vote, v0), v7);
            let v12 = if (sui::table::contains<GaugeID, u64>(&arg0.weights, v8)) {
                sui::table::remove<GaugeID, u64>(&mut arg0.weights, v8)
            } else {
                0
            };
            sui::table::add<GaugeID, u64>(&mut arg0.weights, v8, v12 + v9);
            if (!sui::table::contains<LockID, sui::table::Table<PoolID, u64>>(&arg0.votes, v0)) {
                sui::table::add<LockID, sui::table::Table<PoolID, u64>>(&mut arg0.votes, v0, sui::table::new<PoolID, u64>(arg7));
            };
            let v13 = sui::table::borrow_mut<LockID, sui::table::Table<PoolID, u64>>(&mut arg0.votes, v0);
            let v14 = if (sui::table::contains<PoolID, u64>(v13, v7)) {
                sui::table::remove<PoolID, u64>(v13, v7)
            } else {
                0
            };
            sui::table::add<PoolID, u64>(v13, v7, v14 + v9);
            distribution::fee_voting_reward::deposit(sui::table::borrow_mut<GaugeID, distribution::fee_voting_reward::FeeVotingReward>(&mut arg0.gauge_to_fee, v8), &arg0.gauge_to_fee_authorized_cap, v9, v0.id, arg6, arg7);
            distribution::bribe_voting_reward::deposit(sui::table::borrow_mut<GaugeID, distribution::bribe_voting_reward::BribeVotingReward>(&mut arg0.gauge_to_bribe, v8), &arg0.gauge_to_bribe_authorized_cap, v9, v0.id, arg6, arg7);
            v2 = v2 + v9;
            v3 = v3 + v9;
            let v15 = EventVoted{
                sender        : sui::tx_context::sender(arg7), 
                pool          : v7.id, 
                lock          : v0.id, 
                voting_weight : v9, 
                pool_weight   : *sui::table::borrow<GaugeID, u64>(&arg0.weights, v8),
            };
            sui::event::emit<EventVoted>(v15);
            v4 = v4 + 1;
        };
        if (v2 > 0) {
            distribution::voting_escrow::voting<T0>(arg1, &arg0.voter_cap, v0.id, true);
        };
        arg0.total_weight = arg0.total_weight + v3;
        if (sui::table::contains<LockID, u64>(&arg0.used_weights, v0)) {
            sui::table::remove<LockID, u64>(&mut arg0.used_weights, v0);
        };
        sui::table::add<LockID, u64>(&mut arg0.used_weights, v0, v2);
    }
    
    public fun voted_pools<T0>(arg0: &Voter<T0>, arg1: sui::object::ID) : vector<sui::object::ID> {
        let mut v0 = std::vector::empty<sui::object::ID>();
        let v1 = into_lock_id(arg1);
        let v2 = if (sui::table::contains<LockID, vector<PoolID>>(&arg0.pool_vote, v1)) {
            sui::table::borrow<LockID, vector<PoolID>>(&arg0.pool_vote, v1)
        } else {
            let v3 = std::vector::empty<PoolID>();
            &v3
        };
        let mut v4 = 0;
        while (v4 < std::vector::length<PoolID>(v2)) {
            std::vector::push_back<sui::object::ID>(&mut v0, std::vector::borrow<PoolID>(v2, v4).id);
            v4 = v4 + 1;
        };
        v0
    }
    
    public fun whitelist_nft<T0>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: sui::object::ID, arg3: bool, arg4: &mut sui::tx_context::TxContext) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373956706664472);
        let v0 = into_lock_id(arg2);
        if (sui::table::contains<LockID, bool>(&arg0.is_whitelisted_nft, v0)) {
            sui::table::remove<LockID, bool>(&mut arg0.is_whitelisted_nft, v0);
        };
        sui::table::add<LockID, bool>(&mut arg0.is_whitelisted_nft, v0, arg3);
        let v1 = EventWhitelistNFT{
            sender : sui::tx_context::sender(arg4), 
            id     : arg2, 
            listed : arg3,
        };
        sui::event::emit<EventWhitelistNFT>(v1);
    }
    
    public fun whitelist_token<T0, T1>(arg0: &mut Voter<T0>, arg1: &distribution::voter_cap::GovernorCap, arg2: bool, arg3: &mut sui::tx_context::TxContext) {
        distribution::voter_cap::validate_governor_voter_id(arg1, sui::object::id<Voter<T0>>(arg0));
        assert!(is_governor<T0>(arg0, distribution::voter_cap::who(arg1)), 9223373896577122328);
        whitelist_token_internal<T0>(arg0, std::type_name::get<T1>(), arg2, sui::tx_context::sender(arg3));
    }
    
    fun whitelist_token_internal<T0>(arg0: &mut Voter<T0>, arg1: std::type_name::TypeName, arg2: bool, arg3: address) {
        if (sui::table::contains<std::type_name::TypeName, bool>(&arg0.is_whitelisted_token, arg1)) {
            sui::table::remove<std::type_name::TypeName, bool>(&mut arg0.is_whitelisted_token, arg1);
        };
        sui::table::add<std::type_name::TypeName, bool>(&mut arg0.is_whitelisted_token, arg1, arg2);
        let v0 = EventWhitelistToken{
            sender : arg3, 
            token  : arg1, 
            listed : arg2,
        };
        sui::event::emit<EventWhitelistToken>(v0);
    }
    
    // decompiled from Move bytecode v6
}



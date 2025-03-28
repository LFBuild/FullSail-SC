module sail_token::allow_list;

use sui::token::{Self, ActionRequest, TokenPolicy, TokenPolicyCap};

public struct AllowList has drop {}

public struct AllowListConfig has store {
    allowed: vector<address>
}

public fun verify<T>(
    policy: &TokenPolicy<T>,
    action_request: &mut ActionRequest<T>,
    ctx: &mut TxContext,
) {
    let config: &AllowListConfig = token::rule_config<T, AllowList, AllowListConfig>(AllowList {}, policy);
    if (config.allowed.contains(&ctx.sender())) {
        token::add_approval(AllowList {}, action_request, ctx)
    };
}

public fun allowed_add<T>(
    cap: &TokenPolicyCap<T>,
    policy: &mut TokenPolicy<T>,
    who: address,
    ctx: &mut TxContext,
) {
    let config: &mut AllowListConfig = token::rule_config_mut<T, AllowList, AllowListConfig>(AllowList {}, policy, cap);

    config.allowed.push_back(who)
}

public fun init_rule<T>(
    cap: &TokenPolicyCap<T>,
    policy: &mut TokenPolicy<T>,
    ctx: &mut TxContext
) {
    token::add_rule_for_action<T, AllowList>(policy, cap, token::transfer_action(), ctx);
    token::add_rule_config<T, AllowList, AllowListConfig>(
        AllowList {},
        policy,
        cap,
        AllowListConfig { allowed: vector[] },
        ctx
    )
}
# Delegation Documentation for Voting Escrow

## Table of Contents

1. [Overview](#overview)
2. [Documentation for Lock User](#documentation-for-lock-user)
3. [Documentation for Manager](#documentation-for-manager)
4. [Important Notes](#important-notes)
5. [Usage Examples](#usage-examples)

---

## Overview

In the Voting Escrow system, delegation of voting power is performed through the **`deposit_managed()`** function, which allows you to transfer your lock to a managed lock for collective voting power management.

### Lock Types

- **NORMAL** - regular lock with full control
- **LOCKED** - lock delegated to a managed lock (via `deposit_managed`)
- **MANAGED** - managed lock that accepts delegations

---

## Documentation for Lock User

### What is Delegation?

Delegation allows you to transfer your voting power to a manager who will vote on your behalf. You retain ownership of your tokens but lose the ability to vote independently and receive voting rewards.

### Delegation via `deposit_managed()`

**Requirements:**
- Lock must be of type **NORMAL**
- Lock must have balance > 0
- Managed lock must be active (not deactivated)

**How to use:**

```move
voter::deposit_managed<SailCoinType>(
    voter,
    voting_escrow,
    distribution_config,
    lock,           // Your lock
    managed_lock,   // Manager's managed lock
    clock,
    ctx
);
```

**What happens:**
- Your tokens are "transferred" to the managed lock
- Your lock becomes type **LOCKED**
- Your balance becomes 0
- Voting power transfers to the managed lock
- You are registered in managed reward systems
- **If the managed lock has already voted:** voting is automatically re-voted with updated voting power (including your deposit), preserving the same pools and weight proportions

**Advantages:**
- ✅ Works for any locks (not just permanent)
- ✅ Receive **managed rewards** (free + locked)
- ✅ Automatic reward distribution
- ✅ Manager votes on your behalf
- ✅ Automatic voting update on deposit

**Disadvantages:**
- ❌ **Lose voting rewards** (Fee Voting + Exercise Fee)
- ❌ Cannot manage the lock directly
- ❌ Voting power = 0 (cannot vote independently)
- ❌ Can only deposit until the end of the epoch voting period

---

### What You Can Do with a LOCKED Lock

After `deposit_managed`, your lock becomes type **LOCKED**. Here's what you can do:

#### ✅ Check Accumulated Rewards

**Free managed rewards (can be claimed immediately):**

```move
voting_escrow::free_managed_reward_earned<SailCoinType, RewardCoinType>(
    voting_escrow,
    lock,
    clock,
    ctx
): u64
```

**Locked managed rewards (locked rewards):**
- Available through `locked_managed_reward.earned()`
- Distributed when withdrawing from managed lock

#### ✅ Claim Free Managed Rewards

```move
voting_escrow::free_managed_reward_get_reward<SailCoinType, RewardCoinType>(
    voting_escrow,
    lock,
    clock,
    ctx
)
```

- Can be claimed at any time
- Rewards are transferred to your address

#### ✅ Get List of Reward Types

```move
voting_escrow::free_managed_reward_token_list<SailCoinType>(
    voting_escrow,
    lock_id
): vector<TypeName>
```

#### ✅ Withdraw from Managed Lock

```move
voter::withdraw_managed<SailCoinType>(
    voter,
    voting_escrow,
    distribution_config,
    lock,
    managed_lock,
    clock,
    ctx
)
```

**What happens on withdrawal:**
- You receive back tokens + accumulated locked rewards
- Free rewards can be claimed separately before withdrawal
- Lock returns to type **NORMAL** with maximum lock time
- `permanent = false`
- `end = current_time + max_lock_time()`

#### ✅ Check Lock Information

- Lock type: `escrow_type(lock_id)` → returns `LOCKED`
- Managed lock ID: `id_to_managed(lock_id)`
- Associated reward systems: `managed_to_free(lock_id)`

---

### What You Cannot Do with a LOCKED Lock

#### ❌ Increase Lock Amount

```move
// Blocked for LOCKED type
increase_amount() // → EIncreaseAmountLockedEscrow
```

#### ❌ Increase Lock Time

```move
// Only for NORMAL type
increase_unlock_time() // → EIncreaseTimeNotNormalEscrow
```

#### ❌ Make Lock Permanent

```move
// Only for NORMAL type
lock_permanent() // → ELockPermanentNotNormalEscrow
```

#### ❌ Unlock Permanent

```move
// Only for NORMAL type
unlock_permanent() // → EUnlockPermanentNotNormalEscrow
```

#### ❌ Merge with Other Locks

```move
// Only for NORMAL type
merge() // → EMergeSourceNotNormalEscrow
```

#### ❌ Split Lock

```move
// Only for NORMAL type
split() // → ESplitNotNormalEscrow
```

#### ❌ Transfer Lock

```move
// Blocked for LOCKED type
transfer() // → ETransferLockedPosition
```

#### ❌ Withdraw Tokens Directly

```move
// Only for NORMAL type
withdraw() // → EWithdrawPositionNotNormalEscrow
// Withdrawal only through withdraw_managed
```

#### ❌ Vote Independently

- Voting power = 0
- Manager votes on behalf of the managed lock

#### ❌ Claim Voting Rewards

```move
// LOCKED types cannot claim voting rewards
claim_voting_fee_by_pool() // → ELockedVotingEscrowCannotClaim
claim_exercise_fee_reward() // → Not available for LOCKED
```

---

### Practical Workflow for User

#### Scenario 1: Passive Participation

1. Deposit into managed lock via `deposit_managed`
2. Manager votes on your behalf
3. Periodically check rewards: `free_managed_reward_earned()`
4. Claim free rewards: `free_managed_reward_get_reward()`
5. If you want to withdraw: `withdraw_managed()` (you'll receive tokens + locked rewards)

#### Scenario 2: Free Rewards Only

1. Deposit into managed lock
2. Regularly claim free rewards
3. Keep tokens in managed lock

#### Scenario 3: Full Withdrawal

1. Deposit into managed lock
2. Claim all free rewards
3. Call `withdraw_managed()`
4. Receive:
   - Original tokens
   - Accumulated locked rewards
   - Lock returns to `NORMAL` with maximum lock time

---

## Documentation for Manager

### What is a Managed Lock?

A managed lock is a special lock of type **MANAGED** that can accept delegations from other users. The manager receives voting power from all delegated locks and can vote on their behalf.

### Creating a Managed Lock

**Requirements:**
- You must be in the `allowed_managers` list
- Requires administrator approval

**How to create:**

```move
voting_escrow::create_managed_lock_for<SailCoinType>(
    voting_escrow,
    owner,  // Your address
    clock,
    ctx
): ID  // Returns ID of created managed lock
```

**What is created:**
- Managed lock with `amount = 0`, `permanent = true`
- Reward systems: `LockedManagedReward` and `FreeManagedReward`
- Lock is transferred to your ownership

---

### What You Can Do with a Managed Lock

#### ✅ Increase Lock Amount

```move
voting_escrow::increase_amount<SailCoinType>(
    voting_escrow,
    lock,
    coin,
    clock,
    ctx
)
```

- Can add tokens to managed lock
- When adding, the locked managed rewards system is automatically notified

#### ✅ Vote

```move
voter::vote<SailCoinType>(
    voter,
    voting_escrow,
    distribution_config,
    lock,        // Managed lock
    pools,       // List of pools
    weights,     // Weights for each pool
    volumes,     // Predicted volumes
    clock,
    ctx
)
```

**Managed lock voting power:**
- Voting power = own balance + sum of all delegated locks
- Manager votes with full voting power for everyone

**Example:**
- Managed lock: own balance = 1000 SAIL
- User A deposited: 500 SAIL
- User B deposited: 300 SAIL
- **Total voting power = 1800 SAIL**

**Important:** If a user deposits their lock into a managed lock that has already voted, voting is automatically re-voted with updated voting power. Old votes are reset but re-voted with the same pools, weights, and volumes, only with new voting power.


#### ✅ Manage Rewards

**Add free managed rewards:**

```move
voting_escrow::free_managed_reward_notify_reward<SailCoinType, RewardCoinType>(
    voting_escrow,
    whitelisted_token,  // Optional
    coin,               // Rewards to distribute
    managed_lock_id,
    clock,
    ctx
)
```

- Can add rewards to the free managed reward system
- Rewards are distributed among all users who deposited into the managed lock

#### ✅ Claim Voting Rewards

**Fee Voting Rewards (trading fees):**

```move
voter::claim_voting_fee_by_pool<SailCoinType, FeeCoinType>(
    voter,
    voting_escrow,
    distribution_config,
    lock,        // Managed lock
    pool,
    clock,
    ctx
)
```

**Exercise Fee Rewards (fees from oSAIL unlock):**

```move
voter::claim_exercise_fee_reward<SailCoinType, RewardCoinType>(
    voter,
    voting_escrow,
    distribution_config,
    lock,        // Managed lock
    clock,
    ctx
)
```

**Important:** The manager receives voting rewards for the **entire** voting power of the managed lock, including delegated balances.

#### ✅ Check Information

- Check voting power: `balance_of_nft_at(managed_lock_id, time)`
- Check reward list: `free_managed_reward_token_list()`
- Check number of delegated locks through events

---

### What You Cannot Do with a Managed Lock

#### ❌ Increase Lock Time

```move
// Only for NORMAL type
increase_unlock_time() // → EIncreaseTimeNotNormalEscrow
```

- Managed lock is created as permanent (`end = 0`), so this is not critical

#### ❌ Withdraw Tokens

```move
// Only for NORMAL type
withdraw() // → EWithdrawPositionNotNormalEscrow
```

- Managed lock is permanent, so withdrawal is not possible

#### ❌ Merge with Other Locks

```move
// Only for NORMAL type
merge() // → EMergeSourceNotNormalEscrow
```

#### ❌ Split Lock

```move
// Only for NORMAL type
split() // → ESplitNotNormalEscrow
```

#### ❌ Make Lock Permanent

```move
// Only for NORMAL type
lock_permanent() // → ELockPermanentNotNormalEscrow
```

- Managed lock is already permanent when created

#### ❌ Unlock Permanent

```move
// Only for NORMAL type
unlock_permanent() // → EUnlockPermanentNotNormalEscrow
```

#### ❌ Deactivate Managed Lock Independently

```move
// Requires Emergency Council Cap
set_managed_lock_deactivated() // → Only through Emergency Council
```

- Manager cannot deactivate independently

---

### Rewards for Manager

#### ✅ Voting Rewards (Primary Income Source)

**Fee Voting Rewards:**
- Receives a share of trading fees from pools that the managed lock voted for
- Amount is proportional to managed lock voting power (own + delegated)
- Can be claimed via `claim_voting_fee_by_pool()`

**Exercise Fee Rewards:**
- Receives a share of 50% fee when unlocking oSAIL to SAIL
- Amount is proportional to managed lock voting power
- Can be claimed via `claim_exercise_fee_reward()`

**Important:** The manager receives voting rewards for the **entire** voting power of the managed lock, including delegated balances from users.

#### ❌ Managed Rewards (Not Received for Own Balance)

**Free Managed Rewards:**
- Rewards are distributed only among users who deposited their locks
- Managed lock balance is not registered in reward systems when created

**Locked Managed Rewards:**
- Similarly: rewards go only to users

**How to receive managed rewards:**
If the manager wants to receive managed rewards, they must:
1. Create a separate NORMAL lock
2. Deposit it into their managed lock via `deposit_managed()`
3. Then they will receive managed rewards as a regular user

---

### Practical Workflow for Manager

#### Scenario 1: Creating and Managing Managed Lock

1. Create managed lock via `create_managed_lock_for()`
2. Users deposit their locks via `deposit_managed()`
3. Managed lock voting power increases
4. Vote on behalf of all delegates via `vote()`
5. Claim voting rewards via `claim_voting_fee_by_pool()` and `claim_exercise_fee_reward()`
6. Optionally: add managed rewards via `free_managed_reward_notify_reward()`

#### Scenario 2: Increasing Voting Power

1. Add tokens to managed lock via `increase_amount()`
2. Voting power increases
3. More voting rewards when voting

#### Scenario 3: Distributing Rewards to Users

1. Claim voting rewards
2. Add portion to managed rewards via `free_managed_reward_notify_reward()`
3. Users can claim these rewards

---


## Operations Summary Table

### For User with LOCKED Lock

| Operation | Available? | Comment |
|-----------|-----------|---------|
| Check free rewards | ✅ Yes | `free_managed_reward_earned()` |
| Claim free rewards | ✅ Yes | `free_managed_reward_get_reward()` |
| Withdraw from managed lock | ✅ Yes | `withdraw_managed()` |
| Check reward list | ✅ Yes | `free_managed_reward_token_list()` |
| Increase amount | ❌ No | Only for NORMAL |
| Increase time | ❌ No | Only for NORMAL |
| Make permanent | ❌ No | Only for NORMAL |
| Merge with other lock | ❌ No | Only for NORMAL |
| Split lock | ❌ No | Only for NORMAL |
| Transfer lock | ❌ No | Blocked |
| Withdraw directly | ❌ No | Only through `withdraw_managed` |
| Vote | ❌ No | Voting power = 0 |
| Claim voting rewards | ❌ No | LOCKED types cannot |

### For Manager with Managed Lock

| Operation | Available? | Comment |
|-----------|-----------|---------|
| Increase amount | ✅ Yes | `increase_amount()` works |
| Vote | ✅ Yes | Can vote with full voting power |
| Add rewards | ✅ Yes | `free_managed_reward_notify_reward()` |
| Claim voting rewards | ✅ Yes | For entire voting power (own + delegated) |
| Check voting power | ✅ Yes | `balance_of_nft_at()` |
| Increase time | ❌ No | Only for NORMAL |
| Withdraw tokens | ❌ No | Only for NORMAL |
| Merge with other lock | ❌ No | Only for NORMAL |
| Split lock | ❌ No | Only for NORMAL |
| Make permanent | ❌ No | Already permanent |
| Unlock permanent | ❌ No | Only for NORMAL |
| Deactivate | ❌ No | Only through Emergency Council |

---

## Important Notes

### For Users

1. **Loss of voting rewards:** With `deposit_managed`, you lose the ability to receive voting rewards. They go to the manager.

2. **Compensation:** The only compensation is managed rewards that the manager adds manually.

3. **Automatic voting update:** When depositing your lock into a managed lock that has already voted, voting is automatically re-voted with updated voting power (including your deposit), preserving the same pools and weight proportions.

### For Managers

1. **Responsibility:** You receive voting rewards for the entire voting power, including delegated balances. This is your primary motivation.

2. **Reward distribution:** It is recommended to distribute a portion of voting rewards through managed rewards to attract more delegates.

3. **Voting power:** The more users delegate, the greater your voting power and voting rewards.

---

## Usage Examples

### Example 1: User Delegates via `deposit_managed`

```move
// 1. User deposits their lock into managed lock
voter::deposit_managed<SAIL>(
    &mut voter,
    &mut voting_escrow,
    &distribution_config,
    &mut user_lock,
    &mut managed_lock,
    &clock,
    ctx
);

// 2. Check accumulated free rewards
let earned = voting_escrow::free_managed_reward_earned<SAIL, REWARD_TOKEN>(
    &mut voting_escrow,
    &mut user_lock,
    &clock,
    ctx
);

// 3. Claim free rewards
voting_escrow::free_managed_reward_get_reward<SAIL, REWARD_TOKEN>(
    &mut voting_escrow,
    &mut user_lock,
    &clock,
    ctx
);

// 4. Withdraw from managed lock
voter::withdraw_managed<SAIL>(
    &mut voter,
    &mut voting_escrow,
    &distribution_config,
    &mut user_lock,
    &mut managed_lock,
    &clock,
    ctx
);
```

### Example 2: Manager Manages Managed Lock

```move
// 1. Create managed lock
let managed_lock_id = voting_escrow::create_managed_lock_for<SAIL>(
    &mut voting_escrow,
    manager_address,
    &clock,
    ctx
);

// 2. Vote on behalf of all delegates
voter::vote<SAIL>(
    &mut voter,
    &mut voting_escrow,
    &distribution_config,
    &managed_lock,
    pools,
    weights,
    volumes,
    &clock,
    ctx
);

// 3. Claim voting rewards
voter::claim_voting_fee_by_pool<SAIL, FEE_TOKEN>(
    &mut voter,
    &mut voting_escrow,
    &distribution_config,
    &managed_lock,
    &pool,
    &clock,
    ctx
);

// 4. Add managed rewards for users
voting_escrow::free_managed_reward_notify_reward<SAIL, REWARD_TOKEN>(
    &mut voting_escrow,
    option::none(),
    reward_coin,
    managed_lock_id,
    &clock,
    ctx
);
```

---

## Conclusion

Delegation in Voting Escrow provides a flexible mechanism for managing voting power. Users can delegate their locks to managers, receiving managed rewards but losing voting rewards. Managers receive voting rewards for managing others' voting power, which motivates them to vote effectively and attract more delegates.

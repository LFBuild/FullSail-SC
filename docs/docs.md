# Full Sail Security

## Mechanics Summary

This chapter provides a high-level description of the core mechanics of Full Sail to better assess its security. Full Sail is a ve(4,4) DEX. The ve(4,4) tokenomics is an extension of ve(3,3) with a novel volume prediction mechanic, option tokens, and a smart emission control model. The motivation behind these improvements is described in the [Full Sail Innovation Summary](https://docs.google.com/document/d/1nfJcrq7Dkkw6VLEhw57yb80_diD3XrBcRVsaMSCxQZo/edit?tab=t.0#heading=h.wj3skhaor12d).

### Locks (veSAIL)

SAIL, the governance token of Full Sail, can be locked into veSAIL (voting escrow SAIL), producing a lock object. veSAIL is then used to participate in voting. The amount of veSAIL determines your voting power, which is proportional to the lock duration:

- 1 SAIL locked for 4 years produces 1 veSAIL (1 unit of voting power).
- 1 SAIL locked for 2 years produces 0.5 veSAIL (0.5 units of voting power).

You can also enable the Auto-Max lock feature, which maintains your lock at 4 years, ensuring your voting power does not decay. Voting power begins to decay again once you toggle off this feature.

Locks are transferable, allowing users to sell them on the secondary market. When a lock expires, you can claim your SAIL back.

### Volume Predictions

The protocol operates in one-week epochs, starting and ending at 00:00 UTC every Thursday. Voting begins one hour after the epoch starts and ends one hour before it concludes. In each epoch, veSAIL holders predict trading volume in pools for the next epoch. These predictions govern emissions, and voters are rewarded when their predictions are sufficiently accurate.

For example, consider a voting period starting at 01:00 UTC on Thursday, December 4, 2025, and ending at 23:00 UTC on Wednesday, December 10, 2025. During this time, voters can submit and resubmit volume predictions for the next epoch, which spans from December 11 to December 17. They need to estimate the trading volume in USD for a selected pool from 00:00 UTC, December 11, to 00:00 UTC, December 18. After the epoch change on December 11, these predictions determine emissions for that week. Once the actual trading volume is known after December 18, voters are rewarded based on their prediction accuracy.

### Emissions Formula

At the end of each voting epoch, an emissions formula is applied to the aggregated volume predictions to determine emissions for the next epoch. The formula is described in detail [here](https://docs.fullsail.finance/exchange/responsive-organised-weighing-row).

### Voting Rewards

Trading fees from each pool are redirected to the voters who voted for that pool's volume. The distribution depends on prediction accuracy, which can only be determined at the end of the epoch for which the volume was predicted. This is one week after voting for that epoch has closed and two weeks after it began.

For example, if the voting epoch was from December 4, 2025, to December 10, 2025, voters predicted volume for the epoch from December 11 to December 17. The accuracy (reward multiplier) and voting rewards are determined at the beginning of December 18, right after the epoch change.

Rewards for each voter are allocated according to the formula:

`voterRewards = votingPower * voterRewardMultiplier * totalPoolVotingRewards / totalVotingPowerSubmittedForThePool`

The reward multiplier depends on how far the volume prediction was from the actual volume:

`voterRewardMultiplier = EXP(-alpha * distance^2)`

Where:
`distance = if (predictedVolume > actualVolume) { predictedVolume / actualVolume - 1 } else { actualVolume / predictedVolume - 1 }`

### Liquidity

The protocol uses a concentrated liquidity model with dynamic swap fees, as described in the [Uniswap V3 whitepaper](https://uniswap.org/whitepaper-v3.pdf).

### oSAIL

In Full Sail, liquidity providers (LPs) earn oSAIL option token emissions. These tokens can be converted into liquid SAIL before their expiration date or into veSAIL at any time. LPs do not earn trading fees; fees are redirected to voters.

A new oSAIL type with a new expiration date is issued weekly. The expiration is set to five weeks after the first token can be emitted. The oSAIL type is consistent throughout an epoch, meaning the expiration period is effectively four weeks for the last oSAIL token emitted in that epoch. The oSAIL type is determined at the moment LP rewards are claimed, regardless of when they were earned.

Depending on the expiration date, there are several options to exercise oSAIL:

1.  **Unlock into liquid SAIL**: A 50% exercise fee is required. For example, if the SAIL price is $0.30 and a user exercises 10 oSAIL, they pay a $1.50 fee (10 oSAIL _ $0.30/oSAIL _ 0.5). The user receives 10 SAIL, and 10 oSAIL are burned. A flash loan can be used to fund the fee. This option is only available **before the expiration date**.
2.  **Unlock into USDC**: Similar to the above, but a flash loan funds the exercise fee. The resulting SAIL is instantly sold for USDC; half is sent to the user, and the other half covers the fee. This option is only available **before the expiration date**.
3.  **Lock for 6 months or 2 years**: oSAIL is converted into SAIL using the formula `SAIL amount = oSAIL amount * (0.5 + lock duration / 4 years * 0.5)` and locked for the chosen duration. For example, locking 1 oSAIL for 6 months yields 0.5625 SAIL locked into veSAIL, resulting in 0.0703125 voting power. This is available on-chain but rarely used.
4.  **Lock for 4 years**: The user receives veSAIL on a 1:1 basis. This option is available regardless of the expiration date.

## Technical Docs

This chapter dives deeper into the design of the protocol's smart contracts.

### Packages

- **[clmm_pool](https://github.com/LFBuild/FullSail-CLMM-SC/tree/main/clmm_pool)**: Implements the concentrated liquidity model, liquidity management, and swaps.
- **[voting_escrow](../voting_escrow/sources/)**: Implements veSAIL, voting power calculations, and helper reward contracts.
- **[governance](../governance/sources/)**: Implements emissions control, oSAIL, and voting.

Other packages are either libraries, helper packages, or deprecated.

### Modules

The `voting_escrow` and `governance` packages are the focus of this documentation.

The overall structure can be viewed here: [Mermaid Diagram](https://mermaid.live/edit#pako:eNqNV21v2zYQ_isEgQIt5gR-a2L7w4A1TrsBNmo0wT6sHgZGOsuEZVKjKLtekv--IylZFCUH9Rebx7vn7h7eHelnGskY6IwmimVb8jhfC4Kfd-_I1dUVWfB_Cx5zfSKfU3kk71PYaBLJtNiLD0bBKS9W-fc1rXVXSh54DCpf079R69eXzAlIelbR8oXcLZZLtDNfZMWiHUsADRykFRpTBbpQgqxkzjWXwhqiv7Njq5TKaFercGGVKl8L3ATlB-gkZCnjIq1dhtsGONdsByHyF1YkgHj2O0RxQhf5kamYHLneEvnw2x-LMvAmwc7XHDIQMYiIQ17zupIyfVRMRFtYMoH0mCzawjoE61e7TRIzzVo0OGATzaMClhfqhJBmSap1BePCzy8gfMLzwoj9RCOWRkXKDFFdVo20LR_k_geoiOdQFlcEQmM2rfKyyr_L1FQURutsy3UVLVRQJdNLbrBQ2_0IT6mUVrWTk70RxMQZ_yk1F8l9Hil5RAh_-QZQWakHcCB-1O08XFuwE9kA9EgCmvhxB2x9BiBznmvFnwpbh2dqPPdnBhDx5Uwtmp4tpeGjeyNM64KW8RNX69LTAeqjcbl7ZxMk8g2eWP4TuZjTIMopO16cZTOVlizMoq0QJOBceDkE8bqTL8tT8WTbMfzOthb8YLaBZApiHpWtgCi2FO13GKMTGlNX11yYNuAHyMtBE44VbO_YBIXkV9ghUvOI8kZ-Tc2qZw0Vtt3tuDJ0m5Xl2PZ2i1gr9ZrfDZsymi4Oy_bBeNBJKdtbVG_gNTrN0WkVM3kEFSb7lmZ3_f6UaatognyqyXcnhVYyLYtDy8yrCX86CkTfnIiAI4FMRlvyS3NGhUeC0VSzu4RpY7IkUZAwM7G8SkPkb1_vm7i-VZHF5qSPYAo5rw45SO8BCyDaPklzqCvFIzDTJ65T8_bNzdGpXQ1lW9CZEV8YbF-ULDLk3iuBvHhyLxHzAvhntUsuvRCqV4JbWZoChOAKclj1K6W8ertwO6-87hv5snt_yqHjxtDrcupVt_nMi_3-NKjX3jCoW7Be-4ceVnktfasvOidmK73wEvMLwmmkXOwe9CkFMuoTBJI7mAkpoEI4j7IyReSGnIlwIrvbGCa5BSx3PdDehqfpzDx58owpnJytGAbNGILdYVeEnffGm9x5iKMuxPKherF-PPtx05728GXOY4o5FtCje1B7Zpb02Viuqd7CHutohj9j2LAi1Wu6Fq9oljHxl5T7yhJbLdnS2YalOa7cLJhzhrVaq5g3qLqThdB09tEi0Nkz_UFno-H1ZDCYTMf94c3NdDgejHv0RGfjm_H16HY6_DiYDCf92_7gtUf_sz4H18PxqD_tD28H0_H09mbSozinkK-l-7dh_3S8_g9otSZd)

#### voting_escrow package

Modules in the `voting_escrow` package:

1.  **common.move**: A shared library to centralize time-related logic, ensure consistent epoch calculations, provide reusable conversion utilities, and maintain system-wide constants.
2.  **emergency_council.move**: Acts as a circuit breaker for security incidents, with the power to kill gauges and deactivate managed locks.
3.  **free_managed_reward.move**: A wrapper around the base reward system for reward distribution among delegated locks.
4.  **locked_managed_reward.move**: A wrapper around the base reward system for reward distribution among delegated locks.
5.  **reward_cap.move**: A capability object that authorizes operations on reward contracts, used to validate permissions for depositing, withdrawing, and managing rewards.
6.  **reward_distributor_cap.move**: A capability object that authorizes operations on reward distributor contracts, used to validate permissions for checkpointing tokens and managing reward distribution.
7.  **reward_distributor.move**: Manages the time-weighted distribution of rewards to locks based on their voting power. It tracks token distribution across epochs and handles the claiming process for voting rewards.
8.  **reward.move**: The core reward distribution module, implementing epoch-based checkpointing, balance tracking, and reward claiming. It manages multiple reward token types, tracks earned rewards per lock, and handles supply updates across epochs.
9.  **team_cap.move**: A capability object for team-specific operations, providing authorization for administrative functions in the voting escrow system.
10. **voting_dao.move**: Manages the delegation of voting power between locks. It implements checkpointing for delegated balances and tracks delegation history with timestamp-based checkpoints.
11. **voting_escrow_cap.move**: A capability object authorizing operations on voting escrow contracts, used to validate permissions for administrative functions.
12. **voting_escrow.move**: The core voting escrow implementation, managing lock creation, voting power calculations, time-weighted balances, and lock lifecycle operations. It implements the veSAIL tokenomics with permanent/perpetual lock options.
13. **whitelisted_tokens.move**: Manages a whitelist of tokens allowed for use as rewards, providing validation to ensure only approved tokens are used.

#### governance package

Modules in the `governance` package:

1.  **distribute_cap.move**: A capability object authorizing distribution operations, such as notifying rewards and distributing to gauges. It is typically owned by the minter.
2.  **distribution_config.move**: Manages the global distribution configuration, including active gauges and price aggregators for SAIL and oSAIL tokens. It tracks which gauges are live and can participate in rewards.
3.  **exercise_fee_reward.move**: Manages reward distribution from oSAIL exercise fees (i.e., redemption fees). It tracks and distributes fees collected when users exercise oSAIL options, rewarding voters based on their participation.
4.  **fee_voting_reward.move**: Manages the distribution of trading fees to voters based on their participation. It collects fees from pools and distributes them proportionally to voters who directed liquidity.
5.  **gauge.move**: Manages liquidity pool incentivization and position staking. It tracks staked positions, calculates oSAIL rewards for LPs, collects trading fees, and handles reward distribution based on voting weight.
6.  **minter.move**: The core module managing token emissions, oSAIL minting and exercising, gauge distribution, protocol fees, and emission control. It implements the responsive emission model and coordinates reward distribution.
7.  **rebase_distributor_cap.move**: A capability object authorizing operations on rebase distributor contracts, used to validate permissions for managing rebase distribution.
8.  **rebase_distributor.move**: Manages the distribution of rebased SAIL tokens to voting escrow participants. It wraps the reward distributor to handle SAIL distribution based on voting power, with automatic locking into veSAIL.
9.  **voter_cap.move**: Capability objects for voter authorization, including `VoterCap`, `GovernorCap`, and `EpochGovernorCap`. These provide different permission levels for voting and governance functions.
10. **voter.move**: The core voting module, managing volume predictions, vote casting, gauge creation, and reward distribution. It handles the mechanism where veSAIL holders predict pool volumes and receive rewards based on accuracy.

### Locks

veSAIL is not a token in the traditional sense; it is a SUI object of type `Lock` ([sources](https://github.com/LFBuild/FullSail-SC/blob/c26209e9318f3ccd73f870b21266bba028680ce8/voting_escrow/sources/voting_escrow.move#L113)). Voting power is determined by the `voting_escrow::voting_escrow::balance_of_nft_at` method.

There is a difference between the locked SAIL amount and voting power. Voting power is proportional to the locked SAIL multiplied by the lock duration. Duration is a value from 0 to 1, where 1 represents the maximum duration of 4 years. Voting power is stored in checkpoints for both [user locks](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L283C9-L283C27) and [total voting power](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L277). The total voting power should be precisely synchronized with the sum of all individual lock voting powers. To calculate voting power, the latest checkpoint is used, and an algorithm considering decay speed is applied.

New voting power can be created in a few ways:

1.  By locking SAIL into veSAIL using the [create_lock](https://github.com/LFBuild/FullSail-SC/blob/c26209e9318f3ccd73f870b21266bba028680ce8/voting_escrow/sources/voting_escrow.move#L1213) or [create_lock_advanced](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L1252) methods.
2.  By creating a lock from oSAIL using the [create_lock_from_o_sail](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/governance/sources/minter.move#L2326) method. In this process, oSAIL is burned, and a corresponding amount of SAIL is minted. The amount of SAIL is proportional to the duration, which means the resulting voting power is proportional to the duration squared. This makes low-duration locks significantly less advantageous. The only on-chain durations allowed are 6 months, 2 years, and 4 years.
3.  By depositing oSAIL into an existing lock using [deposit_o_sail_into_lock](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/governance/sources/minter.move#L2402). The oSAIL is burned, and a corresponding amount of SAIL is minted and locked. The only allowed duration is 4 years with auto-max lock enabled (`Lock.permanent`), as other durations would be valid for only a brief moment.

Main methods available for locks:

1.  **[deposit_for](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L1712)**: Deposit additional SAIL into an existing lock, increasing its amount without changing the duration.
2.  **[increase_amount](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2106)**: Increase the amount of tokens in an existing lock. Similar to `deposit_for` but with different internal handling.
3.  **[increase_unlock_time](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2198)**: Extend the duration of an existing lock. The new duration must be longer than the current one.
4.  **[withdraw](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L585)**: Withdraw all tokens from a lock after it has expired. Cannot be used if the lock is currently voting or is permanent.
5.  **[lock_permanent](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2335)**: Convert a time-locked position into a permanent lock, which never expires and maintains constant voting power.
6.  **[unlock_permanent](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2913)**: Convert a permanent lock back to a time-locked position. The lock must not be currently voting.
7.  **[delegate](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L1631)**: Delegate voting power from a permanent lock to another, allowing the transfer of voting power without transferring ownership.
8.  **[merge](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2435)**: Merge two locks into one, combining their balances. The source lock must not have voted, and both must be of the `NORMAL` type.
9.  **[split](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L371)**: Split one lock into two separate locks with specified amounts. Requires split permission, and the lock must not be currently voting.
10. **[deposit_managed](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L1809)**: Deposit a normal lock's tokens into a managed lock. Used for delegation pools where users contribute to collectively managed positions.
11. **[withdraw_managed](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L3079)**: Withdraw tokens from a managed lock back to a normal lock. Requires voting escrow capability authorization.
12. **[balance_of_nft_at](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L283)**: Query the voting power of a lock at a specific timestamp using checkpointing.
13. **[locked](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2390)**: Query the locked balance information for a lock, including its amount, end time, and permanent status.

The total amount of locked SAIL can be obtained using [total_locked](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2805), and the total voting power can be obtained using [total_supply_at](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/voting_escrow.move#L2820).

### Volume Predictions

Volume predictions are submitted on-chain and aggregated off-chain due to the large amount of data involved.

It is the locks that vote, not user addresses. Volume predictions for the next epoch are submitted using the [vote](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/governance/sources/voter.move#L1676) method. The lock's weight is submitted alongside the prediction, and both are recorded.

At the end of the epoch, a backend service aggregates predictions to calculate the final predicted volume and uses the emissions formula to determine emissions for each pool. At the beginning of the next epoch, these values are pushed on-chain via the [distribute_gauge](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/governance/sources/minter.move#L1410) method.

### Voting Rewards

Each lock that participates in voting is rewarded in two ways simultaneously:

1.  **Trading Fees**: Distributed using the `FeeVotingReward` object from the `governance::fee_voting_reward` module.
2.  **oSAIL Redemption Fees**: The 50% fee charged when a user unlocks oSAIL into SAIL, distributed using the `ExerciseFeeReward` object from the `governance::exercise_fee_reward` module.

Both of these contracts are wrappers around the `voting_escrow::reward::Reward` helper object.

#### Reward Contract

This helper object implements reward distribution on a per-epoch basis. Rewards can be deposited throughout the epoch using [notify_reward_amount_internal](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/reward.move#L809). Lock weights can be adjusted using [deposit](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/reward.move#L254) or [withdraw](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/reward.move#L997).

These methods are protected by `voting_escrow::reward_cap::RewardCap`, with final access control implemented by the wrapper contract.

At the end of the epoch, deposited rewards are distributed across locks based on their weights. The reward share becomes available for claim via the [get_reward_internal](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/reward.move#L763) method.

To distribute rewards based on accuracy, we must be able to update voter weights from past epochs, as weights are multiplied by the `voterRewardMultiplier`. The `balance_update_enabled` feature in the `reward` module allows an authorized entity to do this. Balance updates are performed using the [update_balances](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/voting_escrow/sources/reward.move#L349) method, which also recalculates the supply for the target epoch. This method is called in batches, with the final batch using the `final = true` flag to make rewards available for claim.

#### FeeVotingReward

This wrapper distributes trading fees to voters. Fees are allocated via the `governance::voter::distribute_gauge` method at the beginning of each epoch. The method collects all fees accumulated since the last collection and deposits them into the `FeeVotingReward` object. As votes are cast during the week, zero weights are recorded, as they will be updated later.

Votes are submitted for the upcoming epoch's volume. At the end of that next epoch, when the actual volume is known, the reward distribution occurs. Each lock's balance is updated to reflect the `voterRewardMultiplier`, and the epoch is finalized.

Fee voting rewards are distributed with a two-week delay. Consider three epochs:

- **Epoch 1**: Trading fees are collected.
- **Epoch 2**: At the beginning of the week, fees from Epoch 1 are allocated to voters. Predictions for Epoch 3's volume are submitted.
- **Epoch 3**: At the end of this epoch, the actual volume is known, allowing rewards to be calculated and distributed.

Voters who did not vote receive zero rewards. This is implemented by updating the lock weight to zero if a non-zero weight was inherited from the previous epoch.

#### ExerciseFeeReward

This wrapper distributes oSAIL exercise fees (the 50% redemption fee) to voters. The fee is directed to this contract whenever the [distribute_exercise_fee_to_reward](https://github.com/LFBuild/FullSail-SC/blob/c50a30e31e52c615dc1809a9ee8c3abaf0f4485e/governance/sources/minter.move#L1112) method is called.

The actual weight of the lock is recorded when votes are cast. This weight is not updated later, as prediction accuracy does not affect exercise fee distribution. Balance updates are still enabled to nullify rewards for non-voters who may have inherited a non-zero weight from a previous epoch.

`ExerciseFeeReward` rewards are available for claim immediately after the epoch ends.

### Emissions

LPs receive only emissions and partner incentives; trading fees are redirected to voters. Pool emissions are determined by a [formula](https://docs.fullsail.finance/exchange/responsive-organised-weighing-row) using predicted volume, historical volume, liquidity, and ROE (Return on Emissions). ROE measures trading fees generated per dollar of emissions. The formula is executed off-chain, and the resulting USD value is pushed on-chain. On-chain, oSAIL is distributed, and we use a price oracle, synced every 15 minutes, to determine the amount.

The flow is as follows:

1.  Emissions are pushed at the beginning of the week in USD (6 decimals) using the [distribute_gauge](https://github.com/LFBuild/FullSail-SC/blob/0a7136fe481ed0dc2595868f54d28f51bc4f11ec/governance/sources/minter.move#L1410) method.
2.  Distribution speed is adjusted every 15 minutes using [sync_o_sail_distribution_price](https://github.com/LFBuild/FullSail-SC/blob/0a7136fe481ed0dc2595868f54d28f51bc4f11ec/governance/sources/minter.move#L2126), which sources the price from a Switchboard oracle.
3.  oSAIL is not minted at the time of distribution. Instead, the eligible oSAIL amount for each LP position is calculated throughout the week.
4.  Minting occurs only when a user claims their earnings using the [get_position_reward](https://github.com/LFBuild/FullSail-SC/blob/0a7136fe481ed0dc2595868f54d28f51bc4f11ec/governance/sources/minter.move#L3025) method.

The price oracle is critical for emissions. Manipulating the oracle could allow an attacker to alter emissions arbitrarily. To mitigate this risk, we have a dedicated [PriceMonitor](https://outline.customapp.tech/share/fc253e4f-25d2-437a-b28f-09ca32082dc6) package.

### Liquidity

The protocol uses a concentrated liquidity model with dynamic swap fees, as described in the [Uniswap V3 docs](https://uniswap.org/whitepaper-v3.pdf).

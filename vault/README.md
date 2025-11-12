# Vault Package Overview

This package implements the higher-level automation that sits on top of the CLMM pool
and governance staking subsystems.

## Module Summary

### `vault::vault`
Central module that holds the on-chain state for a single CLMM strategy instance.
It manages a staked liquidity position inside the gauge, exposes helpers for
moving liquidity in and out, and routes reward collection.

- `new` – Opens a fresh CLMM position for the configured tick offsets, deposits the
  initial balances, stakes the position in the gauge, and returns the `ClmmVault`
  object that encapsulates the strategy state.
- `rebalance` – Fully migrates the staked position to a new tick range. The function
  withdraws the position from the gauge, removes existing liquidity, opens the new
  range, restakes the position, and returns leftover balances together with migration
  metadata for eventing and accounting.
- `increase_liquidity` / `decrease_liquidity` – Adjusts the staked position while
  preserving its gauge status. These helpers temporarily unroll the stake,
  apply the requested liquidity change, and restake the position so that reward
  accounting continues seamlessly.
- `collect_position_reward` / `collect_pool_reward` – Pulls OSAIL incentives from the
  gauge or pool reward contracts and returns the balances. Downstream modules
  merge these payouts into protocol buffers or user entitlements.

### `vault::port`
User-facing module that wraps `ClmmVault` into share-based accounts called `Port`s.
Each `Port` implements a separate strategy on top of the same CLMM pool and tracks
how much of the underlying assets and rewards belong to every depositor.

- `create_port` – Instantiates a new port, seeds it with initial balances, and binds
  it to a vault, gauge, and CLMM pool. This call also determines the quote asset for
  TVL calculations and sets the rebalance offsets.
- `deposit` – Mints a `PortEntry` NFT representing the depositor’s share. The function
  values the coins by invoking the oracle, pushes liquidity into the CLMM through the
  vault, and records the entry’s reward growth baseline.
- `increase_liquidity` / `withdraw` – Deposit or withdraw additional liquidity for an
  existing entry, including proportional accounting for any buffered assets and live
  position liquidity. Both flows ensure reward snapshots are refreshed before tokens
  move so that payouts remain correct.
- `claim_position_reward` / `claim_pool_reward` – Claim OSAIL or pool reward balances
  accrued to a specific `PortEntry`. The helpers reconcile the entry’s tracked growth
  with the port-level aggregates, transfer the owed coins, and emit events that prove
  the claim.
- `flash_loan` / `repay_flash_loan` – Temporary access to buffered assets for
  rebalancing or maintenance workflows. The port pauses external activity until the
  accompanying certificate is redeemed.

### `vault::pyth_oracle`
Price-utility module that integrates Pyth price feeds for TVL estimation and
rebalancing checks. It exposes helpers to read prices, normalize them to common
decimals, and compute quote values for arbitrary type-name keyed balance maps.
The port uses these routines to cap price deviation before adding liquidity and
to calculate the USD-equivalent hard-cap limit.

## User and Protocol Flows

1. **Strategy Deployment**  
   A maintainer invokes `port::create_port`, which internally provisions a `ClmmVault`
   and links it to the specified gauge and pool. Multiple ports can be created for the
   same pool, each with distinct tick offsets, hard caps, or other strategy parameters.

2. **Liquidity Provision**  
   Users deposit through `port::deposit`, receiving a `PortEntry` NFT. Subsequent top-ups
   use `increase_liquidity`, while withdrawals rely on `withdraw` followed by
   `destory_port_entry` once the LP balance reaches zero.

3. **Reward Lifecycle**  
   Operators update vault-level growth via `update_position_reward` and
   `update_pool_reward`. Users claim their entitlements through `claim_position_reward`
   and `claim_pool_reward`, which rely on the growth snapshots maintained by the port.

4. **Rebalancing and Maintenance**  
   The manager can invoke `rebalance`, `update_liquidity_offset`, `update_hard_cap`,
   or `update_protocol_fee` to adjust strategy parameters. Flash-loan support is
   available for complex migrations that require temporary asset movement.
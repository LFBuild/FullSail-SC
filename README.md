# Overview of Project - FULL_SAIL_DEX

    A Dex platform on SUI chain.

## Overview of Specific Repo - Full_Sail_SCs

A Dex Smart Contract implementing ve(4,4) model which is a modification of ve(3,3) model. On SUI.

## Prerequisities

Need to have knowledge in
- Blockchain Fundamentals
- SUI chain
- Dex(Ve(3,3)) Flow and Logic
- Ve(4,4) innovations
- Move Smart Contract language

## Installation Instructions

- Install SUI. You can reference this link: https://docs.sui.io/guides/developer/getting-started/sui-install
- Need to have SUI Wallet Extension or App for interacting with SUI chain by GUI

## Contract dependencies

Below is the dependency graph showing the relationships between the smart contract packages. Each arrow ("→") points from a contract to the contract it depends on. For instance, the edge

`integrate → clmm_pool`

indicates that Integrate depends on clmm_pool.

![Dependency Graph](dependency_graph.svg)

Notable dependencies:
- integrate depends on nearly all the contracts.

## Deployment

### Initial deployment
- Use the latest version of `sui` CLI.
- Run the `build_all.sh` script to update the git deps of all the packages.
- Run `reset_addresses.sh` to set the `[addresses]` value for each package to `0x0` in the `Move.toml` file.
- Deploy all the packages in an order defined by dependency graph (see [Contract dependencies](#contract-dependencies)). 
Use `sui client publish` command.
- Run `update_addresses.sh` to restore the package address `[addresses]` section in the `Move.toml` for each package with the `original-published-id` after publishing. WARNING the `update_addresses.sh` script supports only mainnet environment.

### Upgrading
- When upgrading, you need to retrieve the UpgradeCap ID of your published package. Automated address management does not track your UpgradeCap.
- When upgrading, you first need to set the `[addresses]` value for your package to 0x0 in the Move.toml, and restore its ID with the ORIGINAL-ADDRESS after upgrading.

## Latest publication artifacts

### Mainnet prediction competiton version (i.e. sandbox)

#### Publication transactions

- [SAIL](https://suivision.xyz/txblock/8h9AypGsfEz4UEycf6zwNjFehpRxHyNYsc7N7JwxzCi)

- [locker_cap](https://suivision.xyz/txblock/A9ETxo574RNtZYkZULKFA69mLrkhBEYYQ1JtpSyYTXGz)
- [price_monitor](https://suivision.xyz/txblock/BGgVbGEVY6ykp3vof5KbCppqSXLKgEj1oSR2er6ft1pi)
- [ve](https://suivision.xyz/txblock/8YKk71XhWNZS6trfWcvqHW2e9SHSc5pTL4kzvnNt7XzQ)
- [distribution](https://suivision.xyz/txblock/715V9xbf87hrs7hAG2xLgpLtue1fjD92ZgESrcMCiLBB)
    * [distribution upgrade](https://suivision.xyz/txblock/8oJ6vQNDxL5mjys8xqM5rZwDfZFRCtMAhL21y92LRKzm)
- [sail](https://suivision.xyz/txblock/68FQpwT3oTKq3bmhc9ez1k6r31D7WqNdgnUDsjQPxBkR)
- [o_sail_token](https://suiscan.xyz/mainnet/tx/71SWPFWjZLXoD4SwQuTDUGQm9sCbHXVPXy4aqsnyRCar)
- [integrate](https://suivision.xyz/txblock/B6CvCzjC3Q8n5QzgRk9mB4dQj5zchQ8JxYPeMQMYNPVE)

- [setup distribtuion tx](https://suiscan.xyz/mainnet/tx/ANbcJt5Yr6zGWabJbt7CbVU2vg4EZ83PHGgpV37qU3wk)
- [activate minter tx](https://suiscan.xyz/mainnet/tx/CbFUk1GqzXiGe3S1UK5rpTV1bTG9vb57mnzc74SPGrw)

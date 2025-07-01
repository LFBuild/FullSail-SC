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

### Mainnet (test version)

#### Publication transactions

- [locker_cap](https://suivision.xyz/txblock/6beJNe6xim5mW2yofXZYyarizeg2GMtYmZrw4BAfhJ1c)
- [distribution](https://suivision.xyz/txblock/CCLQ3jyD6j9g5mVhvDq3RByffokctZpe9uKnNnrwZsDX)
- [liquidity_locker](https://suivision.xyz/txblock/GH87ajY9LB1QXiF7Hm2FcUqt84m42eezqD8Vco8h3AS8)
- [integrate](https://suivision.xyz/txblock/5oGNpGb5CfM1wFnmaoLovNsMDFjhX5sMQtBG3wjABEjd), [upgrade integrate](https://suivision.xyz/txblock/8YboNNJfhMPVVDshfDmCL6hc4P7nS2YorrY9CzzKkvzU)

[Setup distribution tx](https://suivision.xyz/txblock/31N5n7ZHB5X6K1ZPaAtJUny4eEZUYbZJGbFoEqbSnVas)
[Create gauge tx](https://suivision.xyz/txblock/2uLEzLu2JYCM2qqCbCNMgqayVCiT43tNEvbK4pPc425U)
[Create gauge tx2](https://suivision.xyz/txblock/D3vc98r73mvJ7mmsPE2ucsARs8QqA2v5A6aTiy6q4a2H)
[Activate minter tx](https://suivision.xyz/txblock/A6BNVhv4GG7AkniPBinLtrDak7y4um3CcX6ejAe3z7NK)
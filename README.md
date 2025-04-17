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

### Testnet

#### Publication transactions:

- [move_stl](https://testnet.suivision.xyz/txblock/GmnSDVgMEj9FhMBZr4KDeqbSKZmDydfbXSqgA8ToUg1C)
- [integer_mate](https://testnet.suivision.xyz/txblock/58sGFmxKmD7rdKcGWJTKvv61EjYLGn5uAELmphQ6MFga)
- [gauge_cap](https://testnet.suivision.xyz/txblock/Wi57YbH9vRspiEc9LL22NxDjxnQXTV1igShdpzKXvpD)
- [clmm_pool](https://testnet.suivision.xyz/txblock/JDixgrY2ukAH7osgCeJX8YfTeq9xSEPE68VJPmF1EBJs)
- [distribution](https://testnet.suivision.xyz/txblock/ECihTgcyGtTsQdDDs6SjC9x2616brY6jnq4sZnSQc23R)
- [integrate](https://testnet.suivision.xyz/txblock/7FhEtcJBxGJGyntVUwMkemhqgGEZZwgUL63M3xSqwDDb)

[Setup distribution tx](https://testnet.suivision.xyz/txblock/6Z1DjeSo25XEu48MSteNSSmkv1MAD17hH5w1D3YckaL7)

### Mainnet (test version)

#### Publication transactions

- [move_stl](https://suivision.xyz/txblock/D5d6rSAqCjEVm3v58sksyTRFMbDfUfHh6esgwsAivWTw)
- [integer_mate](https://suivision.xyz/txblock/FPsTPKvEpKLB7huuvgxmDetSdUxUwUb6ZQTV6CwULHCp)
- [gauge_cap](https://suivision.xyz/txblock/3zp6J98rVv9c6pDae4gHoRA1kyEeEg9c6w2X5Xqj9EK3)
- [price_provider](https://suivision.xyz/txblock/J2hrKfrUhnmKJTAcWDrCF5B6VfHHaKZcDhXAnaXgEgiL)
- [clmm_pool](https://suivision.xyz/txblock/5WincqGA4JxVFrx4jZLi2pJAGcDNwVfdPxVkKkPgLf4e)
- [distribution](https://suivision.xyz/txblock/AbURt8dazp7U7pd84froyMREqzyg1pzURcYQtzHuqcvC)
- [integrate](https://suivision.xyz/txblock/5HDhhuzHHTTwj9QE9WJu6sNhVS922PPzVNZxxx6Dkdjv)

[Setup distribution tx](https://suivision.xyz/txblock/31N5n7ZHB5X6K1ZPaAtJUny4eEZUYbZJGbFoEqbSnVas)
[Create gauge tx](https://suivision.xyz/txblock/2uLEzLu2JYCM2qqCbCNMgqayVCiT43tNEvbK4pPc425U)
[Create gauge tx2](https://suivision.xyz/txblock/D3vc98r73mvJ7mmsPE2ucsARs8QqA2v5A6aTiy6q4a2H)
[Activate minter tx](https://suivision.xyz/txblock/A6BNVhv4GG7AkniPBinLtrDak7y4um3CcX6ejAe3z7NK)

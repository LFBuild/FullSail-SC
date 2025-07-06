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

- [locker_cap](https://suivision.xyz/txblock/66mFm2xq184KGBUSRJMLfBn6nPs8HKgeLhDbv8GchzBE)
- [distribution](https://suivision.xyz/txblock/Dj5Lsx3Mj2GeFUnUaejBYmUpzDWuaLVAf3vKLDy4j2Ty)
- [liquidity_locker](https://suivision.xyz/txblock/FEMGnXMw4so8TMDE3oYHfSv3A3gcSVeumP3RVPku943)
- [integrate](https://suivision.xyz/txblock/HaWZSzJGFNk5nUJbfUFv3JdW3i4KZEajYkZZNrUVUiRh)

- [locker init tx](https://suivision.xyz/txblock/5zXvzCQgSqL8jyms6oB3ijhCWJpfa5JBGevtYfLNKiz8)
- [setup distribtuion tx](https://suivision.xyz/txblock/BR889z7WhfG1onA9tp74FQinHggW7m8Dfgx8DprKZWTt)
- [activate minter tx](https://suivision.xyz/txblock/Ak9pU4KtbKWCavxN3C3GtUAKoJV9qbiPaHxkhMfCnhTA)

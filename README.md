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

- [locker_cap](https://suivision.xyz/txblock/ATcfkAx4mwjCqio1Zze3TTdd7we5RfSVoMqcSwpCmmRv)
- [distribution](https://suivision.xyz/txblock/9JKTDgzh8pNEWbWTW7arR8UMKGA5kFUktSjRTiue3kRx)
- [liquidity_locker v1](https://suivision.xyz/txblock/9XCGWQMBmxQuRMc6YUviaCdGtj8dncd8RgYpN3jo2pVT)
- [integrate](https://suivision.xyz/txblock/HVFVRCuqXBS2tGxDKSNwBAJRbn4wVHZmBQ7EzYL4dZP7)

- [o sail deploy](https://suivision.xyz/txblock/E5WBdzN9ogWpThLjZkckfy7BhgirnobmaBEcL6qEqo9h)

- [locker init tx](https://suivision.xyz/txblock/327ZPNpNH8ujMZ47cFf2QMoVknfRgsx9PEbKXNK9bVrp)
- [setup distribtuion tx](https://suivision.xyz/txblock/Cqq5ZZNzZFibkCYLHqqEVg1GW6ALKYmXAnz42QTKpkKN)
- [activate minter tx](https://suivision.xyz/txblock/Ak9pU4KtbKWCavxN3C3GtUAKoJV9qbiPaHxkhMfCnhTA)

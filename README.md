# Overview of Project - FULL_SAIL_DEX

    A Dex platform on SUI chain.

## Overview of Specific Repo - Full_Sail_SCs

A Dex Smart Contract implementing ve(3,3) model which has similar logic as [Magmafinance](https://magmafinance.io/) on SUI.

The original code was decompiled from contracts existing deployed contracts. Contract addresses were obtained
from [Magma config](https://github.com/MagmaFinanceIO/magma_clmm_sdk/blob/main/src/config/mainnet.ts).

The reason why we are using this code is because it is the only ve(3,3) model on Sui and it is a good starting point for us to build our own ve(4,4) model.

Some libraries were found opensource:
    
- [move_stl](https://github.com/MagmaFinanceIO/move-stl). No license was found.
- [integer_mate](https://github.com/MagmaFinanceIO/integer-mate). No license was found.

To mitigate the risk of of libraries becoming unavailable, we are using the code directly.

## Prerequisities

Need to have knowledge in
- Blockchain Fundamentals
- SUI chain
- Dex(Ve(3,3)) Flow and Logic
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
- fullsail_config does not depend on any contracts and none of the contracts depends on it.

## Deployment

### Initial deployment
- Use the latest version of `sui` CLI.
- Run the `build_all.sh` script to update the git deps of all the packages.
- In each package set the `[addresses]` value for your package to `0x0` in the `Move.toml` file.
- Deploy all the packages in an order defined by dependency graph (see [Contract dependencies](#contract-dependencies)). 
Use `sui client publish` command.
- In each package restore the package address `[addresses]` section the `Move.toml` with the `original-published-id` after publishing.
You can find the necessary address in the `Move.lock` in the section corresponding to the deployment environment. 
This step is required to build the packages later.

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

- [move_stl](https://suivision.xyz/txblock/DJSKVGhe4Zc27dbWHjq4QVyoXGxXePKTZJMahpxsKssf)
- [integer_mate](https://suivision.xyz/txblock/7KCHahBXG6hfFMnRwNfnWg4Zy6QpWK5qK3cDgg7DcR8R)
- [gauge_cap](https://suivision.xyz/txblock/EgSaGcfSMcqemH9QgcQrwquue4kbCWxEiHnfzTcnQwsP)
- [clmm_pool](https://suivision.xyz/txblock/CuoZkRJNFEqZrA9oByC83BMdhxcHTeLpCaBPjQCyyUpA)
- [distribution](https://suivision.xyz/txblock/CbKBgFnwjhEPemt7LCB9qmpXUEST5BUyyuUJVmapTMRe)
- [integrate](https://suivision.xyz/txblock/Es3DqkbX1cibjToEmiWcd1awpAh763mb36amNAuAm3Xh)

[Setup distribution tx](https://suivision.xyz/txblock/76dT6eHyzTiXR4fe14pzAASeEpq2FnX6DBkpcLATVBrQ)

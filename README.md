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

### Mainnet

- [locker_cap](https://suivision.xyz/txblock/B9mVEC18ZYj4SMgkeYn8DN2u9m7hmTcb9SiDQ73t381b)
    - package `0xa5b0b900f2b1eb1270595e813a0455de9fb91d77f66fb21d8d9f83ef7d90a678`
    - locker_cap::CreateCap `0xf4c41408b5531c15bb6d11c10626db37701c31ec8fd620fd5c881edd92e0d040`
- [liquidity_locker](https://suivision.xyz/txblock/2A2rwHzcHiynEUarnaVzEchx9CXxWUGBLzKN9zsENSYf)
    - package `0x0e84a5a2159c893e3a4ee741205133bf08c210b06a2a2a7981c1feeaed399495`
    - PoolTrancheManager `0x0eee28f8ad9e190ab12348bd8b87c9dc0b9280eaab3bf745fdc0ea2fe962a96a`
    - pool_tranche::SuperAdminCap `0x24a8efa0de9979d14a8551968f85163506390d0ff5e6b1d44855e62b89f33e4a`
    - liquidity_lock_v1::SuperAdminCap `0xbdec146df21fafb6b08fa1755a55ad37b07ad4c092536007ea4068c479c13034`
    - Locker `0xddada1cefdef0bf2422fe6e1935d08fc077ee04e73cc2dfadd21788191f795f4`
- [integrate](https://suivision.xyz/txblock/6u5McVLD4EjrUMWPEm86PhSTDPS5CjeqbX9xe9YE1V9n)
    - package: `0xe1b7d5fd116fea5a8f8e85c13754248d56626a8d0a614b7d916c2348d8323149`

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

- [locker_cap](https://suivision.xyz/txblock/2WWwU828Ygq2ydij4p1Mpf8WZV9zhVDXssB8WHh4v83t)
- [distribution](https://suivision.xyz/txblock/91NPAVHpY1Uqnt3F43spj8tNWTXaYrTDib5UWJnurKU1)
- [sail_token](https://suiscan.xyz/mainnet/tx/GFBK3hRYE5tvXLUjSfJdLj625Ygj4Q69ShzxcjHMU1Rf)
- [o_sail_token](https://suiscan.xyz/mainnet/tx/EioxqVFmWPxW1UDXWbYHcesjREk7ocG1iK26pDmgHKsY)
- [liquidity_locker v1](https://suivision.xyz/txblock/Gzqz1ME5rqxpEua1fSNz6rnz9e3knuCuqZEVL963e7ND)
- [integrate](https://suivision.xyz/txblock/CReixV83EcmgD2a3ijKG3iaqUC4BScd5UBQJ4nypuUHU)

- [setup distribtuion tx](https://suiscan.xyz/mainnet/tx/7ToUiNQeX1rwtmrLkgBGHvcUjBYYh5ogsc9J11Z4VyEZ)
- [activate minter tx](https://suiscan.xyz/mainnet/tx/62CQswg1EmVcyfrA2FGgSMGgTHQsYZJJtq9PChhnqbmL)

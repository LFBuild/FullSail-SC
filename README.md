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

- [locker_cap](https://suivision.xyz/txblock/BFiALGxLFUczQVCshPtAEpY5H11kci33FHSTPCZRdYtA)
- [price_monitor](https://suivision.xyz/txblock/3cLn9fdvXF9Mfn7zGhmqziLEWonbDWeFdWic1GtnaQW4)
- [ve](https://suivision.xyz/txblock/3HUrksyiojmCAwgQEVfVmMh2sf1TJ6v1oeuiMNPrxume)
- [distribution](https://suivision.xyz/txblock/DF8EohFmy656d7ax4msy8UffgyLdK1Q9U81avsGvbDNp)
- [airdrop](https://suivision.xyz/txblock/FA7ModSnkR1kFokbpAyRDE6Kw6ewNDr4wpdm4Np8ARif)
- [price_monitor upgrade](https://suivision.xyz/txblock/2Y1yK4JWfYo4eieEC6w3UPQfoZaJBCQkHaRFVrAW1ZKi)
- [price monitro upgrade 2](https://suivision.xyz/txblock/ADt9FsEJqWabSZnFsyNHBpRZQm8ULjoofSSuXSyZkV3y)
- [voting_escrow](https://suivision.xyz/txblock/73jixRjwnjjFPFriydMFkywpU4P4yXsZa4ui8pgzNyHr)
- [voting_escrow upgrade 1](https://suivision.xyz/txblock/72sCTctxRBTwW29nHYShjeAGcpTkFd2d2hhCUquWgCfG)
- [governance](https://suivision.xyz/txblock/mZ12h5eUrA7C3AxMVokQDXnEaWSxbnMXwAi5LPSibwa)
- [ve upgrade](https://suivision.xyz/txblock/CPMXmUU4tK6nAQ4DB9mpyFUnxmTMxboEwwwWNDsy82N8)
- [distribution upgrade](https://suivision.xyz/txblock/2UYup5jRsdrPQ3eex3aXRdgRTUjpWGfURZUzJ8a5DWix)
- [airdrop upgrade 1](https://suivision.xyz/txblock/CvpiuNxB2VFtCXS8nSiVwjmF5ScDei6QDVStLr9i9L3u)
- [airdrop upgrade 2](https://suivision.xyz/txblock/8PWdRjk9Ch7mEFoLRAEGCBufp8xiVrQZkvqqhMtZuNPk)
- [governance upgrade](https://suivision.xyz/txblock/4dUHtr1oy5xNv66PjdcwTUc6BEnPSgCxeUuosk1u5CSi?tab=Changes)
- [governance upgrade 2](https://suivision.xyz/txblock/AHfTeqNcdEri1jevsFDaKSXbWMTTHrwHw9yDXciKWsU)
- [governance upgrade 3](https://suivision.xyz/txblock/B3PNsA5zHiYs16risbNvjaf2QLaTRbYW8YYg8mLpwqWj)
- [integrate](https://suivision.xyz/txblock/63fn6MNR8ykDWdpieKzmdWpP4m8tcxzryoiAwWTAQjCk)

- [setup distribtuion tx](https://suiscan.xyz/mainnet/tx/21y91npsRHWgg5TPnFkFVSWgCFTLhTcvRfGL4bA4ut1p)
- [activate minter tx](https://suiscan.xyz/mainnet/tx/A3bugfXoFzC5YfDEfDd1QBqqTu3dB1XJuT2mRLknKZr2)
- [o_sail]()
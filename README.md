# Overview of Project - FULL_SAIL_DEX

    A Dex platform on SUI chain.

## Overview of Specific Repo - Full_Sail_SCs

    A Dex Smart Contract implementing ve(3,3) model which has similar logic as [Magmafinance](https://magmafinance.io/) on sui.
    The original code was decompiled from testnet contracts:
    - [config](https://testnet.suivision.xyz/package/0xf5ff7d5ba73b581bca6b4b9fa0049cd320360abd154b809f8700a8fd3cfaf7ca?tab=Code)
    - [clmm_pool](https://testnet.suivision.xyz/package/0x23e0b5ab4aa63d0e6fd98fa5e247bcf9b36ad716b479d39e56b2ba9ff631e09d?tab=Code)
    - [distribution](https://testnet.suivision.xyz/package/0x45ac2371c33ca0df8dc784d62c8ce5126d42edd8c56820396524dff2ae0619b1?tab=Code)
    - [integrate](https://testnet.suivision.xyz/package/0x6d225cd7b90ca74b13e7de114c6eba2f844a1e5e1a4d7459048386bfff0d45df?tab=Code)

    The reason why we are using this code is because it is the only ve(3,3) model on Sui and it is a good reference for us to build our own ve(3,3) model. And the code was not deployed
    on mainnet yet, so we had to use testnet version.

    Addresses were took from the frontend [library config](https://github.com/MagmaFinanceIO/magma_clmm_sdk/blob/main/src/config/testnet.ts)

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

Distribution contracts depend on clmm_pool contracts.
Integrate depends on clmm_pool contracts.
Nothing depends on fullsail_config contracts.
Integrate depends on distribution contracts.
Nothing depends on integrate contracts.



## Tech Stack Used and Why

    Move language used for SUI smart contract

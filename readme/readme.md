# Overview of Project - FULL_SAIL_DEX

    A Dex platform on SUI chain.

## Overview of Specific Repo - Full_Sail_SCs

    A Dex Smart Contract implementing ve(3,3) model which has similar logic of movedrome smart contract on Aptos

## Prerequisities

    Need to have knowledge in
    - Blockchain Fundamentals
    - SUI chain
    - Dex(Ve(3,3)) Flow and Logic
    - Move Smart Contract language

## Installation Instructions

    - Install SUI. You can reference this link: https://docs.sui.io/guides/developer/getting-started/sui-install
    - Need to have SUI Wallet Extension or App for interacting with SUI chain by GUI

## Tech Stack Used and Why

    Move language used for SUI smart contract

## Folder breakdown with brief explanation of each file

- **`coin_wrapper`**: This module implements a coin wrapper system on the Sui blockchain that allows for wrapping and unwrapping different types of coins.

- **`epoch`**: This module appears to be a utility module that handles epoch-related time calculations.

- **`fullsail_token`**: This is a token module that implements a custom fungible token called "FULLSAIL", the coin of Full Sail Dex.

- **`gauge`**: This module manages staking and rewards for liquidity pools in the FullSail ecosystem. It provides functionality for creating gauges, staking tokens, claiming rewards, and managing liquidity pool associations.

- **`liquidity_pool`**: This module provides functionality for managing liquidity pools that support token swaps. The module allows users to add and remove liquidity, swap tokens, and claim fees while ensuring robust tracking and event management.

- **`minter`**: The `minter` module is responsible for managing token emissions and minting in the FullSail ecosystem. It allows for the emission of weekly rewards, manages the emission rate, and handles updates to the team account.

- **`rewards_pool_continuous`**: This module provides functionality for a continuous rewards pool mechanism. It allows users to stake tokens, earn rewards, and claim them periodically and distribute rewards based on user stakes..

- **`rewards_pool`**: This module manages rewards for a pool of participants, distributing rewards across different tokens during specific epochs. It supports adding rewards, claiming rewards, and tracking user allocations.

- **`router`**: This module provides the core functionality for token swapping, liquidity management, and pool creation in the FullSail ecosystem on the Sui blockchain. This module facilitates efficient and secure interactions with the FullSail liquidity pools, allowing developers to build advanced DeFi functionalities.

- **`token_whitelist`**: This module provides functionality for managing global and pool-specific token whitelists. It supports adding, verifying, and maintaining tokens in the whitelist, as well as testing utilities to ensure proper functionality.

- **`vote_manager`**: This module is designed to manage voting processes, gauge creation, reward distribution, and token incentives within the FullSail ecosystem. It integrates with other modules like `voting_escrow`, `liquidity_pool`, and `rewards_pool` to handle governance, rewards, and emissions. Users can vote for liquidity pools using veFullSail tokens, claim rewards, and manage incentives for liquidity pools.

- **`voting_escrow`**: This module provides a mechanism for locking `$SAIL` tokens to gain veFullSail tokens, which represent voting power in the FullSail ecosystem. Users can lock tokens for a specified duration, increase the locked amount, extend lock duration, claim rewards from rebases, and participate in governance. This module also supports merging and splitting locked tokens.

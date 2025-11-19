# FullSail SC

© 2025 Metabyte Labs, Inc. All Rights Reserved.

U.S. Patent Application No. 63/861,982. The technology described herein is the subject of a pending U.S. patent application.

Full Sail has added a license to its Full Sail protocol code. You can view the terms of the license at [ULR](LICENSE/250825_Metabyte_Negotiated_Services_Agreement21634227_2_002.docx).

## Audits

Audit provider: **Plainshift**

Final report date: July 15, 2025

Final commit: [here](https://github.com/LFBuild/FullSail-SC/commit/4dc036a9a04c31fb689682821572c21916b50c7a)

Published: [here](/Plainshift%20Full%20Sail%20Final.pdf)

Audit scope:

- `distribution/sources/*.move`
- `liquidity_locker/sources/liquidity_lock_v2.move`

## Overview

A Dex Smart Contract implementing ve(4,4) model which is a modification of ve(3,3) model. On SUI.

## Integration

Packages that are supposed to be used for integration:

- `governance` - the main package implementing position staking and voting.
- `voting_escrow` - package implementing veSAIL locks.
- `integrate` - utilities to help integrate with smart contracts

Other packages are either irrelevant or deprecated.

Consider reading our [docs](https://docs.fullsail.finance/)

### Some key features

- all of the positions must be staked in [Gauges](governance/sources/gauge.move). Unstaked positions earn zero fees.
- When a position is Staked the underlying `Position` is wrapped into `gauge::StakedPosition` object.
- Staked positions earn oSAIL tokens instead of fees.
- Staked positions still earn rewards from Rewarder.
- Each oSAIL token type has an expiration date. If oSAIL is not expired you can either buy SAIL with 50% discount using it or lock it for 6 mounths, 2 years or 4 years. If oSAIL is expired you can only lock it for 4 years and receive veSAIL in return. After a veSAIL lock ends you receive a liquid SAIL.
- There is a new oSAIL type every week. oSAIL type of the claimed rewards is determined by the week you are claiming a position rewards in.

### Position methods

- `gauge::deposit_position` - stakes the position. You need to claim all of the position fees prior to staking.
- `gauge::withdraw_position` - unstakes the position. You need to claim all of the oSAIL tokens prior to unstaking.
- `minter::get_position_reward` - claims oSAIL for the position. oSAIL needs to be claimed from oldest one to the newest one. You can't claim the oSAIL of the epoch 2 unless you claimed oSAIL of the epoch 1.
- `minter::get_pool_reward` - claims Rewarder rewards. These rewards are deposited into pools externally and are distributed with constant speed.

You could also use some utility methods from [integrate package](integrate/sources/staked_position_script.move). These methods just combine listed above or provide more convenient signatures.

## Installation Instructions

- Install SUI. You can reference this link: https://docs.sui.io/guides/developer/getting-started/sui-install
- Need to have SUI Wallet Extension or App for interacting with SUI chain by GUI

## Latest publication artifacts

### SAIL token

`0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL`

### Packages

- integrate original id: `0x45d26cb841183264ea0f61e7ad022015203ac6aa8fdf1706493a24ba3b38d4fa`
- integrate latest id: `0x45d26cb841183264ea0f61e7ad022015203ac6aa8fdf1706493a24ba3b38d4fa`

- clmm_pool original id: `0xe74104c66dd9f16b3096db2cc00300e556aa92edc871be4bc052b5dfb80db239`
- clmm_pool latest id: `0xf7ca99f9fd82da76083a52ab56d88aff15d039b76499b85db8b8bc4d4804584a`

- voting_escrow original id: `0xe616397e503278d406e184d2258bcbe7a263d0192cc0848de2b54b518165f832`
- voting_escrow latest id: `0xd28ec3bedbf5c072ebb40997e66379b4a537452c7c11b5d00f600b613b320a4f`

- governance original id: `0x03fcdcee11f485731170944af3acd26b17d1b96121ce6b756fe8517a95192b3a`
- governance latest id: `0x9f31e92a57412e0f4fb937c388a9de3d3932858a26cb5eff6d41fe59504cc020`

### Objects

- GlobalConfig: `0xe93baa80cb570b3a494cbf0621b2ba96bc993926d34dc92508c9446f9a05d615`
- RewarderGlobalVault: `0xfb971d3a2fb98bde74e1c30ba15a3d8bef60a02789e59ae0b91660aeed3e64e1`
- Stats: `0x6822a33d1d971e040c32f7cc74507010d1fe786f7d06ab89135083ddb07d2dc2`
- PriceProvider: `0x854b2d2c0381bb656ec962f8b443eb082654384cf97885359d1956c7d76e33c9`
- Pools: `0x0efb954710df6648d090bdfa4a5e274843212d6eb3efe157ee465300086e3650`

- Voter: `0x266ff531d300f00ed725e801ba2898d926cad17b9406ea2150e1085de255898f`
- VotingEscrow: `0xe36c353bf09559253306fcec8ccdd6414ef01c20684f1d31f00ed25034718189`
- DistributionConfig: `0x00c124358cf7145b3b97edd3166054e09c3568e6f6f7ef30ad64c0af74f6f942`
- Minter: `0x58f1b1c1c3b996ffc6e100131cddd0c9999d10a2744db37b5d2422ae52db97f4`
- PriceMonitor: `0x1e2b11f45b7d059c55ebaf026b499114f7a4ed0c1fd9d9b4c76b4c759fb63900`
- RebaseDistributor (unused): `0x3ea124cb8ba5c202eb7f14ef0a6cdcd783f0cfd865f63ad7dd79339b1f0c1918`
- Switchboard Aggregator: `0x6fad8b69ab1d9550302c610e5a0ffcb81c1e2b218ff05b6ea6cdd236b5963346`

#### Publication transactions

- [SAIL](https://suivision.xyz/txblock/8h9AypGsfEz4UEycf6zwNjFehpRxHyNYsc7N7JwxzCi)
- [oSAIL](https://suiscan.xyz/mainnet/tx/G2iDDb2zZMn2emhvWx9TrfnCEhzbtDWbUFzoy1S5tuNS)

- [locker_cap](https://suivision.xyz/txblock/BFiALGxLFUczQVCshPtAEpY5H11kci33FHSTPCZRdYtA)
- [price_monitor](https://suivision.xyz/txblock/3cLn9fdvXF9Mfn7zGhmqziLEWonbDWeFdWic1GtnaQW4)
- [ve (legacy)](https://suivision.xyz/txblock/3HUrksyiojmCAwgQEVfVmMh2sf1TJ6v1oeuiMNPrxume)
- [distribution (legacy)](https://suivision.xyz/txblock/DF8EohFmy656d7ax4msy8UffgyLdK1Q9U81avsGvbDNp)
- [airdrop](https://suivision.xyz/txblock/FA7ModSnkR1kFokbpAyRDE6Kw6ewNDr4wpdm4Np8ARif)
- [price_monitor upgrade](https://suivision.xyz/txblock/2Y1yK4JWfYo4eieEC6w3UPQfoZaJBCQkHaRFVrAW1ZKi)
- [price monitro upgrade 2](https://suivision.xyz/txblock/ADt9FsEJqWabSZnFsyNHBpRZQm8ULjoofSSuXSyZkV3y)
- [price monitor upgrade 3](https://suivision.xyz/txblock/J3Rx1acCDMYSFZ9kV7qPQiZ2Bu6WXcF7gAKUgorBnmvR)
- [voting_escrow](https://suivision.xyz/txblock/73jixRjwnjjFPFriydMFkywpU4P4yXsZa4ui8pgzNyHr)
- [voting_escrow upgrade 1](https://suivision.xyz/txblock/72sCTctxRBTwW29nHYShjeAGcpTkFd2d2hhCUquWgCfG)
- [voting_escrow upgrade 2](https://suivision.xyz/txblock/E2ahiCCBxgtSWWkyiV1HbTWReC1xVhXtPKbHLHqCt3Ee)
- [voting escrow upgrade 3](https://suivision.xyz/txblock/HT147M3zLTWyVEJ4AGVT1MD4U3NymuKNbkdYKrU2Htj5)
- [voting escrow upgrade 4](https://suivision.xyz/txblock/Bezad6dbuPHtE4r8xvVwyjEZDQiVMGZEvPHLayveEYe9)
- [governance](https://suivision.xyz/txblock/mZ12h5eUrA7C3AxMVokQDXnEaWSxbnMXwAi5LPSibwa)
- [ve upgrade](https://suivision.xyz/txblock/CPMXmUU4tK6nAQ4DB9mpyFUnxmTMxboEwwwWNDsy82N8)
- [distribution upgrade](https://suivision.xyz/txblock/2UYup5jRsdrPQ3eex3aXRdgRTUjpWGfURZUzJ8a5DWix)
- [airdrop upgrade 1](https://suivision.xyz/txblock/CvpiuNxB2VFtCXS8nSiVwjmF5ScDei6QDVStLr9i9L3u)
- [airdrop upgrade 2](https://suivision.xyz/txblock/8PWdRjk9Ch7mEFoLRAEGCBufp8xiVrQZkvqqhMtZuNPk)
- [governance upgrade](https://suivision.xyz/txblock/4dUHtr1oy5xNv66PjdcwTUc6BEnPSgCxeUuosk1u5CSi?tab=Changes)
- [governance upgrade 2](https://suivision.xyz/txblock/AHfTeqNcdEri1jevsFDaKSXbWMTTHrwHw9yDXciKWsU)
- [governance upgrade 3](https://suivision.xyz/txblock/B3PNsA5zHiYs16risbNvjaf2QLaTRbYW8YYg8mLpwqWj)
- [governance upgrade 4](https://suivision.xyz/txblock/BqrRF16tR7afaFnW5wPGFXb6CqisWMZDwXtN2KDfqtN7)
- [governance upgrade 5](https://suivision.xyz/txblock/FcykJyQs7gJwX3NJTDtaoZy1yVfM7oyjYMvk335Xw3nX?tab=Changes)
- [governance upgrade 6](https://suiscan.xyz/mainnet/tx/B8r4BzfPboP1j2h9JHY9j8cVZTrPPGk6ZWXnJHj6TMaM)
- [governance upgrade 7](https://suiscan.xyz/mainnet/tx/DECRtUGNB1ZC1CbtBvgbGVWrwgN91MYjLU7TBrLquYTo)
- [integrate](https://suivision.xyz/txblock/66DcHUBhvbTztWTB5iCkD9GpULirchBGMGvTuWN3qF6n)

- [setup distribtuion tx](https://suiscan.xyz/mainnet/tx/21y91npsRHWgg5TPnFkFVSWgCFTLhTcvRfGL4bA4ut1p)
- [activate minter tx](https://suiscan.xyz/mainnet/tx/A3bugfXoFzC5YfDEfDd1QBqqTu3dB1XJuT2mRLknKZr2)

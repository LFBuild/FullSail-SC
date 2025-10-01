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

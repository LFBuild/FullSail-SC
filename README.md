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

- integrate original id: `0x4307327d839e5a8f3e6ea6f069ef9b2112577219be25668875d97deb35ec0193`
- integrate latest id: `0x4307327d839e5a8f3e6ea6f069ef9b2112577219be25668875d97deb35ec0193`

- clmm_pool original id: `0xe74104c66dd9f16b3096db2cc00300e556aa92edc871be4bc052b5dfb80db239`
- clmm_pool latest id: `0xf7ca99f9fd82da76083a52ab56d88aff15d039b76499b85db8b8bc4d4804584a`

- voting_escrow original id: `0xe616397e503278d406e184d2258bcbe7a263d0192cc0848de2b54b518165f832`
- voting_escrow latest id: `0xfc410c145e4a9ba8f4aa3cb266bf3e467c35ea39dc90788e9a34f85338b734b7`

- governance original id: `0x03fcdcee11f485731170944af3acd26b17d1b96121ce6b756fe8517a95192b3a`
- governance latest id: `0x1cde2f0d4a50700960a8062f4ed7b19258f2a8c5eb4dc798fbda5e8b8d8c0658`

- vaults(beta) original id: `0x81c2ae708afabfcf04ee68d8002ec33cf7a56bbc7dfeda57951f7ead43865508`
- vaults(beta) latest id: `0x81c2ae708afabfcf04ee68d8002ec33cf7a56bbc7dfeda57951f7ead43865508`

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

Vaults (beta):

- port::PortRegistry: `0x432696df1ac906c9249115861e25a2293e3f6e5a55963e4db3746f78e393b1ee`
- port_oracle::PortOracle: `0xe6477f0157a806515053f0c9de1e0b60d051716c117415012a6bcbca34d3d5df`
- vault_config::GlobalConfig: `0x4e7736b1fd6fc1327bc76f1779d15ad10ea854f05d6262fbcf8e6b26315655b1`

#### Publication transactions

- [SAIL](https://suivision.xyz/txblock/8h9AypGsfEz4UEycf6zwNjFehpRxHyNYsc7N7JwxzCi)
- [oSAIL](https://suiscan.xyz/mainnet/tx/G2iDDb2zZMn2emhvWx9TrfnCEhzbtDWbUFzoy1S5tuNS)

- [locker_cap](https://suivision.xyz/txblock/6VdLrhi9PGWyRrSJqPF2PcebWmSH23zB4KDGheXBwUgD)
- [price_monitor](https://suivision.xyz/txblock/8thaqiGYsL3cX1T8n9W8xZFyAvkyPy9BzR1nCP27ugXc)
- [airdrop](https://suivision.xyz/txblock/GVr2x4Wm9bosocNZWdfGfgn5rdfGzrnkmDB4nNoenivH)
- [voting_escrow](https://suivision.xyz/txblock/GVr2x4Wm9bosocNZWdfGfgn5rdfGzrnkmDB4nNoenivH)
- [governance](https://suivision.xyz/txblock/HftW78RqSSDU3CT8dBLGxNLgiBBXeqFsfhnDmDSYKXk9)
- [integrate](https://suivision.xyz/txblock/35B4T1WoymG67XroZnRCi8S7giW8EvfDvDv7bBontS31)

- [setup distribtuion tx](https://suiscan.xyz/mainnet/tx/2vY5dZCRPqFFQ9z4Mx2izukKeTkQEn6c4RUq4moUtM5C)

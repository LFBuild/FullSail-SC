# Fetch positions

To fetch your positions by address you can use `
GET https://staging.fullsail.finance/api/positions/by_account?address=0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486&page=0&page_size=20` request.

Example response:

```typescript
{
    "pagination": {
        "page": 0,
        "page_size": 20,
        "total": 3
    },
    "positions": [
        {
            "pool": {
                "address": "0x195fa451874754e5f14f88040756d4897a5fe4b872dffc4e451d80376fa7c858",
                "created_at": 1748471640000,
                "current_sqrt_price": "557464332235486583",
                "dinamic_stats": {
                    "apr": 205.1,
                    "apt": 11824.99,
                    "fees_usd": 12313.45,
                    "fees_usd_24h": 55.08,
                    "fees_usd_30d": 9850.21,
                    "fees_usd_7d": 2369.05,
                    "fees_usd_90d": 12290.55,
                    "lower_active_tick": -76640,
                    "tvl": 144327.56,
                    "upper_active_tick": -65560,
                    "volume_usd": 6891590.99,
                    "volume_usd_24h": 28652.48,
                    "volume_usd_30d": 5420042.87,
                    "volume_usd_7d": 1158507.13,
                    "volume_usd_90d": 6881026.92
                },
                "distributed_osail_24h": "18485015103",
                "fee": 1902,
                "fee_data": {
                    "additional_fee_rate": 2,
                    "adjusted_additional_fee_rate": 2,
                    "adjusted_base_fee_rate": 1900,
                    "base_fee_rate": 1900,
                    "fee_rate": 1902,
                    "is_dynamic": true
                },
                "full_apr": 205.1,
                "gauge_id": "0xaa760719d939ad54317419b99f5d912639c28e2f4d31a11f127649e89b447f6a",
                "is_paused": false,
                "liquidity": "91842744405",
                "name": "wBTC/USDC",
                "rewards": [],
                "tick_spacing": 40,
                "token_a": {
                    "address": "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
                    "current_price": 0.999704,
                    "decimals": 6,
                    "id": 2,
                    "logo_url": "https://app.fullsail.finance/static_files/USDC.png",
                    "name": "USDC",
                    "symbol": "USDC"
                },
                "token_b": {
                    "address": "0xaafb102dd0902f5055cadecd687fb5b71ca82ef0e0285d90afde828ec58ca96b::btc::BTC",
                    "current_price": 109557,
                    "decimals": 8,
                    "id": 6,
                    "logo_url": "https://app.fullsail.finance/static_files/wBTC.png",
                    "name": "Wrapped Bitcoin",
                    "symbol": "wBTC"
                },
                "tokens_reversed": true,
                "type": "concentrated",
                "volume_positions_usd": 0
            },
            "position": {
                "amount_token_a": "358528",
                "amount_token_a_usd": 0.36,
                "amount_token_b": "769",
                "amount_token_b_usd": 0.84,
                "closed_at": 0,
                "created_at": 1754430416213,
                "id": "0x554e633407c84c9b919e8a7edf99fd54fc3108c1c1064cc68f0f4ec21bcfa686",
                "liquidity": "373748",
                "locked": false,
                "owner": "0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486",
                "pool_id": "0x195fa451874754e5f14f88040756d4897a5fe4b872dffc4e451d80376fa7c858",
                "soft_locked": false,
                "stake_info": {
                    "id": "0x7ccc4e613ab8fb4165cd4027cca026d5911dc353d8b5c8a3efe16b204864e114",
                    "stake_time": 1758700284161,
                    "unstake_time": 0
                },
                "staked": true,
                "tick_lower": -71400,
                "tick_upper": -69400
            }
        },
        {
            "pool": {
                "address": "0x7fc2f2f3807c6e19f0d418d1aaad89e6f0e866b5e4ea10b295ca0b686b6c4980",
                "created_at": 1748471760000,
                "current_sqrt_price": "325487507303359803128",
                "dinamic_stats": {
                    "apr": 106.02,
                    "apt": 43310.83,
                    "fees_usd": 39904.06,
                    "fees_usd_24h": 362.4,
                    "fees_usd_30d": 20425.38,
                    "fees_usd_7d": 2804.77,
                    "fees_usd_90d": 38952.7,
                    "lower_active_tick": -443600,
                    "tvl": 198573.91,
                    "upper_active_tick": 443600,
                    "volume_usd": 21764778.61,
                    "volume_usd_24h": 183216.44,
                    "volume_usd_30d": 10966152.12,
                    "volume_usd_7d": 1464282.38,
                    "volume_usd_90d": 21275267.72
                },
                "distributed_osail_24h": "14800773366",
                "fee": 1978,
                "fee_data": {
                    "additional_fee_rate": 185,
                    "adjusted_additional_fee_rate": 185,
                    "adjusted_base_fee_rate": 1793,
                    "base_fee_rate": 1793,
                    "fee_rate": 1978,
                    "is_dynamic": true
                },
                "full_apr": 251,
                "gauge_id": "0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72",
                "is_paused": false,
                "liquidity": "30377694685908",
                "name": "SUI/USDC",
                "rewards": [
                    {
                        "apr": 144.98,
                        "emissions_per_day": "191056920863",
                        "token": {
                            "address": "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
                            "current_price": 3.21,
                            "decimals": 9,
                            "id": 1,
                            "logo_url": "https://app.fullsail.finance/static_files/SUI.png",
                            "name": "Sui",
                            "symbol": "SUI"
                        }
                    }
                ],
                "tick_spacing": 40,
                "token_a": {
                    "address": "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
                    "current_price": 0.999704,
                    "decimals": 6,
                    "id": 2,
                    "logo_url": "https://app.fullsail.finance/static_files/USDC.png",
                    "name": "USDC",
                    "symbol": "USDC"
                },
                "token_b": {
                    "address": "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
                    "current_price": 3.21,
                    "decimals": 9,
                    "id": 1,
                    "logo_url": "https://app.fullsail.finance/static_files/SUI.png",
                    "name": "Sui",
                    "symbol": "SUI"
                },
                "tokens_reversed": true,
                "type": "concentrated",
                "volume_positions_usd": 0
            },
            "position": {
                "amount_token_a": "955819542",
                "amount_token_a_usd": 955.54,
                "amount_token_b": "1677722312093",
                "amount_token_b_usd": 5385.49,
                "closed_at": 0,
                "created_at": 1758859147359,
                "id": "0xf219c70d1d185d4a36fe3f498e30ea3fe2964ec9e442637db7604e23ab057d77",
                "liquidity": "671954457908",
                "locked": false,
                "owner": "0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486",
                "pool_id": "0x7fc2f2f3807c6e19f0d418d1aaad89e6f0e866b5e4ea10b295ca0b686b6c4980",
                "soft_locked": false,
                "stake_info": {
                    "id": "0x46180fd1d7921afa61ff1a47bb2f19eb7687cfc7e40e3b5caa4b2412477813f6",
                    "stake_time": 1758888217947,
                    "unstake_time": 0
                },
                "staked": true,
                "tick_lower": 54360,
                "tick_upper": 57920
            }
        },
        {
            "pool": {
                "address": "0x7fc2f2f3807c6e19f0d418d1aaad89e6f0e866b5e4ea10b295ca0b686b6c4980",
                "created_at": 1748471760000,
                "current_sqrt_price": "325487507303359803128",
                "dinamic_stats": {
                    "apr": 106.02,
                    "apt": 43310.83,
                    "fees_usd": 39904.06,
                    "fees_usd_24h": 362.4,
                    "fees_usd_30d": 20425.38,
                    "fees_usd_7d": 2804.77,
                    "fees_usd_90d": 38952.7,
                    "lower_active_tick": -443600,
                    "tvl": 198573.91,
                    "upper_active_tick": 443600,
                    "volume_usd": 21764778.61,
                    "volume_usd_24h": 183216.44,
                    "volume_usd_30d": 10966152.12,
                    "volume_usd_7d": 1464282.38,
                    "volume_usd_90d": 21275267.72
                },
                "distributed_osail_24h": "14800773366",
                "fee": 1978,
                "fee_data": {
                    "additional_fee_rate": 185,
                    "adjusted_additional_fee_rate": 185,
                    "adjusted_base_fee_rate": 1793,
                    "base_fee_rate": 1793,
                    "fee_rate": 1978,
                    "is_dynamic": true
                },
                "full_apr": 251,
                "gauge_id": "0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72",
                "is_paused": false,
                "liquidity": "30377694685908",
                "name": "SUI/USDC",
                "rewards": [
                    {
                        "apr": 144.98,
                        "emissions_per_day": "191056920863",
                        "token": {
                            "address": "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
                            "current_price": 3.21,
                            "decimals": 9,
                            "id": 1,
                            "logo_url": "https://app.fullsail.finance/static_files/SUI.png",
                            "name": "Sui",
                            "symbol": "SUI"
                        }
                    }
                ],
                "tick_spacing": 40,
                "token_a": {
                    "address": "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
                    "current_price": 0.999704,
                    "decimals": 6,
                    "id": 2,
                    "logo_url": "https://app.fullsail.finance/static_files/USDC.png",
                    "name": "USDC",
                    "symbol": "USDC"
                },
                "token_b": {
                    "address": "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI",
                    "current_price": 3.21,
                    "decimals": 9,
                    "id": 1,
                    "logo_url": "https://app.fullsail.finance/static_files/SUI.png",
                    "name": "Sui",
                    "symbol": "SUI"
                },
                "tokens_reversed": true,
                "type": "concentrated",
                "volume_positions_usd": 0
            },
            "position": {
                "amount_token_a": "782891960",
                "amount_token_a_usd": 782.66,
                "amount_token_b": "99343221367",
                "amount_token_b_usd": 318.89,
                "closed_at": 0,
                "created_at": 1758888400282,
                "id": "0x5de4997f343de8f3ee48f866fe0840186f77f7f4313d831e3c66679780dcfec6",
                "liquidity": "231896753017",
                "locked": false,
                "owner": "0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486",
                "pool_id": "0x7fc2f2f3807c6e19f0d418d1aaad89e6f0e866b5e4ea10b295ca0b686b6c4980",
                "soft_locked": false,
                "stake_info": {
                    "id": "0x2109ef6f4e17afbba3d98e0cb2e0c9bbf506ecd78a60bdb1cbe096737b10808b",
                    "stake_time": 1758888400282,
                    "unstake_time": 0
                },
                "staked": true,
                "tick_lower": 56920,
                "tick_upper": 58640
            }
        }
    ]
}
```

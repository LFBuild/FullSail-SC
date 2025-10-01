# Claim rewards

Incentives are distributed using `rewarder` module from `clmm_pool` package. However, positions
are stored inside `gauge` so it is impossible to call `get_reward` directly. So we
introduce proxy methods to claim rewards in the `gauge` module.

Example call

```typescript
    export type ClaimPoolRewardParams = {
        /**
         * The type of the reward coin.
         */
        rewardCoinTypes: SuiObjectIdType[]
        /**
         * The address type of the coin a in the pair.
         */
        coinTypeA: SuiAddressType

        /**
         * The address type of the coin b in the pair.
         */
        coinTypeB: SuiAddressType
        /**
         * The unique identifier of the pool.
         */
        poolId: SuiObjectIdType
        /**
         * The unique identifier of the stake position.
         */
        positionStakeId: SuiObjectIdType

        /**
         * The unique identifier of the gauge.
         */
        gaugeId: SuiObjectIdType
    }

    static async buildClaimPoolRewardPayload(sdk: SDK, params: ClaimPoolRewardParams, transaction?: Transaction): Promise<Transaction> {
        const tx = transaction ?? new Transaction()

        const { distribution } = sdk.sdkOptions
        const { global_config_id, distribution_config_id } = getPackagerConfigs(sdk.sdkOptions.magma_config)
        const { global_vault_id } = getPackagerConfigs(sdk.sdkOptions.clmm_pool)

        const functionName = 'get_pool_reward'

        params.rewardCoinTypes.forEach((rewardCoinType) => {
        const rewardCoin = tx.moveCall({
            target: `${distribution.published_at}::${Gauge}::${functionName}`,
            typeArguments: [params.coinTypeA, params.coinTypeB, rewardCoinType],
            arguments: [
            tx.object(global_config_id),
            tx.object(global_vault_id),
            tx.object(params.gaugeId),
            tx.object(distribution_config_id),
            tx.object(params.poolId),
            tx.object(params.positionStakeId),
            tx.object(CLOCK_ADDRESS),
            ],
        })

        const coin = tx.moveCall({
            target: `0x2::coin::from_balance`,
            typeArguments: [rewardCoinType],
            arguments: [rewardCoin],
        })

        tx.transferObjects([coin], sdk.senderAddress)
        })

        return tx
    }
```

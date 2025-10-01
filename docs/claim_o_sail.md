# Claim oSAIL

oSAIL it the main reward of liquidity providers. It is an option token that gives you the right to purchase SAIL with 50% discount or you can lock it
and redeem 1 to 1 to SAIL after 4 year lock.

oSAIL type is new every week. It is determined by the week you want to claim your oSAIL in. To get current epoch oSAIL refer to [this doc](./get_o_sail_type.md)

```typescript
    export type ClaimPositionOSailRewardParams = {
        /**
         * The type of oSail.
         */
        oSailCoinType: SuiObjectIdType
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

    static async buildClaimPositionOSailPayload(
        sdk: SDK,
        params: ClaimPositionOSailRewardParams
    ): Promise<{ tx: Transaction; oSailCoin: TransactionResult }> {
        const tx = new Transaction()

        const { distribution } = sdk.sdkOptions
        const { distribution_config_id, minter_id, magma_token } = getPackagerConfigs(sdk.sdkOptions.magma_config)

        const functionName = 'get_position_reward'

        const oSailCoin = tx.moveCall({
        target: `${distribution.published_at}::${Minter}::${functionName}`,
        typeArguments: [params.coinTypeA, params.coinTypeB, magma_token, params.oSailCoinType],
        arguments: [
            tx.object(minter_id),
            tx.object(distribution_config_id),
            tx.object(params.gaugeId),
            tx.object(params.poolId),
            tx.object(params.positionStakeId),
            tx.object(CLOCK_ADDRESS),
        ],
        })

        return { tx, oSailCoin }
    }
```

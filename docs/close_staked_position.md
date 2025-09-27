# Close Staked Position

Note that you need to claim *both oSAIL and rewards (incentives)* prior to closing the position.

Example
```typescript
    export type CloseStakedPositionParams = {
        /**
         * The object id about which pool you want to operation.
         */
        pool_id: SuiObjectIdType
        /**
         * The object id about position.
         */
        pos_id: SuiObjectIdType
            /**
         * The address type of the coin a in the pair.
         */
        coinTypeA: SuiAddressType

        /**
         * The address type of the coin b in the pair.
         */
        coinTypeB: SuiAddressType
        /**
         * Coin types associated with rewarder contracts.
         */
        rewarder_coin_types: SuiAddressType[]

        /**
         * The minimum amount of the first coin to be received.
         */
        min_amount_a: string

        /**
         * The minimum amount of the second coin to be received.
         */
        min_amount_b: string

        /**
         * Indicates whether to collect fees during the closing.
         */
        collect_fee: boolean
        /**
         * The object id of gauge contract for pool.
         */
        gaugeId: SuiObjectIdType

        /**
         * The address type of the osail type token.
         */
        current_epoch_osail_type: SuiAddressType
        positionStakeId: SuiObjectIdType
    }
    async closeStakedPositionTransactionPayload(params: CloseStakedPositionParams, tx?: Transaction): Promise<Transaction> {
        if (!checkInvalidSuiAddress(this._sdk.senderAddress)) {
        throw new ClmmpoolsError('this config sdk senderAddress is not set right', UtilsErrorCode.InvalidSendAddress)
        }

        const { clmm_pool, integrate, magma_config } = this.sdk.sdkOptions
        const clmmConfigs = getPackagerConfigs(clmm_pool)
        const magmaConfigs = getPackagerConfigs(magma_config)

        tx = await TransactionUtil.buildClaimPoolRewardPayload(
        this.sdk,
        {
            rewardCoinTypes: params.rewarder_coin_types,
            coinTypeA: params.coinTypeA,
            coinTypeB: params.coinTypeB,
            poolId: params.pool_id,
            positionStakeId: params.positionStakeId,
            gaugeId: params.gaugeId,
        },
        tx
        )

        const typeArguments = [params.coinTypeA, params.coinTypeB, magmaConfigs.magma_token, params.current_epoch_osail_type]

        const funcName = 'close_staked_position'

        tx.moveCall({
        target: `${integrate.published_at}::${ClmmIntegratePoolV2Module}::${funcName}`,
        typeArguments,
        arguments: [
            tx.object(clmmConfigs.global_config_id),
            tx.object(magmaConfigs.distribution_config_id),
            tx.object(magmaConfigs.minter_id),
            tx.object(clmmConfigs.global_vault_id),
            tx.object(params.pool_id),
            tx.object(params.gaugeId),
            tx.object(params.positionStakeId),
            tx.pure.u64(params.min_amount_a),
            tx.pure.u64(params.min_amount_b),
            tx.object(CLOCK_ADDRESS),
        ],
        })

        return tx
    }
```å
# Add liqudity

To create a new position or add liquidity to existing one use helper methods from `integrate` package.

Below you can see an example of tx payload to add liquidity. Not that you need to _claim oSAIL_ prior to adding liquidity to the existing position.

```typescript
  export type AddLiquidityFixTokenParams = {
    /**
     * If fixed amount A, you must set amount_a, amount_b will be auto calculated by ClmmPoolUtil.estLiquidityAndcoinAmountFromOneAmounts().
     */
    amount_a: number | string
    /**
     * If fixed amount B, you must set amount_b, amount_a will be auto calculated by ClmmPoolUtil.estLiquidityAndcoinAmountFromOneAmounts().
     */
    amount_b: number | string
    /**
     * Price slippage point.
     */
    slippage: number
    /**
     * true means fixed coinA amount, false means fixed coinB amount
     */
    fix_amount_a: boolean
    /**
     * control whether or not to create a new position or add liquidity on existed position.
     */
    is_open: boolean
    stakePositionParams: {
      /**
       * Whether staking is enabled for the position.
       */
      isStakeEnabled: boolean
      /**
       * The object id of the gauge contract for the position.
       */
      gauge_id: SuiObjectIdType
      /**
       * The object id of the last epoch OSail token.
       */
      epoch_osail: SuiObjectIdType
    }
    /**
     * Represents the index of the lower tick boundary.
     */
    tick_lower: string | number
    /**
     * Represents the index of the upper tick boundary.
     */
    tick_upper: string | number
  }

  private static buildAddStakedLiquidityFixTokenArgs(
    tx: Transaction,
    sdk: SDK,
    allCoinAsset: CoinAsset[],
    params: AddLiquidityFixTokenParams,
    primaryCoinAInputs: BuildCoinResult,
    primaryCoinBInputs: BuildCoinResult
  ) {
    const functionName = params.is_open ? 'open_position_and_stake_with_liquidity_by_fix_coin' : 'add_staked_liquidity_by_fix_coin'
    const { clmm_pool, integrate } = sdk.sdkOptions

    const clmmConfig = getPackagerConfigs(clmm_pool)
    const magmaConfig = getPackagerConfigs(sdk.sdkOptions.magma_config)

    const typeArguments = params.is_open
      ? [params.coinTypeA, params.coinTypeB]
      : [params.coinTypeA, params.coinTypeB, magmaConfig.magma_token, params.stakePositionParams.epoch_osail]

    const args = params.is_open
      ? [
          tx.object(clmmConfig.global_config_id),
          tx.object(magmaConfig.distribution_config_id),
          tx.object(clmmConfig.global_vault_id),
          tx.object(params.pool_id),
          tx.object(params.stakePositionParams.gauge_id),
          tx.pure.u32(Number(asUintN(BigInt(params.tick_lower)).toString())),
          tx.pure.u32(Number(asUintN(BigInt(params.tick_upper)).toString())),
          primaryCoinAInputs.targetCoin,
          primaryCoinBInputs.targetCoin,
          tx.pure.u64(params.amount_a),
          tx.pure.u64(params.amount_b),
          tx.pure.bool(params.fix_amount_a),
          tx.object(CLOCK_ADDRESS),
        ]
      : [
          tx.object(clmmConfig.global_config_id),
          tx.object(magmaConfig.distribution_config_id),
          tx.object(magmaConfig.minter_id),
          tx.object(clmmConfig.global_vault_id),
          tx.object(params.pool_id),
          tx.object(params.stakePositionParams.gauge_id),
          tx.object(params.pos_id),
          primaryCoinAInputs.targetCoin,
          primaryCoinBInputs.targetCoin,
          tx.pure.u64(params.amount_a),
          tx.pure.u64(params.amount_b),
          tx.pure.bool(params.fix_amount_a),
          tx.object(CLOCK_ADDRESS),
        ]

    const stakedPos = tx.moveCall({
      target: `${integrate.published_at}::${ClmmIntegratePoolV2Module}::${functionName}`,
      typeArguments,
      arguments: args,
    })

    tx.transferObjects([stakedPos], sdk.senderAddress)

    return tx
  }
```

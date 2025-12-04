#!/bin/bash

source ./export.sh

# Coin types for the pool
export COIN_A=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
export COIN_B=0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL
export POOL=0x038eca6cc3ba17b84829ea28abac7238238364e0787ad714ac35c1140561a6b9
export GAUGE=0x6f8a9cc1e192c67f66667fba28c4e186cef72cd8d228002100069642557a56f9

# Liquidity position parameters
export LOWER_OFFSET=100      # Lower tick offset from current price (u32)
export UPPER_OFFSET=100      # Upper tick offset from current price (u32)
export REBALANCE_THRESHOLD=5 # Rebalance threshold in ticks (u32)

# Port parameters
export QUOTE_TYPE_A=true     # true if CoinTypeA is used as base currency, false if CoinTypeB
export HARD_CAP=1000000000000000  # Maximum port capitalization in base currency (u128)

# Initial balances (Coin IDs to be converted to Balance)
# These coins must be available to the transaction sender
export START_COIN_A_ID=0x...  # CoinTypeA coin ID for initial balance
export START_COIN_B_ID=0x...  # CoinTypeB coin ID for initial balance

sui client ptb \
  --move-call sui::coin::into_balance "<$COIN_A>" @$START_COIN_A_ID \
  --assign balance_a \
  --move-call sui::coin::into_balance "<$COIN_B>" @$START_COIN_B_ID \
  --assign balance_b \
  --move-call $PACKAGE::port::create_port \
    "<$COIN_A,$COIN_B>" \
    @$VAULT_CONFIG \
    @$PORT_REGISTRY \
    @$PORT_ORACLE \
    @$CLMM_GLOBAL_CONFIG \
    @$CLMM_VAULT \
    @$DISTRIBUTION_CONFIG \
    @$GAUGE \
    @$POOL \
    $LOWER_OFFSET \
    $UPPER_OFFSET \
    $REBALANCE_THRESHOLD \
    $QUOTE_TYPE_A \
    $HARD_CAP \
    balance_a \
    balance_b \
    @$CLOCK

#!/bin/bash

source ./export.sh

# Coin types for the pool
export COIN_A=0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC
export COIN_B=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI
export POOL=0xe455d2ce2e83bbe3b47615ee2727dc6c9ffbf022c98fd1c1bfc43535b79c13a2
export GAUGE=0x5c0326e7c8c0aa53afc8a81443b454c8ae46f9d0a29b20b7355d0e32b39a424a

# Liquidity position parameters
export LOWER_OFFSET=5000      # Lower tick offset from current price (u32)
export UPPER_OFFSET=5000      # Upper tick offset from current price (u32)
export REBALANCE_THRESHOLD=4000 # Rebalance threshold in ticks (u32)

# Port parameters
export QUOTE_TYPE_A=true     # true if CoinTypeA is used as base currency, false if CoinTypeB
export HARD_CAP=1000000000  # Maximum port capitalization in base currency (u128)

# Initial balances (Coin IDs to be converted to Balance)
# These coins must be available to the transaction sender
export START_COIN_A_ID=0x7db0b4f6ed3b276d8e9eca2d57c8b42593ad8931fe89e35c1d233154ef8309b7  # CoinTypeA coin ID for initial balance
export START_COIN_B_ID=0x313d714f089daa6e8282a830582e3cbd81d004e29490cfd017db0e25553cf8b6  # CoinTypeB coin ID for initial balance

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

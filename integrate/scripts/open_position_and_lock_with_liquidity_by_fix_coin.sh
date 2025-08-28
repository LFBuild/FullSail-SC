#!/bin/bash

# Script for opening position and locking liquidity
# Method: open_position_and_lock_with_liquidity_by_fix_coin

source ./export.sh

# Parameters for position opening and liquidity locking
export TICK_LOWER=4294965783              # Lower tick boundary (u32) - converted from -1512
export TICK_UPPER=495               # Upper tick boundary (u32)
export AMOUNT_A=1153                    # Amount of token A to add (u64)
export AMOUNT_B=127800004                   # Amount of token B to add (u64)
export FIX_AMOUNT_A=true                # Whether to fix amount A (true) or amount B (false)
export BLOCK_PERIOD_INDEX=0           # Block period index for locking (u64)

# Package IDs
export PACKAGE_INTEGRATE="0x1e415c1f032208644798cf5f3980b3fd4f058a9b01ce191a4eca79696e799a1b"

# Pool ID
export POOL_ID="0xdeade3da8210391df05c266dfbef5733fd4b7198b3d29a4dbebf22eb96aae445"

# Locker and Pool Tranche Manager IDs (from liquidity_locker/scripts/export.sh)
export LOCKER_V1="0xea6da57f34bb097e0842a1bc335b8625c51cd5ff3fe60f4df2a421bd759707b0"
export POOL_TRANCH_MANAGER="0x3bed94d2fc59e91c8ac42ea6f1ff0440d7e6fd26231575997f9165601b222b6b"

# Token types (replace with real types if needed)
export COIN_A_TYPE="0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B"
export COIN_B_TYPE="0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A"

# Coin IDs for the tokens to add (replace with real coin IDs)
export COIN_A_ID="0x74b32706b7b72b07a282de53ca33fbee9ec4bb0801b55c356cd2be37d1130b9d"
export COIN_B_ID="0xb78664f0dd1f6ab649b5bddbbf8c946d0173219a3a668ab97f5f86596c03cd0d"

# Recipient address for the locked positions
export RECIPIENT_ADDRESS="0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340"

# Execute transaction
sui client ptb \
--move-call $PACKAGE_INTEGRATE::liquidity_lock_v1_script::open_position_and_lock_with_liquidity_by_fix_coin \
  "<$COIN_A_TYPE,$COIN_B_TYPE>" \
  @$GLOBAL_CONFIG \
  @$REWARDER_GLOBAL_VAULT \
  @$POOL_ID \
  @$LOCKER_V1 \
  @$POOL_TRANCH_MANAGER \
  $TICK_LOWER \
  $TICK_UPPER \
  @$COIN_A_ID \
  @$COIN_B_ID \
  $AMOUNT_A \
  $AMOUNT_B \
  $FIX_AMOUNT_A \
  $BLOCK_PERIOD_INDEX \
  @$CLOCK \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "Position opened and liquidity locked for address: $RECIPIENT_ADDRESS" 
#!/bin/bash

# Script for creating a new pool tranche
# Method: pool_tranche::new

source ./export.sh

# Pool ID (from the pool we want to create tranche for)
export POOL_ID="0xdeade3da8210391df05c266dfbef5733fd4b7198b3d29a4dbebf22eb96aae445"

# Token types for the pool (must match the pool's token types)
export COIN_A_TYPE="0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B"
export COIN_B_TYPE="0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A"

# Tranche parameters
export VOLUME_IN_COIN_A=true                    # Whether volume is measured in coin A (true) or coin B (false)
export TOTAL_VOLUME=99999999999900000000000000000        # Total volume capacity in Q64.64 format (10000000 << 64)
export MINIMUM_REMAINING_VOLUME_PERCENTAGE=1000 # Minimum volume percentage (10% = 1000)

# Execute transaction
sui client ptb \
--make-move-vec "<u64>" "[10000, 20000]" \
--assign duration_profitabilities \
--move-call $PACKAGE::pool_tranche::new \
  "<$COIN_A_TYPE,$COIN_B_TYPE>" \
  @$POOL_TRANCH_MANAGER \
  @$POOL_ID \
  $VOLUME_IN_COIN_A \
  $TOTAL_VOLUME \
  duration_profitabilities \
  $MINIMUM_REMAINING_VOLUME_PERCENTAGE \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "New pool tranche created for pool: $POOL_ID" 
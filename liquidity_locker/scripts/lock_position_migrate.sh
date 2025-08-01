#!/bin/bash

# Script for migrating lock position from v1 to v2
# Method: liquidity_lock_v2::lock_position_migrate

source ./export.sh

# Token types for the pool (must match the pool's token types)
export COIN_A_TYPE="0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B"
export COIN_B_TYPE="0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A"

# Object IDs (replace with actual IDs)
export GLOBAL_CONFIG="0x2d7c926687a545dd7f4a80bbb2887ea88cfab10df99b92b33962ab04b472c1d3"
export DISTRIBUTION_CONFIG="0x0471e2fc949389e4518d108c6f70a0eaf60f6d1d32bd1d6c0e0c4f4353d75e7a"
export LOCKER_V2="0xea6da57f34bb097e0842a1bc335b8625c51cd5ff3fe60f4df2a421bd759707b0"
export GAUGE="0x0d5211a477bbd78f58d0210d3664b52e0ca9384eb7e0bc82bd45e960892e17e3"
export POOL="0xdeade3da8210391df05c266dfbef5733fd4b7198b3d29a4dbebf22eb96aae445"
export LOCK_POSITION_V1="0xa33543b735c06ba3f10f7e6500275eb36aac575eb937e3015f9f205232dc830b"

# Recipient address for the migrated position
export RECIPIENT_ADDRESS="0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340"

# Execute transaction
sui client ptb \
--move-call $PACKAGE::liquidity_lock_v2::lock_position_migrate \
  "<$COIN_A_TYPE,$COIN_B_TYPE>" \
  @$GLOBAL_CONFIG \
  @$DISTRIBUTION_CONFIG \
  @$LOCKER_V1 \
  @$LOCKER_V2 \
  @$GAUGE \
  @$POOL \
  @$LOCK_POSITION_V1 \
  @$CLOCK \
--assign migrated_position \
--move-call sui::transfer::public_transfer \
  "<$PACKAGE::liquidity_lock_v2::LockedPosition<$COIN_A_TYPE,$COIN_B_TYPE>>" \
  migrated_position \
  @$RECIPIENT_ADDRESS \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "Lock position migrated from v1 to v2 and transferred to address: $RECIPIENT_ADDRESS" 
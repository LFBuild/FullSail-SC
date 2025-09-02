#!/bin/bash

# Script for adding liquidity to a staked position
# Method: add_staked_liquidity_by_fix_coin

source ./export.sh

# Parameters for liquidity addition
export AMOUNT_A=1153                  # Amount of token A to add (u64)
export AMOUNT_B=12784                 # Amount of token B to add (u64)
export FIX_AMOUNT_A=true                 # Whether to fix amount A (true) or amount B (false)

# Staked position ID
export STAKED_POSITION_ID="0xfc85b7c49848a7cce415bc96b0cc60e371006117d1ec02deb33dbc0e39547fd4"

# Pool ID
export POOL_ID="0x92ed1d78ee3fca845e82c1f19947a7204cf6271355735707fc7d16fc80afdf81"

# Gauge ID
export GAUGE_ID="0x0d5211a477bbd78f58d0210d3664b52e0ca9384eb7e0bc82bd45e960892e17e3"

# Minter ID (from governance/scripts/export.sh)
export MINTER_ID="0x7bf4f0583573e2957fca68460d4c14f3be211dc3c17c06b19916aa209a4e2cfd"

# Voter ID (from governance/scripts/export.sh)
export VOTER_ID="0x51d90050e620b75c3d2bb792113029ba705e15ec17c939636260dd943554d06f"

# Distribution config ID (from governance/scripts/export.sh)
export DISTRIBUTION_CONFIG_ID="0x14831b68338f22fe028ff7921cf5d676ac6d1cb505da0c9fc564d5c96c0d3993"

# Token types (replace with real types if needed)
export COIN_A_TYPE="0x60e151f61420f4f782a7c0edb275a2e6eb8476aa6a864b15e2fc82cf2f33e9e3::sail_token::SAIL_TOKEN"
export COIN_B_TYPE="0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A"
export SAIL_COIN_TYPE="0x60e151f61420f4f782a7c0edb275a2e6eb8476aa6a864b15e2fc82cf2f33e9e3::sail_token::SAIL_TOKEN"
export EPOCH_OSAIL_TYPE="0xff1d86425db69d9a4b39aea1094a9396b14abfaa72a5688b00d8aa32742d9805::osail3::OSAIL3"

# Recipient address for the new staked position
export RECIPIENT_ADDRESS="0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340"

# Coin IDs for the tokens to add (replace with real coin IDs)
export COIN_A_ID="0xe721d12e7a98f97f49073294c4bcac6413f02e0fe37bfbf4dfcd69aa1102147b"
export COIN_B_ID="0x9d77a45ba3ba3439fbb16e35db17c16fbe2f971eb15f299c75b9c64663574679"

# Execute transaction
sui client ptb \
--move-call $PACKAGE::pool_script_v2::add_staked_liquidity_by_fix_coin \
  "<$COIN_A_TYPE,$COIN_B_TYPE,$SAIL_COIN_TYPE,$EPOCH_OSAIL_TYPE>" \
  @$GLOBAL_CONFIG \
  @$DISTRIBUTION_CONFIG_ID \
  @$MINTER_ID \
  @$VOTER_ID \
  @$REWARDER_GLOBAL_VAULT \
  @$POOL_ID \
  @$GAUGE_ID \
  @$STAKED_POSITION_ID \
  @$COIN_A_ID \
  @$COIN_B_ID \
  $AMOUNT_A \
  $AMOUNT_B \
  $FIX_AMOUNT_A \
  @$CLOCK \
--assign new_staked_position \
--move-call sui::transfer::public_transfer \
  "<$DISTRIBTION_PACKAGE::gauge::StakedPosition>" \
  new_staked_position \
  @$RECIPIENT_ADDRESS \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "New staked position transferred to address: $RECIPIENT_ADDRESS"
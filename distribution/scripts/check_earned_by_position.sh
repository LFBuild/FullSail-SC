#!/bin/bash

# Script to check earned rewards for a specific position
# Function: earned_by_position

source ./export.sh
source ./pools/pool_sail_tkna.sh

# Position ID to check
export POSITION_ID="0xf0af275e5417bfc6f44d3d94be25a437b65af98631716c85c763684db598d275"

export REWARD_TOKEN_TYPE="0x36903ca4bf06cce628a444275d91522f22616285fa65d2ff5a1d2fffa4caab86::osail16::OSAIL16"

export GAUGE_ID="0x0d5211a477bbd78f58d0210d3664b52e0ca9384eb7e0bc82bd45e960892e17e3"
export POOL_ID="0x92ed1d78ee3fca845e82c1f19947a7204cf6271355735707fc7d16fc80afdf81"
export COIN_A="0x60e151f61420f4f782a7c0edb275a2e6eb8476aa6a864b15e2fc82cf2f33e9e3::sail_token::SAIL_TOKEN"
export COIN_B="0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A"

sui client ptb \
--move-call $PACKAGE::gauge::earned_by_position "<$COIN_A,$COIN_B,$REWARD_TOKEN_TYPE>" @$GAUGE_ID @$POOL_ID @$POSITION_ID @$CLOCK \
--gas-budget 50000000 
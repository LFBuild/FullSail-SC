#!/bin/bash

source ./export.sh

# Port ID
export PORT=0xf8c684c5b8111fee9b4b1eeaa98292749f69f4160039e384ca4dddfa1933e232
export REWARD_COIN_TYPE=0x42d15443d64aacf9f0dcdd9d9d3e3d2d080c871c9256b67606f3f2dcac2e7a83::token_j::TOKEN_J
export REWARD_COIN_ID=0x0f95344dec1742b21069c2c679e926318df4f957bea3dc25b97809e7a122993b

# New emission rate (u128)
# This is in fixed-point format: rate_per_second << 64
# Example: 100 tokens per second = 1 << 64 = 18446744073709551616
# Calculate: NEW_EMISSION_RATE = tokens_per_second * (2^64)
# Adjust this value according to your needs
export NEW_EMISSION_RATE=18446744073709551616  # Example: 1 tokens/sec (1 << 64)

# Combined transaction: deposit reward and update emission in one PTB
sui client ptb \
  --move-call sui::coin::into_balance "<$REWARD_COIN_TYPE>" @$REWARD_COIN_ID \
  --assign reward_balance \
  --move-call $PACKAGE::port::rewarder_deposit_reward "<$REWARD_COIN_TYPE>" \
    @$VAULT_CONFIG \
    @$PORT \
    reward_balance \
  --move-call $PACKAGE::port::rewarder_update_emission "<$REWARD_COIN_TYPE>" \
    @$VAULT_CONFIG \
    @$PORT \
    $NEW_EMISSION_RATE \
    @$CLOCK


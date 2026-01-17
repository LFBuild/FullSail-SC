#!/bin/bash

source ./export.sh

source ./pools/pool_deep_wal.sh

# Save gauge pool variables first
export GAUGE_POOL=$POOL
export GAUGE_COIN_A=$COIN_A
export GAUGE_COIN_B=$COIN_B
export GAUGE_ID=$GAUGE

source ./pools/pool_sail_usdc.sh
export SAIL_POOL=$POOL
export SAIL_POOL_COIN_A=$COIN_A
export SAIL_POOL_COIN_B=$COIN_B

# Set emissions increase amount in USD (with 6 decimals, e.g., 1000000 = 1 USD)
export EMISSIONS_INCREASE_USD=905739409

sui client ptb \
--move-call $PACKAGE::minter::increase_gauge_emissions "<$GAUGE_COIN_A,$GAUGE_COIN_B,$SAIL_POOL_COIN_A,$SAIL_POOL_COIN_B,$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$MINTER_ADMIN_CAP @$GAUGE_ID @$GAUGE_POOL $EMISSIONS_INCREASE_USD @$PRICE_MONITOR @$SAIL_POOL @$AGGREGATOR @$CLOCK 
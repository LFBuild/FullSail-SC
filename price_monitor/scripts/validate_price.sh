#!/bin/bash

# Script to validate price using PriceMonitor
# Function: validate_price

source ./export.sh

echo "Validating price using PriceMonitor..."
echo "Monitor: $MONITOR"
echo "Aggregator: $AGGREGATOR"
echo "Feed Pool: $FEED_POOL"
echo "Coin Type A: $COIN_TYPE_A"
echo "Coin Type B: $COIN_TYPE_B"
echo "Clock: $CLOCK"

# Call validate_price function
sui client ptb \
--move-call $PACKAGE::price_monitor::validate_price "<$COIN_TYPE_A,$COIN_TYPE_B,$BASE_COIN>" \
    @$MONITOR \
    @$AGGREGATOR \
    @$FEED_POOL \
    @$CLOCK \
    --gas-budget 50000000

echo "Price validation completed!"

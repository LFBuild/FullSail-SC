#!/bin/bash
# Script to update supply voted weights for gauges with epoch index 9 or 10
# Generated from: /Users/santalov/WebstormProjects/FullSailRepos/FullSail-Frontend/packages/playground/data/total_supply_comparison_2025-11-18T01-29-09-027Z.json
# Timestamp: 2025-11-18T01:30:07.900Z
# Total updates: 7

set -e

source ./export.sh

export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

# Update 1/7
# Gauge: 0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
# Epoch: 9 (start: 1762387200)

export GAUGE=0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
export EPOCH_START=1762387200
export TOTAL_SUPPLY=0

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 2/7
# Gauge: 0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
# Epoch: 10 (start: 1762992000)

export GAUGE=0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
export EPOCH_START=1762992000
export TOTAL_SUPPLY=0

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 3/7
# Gauge: 0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
# Epoch: 4 (start: 1759363200)

export GAUGE=0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
export EPOCH_START=1759363200
export TOTAL_SUPPLY=10096959183642

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 4/7
# Gauge: 0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
# Epoch: 4 (start: 1759363200)

export GAUGE=0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
export EPOCH_START=1759363200
export TOTAL_SUPPLY=193442328038181

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 5/7
# Gauge: 0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
# Epoch: 4 (start: 1759363200)

export GAUGE=0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
export EPOCH_START=1759363200
export TOTAL_SUPPLY=153755575017385

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 6/7
# Gauge: 0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
# Epoch: 10 (start: 1762992000)

export GAUGE=0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
export EPOCH_START=1762992000
export TOTAL_SUPPLY=35392801187628

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 7/7
# Gauge: 0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
# Epoch: 5 (start: 1759968000)

export GAUGE=0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
export EPOCH_START=1759968000
export TOTAL_SUPPLY=1261162820877

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


echo "All update_supply_voted_weights calls completed!"
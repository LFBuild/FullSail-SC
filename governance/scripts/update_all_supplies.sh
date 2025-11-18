#!/bin/bash
# Script to update supply voted weights for gauges with epoch index 9 or 10
# Generated from: /Users/santalov/WebstormProjects/FullSailRepos/FullSail-Frontend/packages/playground/data/total_supply_comparison_2025-11-17T22-55-26-625Z.json
# Timestamp: 2025-11-18T00:04:31.626Z
# Total updates: 22

set -e

source ./export.sh

export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

# Update 1/22
# Gauge: 0x05e4d855faf3779d357c79878a5819efb56ffe05d189e2b6314eda5a2bc13172
# Epoch: 9 (start: 1762387200)

export GAUGE=0x05e4d855faf3779d357c79878a5819efb56ffe05d189e2b6314eda5a2bc13172
export EPOCH_START=1762387200
export TOTAL_SUPPLY=261078255622

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 2/22
# Gauge: 0x05e4d855faf3779d357c79878a5819efb56ffe05d189e2b6314eda5a2bc13172
# Epoch: 10 (start: 1762992000)

export GAUGE=0x05e4d855faf3779d357c79878a5819efb56ffe05d189e2b6314eda5a2bc13172
export EPOCH_START=1762992000
export TOTAL_SUPPLY=261078255622

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 3/22
# Gauge: 0x15042268059733898716e2ae76285fb7098e0d8b4edaf1b0fc7efcfd84b297ae
# Epoch: 9 (start: 1762387200)

export GAUGE=0x15042268059733898716e2ae76285fb7098e0d8b4edaf1b0fc7efcfd84b297ae
export EPOCH_START=1762387200
export TOTAL_SUPPLY=2562760741922

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 4/22
# Gauge: 0x15042268059733898716e2ae76285fb7098e0d8b4edaf1b0fc7efcfd84b297ae
# Epoch: 10 (start: 1762992000)

export GAUGE=0x15042268059733898716e2ae76285fb7098e0d8b4edaf1b0fc7efcfd84b297ae
export EPOCH_START=1762992000
export TOTAL_SUPPLY=2562760741922

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 5/22
# Gauge: 0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
# Epoch: 9 (start: 1762387200)

export GAUGE=0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
export EPOCH_START=1762387200
export TOTAL_SUPPLY=650665950

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 6/22
# Gauge: 0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
# Epoch: 10 (start: 1762992000)

export GAUGE=0x2320e5d1a6cbedcee9c34406fa5a48b8fba0fecd6ac8ebc6a6b5526a57dc8c1e
export EPOCH_START=1762992000
export TOTAL_SUPPLY=650665950

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 7/22
# Gauge: 0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
# Epoch: 9 (start: 1762387200)

export GAUGE=0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
export EPOCH_START=1762387200
export TOTAL_SUPPLY=7915923040890

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 8/22
# Gauge: 0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
# Epoch: 10 (start: 1762992000)

export GAUGE=0x28dd45f149faa77c22a291b31770dc88a3f51a2a46b7642d1557402a627bba35
export EPOCH_START=1762992000
export TOTAL_SUPPLY=7915403663215

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 9/22
# Gauge: 0x3c5e3059099ff701753c56fcc9a3ce18f73abd6014651c835a78d2ee10236ffe
# Epoch: 9 (start: 1762387200)

export GAUGE=0x3c5e3059099ff701753c56fcc9a3ce18f73abd6014651c835a78d2ee10236ffe
export EPOCH_START=1762387200
export TOTAL_SUPPLY=14302648172045

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 10/22
# Gauge: 0x3c5e3059099ff701753c56fcc9a3ce18f73abd6014651c835a78d2ee10236ffe
# Epoch: 10 (start: 1762992000)

export GAUGE=0x3c5e3059099ff701753c56fcc9a3ce18f73abd6014651c835a78d2ee10236ffe
export EPOCH_START=1762992000
export TOTAL_SUPPLY=14239475513767

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 11/22
# Gauge: 0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
# Epoch: 9 (start: 1762387200)

export GAUGE=0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
export EPOCH_START=1762387200
export TOTAL_SUPPLY=79904015208478

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 12/22
# Gauge: 0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
# Epoch: 10 (start: 1762992000)

export GAUGE=0x67af9dabed6c1bc97990b2b40c061b2b1d1e168d4142926382648285f04e4710
export EPOCH_START=1762992000
export TOTAL_SUPPLY=79837589182752

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 13/22
# Gauge: 0x6f8a9cc1e192c67f66667fba28c4e186cef72cd8d228002100069642557a56f9
# Epoch: 9 (start: 1762387200)

export GAUGE=0x6f8a9cc1e192c67f66667fba28c4e186cef72cd8d228002100069642557a56f9
export EPOCH_START=1762387200
export TOTAL_SUPPLY=6468210778507

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 14/22
# Gauge: 0x6f8a9cc1e192c67f66667fba28c4e186cef72cd8d228002100069642557a56f9
# Epoch: 10 (start: 1762992000)

export GAUGE=0x6f8a9cc1e192c67f66667fba28c4e186cef72cd8d228002100069642557a56f9
export EPOCH_START=1762992000
export TOTAL_SUPPLY=6468210778507

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 15/22
# Gauge: 0xaa760719d939ad54317419b99f5d912639c28e2f4d31a11f127649e89b447f6a
# Epoch: 9 (start: 1762387200)

export GAUGE=0xaa760719d939ad54317419b99f5d912639c28e2f4d31a11f127649e89b447f6a
export EPOCH_START=1762387200
export TOTAL_SUPPLY=14678540969527

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 16/22
# Gauge: 0xaa760719d939ad54317419b99f5d912639c28e2f4d31a11f127649e89b447f6a
# Epoch: 10 (start: 1762992000)

export GAUGE=0xaa760719d939ad54317419b99f5d912639c28e2f4d31a11f127649e89b447f6a
export EPOCH_START=1762992000
export TOTAL_SUPPLY=14635486832105

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 17/22
# Gauge: 0xdbe837b580496226ed166571ddbf5afd126a8b5e6114ea5a72d99bd92e9cf423
# Epoch: 9 (start: 1762387200)

export GAUGE=0xdbe837b580496226ed166571ddbf5afd126a8b5e6114ea5a72d99bd92e9cf423
export EPOCH_START=1762387200
export TOTAL_SUPPLY=1592755119183

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 18/22
# Gauge: 0xdbe837b580496226ed166571ddbf5afd126a8b5e6114ea5a72d99bd92e9cf423
# Epoch: 10 (start: 1762992000)

export GAUGE=0xdbe837b580496226ed166571ddbf5afd126a8b5e6114ea5a72d99bd92e9cf423
export EPOCH_START=1762992000
export TOTAL_SUPPLY=1552613110697

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 19/22
# Gauge: 0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
# Epoch: 9 (start: 1762387200)

export GAUGE=0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
export EPOCH_START=1762387200
export TOTAL_SUPPLY=35440605463955

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 20/22
# Gauge: 0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
# Epoch: 10 (start: 1762992000)

export GAUGE=0xe67a0eed2e9f4059d9f7b3d3ed39489877dc4b740a8a6ec22f22dcf66caa6f72
export EPOCH_START=1762992000
export TOTAL_SUPPLY=35393043866067

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 21/22
# Gauge: 0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
# Epoch: 9 (start: 1762387200)

export GAUGE=0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
export EPOCH_START=1762387200
export TOTAL_SUPPLY=1151202607919

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


# Update 22/22
# Gauge: 0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
# Epoch: 10 (start: 1762992000)

export GAUGE=0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
export EPOCH_START=1762992000
export TOTAL_SUPPLY=1151180078826

sui client ptb \
--move-call $PACKAGE::minter::update_supply_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START $TOTAL_SUPPLY @$CLOCK

echo "Completed update for gauge ${GAUGE} at epoch ${EPOCH_START}"


echo "All update_supply_voted_weights calls completed!"
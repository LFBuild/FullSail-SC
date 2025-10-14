source ./export.sh
source ./pools/pool_wbtc_usdc.sh

export EPOCH_START=1758153600
export GAUGE_ID=0xf1eabda6cf3e83340b37de7e16ce27704efc30343184f7cacc6a43c5f5af1961
export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

sui client ptb \
--move-call $PACKAGE::minter::reset_final_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE_ID $EPOCH_START --gas-budget 50000000 
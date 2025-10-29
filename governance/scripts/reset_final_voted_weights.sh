source ./export.sh
source ./pools/pool_eth_usdc.sh

export EPOCH_START=1759968000
export DISTRIBUTE_GOVERNOR_CAP=0xf5f335807046541711fbb00021927baad8798944eceb0cd4986e229def484ab6

sui client ptb \
--move-call $PACKAGE::minter::reset_final_voted_weights "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE $EPOCH_START --gas-budget 50000000 
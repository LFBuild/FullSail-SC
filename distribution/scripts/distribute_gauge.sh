source ./export.sh
source ./pools/pool_sail_tkna.sh

sui client ptb \
--move-call $PACKAGE::minter::distribute_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE,$OSAIL1_TYPE>" @$MINTER @$VOTER @$DISTRIBUTE_GOVERNOR_CAP @$DISTRIBUTION_CONFIG @$GAUGE @$POOL 0 0 0 0 0 0 @$AGGREGATOR @$CLOCK 
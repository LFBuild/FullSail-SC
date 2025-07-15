source ./export.sh
source ./pools/pool_wbtc_usdc_test.sh

sui client ptb \
--move-call $PACKAGE::minter::inject_voting_fee_reward "<$FULLSAIL_TOKEN_TYPE,$COIN_A>" @$MINTER @$VOTER @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE @$OBJ_A @$CLOCK \
--move-call $PACKAGE::minter::inject_voting_fee_reward "<$FULLSAIL_TOKEN_TYPE,$COIN_B>" @$MINTER @$VOTER @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE @$OBJ_B @$CLOCK \
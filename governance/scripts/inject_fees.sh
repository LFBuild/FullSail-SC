source ./export.sh
source ./pools/pool_tkni_tknk.sh

export OBJ_A=0x4077cb1ccb0b16033f5468063b6790c425cd380c4c4b8d7cf40095b49f08d62b
export OBJ_B=0x165e7ff34aec5bc06d95542143758050bfc4e4aff3c177b1210b6a31137fd23e

sui client ptb \
--move-call $PACKAGE::minter::inject_voting_fee_reward "<$FULLSAIL_TOKEN_TYPE,$COIN_A>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE @$OBJ_A @$CLOCK \
--move-call $PACKAGE::minter::inject_voting_fee_reward "<$FULLSAIL_TOKEN_TYPE,$COIN_B>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$GAUGE @$OBJ_B @$CLOCK
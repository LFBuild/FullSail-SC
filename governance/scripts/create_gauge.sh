source ./export.sh
source ./pools/pool_usdb_usdc.sh

sui client ptb \
--move-call $PACKAGE::minter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$MINTER_ADMIN_CAP @$VOTING_ESCROW @$POOL $BASE_EMISSIONS_USD @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B>>" gauge
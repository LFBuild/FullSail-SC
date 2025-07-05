source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::activate "<$FULLSAIL_TOKEN_TYPE, $OSAIL1_TYPE>" @$MINTER @$VOTER @$MINTER_ADMIN_CAP @$REWARD_DISTRIBUTOR @$OSAIL1_CAP @$OSAIL1_METADATA @$CLOCK
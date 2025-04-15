source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::activate "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$ADMIN_CAP @$REWARD_DISTRIBUTOR @$CLOCK
source ./export.sh

sui client ptb \
--move-call $PACKAGE::voter::add_governor "<$FULLSAIL_TOKEN_TYPE>" @$VOTER @$VOTER_PUBLISHER @$ADDR
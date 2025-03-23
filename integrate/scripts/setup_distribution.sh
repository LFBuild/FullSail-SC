source ./export.sh

sui client ptb \
--move-call $PACKAGE::setup_distribution::create "<$FULLSAIL_TOKEN_TYPE>" @$REWARD_DISTRIBUTOR_PUBLISHER @$GLOBAL_CONFIG @$DISTRIBUTION_CONFIG @$ADDR @$CLOCK
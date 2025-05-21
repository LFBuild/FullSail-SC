source ./export.sh

sui client ptb \
--move-call $PACKAGE::pool_script_v3::update_rewarder_emission "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL @$REWARDER_GLOBAL_VAULT 10000 100000 @$CLOCK
source ./export.sh

sui client ptb \
--move-call $PACKAGE::pool_script_v2::update_rewarder_emission "<$COIN_A,$COIN_B,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL @$REWARDER_GLOBAL_VAULT 152502844524715208465608 @$CLOCK
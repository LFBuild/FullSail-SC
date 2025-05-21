source ./export.sh

sui client ptb \
--move-call $PACKAGE::pool_script_v2::initialize_rewarder "<$COIN_A,$COIN_B,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL
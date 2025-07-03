source ./export.sh

export POOL=0x2e53ea7a13eb6c406a6af3db6e806fbc556f80fc1794c63bd4be699e13ae425f

sui client ptb \
--move-call $PACKAGE::pool_script_v2::initialize_rewarder "<$COIN_A,$COIN_B,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL
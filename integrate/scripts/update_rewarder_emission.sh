source ./export.sh

export POOL1=0xd598cbce392b2365ba01276dbe19d7978303066760f409645e15cef27128e4c6
export COIN_A_1=0x28abec9c9f5dd2f8a2188fc13dfd84c7b2aaf4968d55a8717e728ef3dbebf910::SAIL::SAIL
export COIN_B_1=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export TOTAL_REWARD_AMOUNT1=1000000000000000 # set the total reward amount for the pool
export DISTRIBUTION_PERIOD_SECONDS1=2419200 # set the distribution period in seconds

sui client ptb \
--move-call $PACKAGE::pool_script_v3::update_rewarder_emission "<$COIN_A_1,$COIN_B_1,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL1 @$REWARDER_GLOBAL_VAULT $TOTAL_REWARD_AMOUNT1 $DISTRIBUTION_PERIOD_SECONDS1 @$CLOCK
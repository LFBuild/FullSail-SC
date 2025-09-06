source ./export.sh

export POOL1=0xc9f0c60fb486c8ba0a2599b22cad60d3223a676c60ef6ed3e559274e544f0eec
export COIN_A_1=0xfae8dc6bf7b9d8713f31fcf723f57c251c42c067e7e5c4ef68c1de09652db3cf::SAIL::SAIL
export COIN_B_1=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export TOTAL_REWARD_AMOUNT1=80000000000 # set the total reward amount for the pool
export DISTRIBUTION_PERIOD_SECONDS1=2419200 # set the governance period in seconds

sui client ptb \
--move-call $PACKAGE::pool_script_v3::update_rewarder_emission "<$COIN_A_1,$COIN_B_1,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL1 @$REWARDER_GLOBAL_VAULT $TOTAL_REWARD_AMOUNT1 $DISTRIBUTION_PERIOD_SECONDS1 @$CLOCK
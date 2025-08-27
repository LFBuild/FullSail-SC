source ./export.sh

export POOL1=0x907b98f56f93408d23c98b9745f07cff6a63371a55583341ec9ec28f1c1cd4a4
export COIN_A_1=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B_1=0x47890ab723495c669f086fa589e86eac016a77f48db7846fd4a172d1f7390061::token_e::TOKEN_E
export TOTAL_REWARD_AMOUNT1=10000000000 # set the total reward amount for the pool
export DISTRIBUTION_PERIOD_SECONDS1=432000 # set the distribution period in seconds

sui client ptb \
--move-call $PACKAGE::pool_script_v3::update_rewarder_emission "<$COIN_A_1,$COIN_B_1,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL1 @$REWARDER_GLOBAL_VAULT $TOTAL_REWARD_AMOUNT1 $DISTRIBUTION_PERIOD_SECONDS1 @$CLOCK
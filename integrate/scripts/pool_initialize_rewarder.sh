source ./export.sh


export POOL1=0x907b98f56f93408d23c98b9745f07cff6a63371a55583341ec9ec28f1c1cd4a4
export COIN_A_1=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B_1=0x47890ab723495c669f086fa589e86eac016a77f48db7846fd4a172d1f7390061::token_e::TOKEN_E

sui client ptb \
--move-call $PACKAGE::pool_script_v2::initialize_rewarder "<$COIN_A_1,$COIN_B_1,$REWARD_TOKEN_TYPE>" @$GLOBAL_CONFIG @$POOL1
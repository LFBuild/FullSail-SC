source ./export.sh

export AMOUNT=1000000000000000

sui client ptb \
--move-call "sui::coin::mint" "<0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B>" @0x385215d51c2c692e960b3fdd0ccc66cc1600d7758547251898906889753effd7 $AMOUNT \
--assign new_coins \
--transfer-objects "[new_coins]" @0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340
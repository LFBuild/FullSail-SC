source ./export.sh

export COIN_A=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export POOL=0x1cc7458296445f5e72bb64a4d9847316fd91b6d6417b0e661f9861b9221d7574

sui client ptb \
--move-call $PACKAGE::voter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$GOVERNOR_CAP @$VOTING_ESCROW @$POOL @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>>" gauge
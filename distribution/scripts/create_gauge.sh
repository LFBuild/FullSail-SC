source ./export.sh

export COIN_A=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B=0x4e57cf0fd73647d44d2191fbb3028176893c07388d9472df07124fe7f72c0a66::sail_token::SAIL_TOKEN
export POOL=0x163b704cccf75820c62b6b0d3a3f1b67e15b5c9c9a44d795a13b76b2bec609f3

sui client ptb \
--move-call $PACKAGE::voter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$GOVERNOR_CAP @$VOTING_ESCROW @$POOL @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>>" gauge
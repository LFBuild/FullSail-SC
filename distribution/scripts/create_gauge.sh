source ./export.sh

export COIN_A=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export POOL=0x8537e891464f63f010e4149df47a822678e88b9ed9678e2ffb432566a17537ef
export GAUGE_BASE_EMISSIONS=1000000000000

sui client ptb \
--move-call $PACKAGE::minter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$MINTER_ADMIN_CAP @$VOTING_ESCROW @$POOL $GAUGE_BASE_EMISSIONS @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B>>" gauge
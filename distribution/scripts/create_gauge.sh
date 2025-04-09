source ./export.sh

export COIN_A=0xd80ee37bf2520ef907756ba80327c6f546bf1bdbe9d1e3c149f961591d0e5ef9::sail_token::SAIL_TOKEN
export COIN_B=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export POOL=0x5cc46ab150b14f2d2239b6efca80cd887ebd89776b9ab325e04eaf2513bbba52

sui client ptb \
--move-call $PACKAGE::voter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$GOVERNOR_CAP @$VOTING_ESCROW @$POOL @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>>" gauge --dry-run
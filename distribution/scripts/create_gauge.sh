source ./export.sh

export COIN_A=0xda1f9eaf3d10cd6fa609d3061ac48d640c0aeb36fb031125a263736a0ae0be29::token_b::TOKEN_B
export COIN_B=0xd4d7bdc15013391ea5776db31abfc0c2dcf9121b58dcffc29c179e95b56f4c21::sail_token::SAIL_TOKEN
export POOL=0x2e53ea7a13eb6c406a6af3db6e806fbc556f80fc1794c63bd4be699e13ae425f

sui client ptb \
--move-call $PACKAGE::voter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$GOVERNOR_CAP @$VOTING_ESCROW @$POOL @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>>" gauge
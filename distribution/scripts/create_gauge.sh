source ./export.sh

export COIN_A=0xe69a16dd83717f6f224314157af7b75283a297a61a1e5f20f373ecb9f8904a63::token_c::TOKEN_C
export COIN_B=0x5c6d5739ac03c13d4986671f160dfed00ac9416f15cc9dbcfd30acff3fe1026e::token_d::TOKEN_D
export POOL=0xbe6910c3f9d1c2f4b47c2fb2febc3b1ff20bdcbcfea85ac6c62baef866012e91

sui client ptb \
--move-call $PACKAGE::voter::create_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$VOTER @$DISTRIBUTION_CONFIG @$CREATE_CAP @$GOVERNOR_CAP @$VOTING_ESCROW @$POOL @$CLOCK \
--assign gauge \
--move-call sui::transfer::public_share_object "<$ORIGINAL_PACKAGE::gauge::Gauge<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>>" gauge
source export.sh

export USD_TYPE=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A
export METADATA=0x57ec0b6c22c3dc2c5cbbabb8a8e8baa647726128df41f816c62f22af6bc785bb

sui client ptb \
--move-call $PACKAGE::minter::whitelist_usd "<$FULLSAIL_TOKEN_TYPE,$USD_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$METADATA true \
--move-call $PACKAGE::minter::create_exercise_fee_distributor "<$FULLSAIL_TOKEN_TYPE,$USD_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$CLOCK \
--assign fee_distributor \
--move-call 0x2::transfer::public_share_object "<$PACKAGE::exercise_fee_distributor::ExerciseFeeDistributor<$USD_TYPE>>" fee_distributor



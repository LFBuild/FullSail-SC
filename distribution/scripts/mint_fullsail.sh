source ./export.sh

export AMOUNT=10000000000000

sui client ptb \
--move-call $PACKAGE::fullsail_token::mint "<$FULLSAIL_TOKEN_TYPE>" @$FULLSAIL_TOKEN_MITER_CAP $AMOUNT @$ADDR \
--assign new_coins \
--transfer-objects "[new_coins]" @$ADDR
source ./export.sh

export AMOUNT=10000000000000

sui client ptb \
--move-call "sui::coin::mint" "<$FULLSAIL_TOKEN_TYPE>" @$TREASURY_CAP $AMOUNT \
--assign new_coins \
--transfer-objects "[new_coins]" @$ADDR
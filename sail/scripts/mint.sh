source ./export.sh

export AMOUNT=1000000000000
export TO=0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340

sui client ptb \
--move-call 0x2::coin::mint "<$COIN_TYPE>" @$TREASURY_CAP $AMOUNT \
--assign coin \
--transfer-objects '[coin]' @$TO
source ./export.sh

export AMOUNT=1000000000000
export TO=0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486

sui client ptb \
--move-call 0x2::coin::mint "<$COIN_TYPE>" @$TREASURY_CAP $AMOUNT \
--assign coin \
--transfer-objects '[coin]' @$TO
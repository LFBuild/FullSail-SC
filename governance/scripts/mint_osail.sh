source ./export.sh

export AMOUNT=10000000000000

sui client ptb \
--move-call "sui::coin::mint" "<$OSAIL1_TYPE>" @$OSAIL1_CAP $AMOUNT \
--assign new_coins \
--transfer-objects "[new_coins]" @0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486
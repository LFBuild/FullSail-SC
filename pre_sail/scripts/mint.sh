export TOKEN_TYPE=0x0::pre_sail::PRE_SAIL?
export TREASURY_CAP=0x0?
export AMOUNT=1000000000000
export RECIPIENT=0x0?
export GAS=0x0?

sui client ptb \
--move-call 0x2::coin::mint "<$TOKEN_TYPE>" @$TREASURY_CAP $AMOUNT \
--transfer-objects '[coin]' @$RECIPIENT \
--gas $GAS \
--serialize-unsigned-transaction \
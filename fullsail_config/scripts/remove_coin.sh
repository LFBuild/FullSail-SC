source ./export.sh
source ./coin_tkne.sh

sui client ptb \
--move-call $PACKAGE::coin::remove_coin "<$COIN_TYPE>" @$GLOBAL_CONFIG @$COIN_LIST
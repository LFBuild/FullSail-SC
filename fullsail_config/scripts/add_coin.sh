source ./export.sh
source ./coin_tknc.sh

sui client ptb \
--move-call $PACKAGE::coin::add_coin "<$COIN_TYPE>" @$GLOBAL_CONFIG @$COIN_LIST $COIN_NAME $COIN_SYMBOL $COIN_COINGECKO_ID $COIN_PYTH_ID $COIN_DECIMALS $COIN_LOGO_URL $COIN_PROJECT_URL
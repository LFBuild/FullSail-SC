source ./export.sh

# Coin type for which to update price age
export COIN_TYPE=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI

# Maximum age of price in seconds (e.g., 60 = 60 seconds = 1 minute)
# This determines how old the price can be before it's considered stale
export PRICE_AGE=60

sui client ptb \
  --move-call $PACKAGE::port_oracle::update_price_age "<$COIN_TYPE>" \
    @$PORT_ORACLE \
    @$VAULT_CONFIG \
    $PRICE_AGE


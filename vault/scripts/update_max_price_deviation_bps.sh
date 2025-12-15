source ./export.sh

# Price deviation values in basis points (BPS):
# 100 = 1% (100 / 10000)
# 200 = 2% (200 / 10000) - default value
# 500 = 5% (500 / 10000)
# 1000 = 10% (1000 / 10000)

export NEW_MAX_PRICE_DEVIATION_BPS=1000000

sui client ptb \
  --move-call $PACKAGE::vault_config::update_max_price_deviation_bps @$VAULT_CONFIG $NEW_MAX_PRICE_DEVIATION_BPS


source ./export.sh

# SAIL/USDC
POOL_ID=0x2acf170284a279b79cde66d747697cbd4560d0db6d6fd04c078a01efd1973efa

sui client ptb \
--move-call $PACKAGE::price_monitor::update_pool_price_decimal_multiplier_v2 @$MONITOR @$POOL_ID 6 9 --dry-run


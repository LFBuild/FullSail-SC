source ./export.sh

# SAIL/USDC
POOL_ID=0x038eca6cc3ba17b84829ea28abac7238238364e0787ad714ac35c1140561a6b9

sui client ptb \
--move-call $PACKAGE::price_monitor::update_pool_price_decimal_multiplier_v2 @$MONITOR @$POOL_ID 6 6

source ./export.sh

# !!! CHECK DECIMALS !!!

sui client ptb \
--make-move-vec '<sui::object::ID>' "[@$FEED_POOL]" \
--assign pool_ids \
--move-call $PACKAGE::price_monitor::add_aggregator @$MONITOR @$AGGREGATOR pool_ids "vector[6]" "vector[9]"
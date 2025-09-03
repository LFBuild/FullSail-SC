source ./export.sh

sui client ptb \
--move-call $PACKAGE::price_monitor::remove_pool_from_aggregator @$MONITOR @$AGGREGATOR @$FEED_POOL
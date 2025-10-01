source ./export.sh

sui client ptb \
--move-call $PACKAGE::price_monitor::update_time_config @$MONITOR 120000 7200000 60000 50 10
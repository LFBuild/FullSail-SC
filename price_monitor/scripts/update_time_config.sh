source ./export.sh

sui client ptb \
--move-call $PACKAGE::price_monitor::update_time_config @$MONITOR 60000 280000 60000 48 4
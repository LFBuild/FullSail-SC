source ./export.sh

sui client ptb \
--move-call $PACKAGE::price_monitor::update_validation_toggles @$MONITOR false false false
source ./export.sh

sui client ptb \
--move-call $PACKAGE::price_monitor::update_escalation_toggles @$MONITOR false false
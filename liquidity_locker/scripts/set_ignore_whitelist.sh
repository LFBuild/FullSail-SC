source ./export.sh

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::set_ignore_whitelist @$LOCKER_V1 true
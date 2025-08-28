source ./export.sh

sui client ptb \
--move-call $PACKAGE::pool_soft_tranche::set_ignore_whitelist @$POOL_TRANCH_MANAGER true \
--move-call $PACKAGE::liquidity_soft_lock_v1::set_ignore_whitelist @$LOCKER_V1 true
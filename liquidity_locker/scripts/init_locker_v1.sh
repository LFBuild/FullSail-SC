source ./export.sh

sui client ptb \
--make-move-vec "<u64>" "[4, 13, 26, 39, 52]" \
--assign periods_blocking \
--make-move-vec "<u64>" "[1, 2, 3, 4, 4]" \
--assign periods_post_lockdown \
--move-call $PACKAGE::liquidity_lock_v1::init_locker @$SUPER_ADMIN_CAP_LOCK @$CREATE_LOCKER_CAP @$LOCKER_V1 periods_blocking periods_post_lockdown
source ./export.sh

# Пример обновления периодов блокировки
# periods_blocking: [30, 60, 90] - периоды блокировки в эпохах
# periods_post_lockdown: [10, 20, 30] - периоды после блокировки в эпохах

sui client ptb \
--make-move-vec "<u64>" "[4, 13, 26, 39, 52]" \
--assign periods_blocking \
--make-move-vec "<u64>" "[0, 0, 0, 0, 0]" \
--assign periods_post_lockdown \
--move-call $PACKAGE::liquidity_lock_v1::update_lock_periods @$LOCKER_V1 periods_blocking periods_post_lockdown 
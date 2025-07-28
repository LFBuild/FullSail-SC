source ./export.sh

export NEW_ADMIN=0xd5553230a381cb6e1447c94751017a0235f997003cfbbd379fa8382408dbe434

sui client ptb \
--move-call $PACKAGE::liquidity_soft_lock_v1::add_admin @$SUPER_ADMIN_CAP_LOCK @$LOCKER_V1 @$NEW_ADMIN \
--move-call $PACKAGE::pool_soft_tranche::add_admin @$SUPER_ADMIN_CAP_TRANCH @$POOL_TRANCH_MANAGER @$NEW_ADMIN 
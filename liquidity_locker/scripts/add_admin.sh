source ./export.sh

export NEW_ADMIN=0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::add_admin @$SUPER_ADMIN_CAP @$LOCKER_V1 @$NEW_ADMIN
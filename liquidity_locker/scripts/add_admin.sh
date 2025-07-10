source ./export.sh

export NEW_ADMIN=0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::add_admin @$SUPER_ADMIN_CAP_LOCK @$LOCKER_V1 @$NEW_ADMIN \
--move-call $PACKAGE::pool_tranche::add_admin @$SUPER_ADMIN_CAP_TRANCH @$POOL_TRANCH_MANAGER @$NEW_ADMIN 
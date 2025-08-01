#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Admin address to revoke must be specified"
    echo "Usage: $0 <admin_address_to_revoke>"
    exit 1
fi

export PACKAGE=0x2aaaf44f568c60b8add5a39e5e0e168b9bbb7455e5164638dbc55527918a22c2
export LOCKER=0x2d0870c8570a213537cd6e8a88055e55d68cb8c4ba109846bf73aad91c0c5c52
export ADMIN_TO_REVOKE=$1

sui client ptb \
--move-call $PACKAGE::liquidity_lock_v1::revoke_admin \
@$LOCKER \
@$ADMIN_TO_REVOKE 
#!/bin/bash

# Script for creating locker v2
# Method: liquidity_lock_v2::create_locker

source ./export.sh

# Recipient address for the new SuperAdminCap
export RECIPIENT_ADDRESS="0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340"

# Execute transaction
sui client ptb \
--move-call $PACKAGE::liquidity_lock_v2::create_locker \
  @$SUPER_ADMIN_CAP_LOCK \
  @$LOCKER_V1 \
  @$CREATE_LOCKER_CAP \
--assign new_super_admin_cap \
--move-call sui::transfer::public_transfer \
  "<$PACKAGE::liquidity_lock_v2::SuperAdminCap>" \
  new_super_admin_cap \
  @$RECIPIENT_ADDRESS \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "Locker v2 created and new SuperAdminCap transferred to address: $RECIPIENT_ADDRESS" 
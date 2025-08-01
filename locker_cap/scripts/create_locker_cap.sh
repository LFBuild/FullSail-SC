#!/bin/bash

# Script for creating a locker cap
# Method: locker_cap::create_locker_cap

source ./export.sh

# Recipient address for the new LockerCap
export RECIPIENT_ADDRESS="0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340"

# Execute transaction
sui client ptb \
--move-call $PACKAGE::locker_cap::create_locker_cap \
  @$CREATE_CAP \
--assign new_locker_cap \
--move-call sui::transfer::public_transfer \
  "<$PACKAGE::locker_cap::LockerCap>" \
  new_locker_cap \
  @$RECIPIENT_ADDRESS \
--gas-budget 100000000

echo "Transaction executed successfully!"
echo "New LockerCap created and transferred to address: $RECIPIENT_ADDRESS" 
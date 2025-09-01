#!/bin/bash

source ./export.sh

echo "Updating display for voting_escrow module..."

AMOUNT='"{amount}"'
END='"{end}"'
PERPETUAL='"{perpetual}"'
PERMANENT='"{permanent}"'
LOCK_URL='"https://app.fullsail.finance/lock/{id}"'

sui client ptb \
--move-call $PACKAGE::voting_escrow::update_display @$VOTING_ESCROW_PUBLISHER \
    '"Full Sail veSAIL"' \
    '"Full Sail veSAIL"' \
    $AMOUNT \
    $END \
    $PERPETUAL \
    $PERMANENT \
    $LOCK_URL \
    '"https://app.fullsail.finance/static_files/ve_sail.png"' \
    '"https://app.fullsail.finance"' \
    '"FULLSAIL"' \
--gas-budget 10000000

echo "Display update completed!"

#!/bin/bash

source ./export.sh

export GAUGE_ID=0x34e24a2d7dcefc4210c3a652d9467aad226dbe34ff486f6c6c3ebf6f36c6d0be

sui client ptb \
--move-call $PACKAGE::minter::kill_gauge "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$EMERGENCY_COUNCIL_CAP @$GAUGE_ID 
#!/bin/bash

source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::kill_gauge "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$EMERGENCY_COUNCIL_CAP @$GAUGE_ID 
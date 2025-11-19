#!/bin/bash

source ./export.sh

source ./pools/pool_tkni_tknk.sh

sui client ptb \
--move-call $PACKAGE::minter::revive_gauge "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$EMERGENCY_COUNCIL_CAP @$GAUGE


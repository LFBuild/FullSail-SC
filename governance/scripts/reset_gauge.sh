#!/bin/bash

source ./export.sh

source ./pools/pool_tkni_tknk.sh

sui client ptb \
--move-call $PACKAGE::minter::reset_gauge "<$COIN_A,$COIN_B,$FULLSAIL_TOKEN_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$EMERGENCY_COUNCIL_CAP @$GAUGE $BASE_EMISSIONS_USD @$CLOCK


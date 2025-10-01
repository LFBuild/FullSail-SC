source ./export.sh

sui client ptb \
--move-call $LATEST_PACKAGE::sail_test::unpack_minter_cap "<$COIN_TYPE>" @$MINTER_CAP \
--assign treasury_cap \
--transfer-objects [treasury_cap] @0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340
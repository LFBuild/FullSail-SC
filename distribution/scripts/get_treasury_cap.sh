source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::get_treasury_cap_internal "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP \
--assign treasury_cap \
--transfer-objects [treasury_cap] @$ADDR
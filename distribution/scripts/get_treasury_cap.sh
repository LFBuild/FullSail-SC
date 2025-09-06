source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::get_treasury_cap_internal "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP \
--assign treasury_cap \
--transfer-objects [treasury_cap] @0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

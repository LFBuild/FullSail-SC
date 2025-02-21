source ./export.sh

sui client ptb \
--move-call std::option::some "<$PACKAGE::fullsail_token::MinterCap<$FULLSAIL_TOKEN_TYPE>>" @$FULLSAIL_TOKEN_MITER_CAP \
--assign minter_cap \
--move-call $PACKAGE::minter::create "<$FULLSAIL_TOKEN_TYPE>" @$MINTER_PUBLISHER minter_cap \
--assign minter_and_admin_cap \
--move-call sui::transfer::public_share_object "<$PACKAGE::minter::Minter<$FULLSAIL_TOKEN_TYPE>>" minter_and_admin_cap.0 \
--transfer-objects '[minter_and_admin_cap.1]' @$ADDR
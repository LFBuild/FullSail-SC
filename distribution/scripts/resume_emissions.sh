source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::resume_emission "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP
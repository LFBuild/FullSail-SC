source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::resume_emission "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$DISTRIBUTION_CONFIG @$MINTER_ADMIN_CAP
source ./export.sh

sui client ptb \
--move-call $PACKAGE::voting_escrow::set_package_version "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER 0
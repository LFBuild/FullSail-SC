source ./export.sh

export VOTING_EXPORT_CAP=0xebd0e31707b862611721e3727088f765c426398381fdd3a842372ac112e9fa32

sui client ptb \
--move-call $PACKAGE::voting_escrow::set_voting_escrow_cap "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER @$VOTING_EXPORT_CAP \
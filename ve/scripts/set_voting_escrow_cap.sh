source ./export.sh

export VOTING_EXPORT_CAP=0x9ab3c4aaa01d46f671fb855d4ad6e3f9af788fbc6e539c3d5fe5148a1eb6a461

sui client ptb \
--move-call $PACKAGE::voting_escrow::set_voting_escrow_cap "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER @$VOTING_EXPORT_CAP \
source ./export.sh

export ADDRESS=0x0 # 0x0 allows all addresses
export ALLOWED=false

sui client ptb --move-call $PACKAGE::voting_escrow::toggle_split "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$TEAM_CAP @$ADDRESS $ALLOWED
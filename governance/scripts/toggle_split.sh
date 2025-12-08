source ./export.sh

export ADDRESS=0x7f2bc2cadcead6dc4706c3259ff0e55fcfd6afd5b9134a0978b0ad22453ac486 # 0x0 allows all addresses
export ALLOWED=true

sui client ptb --move-call $VE_PACKAGE::voting_escrow::toggle_split "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$TEAM_CAP @$ADDRESS $ALLOWED
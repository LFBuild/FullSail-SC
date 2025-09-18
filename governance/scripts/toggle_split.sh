source ./export.sh

export ADDRESS=0x2f6af136d3be0f7875143f00310e6587d4a14a54543c6718ddbc51b91418589e # 0x0 allows all addresses
export ALLOWED=true

sui client ptb --move-call $VE_PACKAGE::voting_escrow::toggle_split "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$TEAM_CAP @$ADDRESS $ALLOWED
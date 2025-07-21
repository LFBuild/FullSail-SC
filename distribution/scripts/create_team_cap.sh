source ./export.sh

export ADDRESS=$(sui client active-address)

sui client ptb \
--move-call $PACKAGE::voting_escrow::create_team_cap "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER \
--assign team_cap \
--transfer-objects '[team_cap]' @$ADDRESS
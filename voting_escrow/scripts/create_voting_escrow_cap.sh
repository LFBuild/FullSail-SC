source ./export.sh

export TO=0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340

sui client ptb \
--move-call $PACKAGE::voting_escrow::create_voting_escrow_cap @$VOTING_ESCROW_PUBLISHER @$VOTING_ESCROW \
--assign voting_escrow_cap \
--transfer-objects '[voting_escrow_cap]' @$TO
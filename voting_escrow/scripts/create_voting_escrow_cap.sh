source ./export.sh

export TO=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

sui client ptb \
--move-call $PACKAGE::voting_escrow::create_voting_escrow_cap @$VOTING_ESCROW_PUBLISHER @$VOTING_ESCROW \
--assign voting_escrow_cap \
--transfer-objects '[voting_escrow_cap]' @$TO
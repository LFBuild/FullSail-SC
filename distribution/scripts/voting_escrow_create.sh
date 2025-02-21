source ./export.sh

sui client ptb \
--move-call $PACKAGE::voting_escrow::create "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW_PUBLISHER @$VOTER @0x6 \
--assign voting_escrow \
--move-call sui::transfer::public_share_object "<$PACKAGE::voting_escrow::VotingEscrow<$FULLSAIL_TOKEN_TYPE>>" voting_escrow
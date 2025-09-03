source ./export.sh

sui client ptb \
--move-call $PACKAGE::emergency_council::create_cap @$EMERGENCY_COUNCIL_PUBLISHER @$MINTER @$VOTER @$VOTING_ESCROW
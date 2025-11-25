source ./export.sh

sui client ptb \
--move-call $PACKAGE::emergency_council::create_cap @$EMERGENCY_COUNCIL_PUBLISHER @$VOTER @$MINTER @$VOTING_ESCROW
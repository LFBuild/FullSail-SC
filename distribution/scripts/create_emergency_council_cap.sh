source ./export.sh

sui client ptb \
--move-call $PACKAGE::emergency_council::create_cap @$VOTER @$MINTER
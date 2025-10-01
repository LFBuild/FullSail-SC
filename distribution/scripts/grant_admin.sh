source ./export.sh

sui client ptb \
--move-call $PACKAGE::minter::grant_admin @$MINTER_PUBLISHER @$ADDR
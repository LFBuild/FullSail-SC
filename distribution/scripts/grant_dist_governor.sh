source ./export.sh

export WHO=$ADDR

sui client ptb \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$WHO
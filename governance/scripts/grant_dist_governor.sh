source ./export.sh

export WHO=0x8c30bf5bfd2fb00bd9198599ea1bf6ae84f3b1855a238ed458765dd2adce0340

sui client ptb \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$WHO
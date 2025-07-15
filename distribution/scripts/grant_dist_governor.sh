source ./export.sh

export WHO=0xe28ed0b47bc4561cf70b0a2b058c530320f6ed109eebe0e8b59196990751961c

sui client ptb \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$WHO
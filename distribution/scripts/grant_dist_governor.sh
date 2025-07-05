source ./export.sh

export WHO=0x1e4662015b374c68f205a90bddc7bc930a373c30aa43bffab76933b2039cc273

sui client ptb \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$WHO
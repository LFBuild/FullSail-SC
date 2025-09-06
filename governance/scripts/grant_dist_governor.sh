source ./export.sh

export WHO=0xc2c7a6d112b07a68e6ecf8c5e6275c007589d40a87debbba155efc134ba2b6e1

sui client ptb \
--move-call $PACKAGE::minter::grant_distribute_governor @$MINTER_PUBLISHER @$WHO
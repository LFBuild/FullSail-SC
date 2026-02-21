source ./export.sh

export OPERATIONS_WALLET=0xc1d8fbc5ee3426dc50eeafd25579212bfe8aa0169ebb5445d36abc68932339db

sui client ptb \
--move-call $PACKAGE::minter::set_operations_wallet "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG @$OPERATIONS_WALLET
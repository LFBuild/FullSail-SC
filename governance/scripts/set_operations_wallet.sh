source ./export.sh

export OPERATIONS_WALLET=0x561ed9a59f59bcb4e4ae7b9076c4290edb24aa95b12f8a7b9da7a04e1be0703a

sui client ptb \
--move-call $PACKAGE::minter::set_operations_wallet "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG @$OPERATIONS_WALLET
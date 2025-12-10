source ./export.sh

export PROTOCOL_WALLET=0x423f13bc47d3b3c6b230d5d8e119a363362c86767fa2d6d86ab9580fac336168

sui client ptb \
--move-call $PACKAGE::minter::set_protocol_wallet "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG @$PROTOCOL_WALLET
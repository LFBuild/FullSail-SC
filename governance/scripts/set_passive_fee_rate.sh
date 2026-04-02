source ./export.sh

export PASSIVE_VOTER_FEE_RATE=8000

sui client ptb \
--move-call $PACKAGE::minter::set_passive_voter_fee_rate "<$FULLSAIL_TOKEN_TYPE>" @$MINTER @$MINTER_ADMIN_CAP @$DISTRIBUTION_CONFIG $PASSIVE_VOTER_FEE_RATE

source ./export.sh

# Example fee token for passive-fee distribution (update as needed).
export PASSIVE_FEE_COIN=0x1018b0843a724fd966b37f018bbc489918b6594144451cf4b481d392c9a0a463::token_a::TOKEN_A

sui client ptb \
--move-call $PACKAGE::minter::create_and_start_passive_fee_distributor "<$FULLSAIL_TOKEN_TYPE,$PASSIVE_FEE_COIN>" @$MINTER @$MINTER_ADMIN_CAP @$VOTING_ESCROW @$DISTRIBUTION_CONFIG @$CLOCK \
--assign passive_fee_distributor \
--move-call sui::transfer::public_share_object "<0x1b7c61939e96522ff8b36cd5ad1c971684e885422c30d65fbe2ffa08c318aee1::passive_fee_distributor::PassiveFeeDistributor<$PASSIVE_FEE_COIN>>" passive_fee_distributor

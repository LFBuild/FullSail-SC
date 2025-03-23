#mainnet
#these adresses should be updated after calling each of the scripts
export ADDR=$(sui client active-address)

export PACKAGE=0x56e79fddd96ef2a0710f52edcb6025dbdf6d85b0029c8d599429da518bed0509
export FULLSAIL_TOKEN_TYPE="$PACKAGE::fullsail_token::FULLSAIL_TOKEN"
export FULLSAIL_TOKEN_MITER_CAP=0x167bccfaf9327670acd5fd96eb18b8708ab89afcf5f1c364e64f6d2d426d95e6

# use setup_distribution.sh script in integrate directory to create minter, voter and voting_escrow.
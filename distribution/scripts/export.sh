#mainnet
#these adresses should be updated after calling each of the scripts
export ADDR=$(sui client active-address)

export PACKAGE=0xfc42c50c11c4d6abfbb36d1d38e1023140d610e68c5ca1b8caff7cd6c0b405cb
export FULLSAIL_TOKEN_TYPE="$PACKAGE::sail_token::SAIL_TOKEN"
export FULLSAIL_TOKEN_MITER_CAP=0x525caec1822c762caa53a43429a868fffd966be870437c128b0c58758e0ed63e

# use setup_distribution.sh script in integrate directory to create minter, voter and voting_escrow.
source ./export.sh

export PENALTY_PACKAGE=0xdf673038eeb45331496ee9d5241be2b57302518d77e8816a3049aac47eff8fd2
export CREATE_CAP=0x8b85e71b4630fe730f0e348d96024d0173dda528498f4491e6a8ebdc32ade08a
# ETH/USDC port
# export PORT="0x320ca75b93419d306bfc5db266952e52fb5c81b5ad05372039123a7822b1d0ea"
# SUI/USDC port
export PORT="0x9787a95e76530f80ff8e8dd4a851a2a266b3eadcca4e6503c6d6fa18d8129ccc"

sui client ptb \
--move-call $PENALTY_PACKAGE::penalty_cap::create_penalty_cap @$CREATE_CAP \
--assign penalty_cap \
--move-call $PACKAGE::port::add_penalty_cap @$PORT @$VAULT_CONFIG penalty_cap
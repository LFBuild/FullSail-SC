source ./export.sh

export VE_AIRDROP_ID=
export WITHDRAW_CAP=
export ADDRESS=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

sui client ptb \
  --move-call $PACKAGE::ve_airdrop::withdraw_and_destroy "<$SAIL_TOKEN_TYPE>" @$VE_AIRDROP_ID @$WITHDRAW_CAP
  --assign remaining_coin
  --transfer-objects "[remaining_coin]" @$ADDRESS
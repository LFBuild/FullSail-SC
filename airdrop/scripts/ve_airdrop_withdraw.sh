source ./export.sh

export VE_AIRDROP_ID=0x15c5325d8f6b4308a26ab91ec046d42212b5582a22191104445554a7d810cec7
export WITHDRAW_CAP=0x4ac97b1dd52e87d36d96201f3f8759c8aa5a5c50e7797a875c9de1709af136f0
export ADDRESS=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

sui client ptb \
  --move-call $PACKAGE::ve_airdrop::withdraw_and_destroy "<$SAIL_TOKEN_TYPE>" @$VE_AIRDROP_ID @$WITHDRAW_CAP
  --assign remaining_coin
  --transfer-objects "[remaining_coin]" @$ADDRESS
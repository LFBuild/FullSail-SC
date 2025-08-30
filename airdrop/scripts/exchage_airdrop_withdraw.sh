source ./export.sh

export AMOUNT=1000000000
export ADDRESS=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

sui client ptb \
  --move-call $PACKAGE::exchange_airdrop::withdraw_unclaimed "<$COIN_IN, $SAIL_TOKEN_TYPE>" @$EXCHANGE_AIRDROP @$EXCHANGE_AIRDROP_WITHDRAW_CAP 1000000000 \
  --assign remaining_coin \
  --transfer-objects "[remaining_coin]" @$ADDRESS
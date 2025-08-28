source ./export.sh

sui client ptb --split-coins @0x7d4605c9ae06459e270ebf98a3c3cdd6c2e354f1287505a26b9549ea28cce9c9 "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::exchange_airdrop::new "<$COIN_IN, $SAIL_TOKEN_TYPE>" new_coins.0 0 --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::exchange_airdrop::ExchangeAirdrop<$COIN_IN, $SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR
source ./export.sh

sui client ptb --split-coins @0xf8cf04ceb3a40eff1b72776c7d75e24f8bd457291845c60aef32c0490d6ca971 "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::exchange_airdrop::new "<$COIN_IN, $SAIL_TOKEN_TYPE>" new_coins.0 0 --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::exchange_airdrop::ExchangeAirdrop<$COIN_IN, $SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR
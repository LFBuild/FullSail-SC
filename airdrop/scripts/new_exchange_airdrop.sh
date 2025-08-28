source ./export.sh

sui client ptb --split-coins @0xd2c445312d1c60c95184cef3c2d68092d6bb363d9b89a5d76fff8bc8d0680b81 "[1000000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::exchange_airdrop::new "<$COIN_IN, $SAIL_TOKEN_TYPE>" new_coins.0 0 --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::exchange_airdrop::ExchangeAirdrop<$COIN_IN, $SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR
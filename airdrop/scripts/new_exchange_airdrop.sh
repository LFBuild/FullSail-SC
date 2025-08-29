source ./export.sh

sui client ptb \
  --move-call $PACKAGE::exchange_airdrop::new "<$COIN_IN, $SAIL_TOKEN_TYPE>" @0x5eab2ecf4c38fd21ea8fc1a0aa4eae8224b6acfb7919e5cc752f81fc107319c4 0 --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::exchange_airdrop::ExchangeAirdrop<$COIN_IN, $SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR
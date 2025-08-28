source ./export.sh

sui client ptb --split-coins @0xa28d4aa2e04b59a5446ba26f7afd6e14b4942a10d7d4f8de70adf56227067df9 "[10]" \
  --assign new_coins \
  --move-call $PACKAGE::exchange_airdrop::get_airdrop "<$COIN_IN, $SAIL_TOKEN_TYPE>" @0x27419db41127523afa3e0b88c21f20d62f3e89213d7051a6ccd9fd9bb95b23b7 @0xae9c8d81bf309075e13876d7adba6638212fa61142d55743d8ab5175e4e87d99 new_coins.0 @$CLOCK \
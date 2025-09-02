source ./export.sh

sui client ptb --split-coins @0xf8cf04ceb3a40eff1b72776c7d75e24f8bd457291845c60aef32c0490d6ca971 "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[242,  58,  53,  86,  37, 215, 205, 194,  24, 119, 112, 171, 103,   2, 231, 248,15, 212, 146, 206, 182, 224,  77, 241,82,  30, 190, 178, 168,   2,  67, 236] 1756342500000 @$CLOCK --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop
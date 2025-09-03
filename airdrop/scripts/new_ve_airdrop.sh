source ./export.sh

# !!! don't forget to put the time somewhere in the future

sui client ptb --split-coins @0xf8cf04ceb3a40eff1b72776c7d75e24f8bd457291845c60aef32c0490d6ca971 "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[37,86,32,161,11,231,36,245,142,60,82,84,208,83,49,63,221,166,142,231,45,150,4,70,43,236,11,67,33,84,127,97] 1756857566606 @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR

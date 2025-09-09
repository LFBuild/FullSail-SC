source ./export.sh

# !!! don't forget to put the time somewhere in the future

sui client ptb --split-coins @0xf8cf04ceb3a40eff1b72776c7d75e24f8bd457291845c60aef32c0490d6ca971 "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[216,161,170,150,9,242,1,217,216,211,190,20,198,85,9,245,167,106,175,60,246,91,128,86,157,42,113,219,21,130,236,168] 1757292109000 @$CLOCK \
  --assign airdrop \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop.0 \
  --transfer-objects "[airdrop.1]" @$ADDR

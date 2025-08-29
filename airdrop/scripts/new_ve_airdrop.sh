source ./export.sh

sui client ptb --split-coins @0xe1987f11b3b24cfdd0890f0446002468f18dc9b7bf7b1c4af9e3038155653b1f "[100000000000]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[242,  58,  53,  86,  37, 215, 205, 194,  24, 119, 112, 171, 103,   2, 231, 248,15, 212, 146, 206, 182, 224,  77, 241,82,  30, 190, 178, 168,   2,  67, 236] 1756342500000 @$CLOCK \
  --assign airdrop \
  --transfer-objects "[airdrop.1]" @0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop.0
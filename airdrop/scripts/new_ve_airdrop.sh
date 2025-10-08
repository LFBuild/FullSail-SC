source ./export.sh

# !!! don't forget to put the time somewhere in the future

sui client ptb \
  --sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
  --split-coins @0xef1835311f0d615bf11b2aa2068231e724a8809080ad923393adfe867f929cf0 "[10606133427]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[95,239,101,206,139,229,102,153,71,66,133,58,79,40,139,190,250,93,219,41,73,17,20,12,72,182,191,132,233,104,244,102] 1759981510474 @$CLOCK \
  --assign airdrop \
  --transfer-objects "[airdrop.1]" @0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967 \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop.0
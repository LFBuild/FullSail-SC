source ./export.sh

# !!! don't forget to put the time somewhere in the future

sui client ptb \
  --sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
  --split-coins @0xef1835311f0d615bf11b2aa2068231e724a8809080ad923393adfe867f929cf0 "[63524000000]" \
  --assign new_coins \
  --move-call $PACKAGE::ve_airdrop::new "<$SAIL_TOKEN_TYPE>" new_coins.0 vector[145,10,137,117,161,56,232,197,109,140,219,204,233,162,156,114,168,113,209,77,3,195,48,170,41,50,247,154,99,114,66,104] 1760498037271 @$CLOCK \
  --assign airdrop \
  --transfer-objects "[airdrop.1]" @0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967 \
  --move-call  sui::transfer::public_share_object "<$PACKAGE::ve_airdrop::VeAirdrop<$SAIL_TOKEN_TYPE>>" airdrop.0
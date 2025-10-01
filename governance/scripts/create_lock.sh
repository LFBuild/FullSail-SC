source ./export.sh

sui client ptb \
  --sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
  --split-coins @0xef1835311f0d615bf11b2aa2068231e724a8809080ad923393adfe867f929cf0 "[118017500000000]" \
  --assign new_coins \
  --move-call $VE_PACKAGE::voting_escrow::create_lock "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW new_coins.0 1456 true @$CLOCK
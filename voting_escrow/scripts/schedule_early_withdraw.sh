source ./export.sh

export LOCK=0x3ba5c31ef7644073ca0f8d2d642e01123211df8a4e181fb70a1113d5865e0ab1
export RECIPIENT=$(sui client active-address)

sui client ptb \
  --sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
  --move-call $PACKAGE::voting_escrow::schedule_early_withdraw "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER @$LOCK @$CLOCK \
  --assign withdraw \
  --transfer-objects "[withdraw]" @$RECIPIENT
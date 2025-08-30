export TOKEN_TYPE=0x55385931b718c0d5a2f6126eb1c265277d548da811e820710a479821ed415914::pre_sail::PRE_SAIL
export TREASURY_CAP=0x64d5e6f0a934cefd8d63828f8b776be9f2c94884c72ca87543e83200c6860906
export AMOUNT=3024912000000
export RECIPIENT=0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--move-call 0x2::coin::mint "<$TOKEN_TYPE>" @$TREASURY_CAP $AMOUNT \
--assign coin \
--transfer-objects '[coin]' @$RECIPIENT 
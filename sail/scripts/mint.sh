source ./export.sh

export AMOUNT=1000000000000000
export TO=0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--move-call 0x2::coin::mint "<$COIN_TYPE>" @$TREASURY_CAP $AMOUNT \
--assign coin \
--transfer-objects '[coin]' @$TO \
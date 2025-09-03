source ./export.sh

export TO=0xc3c7b01f09bfb204f93de85afa0a271e5bfabac31e566f7e997b9a8685f18967

sui client ptb --transfer-objects "[@$TREASURY_CAP]" @$TO --sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction
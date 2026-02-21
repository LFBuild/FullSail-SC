source ./export.sh

export UNRESTRICTED_ADDRESS=0xc2c7a6d112b07a68e6ecf8c5e6275c007589d40a87debbba155efc134ba2b6e1

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --gas-price 600 --serialize-unsigned-transaction \
--move-call $PACKAGE::distribution_config::add_unrestricted_address @$DISTRIBUTION_CONFIG @$DISTRIBUTION_CONFIG_PUBLISHER @$UNRESTRICTED_ADDRESS

source ./export.sh

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--move-call $VE_PACKAGE::voting_escrow::set_package_version "<$FULLSAIL_TOKEN_TYPE>" @$VOTING_ESCROW @$VOTING_ESCROW_PUBLISHER 2 \
--move-call $PACKAGE::distribution_config::set_package_version @$DISTRIBUTION_CONFIG @$DISTRIBUTION_CONFIG_PUBLISHER 3
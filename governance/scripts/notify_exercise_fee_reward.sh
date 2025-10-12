source ./export.sh

export EXERCISE_FEE_COIN=0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL
export COIN=0x74ab079317bdb358f1997bd4f7fecc83bb58b603744360030e2c9c1487d2707c

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--move-call $PACKAGE::minter::notify_exercise_fee_reward "<$FULLSAIL_TOKEN_TYPE,$EXERCISE_FEE_COIN>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP @$COIN @$CLOCK
source ./export.sh

export EXERCISE_FEE_COIN=0x1d4a2bdbc1602a0adaa98194942c220202dcc56bb0a205838dfaa63db0d5497e::SAIL::SAIL
export COIN=0x526c8090eb3358447138497a73898cc9202c7d9d526faf5fc885f85273f8d28e

sui client ptb \
--sender @0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas-coin @0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction \
--split-coins @$COIN "[1612790000000]" \
--assign new_coins \
--move-call $PACKAGE::minter::notify_exercise_fee_reward "<$FULLSAIL_TOKEN_TYPE,$EXERCISE_FEE_COIN>" @$MINTER @$VOTER @$DISTRIBUTION_CONFIG @$DISTRIBUTE_GOVERNOR_CAP new_coins.0 @$CLOCK
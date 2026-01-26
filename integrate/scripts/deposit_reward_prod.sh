source ./export.sh

export TOTAL_REWARD_AMOUNT=2000000000000 # set the total reward amount
export COIN_ID=0xba0b5fef30e197f53af775d0c9130f4a881c855bfc4d22fd1ab715c76eeaa25d

export REWARD_TOKEN_TYPE=0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI

sui client call \
  --package $PACKAGE \
  --module rewarder_script \
  --function deposit_reward \
  --type-args $REWARD_TOKEN_TYPE \
  --args \
    $GLOBAL_CONFIG \
    $REWARDER_GLOBAL_VAULT \
    "[$COIN_ID]" \
    $TOTAL_REWARD_AMOUNT
  # --sender 0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas 0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction
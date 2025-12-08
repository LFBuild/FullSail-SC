source ./export.sh

export TOTAL_REWARD_AMOUNT=6000000000000 # set the total reward amount
export COIN_ID=0x5daebe4bdda1e49563617e85b248c769960ff0bec87819d6f3a926c0e1462f12

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
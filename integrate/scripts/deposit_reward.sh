source ./export.sh

export TOTAL_REWARD_AMOUNT=6000000000000 # set the total reward amount
export COIN_ID=0xf4d73af2d53b033dfaa6a594c3725cc4a4bdf1cd7d01cb0853319b76214cf928

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
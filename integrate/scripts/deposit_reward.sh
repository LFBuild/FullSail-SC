source ./export.sh

export TOTAL_REWARD_AMOUNT=501404000000 # set the total reward amount
export COIN_ID=0x71dd5684f4ac1dceb2621b6d5c514d03c30530bd6fd0e8e27b901708d1fe1300

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
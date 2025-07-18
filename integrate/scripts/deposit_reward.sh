source ./export.sh

export TOTAL_REWARD_AMOUNT=10000000000 # set the total reward amount
export COIN_ID=0x0000000000000000000000000000000000000000000000000000000000000000

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
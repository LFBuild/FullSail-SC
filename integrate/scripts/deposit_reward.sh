source ./export.sh

export TOTAL_REWARD_AMOUNT=2500000000000 # set the total reward amount
export COIN_ID=0xb8284f585c41a9fe029b3a6eb97c95ad3bf8ff108110f0f8b4d0f2f750466b3c

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
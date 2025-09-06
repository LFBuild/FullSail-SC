source ./export.sh

export TOTAL_REWARD_AMOUNT=80000000000 # set the total reward amount
export COIN_ID=0x9ef638f3f6bc4751b44317c3677c254bfe1c3a2ee9d83c736ea2296477107ca1

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
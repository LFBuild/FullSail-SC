source ./export.sh

export TOTAL_REWARD_AMOUNT=3500000000000 # set the total reward amount
export COIN_ID=0xafb67522c6716aa0c35734d255cc7ba365a0d4c26f2cb0f3ab6dbe9a9694a5de

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
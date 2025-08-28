source ./export.sh

export TOTAL_REWARD_AMOUNT=10000000000 # set the total reward amount
export COIN_ID=0x7f9add2a5d79961cd5a9b0715a15d35d1d4ee0202bc5747863793500d4ce24cb

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
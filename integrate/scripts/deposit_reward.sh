source ./export.sh

export TOTAL_REWARD_AMOUNT=1000000000000000 # set the total reward amount
export COIN_ID=0xd1de2902b01d2da0fb960a82f7c0378054086c94d55a5042bf98c9037b703fbd

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
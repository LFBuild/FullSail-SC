source ./export.sh

export TOTAL_REWARD_AMOUNT=4500000000 # set the total reward amount
export COIN_ID=0x05a7fa98a874d0d704430e62788a43de7191b173934e11e99bcb52558e4b0dc7

export REWARD_TOKEN_TYPE=0x9420f87aeaf1cd23fa613aeebe3942d1055b4a821439a24d9a703f828aa69fc0::SAIL::SAIL

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
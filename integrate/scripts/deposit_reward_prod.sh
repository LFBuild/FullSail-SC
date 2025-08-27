export TOTAL_REWARD_AMOUNT=642857142857 # set the total reward amount
export COIN_ID=0xf8943c14d619d7570686350cfd983d15eebb1ce8e7a3c11dc22f4e92b2ddb4aa

export REWARD_TOKEN_TYPE=0xb481310100f9f9b812de1fb45b8e118f69c6b69e59145bef34b2232efdd7a8e5::sail_test::SAIL_TEST
export GLOBAL_CONFIG=0xe93baa80cb570b3a494cbf0621b2ba96bc993926d34dc92508c9446f9a05d615
export REWARDER_GLOBAL_VAULT=0xfb971d3a2fb98bde74e1c30ba15a3d8bef60a02789e59ae0b91660aeed3e64e1
export PACKAGE=0xe1b7d5fd116fea5a8f8e85c13754248d56626a8d0a614b7d916c2348d8323149

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
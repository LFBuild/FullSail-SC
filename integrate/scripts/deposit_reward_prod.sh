export TOTAL_REWARD_AMOUNT=2571426000000 # set the total reward amount
export COIN_ID=0x4f9fde1f97237fa320395361445e746985a39358af99a2e762e6c29192c40de9

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
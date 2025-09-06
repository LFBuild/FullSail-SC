export TOTAL_REWARD_AMOUNT=100000000000 # set the total reward amount
export COIN_ID=0xfe04e22223245955ef13606b7a3862d39dcaf238857d93bb7c15788dd3cebdf3

export REWARD_TOKEN_TYPE=0x55385931b718c0d5a2f6126eb1c265277d548da811e820710a479821ed415914::pre_sail::PRE_SAIL
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
    $TOTAL_REWARD_AMOUNT \
  --sender 0xfed1c619fc8dd98367a0422ca9ef53c9825e2893d78dda822106d12687888fb3 --gas 0xe6600100e23ccefd343837558242768b59dacca73b28132482e1b0ec6370c81b --gas-budget 100000000 --serialize-unsigned-transaction
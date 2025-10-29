source ./export.sh

export TOTAL_REWARD_AMOUNT=1000000000000000 # 1000k IKA
export COIN_ID=0x869459eb082d75d68f615973f6e3078c1e4b6b9d82b290ab347a6b0f5392420a

export REWARD_TOKEN_TYPE=0x7262fb2f7a3a14c888c438a3cd9b912469a58cf60f367352c46584262e8299aa::ika::IKA

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
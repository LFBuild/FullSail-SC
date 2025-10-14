source ./export.sh

export TOTAL_REWARD_AMOUNT=900000000000000 # 500k IKA
export COIN_ID=0x6f520bea7f1612b93710644465aaed2054db6d324fab8c22765fe7bbea1f4e6b

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
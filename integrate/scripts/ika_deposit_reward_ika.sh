source ./export.sh

export TOTAL_REWARD_AMOUNT=400000000000000 # 1000k IKA
export COIN_ID=0x35b1116bab6b53f963a0fa77c6f1f8aba4c639dd7627c527b8fd960e4eae2f58

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
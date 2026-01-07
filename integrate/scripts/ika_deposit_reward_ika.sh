source ./export.sh

export TOTAL_REWARD_AMOUNT=220000000000000 # 750k IKA
export COIN_ID=0xc1f3020d9251209dc23ecb2b1b4d7299ff4024d2316e0abe9a5da65488d6ebdc

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
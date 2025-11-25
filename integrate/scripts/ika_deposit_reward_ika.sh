source ./export.sh

export TOTAL_REWARD_AMOUNT=750000000000000 # 750k IKA
export COIN_ID=0x8400d78931870e8074cebe8b43710186828d0b1c612a12db98dc9106ca398e06

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
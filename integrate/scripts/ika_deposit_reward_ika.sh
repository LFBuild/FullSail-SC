source ./export.sh

export TOTAL_REWARD_AMOUNT=1000000000000000 # 750k IKA
export COIN_ID=0xa44df501747ad7da4c4cba651d4720a247960f0b494a261e8ceb2251f43cc1fd

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
source ./export.sh

export TOTAL_REWARD_AMOUNT=840000000000000 # 500k IKA
export COIN_ID=0x59d48c09b9dc56b94181515312cc2154fedf682f59acc3fc790b4b0eb0a7d988

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
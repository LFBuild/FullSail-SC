source ./export.sh

export PORT=0x4a28ac1ccf8535511d8c3421f15347ef0e04961184456f40eca227e0add81800
export NEW_REBALANCE_THRESHOLD=300

sui client ptb \
  --move-call $PACKAGE::port::update_rebalance_threshold @$PORT @$VAULT_CONFIG $NEW_REBALANCE_THRESHOLD
